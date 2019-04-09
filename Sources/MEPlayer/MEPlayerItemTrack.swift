//
//  PlayerItemTrackProtocol.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
import AVFoundation
import CoreMedia
import ffmpeg
protocol PlayerItemTrackProtocol: Capacity {
    var mediaType: AVFoundation.AVMediaType { get }
    var stream: UnsafeMutablePointer<AVStream> { get }
    var isEnabled: Bool { get set }
    // 是否无缝循环
    var isLoopPlay: Bool { get set }
    var delegate: CodecCapacityDelegate? { get set }
    init(stream: UnsafeMutablePointer<AVStream>)
    func open() -> Bool
    func decode()
    func seek(time: TimeInterval)
    func endOfFile()
    func putPacket(packet: Packet)
    func getOutputRender(where predicate: ((MEFrame) -> Bool)?) -> MEFrame?
    func shutdown()
    func changeLoop()
}

extension PlayerItemTrackProtocol {
    var codecpar: UnsafeMutablePointer<AVCodecParameters> {
        return stream.pointee.codecpar
    }
}

class MEPlayerItemTrack<Frame: MEFrame>: PlayerItemTrackProtocol {
    fileprivate var state = MECodecState.idle
    fileprivate let fps: Int
    weak var delegate: CodecCapacityDelegate?
    let mediaType: AVFoundation.AVMediaType
    let stream: UnsafeMutablePointer<AVStream>
    let outputRenderQueue: ObjectQueue<Frame>
    let timebase: Timebase
    var isEnabled = true
    var isLoopPlay = false

    var isFinished: Bool {
        return state.contains(.finished)
    }

    var loadedTime: TimeInterval {
        return TimeInterval(loadedCount) / TimeInterval(fps)
//        return CMTime((packetQueue.duration + outputRenderQueue.duration) * Int64(timebase.num), timebase.den).seconds
    }

    var loadedCount: Int {
        return outputRenderQueue.count
    }

    var bufferingProgress: Int {
        return min(100, loadedCount * 100 / (fps * Int(KSPlayerManager.preferredForwardBufferDuration)))
    }

    var isPlayable: Bool {
        return true
    }

    required init(stream: UnsafeMutablePointer<AVStream>) {
        if stream.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
            mediaType = .audio
        } else if stream.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO {
            mediaType = .video
        } else {
            mediaType = .subtitle
        }
        var timebase = Timebase(stream.pointee.time_base)
        if timebase.num <= 0 || timebase.den <= 0 {
            timebase = Timebase(num: 1, den: mediaType == .audio ? KSDefaultParameter.audioPlayerSampleRate : 25000)
        }
        self.stream = stream
        self.timebase = timebase
        var fps = mediaType == .audio ? 44 : 24
        if stream.pointee.duration > 0, stream.pointee.nb_frames > 0 {
            let count = Int(stream.pointee.nb_frames * Int64(timebase.den) / (stream.pointee.duration * Int64(timebase.num)))
            fps = max(count, fps)
        }
        self.fps = fps
        // 默认缓存队列大小跟帧率挂钩,经测试除以4，最优
        if mediaType == .video {
            outputRenderQueue = ObjectQueue(maxCount: fps / 4, sortObjects: true)
        } else if mediaType == .audio {
            outputRenderQueue = ObjectQueue(maxCount: fps / 4)
        } else {
            outputRenderQueue = ObjectQueue()
        }
    }

    func open() -> Bool {
        state = .opening
        return true
    }

    func decode() {
        state = .decoding
    }

    func seek(time _: TimeInterval) {
        state.remove(.finished)
        state.insert(.flush)
        outputRenderQueue.flush()
    }

    func putPacket(packet _: Packet) {
        fatalError("Abstract method")
    }

    func getOutputRender(where predicate: ((MEFrame) -> Bool)?) -> MEFrame? {
        return outputRenderQueue.getObjectAsync(where: predicate)
    }

    func endOfFile() {
        state.insert(.finished)
    }

    func shutdown() {
        if state == .idle {
            return
        }
        state = .closed
        outputRenderQueue.shutdown()
    }

    func changeLoop() {}

    deinit {
        shutdown()
    }
}

class AsyncPlayerItemTrack<Frame: MEFrame>: MEPlayerItemTrack<Frame> {
    private let operationQueue = OperationQueue()
    private var decodeOperation: BlockOperation?
    private var seekTime = 0.0
    private var isFirst = true
    private var isSeek = false
    // 无缝播放使用的PacketQueue
    private var loopPacketQueue: ObjectQueue<Packet>?
    private var packetQueue = ObjectQueue<Packet>()
    override var loadedTime: TimeInterval {
        return TimeInterval(loadedCount + (loopPacketQueue?.count ?? 0)) / TimeInterval(fps)
    }

