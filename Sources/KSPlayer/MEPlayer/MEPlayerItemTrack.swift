//
//  Decoder.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
import AVFoundation
import CoreMedia
import Libavformat

public class FFmpegAssetTrack: MediaPlayerTrack {
    var startTime: TimeInterval
    public let trackID: Int32
    public let name: String
    public let language: String?
    let stream: UnsafeMutablePointer<AVStream>
    public let mediaType: AVFoundation.AVMediaType
    let timebase: Timebase
    public let nominalFrameRate: Float
    public let bitRate: Int64
    public let rotation: Double
    public let naturalSize: CGSize
    public let depth: Int32
    public let fullRangeVideo: Bool
    public let colorPrimaries: String?
    public let transferFunction: String?
    public let yCbCrMatrix: String?
    public let mediaSubType: CMFormatDescription.MediaSubType
    var subtitle: SyncPlayerItemTrack<SubtitleFrame>?
    public var dovi: DOVIDecoderConfigurationRecord?
    public let audioStreamBasicDescription: AudioStreamBasicDescription?
    public let fieldOrder: FFmpegFieldOrder
    public let description: String
    init?(stream: UnsafeMutablePointer<AVStream>) {
        self.stream = stream
        trackID = stream.pointee.index
        var codecpar = stream.pointee.codecpar.pointee
        if let bitrateEntry = av_dict_get(stream.pointee.metadata, "variant_bitrate", nil, 0) ?? av_dict_get(stream.pointee.metadata, "BPS", nil, 0),
           let bitRate = Int64(String(cString: bitrateEntry.pointee.value))
        {
            self.bitRate = bitRate
        } else {
            bitRate = codecpar.bit_rate
        }
        let format = AVPixelFormat(rawValue: codecpar.format)
        depth = format.bitDepth() * Int32(format.planeCount())
        fullRangeVideo = codecpar.color_range == AVCOL_RANGE_JPEG
        colorPrimaries = codecpar.color_primaries.colorPrimaries as String?
        transferFunction = codecpar.color_trc.transferFunction as String?
        yCbCrMatrix = codecpar.color_space.ycbcrMatrix as String?

        // codec_tag byte order is LSB first
        mediaSubType = codecpar.codec_tag == 0 ? codecpar.codec_id.mediaSubType : CMFormatDescription.MediaSubType(rawValue: codecpar.codec_tag.bigEndian)
        if stream.pointee.side_data?.pointee.type == AV_PKT_DATA_DOVI_CONF {
            dovi = stream.pointee.side_data?.pointee.data.withMemoryRebound(to: DOVIDecoderConfigurationRecord.self, capacity: 1) { $0 }.pointee
        }
        var description = ""
        if let descriptor = avcodec_descriptor_get(codecpar.codec_id) {
            description += String(cString: descriptor.pointee.name)
            if let profile = descriptor.pointee.profiles {
                description += " (\(String(cString: profile.pointee.name)))"
            }
        }
        description += ", \(bitRate)BPS"
        let sar = codecpar.sample_aspect_ratio.size
        naturalSize = CGSize(width: Int(codecpar.width), height: Int(CGFloat(codecpar.height) * sar.height / sar.width))
        fieldOrder = FFmpegFieldOrder(rawValue: UInt8(codecpar.field_order.rawValue)) ?? .unknown
        if codecpar.codec_type == AVMEDIA_TYPE_AUDIO {
            mediaType = .audio
            let layout = codecpar.ch_layout
            let channelsPerFrame = UInt32(layout.nb_channels)
            let sampleFormat = AVSampleFormat(codecpar.format)
            let bytesPerSample = UInt32(av_get_bytes_per_sample(sampleFormat))
            let formatFlags = ((sampleFormat == AV_SAMPLE_FMT_FLT || sampleFormat == AV_SAMPLE_FMT_DBL) ? kAudioFormatFlagIsFloat : sampleFormat == AV_SAMPLE_FMT_U8 ? 0 : kAudioFormatFlagIsSignedInteger) | kAudioFormatFlagIsPacked
            audioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: Float64(codecpar.sample_rate), mFormatID: codecpar.codec_id.mediaSubType.rawValue, mFormatFlags: formatFlags, mBytesPerPacket: bytesPerSample * channelsPerFrame, mFramesPerPacket: 1, mBytesPerFrame: bytesPerSample * channelsPerFrame, mChannelsPerFrame: channelsPerFrame, mBitsPerChannel: bytesPerSample * 8, mReserved: 0)
            description += ", \(codecpar.sample_rate)Hz"
            var str = [Int8](repeating: 0, count: 64)
            _ = av_channel_layout_describe(&codecpar.ch_layout, &str, str.count)
            description += ", \(String(cString: str))"
            if let name = av_get_sample_fmt_name(AVSampleFormat(rawValue: codecpar.format)) {
                let fmt = String(cString: name)
                description += ", \(fmt)"
            }
        } else if codecpar.codec_type == AVMEDIA_TYPE_VIDEO {
            mediaType = .video
            audioStreamBasicDescription = nil
            if let name = av_get_pix_fmt_name(AVPixelFormat(rawValue: codecpar.format)) {
                description += ", \(String(cString: name))"
            }
            description += ", \(Int(naturalSize.width))x\(Int(naturalSize.height))"
        } else if codecpar.codec_type == AVMEDIA_TYPE_SUBTITLE {
            mediaType = .subtitle
            audioStreamBasicDescription = nil
        } else {
            return nil
        }
        var timebase = Timebase(stream.pointee.time_base)
        if timebase.num <= 0 || timebase.den <= 0 {
            timebase = Timebase(num: 1, den: mediaType == .audio ? KSOptions.audioPlayerSampleRate : 25000)
        }
        self.timebase = timebase
        if stream.pointee.start_time != Int64.min {
            startTime = TimeInterval(stream.pointee.start_time) * TimeInterval(timebase.num) / TimeInterval(timebase.den)
        } else {
            startTime = 0
        }
        rotation = stream.rotation
        let frameRate = stream.pointee.avg_frame_rate
        if stream.pointee.duration > 0, stream.pointee.nb_frames > 0, stream.pointee.nb_frames != stream.pointee.duration {
            nominalFrameRate = Float(stream.pointee.nb_frames) * Float(timebase.den) / Float(stream.pointee.duration) * Float(timebase.num)
        } else if frameRate.den > 0, frameRate.num > 0 {
            nominalFrameRate = Float(frameRate.num) / Float(frameRate.den)
        } else {
            nominalFrameRate = mediaType == .audio ? 44 : 24
        }
        if codecpar.codec_type == AVMEDIA_TYPE_VIDEO {
            description += ", \(nominalFrameRate) fps"
        }
        if let entry = av_dict_get(stream.pointee.metadata, "language", nil, 0), let title = entry.pointee.value {
            language = NSLocalizedString(String(cString: title), comment: "")
        } else {
            language = nil
        }
        if let entry = av_dict_get(stream.pointee.metadata, "title", nil, 0), let title = entry.pointee.value {
            name = String(cString: title)
        } else {
            name = language ?? mediaType.rawValue
        }
        description = name + ", " + description
//        var buf = [Int8](repeating: 0, count: 256)
//        avcodec_string(&buf, buf.count, codecpar, 0)
        self.description = description
    }

    public var isEnabled: Bool {
        get {
            stream.pointee.discard == AVDISCARD_DEFAULT
        }
        set {
            stream.pointee.discard = newValue ? AVDISCARD_DEFAULT : AVDISCARD_ALL
        }
    }

    var isImageSubtitle: Bool {
        [AV_CODEC_ID_DVD_SUBTITLE, AV_CODEC_ID_DVB_SUBTITLE, AV_CODEC_ID_DVB_TELETEXT, AV_CODEC_ID_HDMV_PGS_SUBTITLE].contains(stream.pointee.codecpar?.pointee.codec_id)
    }

    public func setIsEnabled(_ isEnabled: Bool) {
        stream.pointee.discard = isEnabled ? AVDISCARD_DEFAULT : AVDISCARD_ALL
    }
}

