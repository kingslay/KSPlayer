//
//  Decoder.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
import AVFoundation
import CoreMedia
import Libavformat

protocol TrackProtocol: MediaPlayerTrack, CustomStringConvertible {
    var stream: UnsafeMutablePointer<AVStream> { get }
    var timebase: Timebase { get }
}

extension TrackProtocol {
    var description: String { name }
    var isEnabled: Bool {
        stream.pointee.discard == AVDISCARD_DEFAULT
    }

    func setIsEnabled(_ isEnabled: Bool) {
        stream.pointee.discard = isEnabled ? AVDISCARD_DEFAULT : AVDISCARD_ALL
    }

    var isImageSubtitle: Bool {
        [AV_CODEC_ID_DVD_SUBTITLE, AV_CODEC_ID_DVB_SUBTITLE, AV_CODEC_ID_DVB_TELETEXT, AV_CODEC_ID_HDMV_PGS_SUBTITLE].contains(stream.pointee.codecpar.pointee.codec_id)
    }
}

struct AssetTrack: TrackProtocol {
    let trackID: Int32
    let name: String
    let language: String?
    let stream: UnsafeMutablePointer<AVStream>
    let mediaType: AVFoundation.AVMediaType
    let timebase: Timebase
    let nominalFrameRate: Float
    let bitRate: Int64
    let rotation: Double
    let naturalSize: CGSize
    let bitDepth: Int32
    let colorPrimaries: String?
    let transferFunction: String?
    let yCbCrMatrix: String?
    let codecType: FourCharCode
    var subtitle: SubtitleInfo?
    init?(stream: UnsafeMutablePointer<AVStream>) {
        self.stream = stream
        trackID = stream.pointee.index
        if let bitrateEntry = av_dict_get(stream.pointee.metadata, "variant_bitrate", nil, 0) ?? av_dict_get(stream.pointee.metadata, "BPS", nil, 0),
           let bitRate = Int64(String(cString: bitrateEntry.pointee.value)) {
            self.bitRate = bitRate
        } else {
            bitRate = stream.pointee.codecpar.pointee.bit_rate
        }
        let format = AVPixelFormat(rawValue: stream.pointee.codecpar.pointee.format)
        bitDepth = format.bitDepth()
        colorPrimaries = stream.pointee.codecpar.pointee.color_primaries.colorPrimaries as String?
        transferFunction = stream.pointee.codecpar.pointee.color_trc.transferFunction as String?
        yCbCrMatrix = stream.pointee.codecpar.pointee.color_space.ycbcrMatrix as String?
        codecType = stream.pointee.codecpar.pointee.codec_tag
        if stream.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
            mediaType = .audio
        } else if stream.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO {
            mediaType = .video
        } else if stream.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_SUBTITLE {
            mediaType = .subtitle
        } else {
            return nil
        }
        var timebase = Timebase(stream.pointee.time_base)
        if timebase.num <= 0 || timebase.den <= 0 {
            timebase = Timebase(num: 1, den: mediaType == .audio ? KSPlayerManager.audioPlayerSampleRate : 25000)
        }
        self.timebase = timebase
        rotation = stream.rotation
        let sar = stream.pointee.codecpar.pointee.sample_aspect_ratio.size
        naturalSize = CGSize(width: Int(stream.pointee.codecpar.pointee.width), height: Int(CGFloat(stream.pointee.codecpar.pointee.height) * sar.height / sar.width))
        let frameRate = av_guess_frame_rate(nil, stream, nil)
        if stream.pointee.duration > 0, stream.pointee.nb_frames > 0, stream.pointee.nb_frames != stream.pointee.duration {
            nominalFrameRate = Float(stream.pointee.nb_frames) * Float(timebase.den) / Float(stream.pointee.duration) * Float(timebase.num)
        } else if frameRate.den > 0, frameRate.num > 0 {
            nominalFrameRate = Float(frameRate.num) / Float(frameRate.den)
        } else {
            nominalFrameRate = mediaType == .audio ? 44 : 24
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
    }
}

protocol PlayerItemTrackProtocol: CapacityProtocol, AnyObject {
    init(assetTrack: TrackProtocol, options: KSOptions)
    // 是否无缝循环
    var isLoopModel: Bool { get set }
    var isEndOfFile: Bool { get set }
    var delegate: CodecCapacityDelegate? { get set }
    func decode()
    func seek(time: TimeInterval)
    func putPacket(packet: Packet)
    func getOutputRender(where predicate: ((MEFrame) -> Bool)?) -> MEFrame?
    func shutdown()
}

