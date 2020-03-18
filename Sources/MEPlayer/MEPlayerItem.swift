//
//  MEPlayerItem.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import ffmpeg
import VideoToolbox

final class MEPlayerItem {
    private let url: URL
    private let options: KSOptions
    private let operationQueue = OperationQueue()
    private let semaphore = DispatchSemaphore(value: 1)
    private let condition = NSCondition()
    private var formatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var openOperation: BlockOperation?
    private var readOperation: BlockOperation?
    private var closeOperation: BlockOperation?
    private var seekingCompletionHandler: ((Bool) -> Void)?
    // 没有音频数据可以渲染
    private var isAudioStalled = false
    private var videoMediaTime = CACurrentMediaTime()
    private var videoTrack: PlayerItemTrackProtocol?
    private var audioTrack: PlayerItemTrackProtocol? {
        didSet {
            audioTrack?.delegate = self
        }
    }
    private var allTracks = [PlayerItemTrackProtocol]()
    private var videoAudioTracks = [PlayerItemTrackProtocol]()
    private var assetTracks = [TrackProtocol]()
    private(set) var subtitleTracks = [SubtitlePlayerItemTrack]()
    private(set) var currentPlaybackTime = TimeInterval(0)
    private(set) var rotation = 0.0
    private(set) var duration: TimeInterval = 0
    private(set) var naturalSize = CGSize.zero
    private var error: NSError? {
        didSet {
            if error != nil {
                state = .failed
            }
        }
    }

    private var state = MESourceState.idle {
        didSet {
            switch state {
            case .opened:
                delegate?.sourceDidOpened()
            case .failed:
                delegate?.sourceDidFailed(error: error)
            default:
                break
            }
        }
    }

    weak var delegate: MEPlayerDelegate?

    init(url: URL, options: KSOptions) {
        self.url = url
        self.options = options
        avformat_network_init()
        av_log_set_callback { _, level, format, args in
            guard let format = format, level <= KSPlayerManager.logLevel.rawValue else {
                return
            }
            var log = String(cString: format)
            let arguments: CVaListPointer? = args
            if let arguments = arguments {
                log = NSString(format: log, arguments: arguments) as String
            }
            // 找不到解码器
            //            if log.hasPrefix("parser not found for codec") {}
            KSLog(log)
        }
        operationQueue.name = "KSPlayer_" + String(describing: self).components(separatedBy: ".").last!
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
    }

    deinit {
        if !operationQueue.operations.isEmpty {
            shutdown()
            operationQueue.waitUntilAllOperationsAreFinished()
        }
    }
}

// MARK: private functions

extension MEPlayerItem {
    private func openThread() {
        avformat_close_input(&self.formatCtx)
        formatCtx = avformat_alloc_context()
        guard let formatCtx = formatCtx else {
            error = NSError(domain: "FFCreateErrorCode", code: MEErrorCode.formatCreate.rawValue, userInfo: nil)
            return
        }
        var interruptCB = AVIOInterruptCB()
        interruptCB.opaque = Unmanaged.passUnretained(self).toOpaque()
        interruptCB.callback = { ctx -> Int32 in
            guard let ctx = ctx else {
                return 0
            }
            let formatContext = Unmanaged<MEPlayerItem>.fromOpaque(ctx).takeUnretainedValue()
            switch formatContext.state {
            case .finished, .closed, .failed:
                return 1
            default:
                return 0
            }
        }
        formatCtx.pointee.interrupt_callback = interruptCB
//        formatCtx.pointee.io_open = { formatCtx, context, url, flags, options -> Int32 in
//            return 0
//        }
        var avOptions = options.formatContextOptions.avOptions
        var result = avformat_open_input(&self.formatCtx, url.isFileURL ? url.path : url.absoluteString, nil, &avOptions)
        av_dict_free(&avOptions)
        if IS_AVERROR_EOF(result) {
            state = .finished
            return
        }
        guard result == 0 else {
            error = .init(result: result, errorCode: .formatOpenInput)
            avformat_close_input(&self.formatCtx)
            return
        }
        result = avformat_find_stream_info(formatCtx, nil)
        guard result == 0 else {
            error = .init(result: result, errorCode: .formatFindStreamInfo)
            avformat_close_input(&self.formatCtx)
            return
        }
        duration = TimeInterval(max(formatCtx.pointee.duration, 0) / Int64(AV_TIME_BASE))
        createCodec(formatCtx: formatCtx.pointee)
        if assetTracks.first == nil {
            state = .failed
        } else {
            play()
        }
    }