protocol PlayerItemTrackProtocol: CapacityProtocol, AnyObject {
    init(assetTrack: FFmpegAssetTrack, options: KSOptions)
    // 是否无缝循环
    var isLoopModel: Bool { get set }
    var isEndOfFile: Bool { get set }
    var delegate: CodecCapacityDelegate? { get set }
    func decode()
    func seek(time: TimeInterval)
    func putPacket(packet: Packet)
//    func getOutputRender<Frame: ObjectQueueItem>(where predicate: ((Frame) -> Bool)?) -> Frame?
    func shutdown()
}

class SyncPlayerItemTrack<Frame: MEFrame>: PlayerItemTrackProtocol, CustomStringConvertible {
    private let options: KSOptions
    private var seekTime = 0.0
    fileprivate var decoderMap = [Int32: DecodeProtocol]()
    fileprivate var state = MECodecState.idle {
        didSet {
            if state == .finished {
                seekTime = 0
            }
        }
    }

    var isEndOfFile: Bool = false
    var packetCount: Int { 0 }
    var frameCount: Int { outputRenderQueue.count }
    let frameMaxCount: Int
    let description: String
    weak var delegate: CodecCapacityDelegate?
    let fps: Float
    let mediaType: AVFoundation.AVMediaType
    let outputRenderQueue: CircularBuffer<Frame>
    var isLoopModel = false

