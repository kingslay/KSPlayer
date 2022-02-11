//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import Libavformat
import VideoToolbox

protocol DecodeProtocol {
    init(assetTrack: TrackProtocol, options: KSOptions, delegate: DecodeResultDelegate)
    func decode()
    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws
    func doFlushCodec()
    func shutdown()
}

protocol DecodeResultDelegate: AnyObject {
    func decodeResult(frame: MEFrame?)
}

extension TrackProtocol {
    func makeDecode(options: KSOptions, delegate: DecodeResultDelegate) -> DecodeProtocol {
        autoreleasepool {
            if mediaType == .subtitle {
                return SubtitleDecode(assetTrack: self, options: options, delegate: delegate)
            } else if mediaType == .video, let session = DecompressionSession(codecpar: stream.pointee.codecpar.pointee, options: options) {
                return VideoHardwareDecode(assetTrack: self, options: options, session: session, delegate: delegate)
            } else {
                return SoftwareDecode(assetTrack: self, options: options, delegate: delegate)
            }
        }
    }
}

extension KSOptions {
    func canHardwareDecode(codecpar: AVCodecParameters) -> Bool {
        if videoFilters != nil {
            return false
        }
        if codecpar.codec_id == AV_CODEC_ID_H264, hardwareDecodeH264 {
            return true
        } else if codecpar.codec_id == AV_CODEC_ID_HEVC, VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC), hardwareDecodeH265 {
            return true
        }
        return false
    }
}

class VideoHardwareDecode: DecodeProtocol {
    private weak var delegate: DecodeResultDelegate?
    private var session: DecompressionSession?
    private let codecpar: AVCodecParameters
    private let timebase: Timebase
    private let options: KSOptions
    private var startTime = Int64(0)
    private var lastPosition = Int64(0)
    required convenience init(assetTrack: TrackProtocol, options: KSOptions, delegate: DecodeResultDelegate) {
        self.init(assetTrack: assetTrack, options: options, session: DecompressionSession(codecpar: assetTrack.stream.pointee.codecpar.pointee, options: options), delegate: delegate)
    }

    init(assetTrack: TrackProtocol, options: KSOptions, session: DecompressionSession?, delegate: DecodeResultDelegate) {
        timebase = assetTrack.timebase
        codecpar = assetTrack.stream.pointee.codecpar.pointee
        self.options = options
        self.session = session
        self.delegate = delegate
    }

    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws {
        guard let data = packet.pointee.data, let session = session else {
            delegate?.decodeResult(frame: nil)
            return
        }
        let sampleBuffer = try session.formatDescription.getSampleBuffer(isConvertNALSize: session.isConvertNALSize, data: data, size: Int(packet.pointee.size))
        let flags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
        var flagOut = VTDecodeInfoFlags.frameDropped
        let pts = packet.pointee.pts
        let packetFlags = packet.pointee.flags
        let duration = packet.pointee.duration
        let size = Int64(packet.pointee.size)
        let status = VTDecompressionSessionDecodeFrame(session.decompressionSession, sampleBuffer: sampleBuffer, flags: flags, infoFlagsOut: &flagOut) { [weak self] status, infoFlags, imageBuffer, _, _ in
            guard let self = self, status == noErr, !infoFlags.contains(.frameDropped) else {
                return
            }
            let frame = VideoVTBFrame()
            frame.corePixelBuffer = imageBuffer
            frame.timebase = self.timebase
            if packetFlags & AV_PKT_FLAG_KEY == 1, packetFlags & AV_PKT_FLAG_DISCARD != 0, self.lastPosition > 0 {
                self.startTime = self.lastPosition - pts
            }
            self.lastPosition = max(self.lastPosition, pts)
            frame.position = self.startTime + pts
            frame.duration = duration
            frame.size = size
            self.lastPosition += frame.duration
            self.delegate?.decodeResult(frame: frame)
        }
        if status == kVTInvalidSessionErr || status == kVTVideoDecoderMalfunctionErr || status == kVTVideoDecoderBadDataErr {
            if packet.pointee.flags & AV_PKT_FLAG_KEY == 1 {
                throw NSError(errorCode: .codecVideoReceiveFrame, ffmpegErrnum: status)
            } else {
                // 解决从后台切换到前台，解码失败的问题
                doFlushCodec()
            }
        }
    }

