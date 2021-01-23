//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import libavformat
import VideoToolbox

protocol DecodeProtocol {
    init(assetTrack: TrackProtocol, options: KSOptions)
    func decode()
    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws -> [Frame]
    func seek(time: TimeInterval)
    func doFlushCodec()
    func shutdown()
}

extension TrackProtocol {
    func makeDecode(options: KSOptions) -> DecodeProtocol {
        autoreleasepool {
            if let session = DecompressionSession(codecpar: stream.pointee.codecpar.pointee, options: options) {
                return HardwareDecode(assetTrack: self, options: options, session: session)
            } else {
                return SoftwareDecode(assetTrack: self, options: options)
            }
        }
    }
}

extension KSOptions {
    func canHardwareDecode(codecpar: AVCodecParameters) -> Bool {
        if codecpar.codec_id == AV_CODEC_ID_H264, hardwareDecodeH264 {
            return true
        } else if codecpar.codec_id == AV_CODEC_ID_HEVC, #available(iOS 11.0, tvOS 11.0, OSX 10.13, *), VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC), hardwareDecodeH265 {
            return true
        }
        return false
    }
}

class HardwareDecode: DecodeProtocol {
    private var session: DecompressionSession?
    private let codecpar: AVCodecParameters
    private let timebase: Timebase
    private let options: KSOptions
    private var startTime = Int64(0)
    private var lastPosition = Int64(0)
    required init(assetTrack: TrackProtocol, options: KSOptions) {
        timebase = assetTrack.timebase
        codecpar = assetTrack.stream.pointee.codecpar.pointee
        self.options = options
        session = DecompressionSession(codecpar: codecpar, options: options)
    }

    init(assetTrack: TrackProtocol, options: KSOptions, session: DecompressionSession) {
        timebase = assetTrack.timebase
        codecpar = assetTrack.stream.pointee.codecpar.pointee
        self.options = options
        self.session = session
    }

    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws -> [Frame] {
        guard let data = packet.pointee.data, let session = session else {
            return []
        }
        let sampleBuffer = try session.formatDescription.getSampleBuffer(isConvertNALSize: session.isConvertNALSize, data: data, size: Int(packet.pointee.size))
        var result = [VideoVTBFrame]()
        let flags = options.asynchronousDecompression ? VTDecodeFrameFlags._EnableAsynchronousDecompression : VTDecodeFrameFlags(rawValue: 0)
        var vtStatus = noErr
        let status = VTDecompressionSessionDecodeFrame(session.decompressionSession, sampleBuffer: sampleBuffer, flags: flags, infoFlagsOut: nil) { [weak self] status, _, imageBuffer, _, _ in
            vtStatus = status
            guard let self = self, status == noErr, let imageBuffer = imageBuffer else {
                return
            }
            let frame = VideoVTBFrame()
            frame.corePixelBuffer = imageBuffer
            frame.timebase = self.timebase
            let timestamp = packet.pointee.pts
            if packet.pointee.flags & AV_PKT_FLAG_KEY == 1, packet.pointee.flags & AV_PKT_FLAG_DISCARD != 0, self.lastPosition > 0 {
                self.startTime = self.lastPosition - timestamp
            }
            self.lastPosition = max(self.lastPosition, timestamp)
            frame.position = self.startTime + timestamp
            frame.duration = packet.pointee.duration
            frame.size = Int64(packet.pointee.size)
            self.lastPosition += frame.duration
            result.append(frame)
        }
        if vtStatus != noErr {
//            status == kVTInvalidSessionErr || status == kVTVideoDecoderMalfunctionErr || status == kVTVideoDecoderBadDataErr
            if packet.pointee.flags & AV_PKT_FLAG_KEY == 1 {
                throw NSError(errorCode: .codecVideoReceiveFrame, ffmpegErrnum: vtStatus)
            } else {
                // 解决从后台切换到前台，解码失败的问题
                doFlushCodec()
            }
        }
        return result
    }

    func doFlushCodec() {
        session = DecompressionSession(codecpar: codecpar, options: options)
    }

    func shutdown() {
        session = nil
    }

    func seek(time _: TimeInterval) {
        lastPosition = 0
        startTime = 0
    }

    func decode() {
        lastPosition = 0
        startTime = 0
    }
}

class DecompressionSession {
    fileprivate let isConvertNALSize: Bool
    fileprivate let formatDescription: CMFormatDescription
    fileprivate let decompressionSession: VTDecompressionSession