    required init(assetTrack: FFmpegAssetTrack, options: KSOptions) {
        self.options = options
        options.process(assetTrack: assetTrack)
        mediaType = assetTrack.mediaType
        description = mediaType.rawValue
        fps = assetTrack.nominalFrameRate
        // 默认缓存队列大小跟帧率挂钩,经测试除以4，最优
        if mediaType == .audio {
            let capacity = options.audioFrameMaxCount(fps: fps, channels: Int(assetTrack.stream.pointee.codecpar.pointee.ch_layout.nb_channels))
            outputRenderQueue = CircularBuffer(initialCapacity: capacity, expanding: false)
        } else if mediaType == .video {
            outputRenderQueue = CircularBuffer(initialCapacity: options.videoFrameMaxCount(fps: fps), sorted: true, expanding: false)
            options.preferredFramesPerSecond = fps
        } else {
            outputRenderQueue = CircularBuffer()
        }
        frameMaxCount = outputRenderQueue.maxCount
        decoderMap[assetTrack.trackID] = assetTrack.makeDecode(options: options, delegate: self)
    }

    func decode() {
        isEndOfFile = false
        state = .decoding
    }

    func seek(time: TimeInterval) {
        seekTime = time
        isEndOfFile = false
        state = .flush
        outputRenderQueue.flush()
        isLoopModel = false
    }

    func putPacket(packet: Packet) {
        if state == .flush {
            decoderMap.values.forEach { $0.doFlushCodec() }
            state = .decoding
        }
        if state == .decoding {
            doDecode(packet: packet)
        }
    }

    func getOutputRender(where predicate: ((Frame) -> Bool)?) -> Frame? {
        let outputFecthRender = outputRenderQueue.pop(where: predicate)
        if outputFecthRender == nil {
            if state == .finished, frameCount == 0 {
                delegate?.codecDidFinished(track: self)
            }
        }
        return outputFecthRender
    }

    func shutdown() {
        if state == .idle {
            return
        }
        state = .closed
        outputRenderQueue.shutdown()
    }

    fileprivate func doDecode(packet: Packet) {
        let decoder = decoderMap.value(for: packet.assetTrack.trackID, default: packet.assetTrack.makeDecode(options: options, delegate: self))
        do {
            try decoder.doDecode(packet: packet)
            if options.decodeAudioTime == 0, mediaType == .audio {
                options.decodeAudioTime = CACurrentMediaTime()
            }
            if options.decodeVideoTime == 0, mediaType == .video {
                options.decodeVideoTime = CACurrentMediaTime()
            }
        } catch {
            KSLog("Decoder did Failed : \(error)")
            if decoder is VideoToolboxDecode {
                decoder.shutdown()
                decoderMap[packet.assetTrack.trackID] = FFmpegDecode(assetTrack: packet.assetTrack, options: options, delegate: self)
                KSLog("VideoCodec switch to software decompression")
                doDecode(packet: packet)
            } else {
                state = .failed
            }
        }
    }
}

extension SyncPlayerItemTrack: DecodeResultDelegate {
    func decodeResult(frame: MEFrame?) {
        guard let frame else {
            return
        }
        if state == .flush || state == .closed {
            return
        }
        if seekTime > 0, options.isAccurateSeek {
            let timestamp = frame.position + frame.duration
            if timestamp <= 0 || frame.timebase.cmtime(for: timestamp).seconds < seekTime {
                return
            } else {
                seekTime = 0.0
            }
        }
        if let frame = frame as? Frame {
            outputRenderQueue.push(frame)
        }
    }
}