    private func createCodec(formatCtx: AVFormatContext) {
        assetTracks.removeAll()
        assetTracks = (0 ..< Int(formatCtx.nb_streams)).compactMap { i in
            if let coreStream = formatCtx.streams[i] {
                return AssetTrack(stream: coreStream)
            }
            return nil
        }
        let videos = assetTracks.filter { $0.mediaType == .video }
        if let first = videos.first {
            rotation = first.stream.rotation
            let codecpar = first.stream.pointee.codecpar.pointee
            naturalSize = CGSize(width: Int(codecpar.width), height: Int(codecpar.height))
            let track = AsyncPlayerItemTrack(assetTrack: first, options: options)
            videoAudioTracks.append(track)
            track.delegate = self
            videoTrack = track
        }
        let audios = assetTracks.filter { $0.mediaType == .audio }
        if let first = audios.first {
            let track = AsyncPlayerItemTrack(assetTrack: first, options: options)
            track.delegate = self
            videoAudioTracks.append(track)
            audioTrack = track
            if videos.count == 1 {
                audios.filter { $0.streamIndex != first.streamIndex }.forEach { $0.isEnabled = false }
            }
        } else {
            isAudioStalled = true
        }
        subtitleTracks = assetTracks.filter { $0.mediaType == .subtitle }.map {
            SubtitlePlayerItemTrack(assetTrack: $0, options: options)
        }
        allTracks.append(contentsOf: videoAudioTracks)
        allTracks.append(contentsOf: subtitleTracks)
    }

    private func read() {
        readOperation = BlockOperation { [weak self] in
            guard let self = self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_read"
            Thread.current.stackSize = KSPlayerManager.stackSize
            self.readThread()
        }
        readOperation?.queuePriority = .veryHigh
        readOperation?.qualityOfService = .userInteractive
        if let openOperation = openOperation {
            readOperation?.addDependency(openOperation)
        }
        if let readOperation = readOperation {
            operationQueue.addOperation(readOperation)
        }
    }

    private func readThread() {
        allTracks.forEach { $0.decode() }
        while readOperation?.isCancelled == false {
            if formatCtx == nil || [MESourceState.finished, .closed, .failed].contains(state) {
                break
            } else if state == .paused {
                condition.wait()
            } else if state == .seeking {
                let timeStamp = Int64(currentPlaybackTime * TimeInterval(AV_TIME_BASE))
                // 不要用avformat_seek_file，否则可能会向前跳
                //                let tolerance: Int64 = KSPlayerManager.isAccurateSeek ? 0 : 2
                //                let result = avformat_seek_file(formatCtx, -1, timeStamp - tolerance, timeStamp, timeStamp, AVSEEK_FLAG_BACKWARD)
                let result = av_seek_frame(formatCtx, -1, timeStamp, AVSEEK_FLAG_BACKWARD)
                allTracks.forEach { $0.seek(time: currentPlaybackTime) }
                seekingCompletionHandler?(result >= 0)
                seekingCompletionHandler = nil
                state = .reading
            } else if state == .reading {
                let packet = Packet()
                let readResult = av_read_frame(formatCtx, packet.corePacket)
                if readResult == 0 {
                    packet.fill()
                    let first = assetTracks.first { $0.isEnabled && $0.stream.pointee.index == packet.corePacket.pointee.stream_index }
                    if let first = first {
                        packet.assetTrack = first
                        if first.mediaType == .video {
                            videoTrack?.putPacket(packet: packet)
                        } else if first.mediaType == .audio {
                            audioTrack?.putPacket(packet: packet)
                        } else {
                            subtitleTracks.first { $0.assetTrack == first }?.putPacket(packet: packet)
                        }
                    }
                } else {
                    if IS_AVERROR_EOF(readResult) || avio_feof(formatCtx?.pointee.pb) != 0 {
                        if options.isLoopPlay {
                            if allTracks.first(where: { $0.isLoopModel }) == nil {
                                allTracks.forEach { $0.isLoopModel = true }
                                _ = av_seek_frame(formatCtx, -1, 0, AVSEEK_FLAG_BACKWARD)
                            } else {
                                allTracks.forEach { $0.endOfFile() }
                                state = .finished
                            }
                        } else {
                            allTracks.forEach { $0.endOfFile() }
                            state = .finished
                        }
                    } else {
                        //                        if IS_AVERROR_INVALIDDATA(readResult)
                        error = .init(result: readResult, errorCode: .readFrame)
                    }
                }
            }
        }
    }

    private func pause() {
        if state == .reading {
            state = .paused
        }
    }

    private func resume() {
        if state == .paused {
            state = .reading
            condition.signal()
        }
    }
}

// MARK: MediaPlayback

extension MEPlayerItem: MediaPlayback {
    var seekable: Bool {
        guard let formatCtx = formatCtx else {
            return false
        }
        var seekable = true
        if let ioContext = formatCtx.pointee.pb {
            seekable = ioContext.pointee.seekable > 0
        }
        return seekable && duration > 0
    }

    func prepareToPlay() {
        state = .opening
        openOperation = BlockOperation { [weak self] in
            guard let self = self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_open"
            Thread.current.stackSize = KSPlayerManager.stackSize
            self.openThread()
        }
        openOperation?.queuePriority = .veryHigh
        openOperation?.qualityOfService = .userInteractive
        if let openOperation = openOperation {
            operationQueue.addOperation(openOperation)
        }
    }

    func play() {
        if state == .opening {
            state = .opened
            state = .reading
            read()
        }
    }

