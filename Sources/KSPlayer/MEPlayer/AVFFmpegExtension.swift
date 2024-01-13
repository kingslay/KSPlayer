import CoreMedia
import FFmpegKit
import Libavcodec
import Libavfilter
import Libavformat

func toDictionary(_ native: OpaquePointer?) -> [String: String] {
    var dict = [String: String]()
    if let native {
        var prev: UnsafeMutablePointer<AVDictionaryEntry>?
        while let tag = av_dict_get(native, "", prev, AV_DICT_IGNORE_SUFFIX) {
            dict[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            prev = tag
        }
    }
    return dict
}

extension UnsafeMutablePointer where Pointee == AVCodecContext {
    func getFormat() {
        pointee.get_format = { ctx, fmt -> AVPixelFormat in
            guard let fmt, let ctx else {
                return AV_PIX_FMT_NONE
            }
            var i = 0
            while fmt[i] != AV_PIX_FMT_NONE {
                if fmt[i] == AV_PIX_FMT_VIDEOTOOLBOX {
                    let deviceCtx = av_hwdevice_ctx_alloc(AV_HWDEVICE_TYPE_VIDEOTOOLBOX)
                    if deviceCtx == nil {
                        break
                    }
                    // 只要有hw_device_ctx就可以了。不需要hw_frames_ctx
                    ctx.pointee.hw_device_ctx = deviceCtx
//                    var framesCtx = av_hwframe_ctx_alloc(deviceCtx)
//                    if let framesCtx {
//                        let framesCtxData = UnsafeMutableRawPointer(framesCtx.pointee.data)
//                            .bindMemory(to: AVHWFramesContext.self, capacity: 1)
//                        framesCtxData.pointee.format = AV_PIX_FMT_VIDEOTOOLBOX
//                        framesCtxData.pointee.sw_format = ctx.pointee.pix_fmt.bestPixelFormat
//                        framesCtxData.pointee.width = ctx.pointee.width
//                        framesCtxData.pointee.height = ctx.pointee.height
//                    }
//                    if av_hwframe_ctx_init(framesCtx) != 0 {
//                        av_buffer_unref(&framesCtx)
//                        break
//                    }
//                    ctx.pointee.hw_frames_ctx = framesCtx
                    return fmt[i]
                }
                i += 1
            }
            return fmt[0]
        }
    }
}

extension AVCodecContext {
    func parseASSEvents() -> Int {
        var subtitleASSEvents = 10
        if subtitle_header_size > 0, let events = String(data: Data(bytes: subtitle_header, count: Int(subtitle_header_size)), encoding: .ascii), let eventsRange = events.range(of: "[Events]") {
            var range = eventsRange.upperBound ..< events.endIndex
            if let eventsRange = events.range(of: "Format:", options: String.CompareOptions(rawValue: 0), range: range, locale: nil) {
                range = eventsRange.upperBound ..< events.endIndex
                if let eventsRange = events.rangeOfCharacter(from: CharacterSet.newlines, options: String.CompareOptions(rawValue: 0), range: range) {
                    range = range.lowerBound ..< eventsRange.upperBound
                    let format = events[range]
                    let fields = format.components(separatedBy: ",")
                    let text = fields.last
                    if let text, text.trimmingCharacters(in: .whitespacesAndNewlines) == "Text" {
                        subtitleASSEvents = fields.count
                    }
                }
            }
        }
        return subtitleASSEvents
    }
}

extension AVCodecParameters {
    mutating func createContext(options: KSOptions?) throws -> UnsafeMutablePointer<AVCodecContext> {
        var codecContextOption = avcodec_alloc_context3(nil)
        guard let codecContext = codecContextOption else {
            throw NSError(errorCode: .codecContextCreate)
        }
        var result = avcodec_parameters_to_context(codecContext, &self)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codecContextSetParam, avErrorCode: result)
        }
        if codec_type == AVMEDIA_TYPE_VIDEO, options?.hardwareDecode ?? false {
            codecContext.getFormat()
        }
        guard let codec = avcodec_find_decoder(codecContext.pointee.codec_id) else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codecContextFindDecoder, avErrorCode: result)
        }
        codecContext.pointee.codec_id = codec.pointee.id
        codecContext.pointee.flags2 |= AV_CODEC_FLAG2_FAST
        if options?.codecLowDelay == true {
            codecContext.pointee.flags |= AV_CODEC_FLAG_LOW_DELAY
        }
        var avOptions = options?.decoderOptions.avOptions
        if let options {
            var lowres = options.lowres
            if lowres > codec.pointee.max_lowres {
                lowres = codec.pointee.max_lowres
            }
            codecContext.pointee.lowres = Int32(lowres)
            if lowres > 0 {
                av_dict_set_int(&avOptions, "lowres", Int64(lowres), 0)
            }
        }
        result = avcodec_open2(codecContext, codec, &avOptions)
        av_dict_free(&avOptions)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codesContextOpen, avErrorCode: result)
        }
        return codecContext
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
            return kCVImageBufferTransferFunction_Linear
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
}

