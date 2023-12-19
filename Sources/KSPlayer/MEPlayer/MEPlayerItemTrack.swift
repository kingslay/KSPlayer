//
//  Decoder.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
import AVFoundation
import CoreMedia
import Libavformat

protocol PlayerItemTrackProtocol: CapacityProtocol, AnyObject {
    init(mediaType: AVFoundation.AVMediaType, frameCapacity: UInt8, options: KSOptions)
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
    let description: String
    weak var delegate: CodecCapacityDelegate?
    let mediaType: AVFoundation.AVMediaType
    let outputRenderQueue: CircularBuffer<Frame>
    var isLoopModel = false
    var frameCount: Int { outputRenderQueue.count }
    var frameMaxCount: Int {
        outputRenderQueue.maxCount
    }

    var fps: Float {
        outputRenderQueue.fps
    }

    required init(mediaType: AVFoundation.AVMediaType, frameCapacity: UInt8, options: KSOptions) {
        self.options = options
        self.mediaType = mediaType
        description = mediaType.rawValue
        // 默认缓存队列大小跟帧率挂钩,经测试除以4，最优
        if mediaType == .audio {
            outputRenderQueue = CircularBuffer(initialCapacity: Int(frameCapacity), expanding: false)
        } else if mediaType == .video {
            outputRenderQueue = CircularBuffer(initialCapacity: Int(frameCapacity), sorted: true, expanding: false)
        } else {
            outputRenderQueue = CircularBuffer(initialCapacity: Int(frameCapacity))
        }
    }

    func decode() {
        isEndOfFile = false
        state = .decoding
    }

    func seek(time: TimeInterval) {
        if options.isAccurateSeek {
            seekTime = time
        } else {
            seekTime = 0
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

    func getOutputRender(where predicate: ((Frame, Int) -> Bool)?) -> Frame? {
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

    private var lastPacketBytes = Int32(0)
    private var lastPacketSeconds = Double(-1)
    var bitrate = Double(0)
    fileprivate func doDecode(packet: Packet) {
        if packet.isKeyFrame, packet.assetTrack.mediaType != .subtitle {
            let seconds = packet.seconds
            let diff = seconds - lastPacketSeconds
            if lastPacketSeconds < 0 || diff < 0 {
                bitrate = 0
                lastPacketBytes = 0
                lastPacketSeconds = seconds
            } else if diff > 1 {
                bitrate = Double(lastPacketBytes) / diff
                lastPacketBytes = 0
                lastPacketSeconds = seconds
            }
        }
        lastPacketBytes += packet.size
        let decoder = decoderMap.value(for: packet.assetTrack.trackID, default: makeDecode(assetTrack: packet.assetTrack))
//        var startTime = CACurrentMediaTime()
        decoder.decodeFrame(from: packet) { [weak self] result in
            guard let self else {
                return
            }
            do {
//                if packet.assetTrack.mediaType == .video {
//                    print("[video] decode time: \(CACurrentMediaTime()-startTime)")
//                    startTime = CACurrentMediaTime()
//                }
                let frame = try result.get()
                if self.state == .flush || self.state == .closed {
                    return
                }
                if self.seekTime > 0 {
                    let timestamp = frame.timestamp + frame.duration
//                    KSLog("seektime \(self.seekTime), frame \(frame.seconds), mediaType \(packet.assetTrack.mediaType)")
                    if timestamp <= 0 || frame.timebase.cmtime(for: timestamp).seconds < self.seekTime {
                        return
                    } else {
                        self.seekTime = 0.0
                    }
                }
                if let frame = frame as? Frame {
                    self.outputRenderQueue.push(frame)
                    self.outputRenderQueue.fps = packet.assetTrack.nominalFrameRate
                }
            } catch {
                KSLog("Decoder did Failed : \(error)")
                if decoder is VideoToolboxDecode {
                    decoder.shutdown()
                    self.decoderMap[packet.assetTrack.trackID] = FFmpegDecode(assetTrack: packet.assetTrack, options: self.options)
                    KSLog("VideoCodec switch to software decompression")
                    self.doDecode(packet: packet)
                } else {
                    self.state = .failed
                }
            }
        }
        if options.decodeAudioTime == 0, mediaType == .audio {
            options.decodeAudioTime = CACurrentMediaTime()
        }
        if options.decodeVideoTime == 0, mediaType == .video {
            options.decodeVideoTime = CACurrentMediaTime()
        }
    }
}

final class AsyncPlayerItemTrack<Frame: MEFrame>: SyncPlayerItemTrack<Frame> {
    private let operationQueue = OperationQueue()
    private var decodeOperation: BlockOperation!
    // 无缝播放使用的PacketQueue
    private var loopPacketQueue: CircularBuffer<Packet>?
    var packetQueue = CircularBuffer<Packet>()
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

    required init(mediaType: AVFoundation.AVMediaType, frameCapacity: UInt8, options: KSOptions) {
        super.init(mediaType: mediaType, frameCapacity: frameCapacity, options: options)
        operationQueue.name = "KSPlayer_" + mediaType.rawValue
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
    func decode()
    func decodeFrame(from packet: Packet, completionHandler: @escaping (Result<MEFrame, Error>) -> Void)
    func doFlushCodec()
    func shutdown()
}

extension SyncPlayerItemTrack {
    func makeDecode(assetTrack: FFmpegAssetTrack) -> DecodeProtocol {
        autoreleasepool {
            if mediaType == .subtitle {
                return SubtitleDecode(assetTrack: assetTrack, options: options)
            } else {
                if mediaType == .video, options.asynchronousDecompression, options.hardwareDecode,
                   let session = DecompressionSession(assetTrack: assetTrack, options: options)
                {
                    return VideoToolboxDecode(options: options, session: session)
                } else {
                    return FFmpegDecode(assetTrack: assetTrack, options: options)
                }
            }
        }
    }
}