class FFPlayerItemTrack<Frame: MEFrame>: PlayerItemTrackProtocol, CustomStringConvertible {
    private let options: KSOptions
    private var seekTime = 0.0
    fileprivate var decoderMap = [Int32: DecodeProtocol]()
    fileprivate var state = MECodecState.idle
    var isEndOfFile: Bool = false {
        didSet {
            set(isEndOfFile: isEndOfFile)
        }
    }

    var packetCount: Int { 0 }
    var frameCount: Int { outputRenderQueue.count }
    let frameMaxCount: Int
    let description: String
    weak var delegate: CodecCapacityDelegate?
    let fps: Float
    let mediaType: AVFoundation.AVMediaType
    let outputRenderQueue: CircularBuffer<Frame>
    var isLoopModel = false

    required init(assetTrack: TrackProtocol, options: KSOptions) {
        self.options = options
        mediaType = assetTrack.mediaType
        description = mediaType.rawValue
        fps = assetTrack.nominalFrameRate
        // 默认缓存队列大小跟帧率挂钩,经测试除以4，最优
        if mediaType == .audio {
            let capacity = options.audioFrameMaxCount(fps: fps, channels: Int(assetTrack.stream.pointee.codecpar.pointee.channels))
            outputRenderQueue = CircularBuffer(initialCapacity: capacity, expanding: false)
        } else if mediaType == .video {
            outputRenderQueue = CircularBuffer(initialCapacity: options.videoFrameMaxCount(fps: fps), sorted: true, expanding: false)
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
            autoreleasepool {
                doDecode(packet: packet)
            }
        }
    }

    func set(isEndOfFile: Bool) {
        if isEndOfFile {
            state = .finished
        }
    }

    func getOutputRender(where predicate: ((MEFrame) -> Bool)?) -> MEFrame? {
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
            try decoder.doDecode(packet: packet.corePacket)
            if options.decodeAudioTime == 0, mediaType == .audio {
                options.decodeAudioTime = CACurrentMediaTime()
            }
            if options.decodeVideoTime == 0, mediaType == .video {
                options.decodeVideoTime = CACurrentMediaTime()
            }
        } catch {
            KSLog("Decoder did Failed : \(error)")
            state = .failed
        }
    }
}

extension FFPlayerItemTrack: DecodeResultDelegate {
    func decodeResult(frame: MEFrame?) {
        guard let frame = frame else {
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

final class AsyncPlayerItemTrack<Frame: MEFrame>: FFPlayerItemTrack<Frame> {
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
                if let loopPacketQueue = loopPacketQueue {
                    packetQueue.shutdown()
                    packetQueue = loopPacketQueue
                    self.loopPacketQueue = nil
                }
            }
        }
    }

    required init(assetTrack: TrackProtocol, options: KSOptions) {
        super.init(assetTrack: assetTrack, options: options)
        operationQueue.name = "KSPlayer_" + description
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
    }

    override func set(isEndOfFile: Bool) {
        if isEndOfFile {
            if state == .finished, frameCount == 0 {
                delegate?.codecDidFinished(track: self)
            }
        }
    }

    override func putPacket(packet: Packet) {
        if isLoopModel {
            loopPacketQueue?.push(packet)
        } else {
            packetQueue.push(packet)
        }
    }

    override func decode() {
        guard operationQueue.operationCount == 0 else { return }
        decodeOperation = BlockOperation { [weak self] in
            guard let self = self else { return }
            Thread.current.name = self.operationQueue.name
            Thread.current.stackSize = KSPlayerManager.stackSize
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
        while !decodeOperation.isCancelled {
            if state == .closed {
                decoderMap.values.forEach { $0.shutdown() }
                break
            }
            if state == .flush {
                decoderMap.values.forEach { $0.doFlushCodec() }
                state = .decoding
            } else if isEndOfFile, packetQueue.count == 0 {
                state = .finished
                break
            } else if state == .decoding {
                guard let packet = packetQueue.pop(wait: true), state != .flush, state != .closed else {
                    continue
                }
                autoreleasepool {
                    doDecode(packet: packet)
                }
            } else {
                break
            }
        }
    }

    override func seek(time: TimeInterval) {
        isEndOfFile = false
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
            } else {
                return SoftwareDecode(assetTrack: self, options: options, delegate: delegate)
            }
        }
    }
}
