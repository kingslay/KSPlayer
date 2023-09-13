//
//  FFmpegAssetTrack.swift
//  KSPlayer
//
//  Created by kintan on 2023/2/12.
//

import AVFoundation
import Libavformat

public class FFmpegAssetTrack: MediaPlayerTrack {
    public private(set) var trackID: Int32 = 0
    public var name: String = ""
    public let mediaSubType: CMFormatDescription.MediaSubType
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
    public let audioStreamBasicDescription: AudioStreamBasicDescription?
    public let audioDescriptor: AudioDescriptor?
    // subtitle
    public let isImageSubtitle: Bool
    public var delay: TimeInterval = 0
    weak var subtitle: SyncPlayerItemTrack<SubtitleFrame>?
    // video
    public private(set) var rotation: Int16 = 0
    public let naturalSize: CGSize
    public let depth: Int32
    public let fullRangeVideo: Bool
    public let colorPrimaries: String?
    public let transferFunction: String?
    public let yCbCrMatrix: String?
    public var dovi: DOVIDecoderConfigurationRecord?
    public let fieldOrder: FFmpegFieldOrder
    var closedCaptionsTrack: FFmpegAssetTrack?

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
        let frameRate = stream.pointee.avg_frame_rate
        if stream.pointee.duration > 0, stream.pointee.nb_frames > 0, stream.pointee.nb_frames != stream.pointee.duration {
            nominalFrameRate = Float(stream.pointee.nb_frames) * Float(timebase.den) / Float(stream.pointee.duration) * Float(timebase.num)
        } else if frameRate.den > 0, frameRate.num > 0 {
            nominalFrameRate = Float(frameRate.num) / Float(frameRate.den)
        } else {
            if mediaType == .audio {
                var frameSize = codecpar.frame_size
                if frameSize < 1 {
                    frameSize = timebase.den / timebase.num
                }
                nominalFrameRate = max(Float(codecpar.sample_rate / frameSize), 44)
            } else {
                nominalFrameRate = 24
            }
        }
        if codecpar.codec_type == AVMEDIA_TYPE_VIDEO {
            description += ", \(nominalFrameRate) fps"
        }
        if let value = metadata["language"] {
            language = Locale.current.localizedString(forLanguageCode: value)
        } else {
            language = nil
        }
        if let value = metadata["title"] {
            name = value
        } else {
            name = language ?? mediaType.rawValue
        }
        var info = name
        if mediaType == .subtitle {
            info += " (Embed)"
        }
        description = info + ", " + description
        //        var buf = [Int8](repeating: 0, count: 256)
        //        avcodec_string(&buf, buf.count, codecpar, 0)
    }

    init?(codecpar: AVCodecParameters) {
        self.codecpar = codecpar
        let format = AVPixelFormat(rawValue: codecpar.format)
        bitRate = codecpar.bit_rate
        depth = format.bitDepth() * Int32(format.planeCount())
        fullRangeVideo = codecpar.color_range == AVCOL_RANGE_JPEG
        colorPrimaries = codecpar.color_primaries.colorPrimaries as String?
        transferFunction = codecpar.color_trc.transferFunction as String?
        yCbCrMatrix = codecpar.color_space.ycbcrMatrix as String?
        // codec_tag byte order is LSB first
        mediaSubType = codecpar.codec_tag == 0 ? codecpar.codec_id.mediaSubType : CMFormatDescription.MediaSubType(rawValue: codecpar.codec_tag.bigEndian)
        var description = ""
        if let descriptor = avcodec_descriptor_get(codecpar.codec_id) {
            description += String(cString: descriptor.pointee.name)
            if let profile = descriptor.pointee.profiles {
                description += " (\(String(cString: profile.pointee.name)))"
            }
        }
        let sar = codecpar.sample_aspect_ratio.size
        naturalSize = CGSize(width: Int(codecpar.width), height: Int(CGFloat(codecpar.height) * sar.height / sar.width))
        fieldOrder = FFmpegFieldOrder(rawValue: UInt8(codecpar.field_order.rawValue)) ?? .unknown
        if codecpar.codec_type == AVMEDIA_TYPE_AUDIO {
            mediaType = .audio
            audioDescriptor = AudioDescriptor(codecpar: codecpar)
            let layout = codecpar.ch_layout
            let channelsPerFrame = UInt32(layout.nb_channels)
            let sampleFormat = AVSampleFormat(codecpar.format)
            let bytesPerSample = UInt32(av_get_bytes_per_sample(sampleFormat))
            let formatFlags = ((sampleFormat == AV_SAMPLE_FMT_FLT || sampleFormat == AV_SAMPLE_FMT_DBL) ? kAudioFormatFlagIsFloat : sampleFormat == AV_SAMPLE_FMT_U8 ? 0 : kAudioFormatFlagIsSignedInteger) | kAudioFormatFlagIsPacked
            audioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: Float64(codecpar.sample_rate), mFormatID: codecpar.codec_id.mediaSubType.rawValue, mFormatFlags: formatFlags, mBytesPerPacket: bytesPerSample * channelsPerFrame, mFramesPerPacket: 1, mBytesPerFrame: bytesPerSample * channelsPerFrame, mChannelsPerFrame: channelsPerFrame, mBitsPerChannel: bytesPerSample * 8, mReserved: 0)
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
            audioStreamBasicDescription = nil
            if let name = av_get_pix_fmt_name(format) {
                formatName = String(cString: name)
            } else {
                formatName = nil
            }
            description += ", \(Int(naturalSize.width))x\(Int(naturalSize.height))"
        } else if codecpar.codec_type == AVMEDIA_TYPE_SUBTITLE {
            mediaType = .subtitle
            audioStreamBasicDescription = nil
            audioDescriptor = nil
            formatName = nil
        } else {
            return nil
        }
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
            stream?.pointee.discard = newValue ? AVDISCARD_DEFAULT : AVDISCARD_ALL
        }
    }
}
