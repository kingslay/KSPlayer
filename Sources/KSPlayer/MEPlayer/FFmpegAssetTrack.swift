//
//  FFmpegAssetTrack.swift
//  KSPlayer
//
//  Created by kintan on 2023/2/12.
//

import AVFoundation
import FFmpegKit
import Libavformat
public class FFmpegAssetTrack: MediaPlayerTrack {
    public private(set) var trackID: Int32 = 0
    public var name: String = ""
    public private(set) var language: String?
    public private(set) var nominalFrameRate: Float = 0
    public private(set) var bitRate: Int64 = 0
    public private(set) var description: String
    public let mediaType: AVFoundation.AVMediaType
    public let formatName: String?
    private var stream: UnsafeMutablePointer<AVStream>?
    var startTime = TimeInterval(0)
    var codecpar: AVCodecParameters
    var timebase: Timebase = .defaultValue
    // audio
    public let audioDescriptor: AudioDescriptor?
    // subtitle
    public let isImageSubtitle: Bool
    public var delay: TimeInterval = 0
    weak var subtitle: SyncPlayerItemTrack<SubtitleFrame>?
    // video
    public private(set) var rotation: Int16 = 0
    public var dovi: DOVIDecoderConfigurationRecord?
    public let fieldOrder: FFmpegFieldOrder
    public let formatDescription: CMFormatDescription?
    var closedCaptionsTrack: FFmpegAssetTrack?
    let isConvertNALSize: Bool
    convenience init?(stream: UnsafeMutablePointer<AVStream>) {
        let codecpar = stream.pointee.codecpar.pointee
        self.init(codecpar: codecpar)
        self.stream = stream
        let metadata = toDictionary(stream.pointee.metadata)
        if let value = metadata["variant_bitrate"] ?? metadata["BPS"], let bitRate = Int64(value) {
            self.bitRate = bitRate
        }
        if bitRate > 0 {
            description += ", \(bitRate)BPS"
        }
        if stream.pointee.side_data?.pointee.type == AV_PKT_DATA_DOVI_CONF {
            dovi = stream.pointee.side_data?.pointee.data.withMemoryRebound(to: DOVIDecoderConfigurationRecord.self, capacity: 1) { $0 }.pointee
        }
        trackID = stream.pointee.index
        var timebase = Timebase(stream.pointee.time_base)
        if timebase.num <= 0 || timebase.den <= 0 {
            timebase = Timebase(num: 1, den: 1000)
        }
        self.timebase = timebase
        if let rotateTag = metadata["rotate"], rotateTag == "0" {
            rotation = 0
        } else if let displaymatrix = av_stream_get_side_data(stream, AV_PKT_DATA_DISPLAYMATRIX, nil) {
            let matrix = displaymatrix.withMemoryRebound(to: Int32.self, capacity: 1) { $0 }
            rotation = Int16(Int(-av_display_rotation_get(matrix)) % 360)
        } else {
            rotation = 0
        }

        if mediaType == .audio {
            var frameSize = codecpar.frame_size
            if frameSize < 1 {
                frameSize = timebase.den / timebase.num
            }
            nominalFrameRate = max(Float(codecpar.sample_rate / frameSize), 44)
        } else {
            let frameRate = stream.pointee.avg_frame_rate
            if stream.pointee.duration > 0, stream.pointee.nb_frames > 0, stream.pointee.nb_frames != stream.pointee.duration {
                nominalFrameRate = Float(stream.pointee.nb_frames) * Float(timebase.den) / Float(stream.pointee.duration) * Float(timebase.num)
            } else if frameRate.den > 0, frameRate.num > 0 {
                nominalFrameRate = Float(frameRate.num) / Float(frameRate.den)
            } else {
                nominalFrameRate = 24
            }
        }

        if codecpar.codec_type == AVMEDIA_TYPE_VIDEO {
            description += ", \(nominalFrameRate) fps"
        }
        language = metadata["language"]
        if let value = metadata["title"] {
            name = value
        } else {
            name = language ?? mediaType.rawValue
        }
        description = name + ", " + description
        // AV_DISPOSITION_DEFAULT
        if mediaType == .subtitle {
            isEnabled = !isImageSubtitle || stream.pointee.disposition & AV_DISPOSITION_FORCED == AV_DISPOSITION_FORCED
        }
        //        var buf = [Int8](repeating: 0, count: 256)
        //        avcodec_string(&buf, buf.count, codecpar, 0)
    }

