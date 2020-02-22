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
    private var tracks = [PlayerItemTrackProtocol]()
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
            #if arch(x86_64)
            #if DEBUG
            log = NSString(format: log, arguments: args) as String
            #endif
            #else
            if let args = args {
                log = NSString(format: log, arguments: args) as String
            }
            #endif
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
        var avOptions = options.formatContextOptions.avOptions
        var result = avformat_open_input(&self.formatCtx, url.isFileURL ? url.path : url.absoluteString, nil, &avOptions)
        av_dict_free(&avOptions)
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
        if tracks.first == nil {
            state = .failed
        } else {
            play()
        }
    }

    private func createCodec(formatCtx: AVFormatContext) {
        tracks.forEach { $0.shutdown() }
        tracks.removeAll()
        for i in 0 ..< Int(formatCtx.nb_streams) {
            if let coreStream = formatCtx.streams[i],
                let codec = coreStream.createCodec(options: options) {
                codec.delegate = self
                tracks.append(codec)
            }
        }
        let audios = tracks.filter { $0.mediaType == .audio }
        if audios.isEmpty {
            isAudioStalled = true
        } else {
            audios.dropFirst().forEach { $0.isEnabled = false }
        }
        if let currentVideoCodec = tracks.first(where: { $0.mediaType == .video }) {
            rotation = currentVideoCodec.stream.rotation
            let codecpar = currentVideoCodec.stream.pointee.codecpar.pointee
            naturalSize = CGSize(width: Int(codecpar.width), height: Int(codecpar.height))
            KSLog("VideoCodec is \(currentVideoCodec.self)")
        }
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
        tracks.forEach { $0.decode() }
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
                tracks.forEach { $0.seek(time: currentPlaybackTime) }
                seekingCompletionHandler?(result >= 0)
                seekingCompletionHandler = nil
                state = .reading
            } else if state == .reading {
                let packet = Packet()
                let readResult = av_read_frame(formatCtx, packet.corePacket)
                if readResult == 0 {
                    packet.fill()
                    tracks.first { $0.isEnabled && $0.stream.pointee.index == packet.corePacket.pointee.stream_index }?.putPacket(packet: packet)
                } else {
                    if IS_AVERROR_EOF(readResult) {
                        if options.isLoopPlay {
                            if tracks.first(where: { $0.isLoopPlay }) == nil {
                                tracks.forEach { $0.isLoopPlay = true }
                                _ = av_seek_frame(formatCtx, -1, 0, AVSEEK_FLAG_BACKWARD)
                            } else {
                                tracks.forEach { $0.endOfFile() }
                                state = .finished
                            }
                        } else {
                            tracks.forEach { $0.endOfFile() }
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
            self.tracks.forEach { $0.shutdown() }
            ObjectPool.share.removeAll()
            KSLog("清空formatCtx")
            avformat_close_input(&self.formatCtx)
            self.duration = 0
            self.closeOperation = nil
            self.operationQueue.cancelAllOperations()
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
        isAudioStalled = tracks.first { $0.mediaType == .audio && $0.isEnabled } == nil
    }
}

extension MEPlayerItem: CodecCapacityDelegate {
    func codecFailed(error: NSError, track: PlayerItemTrackProtocol) {
        KSLog("Decoder did Failed : \(error)")
        if track is VTBPlayerItemTrack {
            let newVideoCodec = VideoPlayerItemTrack(stream: track.stream, options: options)
            if newVideoCodec.open() {
                track.shutdown()
                newVideoCodec.delegate = self
                newVideoCodec.decode()
                if let index = tracks.firstIndex(where: { $0 === track }) {
                    tracks.remove(at: index)
                    tracks.insert(newVideoCodec, at: 0)
                    KSLog("VideoCodec switch to \(newVideoCodec.self)")
                }
            }
        }
    }

    func codecDidChangeCapacity(track _: PlayerItemTrackProtocol) {
        semaphore.wait()
        let mix = MixCapacity(array: tracks.filter { $0.isEnabled && ($0.mediaType == .audio || $0.mediaType == .video) })
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
        let allSatisfy = tracks.filter { $0.isEnabled && ($0.mediaType == .audio || $0.mediaType == .video) }.allSatisfy { $0.isFinished && $0.loadedCount == 0 }
        delegate?.sourceDidFinished(type: track.mediaType, allSatisfy: allSatisfy)
        if allSatisfy, options.isLoopPlay {
            isAudioStalled = false
            tracks.forEach { $0.changeLoop() }
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
        return tracks.first { $0.mediaType == type && $0.isEnabled }?.getOutputRender(where: predicate)
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

    func createCodec(options: KSOptions) -> PlayerItemTrackProtocol? {
        switch pointee.codecpar.pointee.codec_type {
        case AVMEDIA_TYPE_AUDIO:
            let codec = AudioPlayerItemTrack(stream: self, options: options)
            return codec.open() ? codec : nil
        case AVMEDIA_TYPE_SUBTITLE:
            let codec = SubtitlePlayerItemTrack(stream: self, options: options)
            return codec.open() ? codec : nil
        case AVMEDIA_TYPE_VIDEO:
            var videotoolbox = false
            if pointee.codecpar.pointee.codec_id == AV_CODEC_ID_H264, options.hardwareDecodeH264 {
                videotoolbox = true
            } else if pointee.codecpar.pointee.codec_id == AV_CODEC_ID_HEVC, #available(iOS 11.0, tvOS 11.0, OSX 10.13, *), VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC), options.hardwareDecodeH265 {
                videotoolbox = true
            }
            if videotoolbox {
                let codec = VTBPlayerItemTrack(stream: self, options: options)
                if codec.open() {
                    return codec
                }
            }
            let codec = VideoPlayerItemTrack(stream: self, options: options)
            return codec.open() ? codec : nil
        default:
            return nil
        }
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

extension MEPlayerItem {
    var subtitleTracks: [SubtitlePlayerItemTrack] {
        return tracks.compactMap { $0 as? SubtitlePlayerItemTrack }
    }
}