extension AVChromaLocation {
    var chroma: CFString? {
        switch self {
        case AVCHROMA_LOC_LEFT:
            return kCVImageBufferChromaLocation_Left
        case AVCHROMA_LOC_CENTER:
            return kCVImageBufferChromaLocation_Center
        case AVCHROMA_LOC_TOP:
            return kCVImageBufferChromaLocation_Top
        case AVCHROMA_LOC_BOTTOM:
            return kCVImageBufferChromaLocation_Bottom
        case AVCHROMA_LOC_TOPLEFT:
            return kCVImageBufferChromaLocation_TopLeft
        case AVCHROMA_LOC_BOTTOMLEFT:
            return kCVImageBufferChromaLocation_BottomLeft
        default:
            return nil
        }
    }
}

extension AVPixelFormat {
    var bitDepth: Int32 {
        let descriptor = av_pix_fmt_desc_get(self)
        return descriptor?.pointee.comp.0.depth ?? 8
    }

    var planeCount: UInt8 {
        if let desc = av_pix_fmt_desc_get(self) {
            switch desc.pointee.nb_components {
            case 3:
                return UInt8(desc.pointee.comp.2.plane + 1)
            case 2:
                return UInt8(desc.pointee.comp.1.plane + 1)
            default:
                return UInt8(desc.pointee.comp.0.plane + 1)
            }
        } else {
            return 1
        }
    }

    var leftShift: UInt8 {
        if [AV_PIX_FMT_YUV420P10LE, AV_PIX_FMT_YUV422P10LE, AV_PIX_FMT_YUV444P10LE].contains(self) {
            return 6
        } else {
            return 0
        }
    }

    // videotoolbox_best_pixel_format
    var bestPixelFormat: AVPixelFormat {
        if let desc = av_pix_fmt_desc_get(self) {
            if desc.pointee.flags & UInt64(AV_PIX_FMT_FLAG_ALPHA) != 0 {
                return AV_PIX_FMT_AYUV64LE
            }
            let depth = desc.pointee.comp.0.depth
            if depth > 10 {
                return desc.pointee.log2_chroma_w == 0 ? AV_PIX_FMT_P416LE : AV_PIX_FMT_P216LE
            }
            if desc.pointee.log2_chroma_w == 0 {
                return depth <= 8 ? AV_PIX_FMT_NV24 : AV_PIX_FMT_P410LE
            }
            if desc.pointee.log2_chroma_h == 0 {
                return depth <= 8 ? AV_PIX_FMT_NV16 : AV_PIX_FMT_P210LE
            }
            return depth <= 8 ? AV_PIX_FMT_NV12 : AV_PIX_FMT_P010LE
        } else {
            return AV_PIX_FMT_NV12
        }
    }