    func shutdown() {
        guard state != .closed else { return }
        state = .closed
        condition.signal()
        // 故意循环引用。等结束了。才释放
        let closeOperation = BlockOperation {
            Thread.current.name = (self.operationQueue.name ?? "") + "_close"
            self.allTracks.forEach { $0.shutdown() }
            ObjectPool.share.removeAll()
            KSLog("清空formatCtx")
            avformat_close_input(&self.formatCtx)
            self.duration = 0
            self.closeOperation = nil
            self.operationQueue.cancelAllOperations()
            ObjectPool.share.removeAll()
        }
        closeOperation.queuePriority = .veryHigh
        closeOperation.qualityOfService = .userInteractive
        if let readOperation = readOperation {
            readOperation.cancel()
            closeOperation.addDependency(readOperation)
        } else if let openOperation = openOperation {
            openOperation.cancel()
            closeOperation.addDependency(openOperation)
        }
        operationQueue.addOperation(closeOperation)
        self.closeOperation = closeOperation
    }

    func seek(time: TimeInterval, completion handler: ((Bool) -> Void)?) {
        if state == .reading || state == .paused {
            currentPlaybackTime = time
            seekingCompletionHandler = handler
            state = .seeking
            condition.signal()
        } else if state == .finished {
            currentPlaybackTime = time
            seekingCompletionHandler = handler
            state = .seeking
            read()
        }
        isAudioStalled = assetTracks.first { $0.mediaType == .audio && $0.isEnabled } == nil
    }
}

extension MEPlayerItem: CodecCapacityDelegate {
    func codecDidChangeCapacity(track _: PlayerItemTrackProtocol) {
        semaphore.wait()
        let mix = MixCapacity(array: videoAudioTracks)
        delegate?.sourceDidChange(capacity: mix)
        if mix.isPlayable {
            if mix.loadedTime > options.maxBufferDuration {
                pause()
            } else if mix.loadedTime < options.maxBufferDuration / 2 {
                resume()
            }
        } else {
            resume()
        }
        semaphore.signal()
    }

    func codecDidFinished(track: PlayerItemTrackProtocol) {
        if track.mediaType == .audio {
            isAudioStalled = true
        }
        let allSatisfy = videoAudioTracks.allSatisfy { $0.isFinished && $0.loadedCount == 0 }
        delegate?.sourceDidFinished(type: track.mediaType, allSatisfy: allSatisfy)
        if allSatisfy, options.isLoopPlay {
            isAudioStalled = false
            audioTrack?.isLoopModel = false
            videoTrack?.isLoopModel = false
            if state == .finished {
                state = .reading
                read()
            }
        }
    }
}

extension MEPlayerItem: OutputRenderSourceDelegate {
    func setVideo(time: CMTime) {
        if isAudioStalled {
            currentPlaybackTime = time.seconds
            videoMediaTime = CACurrentMediaTime()
        }
    }

    func setAudio(time: CMTime) {
        if !isAudioStalled {
            currentPlaybackTime = time.seconds
        }
    }

    func getOutputRender(type: AVFoundation.AVMediaType, isDependent: Bool) -> MEFrame? {
        var predicate: ((MEFrame) -> Bool)?
        if isDependent {
            predicate = { [weak self] (frame) -> Bool in
                guard let self = self else { return true }
                var desire = self.currentPlaybackTime
                if self.isAudioStalled {
                    desire += max(CACurrentMediaTime() - self.videoMediaTime, 0)
                }
                return frame.cmtime.seconds <= desire
            }
        }
        return (type == .video ? videoTrack : audioTrack)?.getOutputRender(where: predicate)
    }
}

extension UnsafeMutablePointer where Pointee == AVStream {
    var rotation: Double {
        let displaymatrix = av_stream_get_side_data(self, AV_PKT_DATA_DISPLAYMATRIX, nil)
        let rotateTag = av_dict_get(pointee.metadata, "rotate", nil, 0)
        if let rotateTag = rotateTag, String(cString: rotateTag.pointee.value) == "0" {
            return 0.0
        } else if let displaymatrix = displaymatrix {
            let matrix = displaymatrix.withMemoryRebound(to: Int32.self, capacity: 1) { $0 }
            return -av_display_rotation_get(matrix)
        }
        return 0.0
    }
}

private final class MixCapacity: Capacity {
    private let array: [PlayerItemTrackProtocol]

    lazy var loadedTime: TimeInterval = {
        array.min { $0.loadedTime < $1.loadedTime }?.loadedTime ?? 0
    }()

    lazy var loadedCount: Int = {
        array.min { $0.loadedCount < $1.loadedCount }?.loadedCount ?? 0
    }()

    lazy var bufferingProgress: Int = {
        array.min { $0.bufferingProgress < $1.bufferingProgress }?.bufferingProgress ?? 0
    }()

    lazy var isPlayable: Bool = {
        array.allSatisfy { $0.isPlayable }
    }()

    lazy var isFinished: Bool = {
        array.allSatisfy { $0.isFinished }
    }()

    init(array: [PlayerItemTrackProtocol]) {
        self.array = array
    }
}
