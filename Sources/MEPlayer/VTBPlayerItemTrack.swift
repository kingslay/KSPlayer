//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import ffmpeg
import VideoToolbox

class SamplePlayerItemTrack<Frame: MEFrame>: AsyncPlayerItemTrack<Frame>, PixelFormat {
    fileprivate var isConvertNALSize = false
    fileprivate var formatDescription: CMFormatDescription?
    var pixelFormatType: OSType = KSDefaultParameter.bufferPixelFormatType
    override func open() -> Bool {
        if setupDecompressionSession(), super.open() {
            return true
        } else {
            return false
        }
    }

    override func shutdown() {
        super.shutdown()
        destoryDecompressionSession()
    }

    fileprivate func setupDecompressionSession() -> Bool {
        guard codecpar.pointee.codec_id == AV_CODEC_ID_H264 || codecpar.pointee.codec_id == AV_CODEC_ID_HEVC,
            codecpar.pointee.format == AV_PIX_FMT_YUV420P.rawValue,
            let extradata = codecpar.pointee.extradata else {
            return false
        }
        let extradataSize = codecpar.pointee.extradata_size
        guard extradataSize >= 7, extradata[0] == 1 else {
            return false
        }

        if extradata[4] == 0xFE {
            extradata[4] = 0xFF
            isConvertNALSize = true
        }
        let dic: NSMutableDictionary = [
            kCVImageBufferChromaLocationBottomFieldKey: "left",
            kCVImageBufferChromaLocationTopFieldKey: "left",
            kCMFormatDescriptionExtension_FullRangeVideo: pixelFormatType != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [
                codecpar.pointee.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? "hvcC" : "avcC": NSData(bytes: extradata, length: Int(extradataSize)),
            ],
        ]
        if let aspectRatio = codecpar.pointee.aspectRatio {
            dic[kCVImageBufferPixelAspectRatioKey] = aspectRatio
        }
        if codecpar.pointee.color_space == AVCOL_SPC_BT709 {
            dic[kCMFormatDescriptionExtension_YCbCrMatrix] = kCMFormatDescriptionColorPrimaries_ITU_R_709_2
        }
        // codecpar.pointee.color_range == AVCOL_RANGE_JPEG kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let type = codecpar.pointee.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        // swiftlint:disable line_length
        let status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: type, width: codecpar.pointee.width, height: codecpar.pointee.height, extensions: dic, formatDescriptionOut: &formatDescription)
        // swiftlint:enable line_length
        if status != noErr {
            formatDescription = nil
        }
        return formatDescription != nil
    }

    fileprivate func destoryDecompressionSession() {
        formatDescription = nil
        isConvertNALSize = false
    }
}

final class VideoSamplePlayerItemTrack: SamplePlayerItemTrack<VideoSampleBufferFrame> {
    override func doDecode(packet: Packet) throws -> [VideoSampleBufferFrame] {
        guard let corePacket = packet.corePacket, let data = corePacket.pointee.data, let formatDescription = formatDescription else {
            return []
        }
        let sampleBuffer = try formatDescription.getSampleBuffer(isConvertNALSize: isConvertNALSize, data: data, size: Int(corePacket.pointee.size))
        let frame = VideoSampleBufferFrame()
        frame.sampleBuffer = sampleBuffer
        frame.timebase = timebase
        frame.position = corePacket.pointee.pts
        if frame.position == Int64.min || frame.position < 0 {
            frame.position = max(corePacket.pointee.dts, 0)
        }
        frame.duration = corePacket.pointee.duration
        frame.size = Int64(corePacket.pointee.size)
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [Any] {
            if let dic = attachmentsArray.first as? NSMutableDictionary {
                dic[kCMSampleAttachmentKey_DisplayImmediately] = false
                CMSampleBufferSetOutputPresentationTimeStamp(sampleBuffer, newValue: frame.cmtime)
            }
        }
        return [frame]
    }
}

final class VTBPlayerItemTrack: SamplePlayerItemTrack<VideoVTBFrame> {
    // 刷新Session的话，后续的解码还是会失败，直到遇到I帧
    private var refreshSession = false
    private var decompressionSession: VTDecompressionSession?
    override func doDecode(packet: Packet) throws -> [VideoVTBFrame] {
        guard let corePacket = packet.corePacket, let data = corePacket.pointee.data, let decompressionSession = decompressionSession, let formatDescription = formatDescription else {
            return []
        }
        let sampleBuffer = try formatDescription.getSampleBuffer(isConvertNALSize: isConvertNALSize, data: data, size: Int(corePacket.pointee.size))
        if refreshSession, corePacket.pointee.flags & AV_PKT_FLAG_KEY == 1 {
            refreshSession = false
        }
        var result = [VideoVTBFrame]()
        var error: NSError?
        let status = VTDecompressionSessionDecodeFrame(decompressionSession, sampleBuffer: sampleBuffer, flags: VTDecodeFrameFlags(rawValue: 0), infoFlagsOut: nil) { status, _, imageBuffer, _, _ in
            if status == noErr {
                if let imageBuffer = imageBuffer {
                    let frame = VideoVTBFrame()
                    frame.corePixelBuffer = imageBuffer
                    frame.timebase = self.timebase
                    frame.position = corePacket.pointee.pts
                    if frame.position == Int64.min || frame.position < 0 {
                        frame.position = max(corePacket.pointee.dts, 0)
                    }
                    frame.duration = corePacket.pointee.duration
                    frame.size = Int64(corePacket.pointee.size)
                    result.append(frame)
                }
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
                destoryDecompressionSession()
                _ = setupDecompressionSession()
                refreshSession = true
            } else if status != noErr {
                throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
            }
            return result
        }
    }

    override func doFlushCodec() {
        super.doFlushCodec()
        destoryDecompressionSession()
        _ = setupDecompressionSession()
    }

    fileprivate override func setupDecompressionSession() -> Bool {
        guard super.setupDecompressionSession(), let formatDescription = formatDescription else {
            return false
        }
        let dic: NSDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: codecpar.pointee.width,
            kCVPixelBufferHeightKey: codecpar.pointee.height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ]
        // swiftlint:disable line_length
        let status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: formatDescription, decoderSpecification: nil, imageBufferAttributes: dic, outputCallback: nil, decompressionSessionOut: &decompressionSession)
        // swiftlint:enable line_length
        if status != noErr {
            decompressionSession = nil
        }
        return decompressionSession != nil
    }

    fileprivate override func destoryDecompressionSession() {
        super.destoryDecompressionSession()
        if let decompressionSession = decompressionSession {
            VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession)
            VTDecompressionSessionInvalidate(decompressionSession)
            self.decompressionSession = nil
        }
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
