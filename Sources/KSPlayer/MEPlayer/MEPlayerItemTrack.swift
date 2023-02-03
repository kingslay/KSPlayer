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
    public private(set) var trackID: Int32 = 0
    public var name: String = ""
    public private(set) var language: String?
    public private(set) var nominalFrameRate: Float = 0
    public private(set) var bitRate: Int64 = 0
    public private(set) var rotation: Double = 0
    public private(set) var description: String
    public let mediaType: AVFoundation.AVMediaType
    public let naturalSize: CGSize
    public let depth: Int32
    public let fullRangeVideo: Bool
    public let colorPrimaries: String?
    public let transferFunction: String?
    public let yCbCrMatrix: String?
    public let mediaSubType: CMFormatDescription.MediaSubType
    public var dovi: DOVIDecoderConfigurationRecord?
    public let audioStreamBasicDescription: AudioStreamBasicDescription?
    public let fieldOrder: FFmpegFieldOrder
    private var stream: UnsafeMutablePointer<AVStream>?
    let isImageSubtitle: Bool
    let audioDescriptor: AudioDescriptor
    var startTime = TimeInterval(0)
    var codecpar: AVCodecParameters
    var timebase: Timebase = .defaultValue
    var subtitle: SyncPlayerItemTrack<SubtitleFrame>?
    var closedCaptionsTrack: FFmpegAssetTrack?
    convenience init?(stream: UnsafeMutablePointer<AVStream>) {
        let codecpar = stream.pointee.codecpar.pointee
        self.init(codecpar: codecpar)
        self.stream = stream
        let metadata = toDictionary(stream.pointee.metadata)
        if let value = metadata["variant_bitrate"] ?? metadata["BPS"], let bitRate = Int64(value) {
            self.bitRate = bitRate
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
            rotation = -av_display_rotation_get(matrix)
        } else {
            rotation = 0
        }
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
        if let value = metadata["language"] {
            language = NSLocalizedString(value, comment: "")
        } else {
            language = nil
        }
        if let value = metadata["title"] {
            name = value
        } else {
            name = language ?? mediaType.rawValue
        }
        description = name + ", " + description
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
        audioDescriptor = AudioDescriptor(codecpar: codecpar)
        // codec_tag byte order is LSB first
        mediaSubType = codecpar.codec_tag == 0 ? codecpar.codec_id.mediaSubType : CMFormatDescription.MediaSubType(rawValue: codecpar.codec_tag.bigEndian)
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
            description += ", \(codecpar.ch_layout.description)"
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

    public func setIsEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
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
    var seekTime = 0.0
    fileprivate let options: KSOptions
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
            let capacity = options.audioFrameMaxCount(fps: fps, channels: Int(assetTrack.audioDescriptor.channels))
            outputRenderQueue = CircularBuffer(initialCapacity: capacity, expanding: false)
        } else if mediaType == .video {
            outputRenderQueue = CircularBuffer(initialCapacity: options.videoFrameMaxCount(fps: fps), sorted: true, expanding: false)
        } else {
            outputRenderQueue = CircularBuffer()
        }
        frameMaxCount = outputRenderQueue.maxCount
    }

    func decode() {
        isEndOfFile = false
        state = .decoding
    }

    func seek(time: TimeInterval) {
        if options.isAccurateSeek {
            seekTime = time
        }
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
        let decoder = decoderMap.value(for: packet.assetTrack.trackID, default: makeDecode(assetTrack: packet.assetTrack))
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
        if seekTime > 0 {
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

extension SyncPlayerItemTrack {
    func makeDecode(assetTrack: FFmpegAssetTrack) -> DecodeProtocol {
        autoreleasepool {
            if mediaType == .subtitle {
                return SubtitleDecode(assetTrack: assetTrack, options: options, delegate: self)
            } else {
                if mediaType == .video, options.asynchronousDecompression, options.hardwareDecode,
                   let session = DecompressionSession(codecpar: assetTrack.codecpar, options: options)
                {
                    return VideoToolboxDecode(assetTrack: assetTrack, options: options, session: session, delegate: self)
                } else {
                    return FFmpegDecode(assetTrack: assetTrack, options: options, delegate: self)
                }
            }
        }
    }
}