    func doFlushCodec() {
        session = DecompressionSession(codecpar: codecpar, options: options)
        lastPosition = 0
        startTime = 0
    }

    func shutdown() {
        session = nil
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
        let format = AVPixelFormat(codecpar.format)
        guard options.canHardwareDecode(codecpar: codecpar), let pixelFormatType = format.osType(), let extradata = codecpar.extradata else {
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
        let isFullRangeVideo = codecpar.color_range == AVCOL_RANGE_JPEG
        let videoCodecType = codecpar.codec_id.videoCodecType
        let dic: NSMutableDictionary = [
            kCVImageBufferChromaLocationBottomFieldKey: kCVImageBufferChromaLocation_Left,
            kCVImageBufferChromaLocationTopFieldKey: kCVImageBufferChromaLocation_Left,
            kCMFormatDescriptionExtension_FullRangeVideo: isFullRangeVideo,
            videoCodecType == kCMVideoCodecType_HEVC ? "EnableHardwareAcceleratedVideoDecoder" : "RequireHardwareAcceleratedVideoDecoder": true,
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [
                videoCodecType.avc: NSData(bytes: extradata, length: Int(extradataSize)),
            ],
        ]
        dic[kCVImageBufferPixelAspectRatioKey] = codecpar.sample_aspect_ratio.size.aspectRatio
        dic[kCVImageBufferColorPrimariesKey] = codecpar.color_primaries.colorPrimaries
        dic[kCVImageBufferTransferFunctionKey] = codecpar.color_trc.transferFunction
        dic[kCVImageBufferYCbCrMatrixKey] = codecpar.color_space.ycbcrMatrix
        // swiftlint:disable line_length
        var description: CMFormatDescription?
        var status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: videoCodecType, width: codecpar.width, height: codecpar.height, extensions: dic, formatDescriptionOut: &description)
        // swiftlint:enable line_length
        guard status == noErr, let formatDescription = description else {
            return nil
        }
        self.formatDescription = formatDescription

        let attributes: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferMetalCompatibilityKey: true,
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

extension CGSize {
    var aspectRatio: NSDictionary? {
        if width != 0, height != 0, width != height {
            return [kCVImageBufferPixelAspectRatioHorizontalSpacingKey: width,
                    kCVImageBufferPixelAspectRatioVerticalSpacingKey: height]
        } else {
            return nil
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

extension AVCodecID {
    var videoCodecType: CMVideoCodecType {
        switch self {
        case AV_CODEC_ID_H263:
            return kCMVideoCodecType_H263
        case AV_CODEC_ID_H264:
            return kCMVideoCodecType_H264
        case AV_CODEC_ID_HEVC:
            return kCMVideoCodecType_HEVC
        case AV_CODEC_ID_MPEG1VIDEO:
            return kCMVideoCodecType_MPEG1Video
        case AV_CODEC_ID_MPEG2VIDEO:
            return kCMVideoCodecType_MPEG2Video
        case AV_CODEC_ID_MPEG4:
            return kCMVideoCodecType_MPEG4Video
        default:
            return kCMVideoCodecType_H264
        }
    }
}

extension CMVideoCodecType {
    var avc: String {
        switch self {
        case kCMVideoCodecType_MPEG4Video:
            return "esds"
        case kCMVideoCodecType_H264:
            return "avcC"
        case kCMVideoCodecType_HEVC:
            return "hvcC"
        case kCMVideoCodecType_VP9:
            return "vpcC"
        default: return "avcC"
        }
    }
}

/**
 Clients who specify AVVideoColorPropertiesKey must specify a color primary, transfer function, and Y'CbCr matrix.
 Most clients will want to specify HD, which consists of:

 AVVideoColorPrimaries_ITU_R_709_2
 AVVideoTransferFunction_ITU_R_709_2
 AVVideoYCbCrMatrix_ITU_R_709_2

 If you require SD colorimetry use:

 AVVideoColorPrimaries_SMPTE_C
 AVVideoTransferFunction_ITU_R_709_2
 AVVideoYCbCrMatrix_ITU_R_601_4

 If you require wide gamut HD colorimetry, you can use:

 AVVideoColorPrimaries_P3_D65
 AVVideoTransferFunction_ITU_R_709_2
 AVVideoYCbCrMatrix_ITU_R_709_2

 If you require 10-bit wide gamut HD colorimetry, you can use:

 AVVideoColorPrimaries_P3_D65
 AVVideoTransferFunction_ITU_R_2100_HLG
 AVVideoYCbCrMatrix_ITU_R_709_2
 */
extension AVColorPrimaries {
    var colorPrimaries: CFString? {
        switch self {
        case AVCOL_PRI_BT470BG:
            return kCVImageBufferColorPrimaries_EBU_3213
        case AVCOL_PRI_SMPTE170M:
            return kCVImageBufferColorPrimaries_SMPTE_C
        case AVCOL_PRI_BT709:
            return kCVImageBufferColorPrimaries_ITU_R_709_2
        case AVCOL_PRI_BT2020:
            return kCVImageBufferColorPrimaries_ITU_R_2020
        default:
            return CVColorPrimariesGetStringForIntegerCodePoint(Int32(rawValue))?.takeUnretainedValue()
        }
    }
}

extension AVColorTransferCharacteristic {
    var transferFunction: CFString? {
        switch self {
        case AVCOL_TRC_SMPTE2084:
            return kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ
        case AVCOL_TRC_BT2020_10, AVCOL_TRC_BT2020_12:
            return kCVImageBufferTransferFunction_ITU_R_2020
        case AVCOL_TRC_BT709:
            return kCVImageBufferTransferFunction_ITU_R_709_2
        case AVCOL_TRC_SMPTE240M:
            return kCVImageBufferTransferFunction_SMPTE_240M_1995
        case AVCOL_TRC_LINEAR:
            if #available(iOS 12.0, tvOS 12.0, macOS 10.14, *) {
                return kCVImageBufferTransferFunction_Linear
            } else {
                return nil
            }
        case AVCOL_TRC_SMPTE428:
            return kCVImageBufferTransferFunction_SMPTE_ST_428_1
        case AVCOL_TRC_ARIB_STD_B67:
            return kCVImageBufferTransferFunction_ITU_R_2100_HLG
        case AVCOL_TRC_GAMMA22, AVCOL_TRC_GAMMA28:
            return kCVImageBufferTransferFunction_UseGamma
        default:
            return CVTransferFunctionGetStringForIntegerCodePoint(Int32(rawValue))?.takeUnretainedValue()
        }
    }
}

extension AVColorSpace {
    var ycbcrMatrix: CFString? {
        switch self {
        case AVCOL_SPC_BT709:
            return kCVImageBufferYCbCrMatrix_ITU_R_709_2
        case AVCOL_SPC_BT470BG, AVCOL_SPC_SMPTE170M:
            return kCVImageBufferYCbCrMatrix_ITU_R_601_4
        case AVCOL_SPC_SMPTE240M:
            return kCVImageBufferYCbCrMatrix_SMPTE_240M_1995
        case AVCOL_SPC_BT2020_CL, AVCOL_SPC_BT2020_NCL:
            return kCVImageBufferYCbCrMatrix_ITU_R_2020
        default:
            return CVYCbCrMatrixGetStringForIntegerCodePoint(Int32(rawValue))?.takeUnretainedValue()
        }
    }

    var colorSpace: CGColorSpace? {
        switch self {
        case AVCOL_SPC_BT709:
            return CGColorSpace(name: CGColorSpace.itur_709)
        case AVCOL_SPC_BT470BG, AVCOL_SPC_SMPTE170M:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case AVCOL_SPC_BT2020_CL, AVCOL_SPC_BT2020_NCL:
            return CGColorSpace(name: CGColorSpace.itur_2020)
        default:
            return nil
        }
    }
}