    // swiftlint:disable cyclomatic_complexity
    // avfoundation.m
    func osType(fullRange: Bool = false) -> OSType? {
        switch self {
        case AV_PIX_FMT_MONOBLACK: return kCVPixelFormatType_1Monochrome
//        case AV_PIX_FMT_PAL8: return kCVPixelFormatType_32RGBA
        case AV_PIX_FMT_GRAY8: return kCVPixelFormatType_OneComponent8
        case AV_PIX_FMT_RGB555BE: return kCVPixelFormatType_16BE555
        case AV_PIX_FMT_RGB555LE: return kCVPixelFormatType_16LE555
        case AV_PIX_FMT_RGB565BE: return kCVPixelFormatType_16BE565
        case AV_PIX_FMT_RGB565LE: return kCVPixelFormatType_16LE565
        case AV_PIX_FMT_BGR24: return kCVPixelFormatType_24BGR
        case AV_PIX_FMT_RGB24: return kCVPixelFormatType_24RGB
        case AV_PIX_FMT_0RGB: return kCVPixelFormatType_32ARGB
        case AV_PIX_FMT_ARGB: return kCVPixelFormatType_32ARGB
        case AV_PIX_FMT_BGR0: return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_BGRA: return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_0BGR: return kCVPixelFormatType_32ABGR
        case AV_PIX_FMT_RGB0: return kCVPixelFormatType_32RGBA
        case AV_PIX_FMT_RGBA: return kCVPixelFormatType_32RGBA
        case AV_PIX_FMT_BGR48BE, AV_PIX_FMT_BGR48LE: return kCVPixelFormatType_48RGB
        case AV_PIX_FMT_NV12: return fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        //  AVSampleBufferDisplayLayer不能显示 kCVPixelFormatType_420YpCbCr8PlanarFullRange,所以换成是kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        case AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUVJ420P: return fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8Planar
        case AV_PIX_FMT_P010BE, AV_PIX_FMT_P010LE, AV_PIX_FMT_YUV420P10BE, AV_PIX_FMT_YUV420P10LE: return fullRange ? kCVPixelFormatType_420YpCbCr10BiPlanarFullRange : kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case AV_PIX_FMT_UYVY422: return kCVPixelFormatType_422YpCbCr8
        case AV_PIX_FMT_YUYV422: return kCVPixelFormatType_422YpCbCr8_yuvs
        case AV_PIX_FMT_NV16: return fullRange ? kCVPixelFormatType_422YpCbCr8BiPlanarFullRange : kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_YUV422P, AV_PIX_FMT_YUVJ422P: return fullRange ? kCVPixelFormatType_422YpCbCr8BiPlanarFullRange : kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_Y210BE, AV_PIX_FMT_Y210LE: return kCVPixelFormatType_422YpCbCr10
        case AV_PIX_FMT_P210BE, AV_PIX_FMT_P210LE, AV_PIX_FMT_YUV422P10BE, AV_PIX_FMT_YUV422P10LE: return fullRange ? kCVPixelFormatType_422YpCbCr10BiPlanarFullRange : kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange
        case AV_PIX_FMT_P216BE, AV_PIX_FMT_P216LE, AV_PIX_FMT_YUV422P16BE, AV_PIX_FMT_YUV422P16LE: return kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange
        case AV_PIX_FMT_NV24, AV_PIX_FMT_YUV444P: return fullRange ? kCVPixelFormatType_444YpCbCr8BiPlanarFullRange : kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_YUVA444P: return kCVPixelFormatType_4444YpCbCrA8R
        case AV_PIX_FMT_P410BE, AV_PIX_FMT_P410LE, AV_PIX_FMT_YUV444P10BE, AV_PIX_FMT_YUV444P10LE: return fullRange ? kCVPixelFormatType_444YpCbCr10BiPlanarFullRange : kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange
        case AV_PIX_FMT_P416BE, AV_PIX_FMT_P416LE: return kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange
        case AV_PIX_FMT_AYUV64BE, AV_PIX_FMT_AYUV64LE: return kCVPixelFormatType_4444AYpCbCr16
        case AV_PIX_FMT_YUVA444P16BE, AV_PIX_FMT_YUVA444P16LE: return kCVPixelFormatType_4444AYpCbCr16
        default:
            return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

extension AVCodecID {
    var mediaSubType: CMFormatDescription.MediaSubType {
        switch self {
        case AV_CODEC_ID_H263:
            return .h263
        case AV_CODEC_ID_H264:
            return .h264
        case AV_CODEC_ID_HEVC:
            return .hevc
        case AV_CODEC_ID_MPEG1VIDEO:
            return .mpeg1Video
        case AV_CODEC_ID_MPEG2VIDEO:
            return .mpeg2Video
        case AV_CODEC_ID_MPEG4:
            return .mpeg4Video
        case AV_CODEC_ID_VP9:
            return CMFormatDescription.MediaSubType(rawValue: kCMVideoCodecType_VP9)
        case AV_CODEC_ID_AAC:
            return .mpeg4AAC
        case AV_CODEC_ID_AC3:
            return .ac3
        case AV_CODEC_ID_ADPCM_IMA_QT:
            return .appleIMA4
        case AV_CODEC_ID_ALAC:
            return .appleLossless
        case AV_CODEC_ID_AMR_NB:
            return .amr
        case AV_CODEC_ID_EAC3:
            return .enhancedAC3
        case AV_CODEC_ID_GSM_MS:
            return .microsoftGSM
        case AV_CODEC_ID_ILBC:
            return .iLBC
        case AV_CODEC_ID_MP1:
            return .mpegLayer1
        case AV_CODEC_ID_MP2:
            return .mpegLayer2
        case AV_CODEC_ID_MP3:
            return .mpegLayer3
        case AV_CODEC_ID_PCM_ALAW:
            return .aLaw
        case AV_CODEC_ID_PCM_MULAW:
            return .uLaw
        case AV_CODEC_ID_QDMC:
            return .qDesign
        case AV_CODEC_ID_QDM2:
            return .qDesign2
        default:
            return CMFormatDescription.MediaSubType(rawValue: 0)
        }
    }
}

extension AVRational {
    var size: CGSize {
        num > 0 && den > 0 ? CGSize(width: Int(num), height: Int(den)) : CGSize(width: 1, height: 1)
    }
}

extension AVBufferSrcParameters: Equatable {
    public static func == (lhs: AVBufferSrcParameters, rhs: AVBufferSrcParameters) -> Bool {
        lhs.format == rhs.format && lhs.width == rhs.width && lhs.height == rhs.height && lhs.sample_aspect_ratio == rhs.sample_aspect_ratio && lhs.sample_rate == rhs.sample_rate && lhs.ch_layout == rhs.ch_layout
    }

    var arg: String {
        if sample_rate > 0 {
            let fmt = String(cString: av_get_sample_fmt_name(AVSampleFormat(rawValue: format)))
            return "sample_rate=\(sample_rate):sample_fmt=\(fmt):time_base=\(time_base.num)/\(time_base.den):channels=\(ch_layout.nb_channels):channel_layout=\(ch_layout.description)"
        } else {
            return "video_size=\(width)x\(height):pix_fmt=\(format):time_base=\(time_base.num)/\(time_base.den):pixel_aspect=\(sample_aspect_ratio.num)/\(sample_aspect_ratio.den)"
        }
    }
}

extension AVChannelLayout: Equatable {
    public static func == (lhs: AVChannelLayout, rhs: AVChannelLayout) -> Bool {
        var lhs = lhs
        var rhs = rhs
        return av_channel_layout_compare(&lhs, &rhs) == 0
    }
}

extension AVChannelLayout: CustomStringConvertible {
    static let defaultValue = AVChannelLayout(order: AV_CHANNEL_ORDER_NATIVE, nb_channels: 2, u: AVChannelLayout.__Unnamed_union_u(mask: swift_AV_CH_LAYOUT_STEREO), opaque: nil)
    var layoutTag: AudioChannelLayoutTag? {
        KSLog("[audio] FFmepg AVChannelLayout: \(self) order: \(order) mask: \(u.mask)")
        let tag = layoutMapTuple.first { _, mask in
            u.mask == mask
        }?.tag
        if let tag {
            return tag
        } else {
            KSLog("[audio] can not find AudioChannelLayoutTag FFmepg channelLayout: \(self) order: \(order) mask: \(u.mask)")
            return nil
        }
    }

    public var description: String {
        var channelLayout = self
        var str = [Int8](repeating: 0, count: 64)
        _ = av_channel_layout_describe(&channelLayout, &str, str.count)
        return String(cString: str)
    }
}

extension AVRational: Equatable {
    public static func == (lhs: AVRational, rhs: AVRational) -> Bool {
        lhs.num == rhs.num && rhs.den == rhs.den
    }
}

public struct AVError: Error, Equatable {
    public var code: Int32
    public var message: String

    init(code: Int32) {
        self.code = code
        message = String(avErrorCode: code)
    }
}

extension Dictionary where Key == String {
    var avOptions: OpaquePointer? {
        var avOptions: OpaquePointer?
        forEach { key, value in
            if let i = value as? Int64 {
                av_dict_set_int(&avOptions, key, i, 0)
            } else if let i = value as? Int {
                av_dict_set_int(&avOptions, key, Int64(i), 0)
            } else if let string = value as? String {
                av_dict_set(&avOptions, key, string, 0)
            } else if let dic = value as? Dictionary {
                let string = dic.map { "\($0.0)=\($0.1)" }.joined(separator: "\r\n")
                av_dict_set(&avOptions, key, string, 0)
            } else if let array = value as? [String] {
                let string = array.joined(separator: "+")
                av_dict_set(&avOptions, key, string, 0)
            }
        }
        return avOptions
    }
}

extension String {
    init(avErrorCode code: Int32) {
        let buf = UnsafeMutablePointer<Int8>.allocate(capacity: Int(AV_ERROR_MAX_STRING_SIZE))
        buf.initialize(repeating: 0, count: Int(AV_ERROR_MAX_STRING_SIZE))
        defer { buf.deallocate() }
        self = String(cString: av_make_error_string(buf, Int(AV_ERROR_MAX_STRING_SIZE), code))
    }
}

extension NSError {
    convenience init(errorCode: KSPlayerErrorCode, avErrorCode: Int32) {
        let underlyingError = AVError(code: avErrorCode)
        self.init(errorCode: errorCode, userInfo: [NSUnderlyingErrorKey: underlyingError])
    }
}

public extension AVError {
    /// Resource temporarily unavailable
    static let tryAgain = AVError(code: swift_AVERROR(EAGAIN))
    /// Invalid argument
    static let invalidArgument = AVError(code: swift_AVERROR(EINVAL))
    /// Cannot allocate memory
    static let outOfMemory = AVError(code: swift_AVERROR(ENOMEM))
    /// The value is out of range
    static let outOfRange = AVError(code: swift_AVERROR(ERANGE))
    /// The value is not valid
    static let invalidValue = AVError(code: swift_AVERROR(EINVAL))
    /// Function not implemented
    static let noSystem = AVError(code: swift_AVERROR(ENOSYS))

    /// Bitstream filter not found
    static let bitstreamFilterNotFound = AVError(code: swift_AVERROR_BSF_NOT_FOUND)
    /// Internal bug, also see `bug2`
    static let bug = AVError(code: swift_AVERROR_BUG)
    /// Buffer too small
    static let bufferTooSmall = AVError(code: swift_AVERROR_BUFFER_TOO_SMALL)
    /// Decoder not found
    static let decoderNotFound = AVError(code: swift_AVERROR_DECODER_NOT_FOUND)
    /// Demuxer not found
    static let demuxerNotFound = AVError(code: swift_AVERROR_DEMUXER_NOT_FOUND)
    /// Encoder not found
    static let encoderNotFound = AVError(code: swift_AVERROR_ENCODER_NOT_FOUND)
    /// End of file
    static let eof = AVError(code: swift_AVERROR_EOF)
    /// Immediate exit was requested; the called function should not be restarted
    static let exit = AVError(code: swift_AVERROR_EXIT)
    /// Generic error in an external library
    static let external = AVError(code: swift_AVERROR_EXTERNAL)
    /// Filter not found
    static let filterNotFound = AVError(code: swift_AVERROR_FILTER_NOT_FOUND)
    /// Invalid data found when processing input
    static let invalidData = AVError(code: swift_AVERROR_INVALIDDATA)
    /// Muxer not found
    static let muxerNotFound = AVError(code: swift_AVERROR_MUXER_NOT_FOUND)
    /// Option not found
    static let optionNotFound = AVError(code: swift_AVERROR_OPTION_NOT_FOUND)
    /// Not yet implemented in FFmpeg, patches welcome
    static let patchWelcome = AVError(code: swift_AVERROR_PATCHWELCOME)
    /// Protocol not found
    static let protocolNotFound = AVError(code: swift_AVERROR_PROTOCOL_NOT_FOUND)
    /// Stream not found
    static let streamNotFound = AVError(code: swift_AVERROR_STREAM_NOT_FOUND)
    /// This is semantically identical to `bug`. It has been introduced in Libav after our `bug` and
    /// with a modified value.
    static let bug2 = AVError(code: swift_AVERROR_BUG2)
    /// Unknown error, typically from an external library
    static let unknown = AVError(code: swift_AVERROR_UNKNOWN)
    ///  Requested feature is flagged experimental. Set strict_std_compliance if you really want to use it.
    static let experimental = AVError(code: swift_AVERROR_EXPERIMENTAL)
    /// Input changed between calls. Reconfiguration is required. (can be OR-ed with `outputChanged`)
    static let inputChanged = AVError(code: swift_AVERROR_INPUT_CHANGED)
    /// Output changed between calls. Reconfiguration is required. (can be OR-ed with `inputChanged`)
    static let outputChanged = AVError(code: swift_AVERROR_OUTPUT_CHANGED)

    /* HTTP & RTSP errors */
    static let httpBadRequest = AVError(code: swift_AVERROR_HTTP_BAD_REQUEST)
    static let httpUnauthorized = AVError(code: swift_AVERROR_HTTP_UNAUTHORIZED)
    static let httpForbidden = AVError(code: swift_AVERROR_HTTP_FORBIDDEN)
    static let httpNotFound = AVError(code: swift_AVERROR_HTTP_NOT_FOUND)
    static let httpOther4xx = AVError(code: swift_AVERROR_HTTP_OTHER_4XX)
    static let httpServerError = AVError(code: swift_AVERROR_HTTP_SERVER_ERROR)
}