    init?(codecpar: AVCodecParameters) {
        self.codecpar = codecpar
        bitRate = codecpar.bit_rate
        // codec_tag byte order is LSB first CMFormatDescription.MediaSubType(rawValue: codecpar.codec_tag.bigEndian)
        let codecType = codecpar.codec_id.mediaSubType
        var description = ""
        if let descriptor = avcodec_descriptor_get(codecpar.codec_id) {
            description += String(cString: descriptor.pointee.name)
            if let profile = descriptor.pointee.profiles {
                description += " (\(String(cString: profile.pointee.name)))"
            }
        }
        fieldOrder = FFmpegFieldOrder(rawValue: UInt8(codecpar.field_order.rawValue)) ?? .unknown
        var formatDescriptionOut: CMFormatDescription?
        if codecpar.codec_type == AVMEDIA_TYPE_AUDIO {
            mediaType = .audio
            audioDescriptor = AudioDescriptor(codecpar: codecpar)
            isConvertNALSize = false
            let layout = codecpar.ch_layout
            let channelsPerFrame = UInt32(layout.nb_channels)
            let sampleFormat = AVSampleFormat(codecpar.format)
            let bytesPerSample = UInt32(av_get_bytes_per_sample(sampleFormat))
            let formatFlags = ((sampleFormat == AV_SAMPLE_FMT_FLT || sampleFormat == AV_SAMPLE_FMT_DBL) ? kAudioFormatFlagIsFloat : sampleFormat == AV_SAMPLE_FMT_U8 ? 0 : kAudioFormatFlagIsSignedInteger) | kAudioFormatFlagIsPacked
            var audioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: Float64(codecpar.sample_rate), mFormatID: codecType.rawValue, mFormatFlags: formatFlags, mBytesPerPacket: bytesPerSample * channelsPerFrame, mFramesPerPacket: 1, mBytesPerFrame: bytesPerSample * channelsPerFrame, mChannelsPerFrame: channelsPerFrame, mBitsPerChannel: bytesPerSample * 8, mReserved: 0)
            _ = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioStreamBasicDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDescriptionOut)
            description += ", \(codecpar.sample_rate)Hz"
            description += ", \(codecpar.ch_layout.description)"
            if let name = av_get_sample_fmt_name(sampleFormat) {
                formatName = String(cString: name)
            } else {
                formatName = nil
            }
        } else if codecpar.codec_type == AVMEDIA_TYPE_VIDEO {
            audioDescriptor = nil
            mediaType = .video
            let sar = codecpar.sample_aspect_ratio.size
            var extradataSize = Int32(0)
            var extradata = codecpar.extradata
            let atomsData: Data?
            if let extradata {
                extradataSize = codecpar.extradata_size
                if extradataSize >= 5, extradata[4] == 0xFE {
                    extradata[4] = 0xFF
                    isConvertNALSize = true
                } else {
                    isConvertNALSize = false
                }
                atomsData = Data(bytes: extradata, count: Int(extradataSize))
            } else {
                if codecType.rawValue == kCMVideoCodecType_VP9 {
                    // ff_videotoolbox_vpcc_extradata_create
                    var ioContext: UnsafeMutablePointer<AVIOContext>?
                    guard avio_open_dyn_buf(&ioContext) == 0 else {
                        return nil
                    }
                    ff_isom_write_vpcc(nil, ioContext, nil, 0, &self.codecpar)
                    extradataSize = avio_close_dyn_buf(ioContext, &extradata)
                    guard let extradata else {
                        return nil
                    }
                    var data = Data()
                    var array: [UInt8] = [1, 0, 0, 0]
                    data.append(&array, count: 4)
                    data.append(extradata, count: Int(extradataSize))
                    atomsData = data
                } else {
                    atomsData = nil
                }
                isConvertNALSize = false
            }
            let format = AVPixelFormat(rawValue: codecpar.format)
            let fullRange = codecpar.color_range == AVCOL_RANGE_JPEG
            let dic: NSMutableDictionary = [
                kCVImageBufferChromaLocationBottomFieldKey: kCVImageBufferChromaLocation_Left,
                kCVImageBufferChromaLocationTopFieldKey: kCVImageBufferChromaLocation_Left,
                kCMFormatDescriptionExtension_Depth: format.bitDepth * Int32(format.planeCount),
                kCMFormatDescriptionExtension_FullRangeVideo: fullRange,
                codecType.rawValue == kCMVideoCodecType_HEVC ? "EnableHardwareAcceleratedVideoDecoder" : "RequireHardwareAcceleratedVideoDecoder": true,
            ]
            // kCMFormatDescriptionExtension_BitsPerComponent
            if let atomsData {
                dic[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] = [codecType.rawValue.avc: atomsData]
            }
            dic[kCVPixelBufferPixelFormatTypeKey] = format.osType(fullRange: fullRange)
            dic[kCVImageBufferPixelAspectRatioKey] = sar.aspectRatio
            dic[kCVImageBufferColorPrimariesKey] = codecpar.color_primaries.colorPrimaries as String?
            dic[kCVImageBufferTransferFunctionKey] = codecpar.color_trc.transferFunction as String?
            dic[kCVImageBufferYCbCrMatrixKey] = codecpar.color_space.ycbcrMatrix as String?
            // swiftlint:disable line_length
            _ = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: codecType.rawValue, width: codecpar.width, height: codecpar.height, extensions: dic, formatDescriptionOut: &formatDescriptionOut)
            // swiftlint:enable line_length
            if let name = av_get_pix_fmt_name(format) {
                formatName = String(cString: name)
            } else {
                formatName = nil
            }
            let naturalSize = CGSize(width: Int(codecpar.width), height: Int(CGFloat(codecpar.height) * sar.height / sar.width))
            description += ", \(Int(naturalSize.width))x\(Int(naturalSize.height))"
        } else if codecpar.codec_type == AVMEDIA_TYPE_SUBTITLE {
            mediaType = .subtitle
            audioDescriptor = nil
            formatName = nil
            isConvertNALSize = false
            _ = CMFormatDescriptionCreate(allocator: kCFAllocatorDefault, mediaType: kCMMediaType_Subtitle, mediaSubType: codecType.rawValue, extensions: nil, formatDescriptionOut: &formatDescriptionOut)
        } else {
            return nil
        }
        formatDescription = formatDescriptionOut
        if let formatName {
            description += ", \(formatName)"
        }
        if codecpar.bits_per_raw_sample != 0 {
            description += ", (\(codecpar.bits_per_raw_sample) bit)"
        }
        isImageSubtitle = [AV_CODEC_ID_DVD_SUBTITLE, AV_CODEC_ID_DVB_SUBTITLE, AV_CODEC_ID_DVB_TELETEXT, AV_CODEC_ID_HDMV_PGS_SUBTITLE].contains(codecpar.codec_id)
        self.description = description
        trackID = 0
    }

    func ceateContext(options: KSOptions) throws -> UnsafeMutablePointer<AVCodecContext> {
        try codecpar.ceateContext(options: options)
    }

    public var isEnabled: Bool {
        get {
            stream?.pointee.discard == AVDISCARD_DEFAULT
        }
        set {
            var discard = newValue ? AVDISCARD_DEFAULT : AVDISCARD_ALL
            if mediaType == .subtitle, !isImageSubtitle {
                discard = AVDISCARD_ALL
            }
            stream?.pointee.discard = discard
        }
    }
}

extension FFmpegAssetTrack {
    var pixelFormatType: OSType? {
        let format = AVPixelFormat(codecpar.format)
        return format.osType(fullRange: fullRangeVideo)
    }
}