    init?(codecpar: AVCodecParameters, options: KSOptions) {
        let formats = [AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUV420P9BE, AV_PIX_FMT_YUV420P9LE,
                       AV_PIX_FMT_YUV420P10BE, AV_PIX_FMT_YUV420P10LE, AV_PIX_FMT_YUV420P12BE, AV_PIX_FMT_YUV420P12LE,
                       AV_PIX_FMT_YUV420P14BE, AV_PIX_FMT_YUV420P14LE, AV_PIX_FMT_YUV420P16BE, AV_PIX_FMT_YUV420P16LE]
        guard options.canHardwareDecode(codecpar: codecpar), formats.contains(AVPixelFormat(codecpar.format)), let extradata = codecpar.extradata else {
            return nil
        }
        let extradataSize = codecpar.extradata_size
        guard extradataSize >= 7, extradata[0] == 1 else {
            return nil
        }

        if extradata[4] == 0xFE {
            extradata[4] = 0xFF
            isConvertNALSize = true
        } else {
            isConvertNALSize = false
        }
        let dic: NSMutableDictionary = [
            kCVImageBufferChromaLocationBottomFieldKey: "left",
            kCVImageBufferChromaLocationTopFieldKey: "left",
            kCMFormatDescriptionExtension_FullRangeVideo: options.bufferPixelFormatType != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [
                codecpar.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? "hvcC" : "avcC": NSData(bytes: extradata, length: Int(extradataSize))
            ]
        ]
        if let aspectRatio = codecpar.aspectRatio {
            dic[kCVImageBufferPixelAspectRatioKey] = aspectRatio
        }
        if codecpar.color_space == AVCOL_SPC_BT709 {
            dic[kCMFormatDescriptionExtension_YCbCrMatrix] = kCMFormatDescriptionColorPrimaries_ITU_R_709_2
        }
        // codecpar.pointee.color_range == AVCOL_RANGE_JPEG kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let type = codecpar.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        // swiftlint:disable line_length
        var description: CMFormatDescription?
        var status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: type, width: codecpar.width, height: codecpar.height, extensions: dic, formatDescriptionOut: &description)
        // swiftlint:enable line_length
        guard status == noErr, let formatDescription = description else {
            return nil
        }
        self.formatDescription = formatDescription
        let attributes: NSDictionary = [
            kCVPixelBufferPixelFormatTypeKey: options.bufferPixelFormatType,
            kCVPixelBufferWidthKey: codecpar.width,
            kCVPixelBufferHeightKey: codecpar.height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()
        ]
        var session: VTDecompressionSession?
        // swiftlint:disable line_length
        status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: formatDescription, decoderSpecification: nil, imageBufferAttributes: attributes, outputCallback: nil, decompressionSessionOut: &session)
        // swiftlint:enable line_length
        guard status == noErr, let decompressionSession = session else {
            return nil
        }
        self.decompressionSession = decompressionSession
    }

    deinit {
        VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession)
        VTDecompressionSessionInvalidate(decompressionSession)
    }
}

extension CMFormatDescription {
    fileprivate func getSampleBuffer(isConvertNALSize: Bool, data: UnsafeMutablePointer<UInt8>, size: Int) throws -> CMSampleBuffer {
        if isConvertNALSize {
            var ioContext: UnsafeMutablePointer<AVIOContext>?
            let status = avio_open_dyn_buf(&ioContext)
            if status == 0 {
                var nalSize: UInt32 = 0
                let end = data + size
                var nalStart = data
                while nalStart < end {
                    nalSize = UInt32(nalStart[0]) << 16 | UInt32(nalStart[1]) << 8 | UInt32(nalStart[2])
                    avio_wb32(ioContext, nalSize)
                    nalStart += 3
                    avio_write(ioContext, nalStart, Int32(nalSize))
                    nalStart += Int(nalSize)
                }
                var demuxBuffer: UnsafeMutablePointer<UInt8>?
                let demuxSze = avio_close_dyn_buf(ioContext, &demuxBuffer)
                return try createSampleBuffer(data: demuxBuffer, size: Int(demuxSze))
            } else {
                throw NSError(errorCode: .codecVideoReceiveFrame, ffmpegErrnum: status)
            }
        } else {
            return try createSampleBuffer(data: data, size: size)
        }
    }

    private func createSampleBuffer(data: UnsafeMutablePointer<UInt8>?, size: Int) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        var sampleBuffer: CMSampleBuffer?
        // swiftlint:disable line_length
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: data, blockLength: size, blockAllocator: kCFAllocatorNull, customBlockSource: nil, offsetToData: 0, dataLength: size, flags: 0, blockBufferOut: &blockBuffer)
        if status == noErr {
            status = CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self, sampleCount: 1, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer)
            if let sampleBuffer = sampleBuffer {
                return sampleBuffer
            }
        }
        throw NSError(errorCode: .codecVideoReceiveFrame, ffmpegErrnum: status)
        // swiftlint:enable line_length
    }
}
