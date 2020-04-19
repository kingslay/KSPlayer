//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import ffmpeg
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
        if let session = DecompressionSession(codecpar: stream.pointee.codecpar.pointee, options: options) {
            return HardwareDecode(assetTrack: self, options: options, session: session)
        } else {
            return SoftwareDecode(assetTrack: self, options: options)
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
    // 刷新Session的话，后续的解码还是会失败，直到遇到I帧
    private var refreshSession = false
    private let options: KSOptions
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
        if refreshSession, packet.pointee.flags & AV_PKT_FLAG_KEY == 1 {
            refreshSession = false
        }
        var result = [VideoVTBFrame]()
        var error: NSError?
        let flags = options.asynchronousDecompression ? VTDecodeFrameFlags._EnableAsynchronousDecompression : VTDecodeFrameFlags(rawValue: 0)
        let status = VTDecompressionSessionDecodeFrame(session.decompressionSession, sampleBuffer: sampleBuffer, flags: flags, infoFlagsOut: nil) { [weak self] status, _, imageBuffer, _, _ in
            guard let self = self else {
                return
            }
            if status == noErr {
                guard let imageBuffer = imageBuffer else {
                    return
                }
                let frame = VideoVTBFrame()
                frame.corePixelBuffer = imageBuffer
                frame.timebase = self.timebase
                frame.position = packet.pointee.pts
                if frame.position == Int64.min || frame.position < 0 {
                    frame.position = max(packet.pointee.dts, 0)
                }
                frame.duration = packet.pointee.duration
                frame.size = Int64(packet.pointee.size)
                result.append(frame)
            } else {
                if !self.refreshSession {
                    error = .init(result: status, errorCode: .codecVideoReceiveFrame)
                }
            }
        }
        if let error = error {
            throw error
        } else {
            if status == kVTInvalidSessionErr || status == kVTVideoDecoderMalfunctionErr {
                // 解决从后台切换到前台，解码失败的问题
                doFlushCodec()
                refreshSession = true
            } else if status != noErr {
                throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
            }
            return result
        }
    }

    func doFlushCodec() {
        session = DecompressionSession(codecpar: codecpar, options: options)
    }

    func shutdown() {
        session = nil
    }

    func seek(time _: TimeInterval) {}

    func decode() {}
}

class DecompressionSession {
    fileprivate let isConvertNALSize: Bool
    fileprivate let formatDescription: CMFormatDescription
    fileprivate let decompressionSession: VTDecompressionSession

    init?(codecpar: AVCodecParameters, options: KSOptions) {
        guard options.canHardwareDecode(codecpar: codecpar), codecpar.format == AV_PIX_FMT_YUV420P.rawValue, let extradata = codecpar.extradata else {
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
                codecpar.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? "hvcC" : "avcC": NSData(bytes: extradata, length: Int(extradataSize)),
            ],
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
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
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
                    nalSize = UInt32(UInt32(nalStart[0]) << 16 | UInt32(nalStart[1]) << 8 | UInt32(nalStart[2]))
                    avio_wb32(ioContext, nalSize)
                    nalStart += 3
                    avio_write(ioContext, nalStart, Int32(nalSize))
                    nalStart += Int(nalSize)
                }
                var demuxBuffer: UnsafeMutablePointer<UInt8>?
                let demuxSze = avio_close_dyn_buf(ioContext, &demuxBuffer)
                return try createSampleBuffer(data: demuxBuffer, size: Int(demuxSze))
            } else {
                throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
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
        throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
        // swiftlint:enable line_length
    }
}
