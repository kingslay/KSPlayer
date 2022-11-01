import FFmpeg
import Libavcodec
import Libavfilter
import Libavformat
extension UnsafeMutablePointer where Pointee == AVStream {
    var rotation: Double {
        let displaymatrix = av_stream_get_side_data(self, AV_PKT_DATA_DISPLAYMATRIX, nil)
        let rotateTag = av_dict_get(pointee.metadata, "rotate", nil, 0)
        if let rotateTag, String(cString: rotateTag.pointee.value) == "0" {
            return 0.0
        } else if let displaymatrix {
            let matrix = displaymatrix.withMemoryRebound(to: Int32.self, capacity: 1) { $0 }
            return -av_display_rotation_get(matrix)
        }
        return 0.0
    }
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
                    var framesCtx = av_hwframe_ctx_alloc(deviceCtx)
                    if let framesCtx {
                        let framesCtxData = UnsafeMutableRawPointer(framesCtx.pointee.data)
                            .bindMemory(to: AVHWFramesContext.self, capacity: 1)
                        framesCtxData.pointee.format = AV_PIX_FMT_VIDEOTOOLBOX
                        framesCtxData.pointee.sw_format = ctx.pointee.pix_fmt.bestPixelFormat()
                        framesCtxData.pointee.width = ctx.pointee.width
                        framesCtxData.pointee.height = ctx.pointee.height
                    }
                    if av_hwframe_ctx_init(framesCtx) != 0 {
                        av_buffer_unref(&framesCtx)
                        break
                    }
                    ctx.pointee.hw_frames_ctx = framesCtx
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
    mutating func ceateContext(options: KSOptions) throws -> UnsafeMutablePointer<AVCodecContext> {
        var codecContextOption = avcodec_alloc_context3(nil)
        guard let codecContext = codecContextOption else {
            throw NSError(errorCode: .codecContextCreate)
        }
        var result = avcodec_parameters_to_context(codecContext, &self)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codecContextSetParam, ffmpegErrnum: result)
        }
        if codec_type == AVMEDIA_TYPE_VIDEO, options.hardwareDecode {
            codecContext.getFormat()
        }
        guard let codec = avcodec_find_decoder(codecContext.pointee.codec_id) else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codecContextFindDecoder, ffmpegErrnum: result)
        }
        codecContext.pointee.codec_id = codec.pointee.id
        codecContext.pointee.flags2 |= AV_CODEC_FLAG2_FAST
        var lowres = options.lowres
        if lowres > codec.pointee.max_lowres {
            lowres = codec.pointee.max_lowres
        }
        codecContext.pointee.lowres = Int32(lowres)
        var avOptions = options.decoderOptions.avOptions
        if lowres > 0 {
            av_dict_set_int(&avOptions, "lowres", Int64(lowres), 0)
        }
        result = avcodec_open2(codecContext, codec, &avOptions)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codesContextOpen, ffmpegErrnum: result)
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
    func bitDepth() -> Int32 {
        let descriptor = av_pix_fmt_desc_get(self)
        return descriptor?.pointee.comp.0.depth ?? 8
    }

    func planeCount() -> UInt8 {
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

    func bestPixelFormat() -> AVPixelFormat {
        bitDepth() > 8 ? AV_PIX_FMT_P010LE : AV_PIX_FMT_NV12
    }

    // swiftlint:disable cyclomatic_complexity
    // avfoundation.m
    func osType() -> OSType? {
        switch self {
        case AV_PIX_FMT_MONOBLACK: return kCVPixelFormatType_1Monochrome
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
        case AV_PIX_FMT_BGR48BE: return kCVPixelFormatType_48RGB
        case AV_PIX_FMT_NV12: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_P010LE: return kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case AV_PIX_FMT_YUV420P10LE: return kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case AV_PIX_FMT_YUV420P: return kCVPixelFormatType_420YpCbCr8Planar
        case AV_PIX_FMT_UYVY422: return kCVPixelFormatType_422YpCbCr8
        case AV_PIX_FMT_YUYV422: return kCVPixelFormatType_422YpCbCr8_yuvs
        case AV_PIX_FMT_YUVJ420P: return kCVPixelFormatType_420YpCbCr8PlanarFullRange
        case AV_PIX_FMT_YUV422P10LE: return kCVPixelFormatType_422YpCbCr10
        case AV_PIX_FMT_YUV422P16LE: return kCVPixelFormatType_422YpCbCr16
        case AV_PIX_FMT_YUV444P: return kCVPixelFormatType_444YpCbCr8
        case AV_PIX_FMT_YUV444P10LE: return kCVPixelFormatType_444YpCbCr10
        case AV_PIX_FMT_YUVA444P: return kCVPixelFormatType_4444YpCbCrA8R
        case AV_PIX_FMT_YUVA444P16LE: return kCVPixelFormatType_4444AYpCbCr16
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
        lhs.format == rhs.format && lhs.time_base == rhs.time_base &&
            lhs.width == rhs.width && lhs.height == rhs.height && lhs.sample_aspect_ratio == rhs.sample_aspect_ratio &&
            lhs.sample_rate == rhs.sample_rate && lhs.ch_layout == rhs.ch_layout
    }

    var arg: String {
        if sample_rate > 0 {
            let fmt = String(cString: av_get_sample_fmt_name(AVSampleFormat(rawValue: format)))
            var str = [Int8](repeating: 0, count: 64)
            var chLayout = ch_layout
            _ = av_channel_layout_describe(&chLayout, &str, str.count)
            return "sample_rate=\(sample_rate):sample_fmt=\(fmt):time_base=\(time_base.num)/\(time_base.den):channels=\(ch_layout.nb_channels):channel_layout=\(String(cString: str))"
        } else {
            return "video_size=\(width)x\(height):pix_fmt=\(format):time_base=\(time_base.num)/\(time_base.den):pixel_aspect=\(sample_aspect_ratio.num)/\(sample_aspect_ratio.den)"
        }
    }
}

extension AVChannelLayout: Equatable {
    public static func == (lhs: AVChannelLayout, rhs: AVChannelLayout) -> Bool {
        lhs.nb_channels == rhs.nb_channels && lhs.order == rhs.order
    }
}

extension AVRational: Equatable {
    public static func == (lhs: AVRational, rhs: AVRational) -> Bool {
        lhs.num == rhs.num && rhs.den == rhs.den
    }
}

public extension AVError {
    static let tryAgain = AVError(code: swift_AVERROR(EAGAIN))
    static let eof = AVError(code: swift_AVERROR_EOF)
}