    override var isLoopPlay: Bool {
        didSet {
            if isLoopPlay {
                loopPacketQueue = ObjectQueue<Packet>()
                endOfFile()
            }
        }
    }

    override var loadedCount: Int {
        return packetQueue.count + super.loadedCount
    }

    override var isPlayable: Bool {
        guard !state.contains(.finished) else {
            return true
        }
        // 让音频能更快的打开
        let isSecondOpen = mediaType == .audio || KSPlayerManager.isSecondOpen
        let status = LoadingStatus(fps: fps, packetCount: packetQueue.count,
                                   frameCount: outputRenderQueue.count,
                                   frameMaxCount: outputRenderQueue.maxCount,
                                   isFirst: isFirst, isSeek: isSeek, isSecondOpen: isSecondOpen)
        if KSDefaultParameter.playable(status) {
            isFirst = false
            isSeek = false
            return true
        } else {
            return false
        }
    }

    override func open() -> Bool {
        if super.open() {
            operationQueue.name = "KSPlayer_" + String(describing: self).components(separatedBy: ".").last!
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.qualityOfService = .userInteractive
            return true
        } else {
            return false
        }
    }

    override func putPacket(packet: Packet) {
        if isLoopPlay {
            loopPacketQueue?.putObjectSync(object: packet)
        } else {
            packetQueue.putObjectSync(object: packet)
            delegate?.codecDidChangeCapacity(track: self)
        }
    }

    override func changeLoop() {
        if let loopPacketQueue = loopPacketQueue {
            packetQueue = loopPacketQueue
        }
        isLoopPlay = false
        decode()
    }

    override func decode() {
        guard isEnabled, operationQueue.operationCount == 0 else { return }
        decodeOperation = BlockOperation { [weak self] in
            guard let self = self else { return }
            Thread.current.name = self.operationQueue.name
            self.decodeThread()
        }
        decodeOperation?.queuePriority = .veryHigh
        decodeOperation?.qualityOfService = .userInteractive
        if let decodeOperation = decodeOperation {
            operationQueue.addOperation(decodeOperation)
        }
    }

    private func decodeThread() {
        state = .decoding
        while decodeOperation?.isCancelled == false {
            if state.contains(.closed) || state.contains(.failed) || (state.contains(.finished) && packetQueue.isEmpty) {
                break
            } else if state.contains(.flush) {
                doFlushCodec()
                state.remove(.flush)
            } else if state.contains(.decoding) {
                guard let packet = packetQueue.getObjectSync(), !state.contains(.flush), !state.contains(.closed) else {
                    continue
                }
                do {
                    //                        let startTime = CACurrentMediaTime()
                    let frames = try doDecode(packet: packet).get()
                    //                        if type == .video {
                    //                            KSLog("视频解码耗时：\(CACurrentMediaTime()-startTime)")
                    //                        } else if type == .audio {
                    //                            KSLog("音频解码耗时：\(CACurrentMediaTime()-startTime)")
                    //                        }
                    frames.forEach { frame in
                        guard !state.contains(.flush), !state.contains(.closed) else {
                            return
                        }
                        if seekTime > 0, KSPlayerManager.isAccurateSeek {
                            if frame.seconds < seekTime {
                                return
                            } else {
                                seekTime = 0.0
                            }
                        }
                        outputRenderQueue.putObjectSync(object: frame)
                        delegate?.codecDidChangeCapacity(track: self)
                    }
                } catch {
                    delegate?.codecFailed(error: error as NSError, track: self)
                    state = .failed
                }
            }
        }
    }

    override func getOutputRender(where predicate: ((MEFrame) -> Bool)?) -> MEFrame? {
        let outputFecthRender = outputRenderQueue.getObjectAsync(where: predicate)
        if outputFecthRender == nil {
            if state.contains(.finished), loadedCount == 0 {
                delegate?.codecDidFinished(track: self)
            }
        } else {
            delegate?.codecDidChangeCapacity(track: self)
        }
        return outputFecthRender
    }

    override func seek(time: TimeInterval) {
        seekTime = time
        packetQueue.flush()
        super.seek(time: time)
        isLoopPlay = false
        loopPacketQueue = nil
        delegate?.codecDidChangeCapacity(track: self)
        isSeek = true
    }

    override func endOfFile() {
        super.endOfFile()
        if loadedCount == 0 {
            delegate?.codecDidFinished(track: self)
        }
        delegate?.codecDidChangeCapacity(track: self)
    }

    override func shutdown() {
        if state == .idle {
            return
        }
        super.shutdown()
        packetQueue.shutdown()
        operationQueue.cancelAllOperations()
        if Thread.current.name != operationQueue.name {
            operationQueue.waitUntilAllOperationsAreFinished()
        }
    }

    func doFlushCodec() {}

    func doDecode(packet _: Packet) -> Result<[Frame], NSError> {
        fatalError("Abstract method")
    }
}