final class AsyncPlayerItemTrack<Frame: MEFrame>: SyncPlayerItemTrack<Frame> {
    private let operationQueue = OperationQueue()
    private var decodeOperation: BlockOperation!
    // 无缝播放使用的PacketQueue
    private var loopPacketQueue: CircularBuffer<Packet>?
    private var packetQueue = CircularBuffer<Packet>()
    override var packetCount: Int { packetQueue.count }
    override var isLoopModel: Bool {
        didSet {
            if isLoopModel {
                loopPacketQueue = CircularBuffer<Packet>()
                isEndOfFile = true
            } else {
                if let loopPacketQueue {
                    packetQueue.shutdown()
                    packetQueue = loopPacketQueue
                    self.loopPacketQueue = nil
                    if decodeOperation.isFinished {
                        decode()
                    }
                }
            }
        }
    }

    required init(assetTrack: FFmpegAssetTrack, options: KSOptions) {
        super.init(assetTrack: assetTrack, options: options)
        operationQueue.name = "KSPlayer_" + description
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
    }

    override func putPacket(packet: Packet) {
        if isLoopModel {
            loopPacketQueue?.push(packet)
        } else {
            packetQueue.push(packet)
        }
    }

    override func decode() {
        isEndOfFile = false
        guard operationQueue.operationCount == 0 else { return }
        decodeOperation = BlockOperation { [weak self] in
            guard let self else { return }
            Thread.current.name = self.operationQueue.name
            Thread.current.stackSize = KSOptions.stackSize
            self.decodeThread()
        }
        decodeOperation.queuePriority = .veryHigh
        decodeOperation.qualityOfService = .userInteractive
        operationQueue.addOperation(decodeOperation)
    }

    private func decodeThread() {
        state = .decoding
        isEndOfFile = false
        decoderMap.values.forEach { $0.decode() }
        outerLoop: while !decodeOperation.isCancelled {
            switch state {
            case .idle:
                break outerLoop
            case .finished, .closed, .failed:
                decoderMap.values.forEach { $0.shutdown() }
                decoderMap.removeAll()
                break outerLoop
            case .flush:
                decoderMap.values.forEach { $0.doFlushCodec() }
                state = .decoding
            case .decoding:
                if isEndOfFile, packetQueue.count == 0 {
                    state = .finished
                } else {
                    guard let packet = packetQueue.pop(wait: true), state != .flush, state != .closed else {
                        continue
                    }
                    autoreleasepool {
                        doDecode(packet: packet)
                    }
                }
            }
        }
    }

    override func seek(time: TimeInterval) {
        if decodeOperation.isFinished {
            decode()
        }
        packetQueue.flush()
        super.seek(time: time)
        loopPacketQueue = nil
    }

    override func shutdown() {
        if state == .idle {
            return
        }
        super.shutdown()
        packetQueue.shutdown()
    }
}

public extension Dictionary {
    mutating func value(for key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        if let value = self[key] {
            return value
        } else {
            let value = defaultValue()
            self[key] = value
            return value
        }
    }
}

protocol DecodeProtocol {
    init(assetTrack: FFmpegAssetTrack, options: KSOptions, delegate: DecodeResultDelegate)
    func decode()
    func doDecode(packet: Packet) throws
    func doFlushCodec()
    func shutdown()
}

protocol DecodeResultDelegate: AnyObject {
    func decodeResult(frame: MEFrame?)
}

extension FFmpegAssetTrack {
    func makeDecode(options: KSOptions, delegate: DecodeResultDelegate) -> DecodeProtocol {
        autoreleasepool {
            if mediaType == .subtitle {
                return SubtitleDecode(assetTrack: self, options: options, delegate: delegate)
            } else {
                if mediaType == .video, options.asynchronousDecompression, options.hardwareDecode,
                   let session = DecompressionSession(codecparPtr: stream.pointee.codecpar, options: options)
                {
                    return VideoToolboxDecode(assetTrack: self, options: options, session: session, delegate: delegate)
                } else {
                    return FFmpegDecode(assetTrack: self, options: options, delegate: delegate)
                }
            }
        }
    }
}
