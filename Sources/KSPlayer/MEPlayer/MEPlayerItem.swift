//
//  MEPlayerItem.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Libavformat
import VideoToolbox

final class MEPlayerItem {
    private let url: URL
    private let options: KSOptions
    private let operationQueue = OperationQueue()
    private let condition = NSCondition()
    private var formatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var openOperation: BlockOperation?
    private var readOperation: BlockOperation?
    private var closeOperation: BlockOperation?
    private var seekingCompletionHandler: ((Bool) -> Void)?
    // 没有音频数据可以渲染
    private var isAudioStalled = true
    private var videoMediaTime = CACurrentMediaTime()
    private var isFirst = true
    private var isSeek = false
    private var allTracks = [PlayerItemTrackProtocol]()
    private var videoAudioTracks: [CapacityProtocol] {
        var tracks = [CapacityProtocol]()
        if let audioTrack {
            tracks.append(audioTrack)
        }
        if !options.videoDisable, let videoTrack {
            tracks.append(videoTrack)
        }
        return tracks
    }

    private var videoTrack: FFPlayerItemTrack<VideoVTBFrame>?
    private var audioTrack: FFPlayerItemTrack<AudioFrame>? {
        didSet {
            audioTrack?.delegate = self
        }
    }

    private(set) var assetTracks = [AssetTrack]()
    private var videoAdaptation: VideoAdaptationState?
    private(set) var currentPlaybackTime = TimeInterval(0)
    private var startTime = TimeInterval(0)
    private var videoClockDelay = TimeInterval(0)
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
            case .reading:
                timer.fireDate = Date.distantPast
            case .closed:
                timer.invalidate()
            case .failed:
                delegate?.sourceDidFailed(error: error)
                timer.fireDate = Date.distantFuture
            case .idle, .opening, .seeking, .paused, .finished:
                break
            }
        }
    }

    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        self?.codecDidChangeCapacity()
    }

    weak var delegate: MEPlayerDelegate?

    init(url: URL, options: KSOptions) {
        self.url = url
        self.options = options
        timer.fireDate = Date.distantFuture
        avformat_network_init()
        av_log_set_callback { _, level, format, args in
            guard let format, level <= KSPlayerManager.logLevel.rawValue else {
                return
            }
            var log = String(cString: format)
            let arguments: CVaListPointer? = args
            if let arguments {
                log = NSString(format: log, arguments: arguments) as String
            }
            // 找不到解码器
            if log.hasPrefix("parser not found for codec") {}
            KSLog(log)
        }
        operationQueue.name = "KSPlayer_" + String(describing: self).components(separatedBy: ".").last!
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
    }

    func select(track: MediaPlayerTrack) {
        if track.isEnabled {
            return
        }
        assetTracks.filter { $0.mediaType == track.mediaType }.forEach {
            if $0.mediaType == .subtitle, !$0.isImageSubtitle {
                return
            }
            $0.stream.pointee.discard = AVDISCARD_ALL
        }
        track.setIsEnabled(true)
        if track.mediaType == .video, let assetTrack = track as? AssetTrack {
            findBestAudio(videoTrack: assetTrack)
        }
        if track.mediaType == .subtitle, !((track as? AssetTrack)?.isImageSubtitle ?? false) {
            return
        }
        seek(time: currentPlaybackTime) { _ in
        }
    }
}

// MARK: private functions

extension MEPlayerItem {
    private func openThread() {
        avformat_close_input(&self.formatCtx)
        formatCtx = avformat_alloc_context()
        guard let formatCtx else {
            error = NSError(errorCode: .formatCreate)
            return
        }
        var interruptCB = AVIOInterruptCB()
        interruptCB.opaque = Unmanaged.passUnretained(self).toOpaque()
        interruptCB.callback = { ctx -> Int32 in
            guard let ctx else {
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
        let urlString: String
        if url.isFileURL {
            urlString = url.path
        } else {
            if url.absoluteString.hasPrefix("https") || !options.cache {
                urlString = url.absoluteString
            } else {
                urlString = "async:cache:" + url.absoluteString
            }
        }
        var result = avformat_open_input(&self.formatCtx, urlString, nil, &avOptions)
        av_dict_free(&avOptions)
        if result == AVError.eof.code {
            state = .finished
            return
        }
        guard result == 0 else {
            error = .init(errorCode: .formatOpenInput, ffmpegErrnum: result)
            avformat_close_input(&self.formatCtx)
            return
        }
        formatCtx.pointee.flags |= AVFMT_FLAG_GENPTS
        av_format_inject_global_side_data(formatCtx)
        options.openTime = CACurrentMediaTime()
        if let probesize = options.probesize {
            formatCtx.pointee.probesize = probesize
        }
        if let maxAnalyzeDuration = options.maxAnalyzeDuration {
            formatCtx.pointee.max_analyze_duration = maxAnalyzeDuration
        }
        result = avformat_find_stream_info(formatCtx, nil)
        guard result == 0 else {
            error = .init(errorCode: .formatFindStreamInfo, ffmpegErrnum: result)
            avformat_close_input(&self.formatCtx)
            return
        }
        options.findTime = CACurrentMediaTime()
        options.formatName = String(cString: formatCtx.pointee.iformat.pointee.name)
        if formatCtx.pointee.start_time != Int64.min {
            startTime = TimeInterval(formatCtx.pointee.start_time / Int64(AV_TIME_BASE))
        }
        duration = TimeInterval(max(formatCtx.pointee.duration, 0) / Int64(AV_TIME_BASE))
        if duration > startTime {
            duration -= startTime
        }
        createCodec(formatCtx: formatCtx)
        if videoTrack == nil, audioTrack == nil {
            state = .failed
        } else {
            state = .opened
            state = .reading
            read()
        }
    }

    private func createCodec(formatCtx: UnsafeMutablePointer<AVFormatContext>) {
        allTracks.removeAll()
        assetTracks.removeAll()
        videoAdaptation = nil
        videoTrack = nil
        audioTrack = nil
        assetTracks = (0 ..< Int(formatCtx.pointee.nb_streams)).compactMap { i in
            if let coreStream = formatCtx.pointee.streams[i] {
                coreStream.pointee.discard = AVDISCARD_ALL
                if let assetTrack = AssetTrack(stream: coreStream) {
                    if !options.subtitleDisable, assetTrack.mediaType == .subtitle {
                        let subtitle = FFPlayerItemTrack<SubtitleFrame>(assetTrack: assetTrack, options: options)
                        assetTrack.subtitle = subtitle
                        allTracks.append(subtitle)
                    }
                    return assetTrack
                }
            }
            return nil
        }
        if options.autoSelectEmbedSubtitle {
            assetTracks.first { $0.mediaType == .subtitle }?.setIsEnabled(true)
        }
        var videoIndex: Int32 = -1
        if !options.videoDisable {
            let videos = assetTracks.filter { $0.mediaType == .video }
            let bitRates = videos.map(\.bitRate)
            let wantedStreamNb: Int32
            if videos.count > 0, let index = options.wantedVideo(bitRates: bitRates) {
                wantedStreamNb = videos[index].trackID
            } else {
                wantedStreamNb = -1
            }
            videoIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, wantedStreamNb, -1, nil, 0)
            if let first = videos.first(where: { $0.trackID == videoIndex }) {
                first.stream.pointee.discard = AVDISCARD_DEFAULT
                rotation = first.rotation
                naturalSize = first.naturalSize
                let track = options.syncDecodeVideo ? FFPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options)
                track.delegate = self
                allTracks.append(track)
                videoTrack = track
                if videos.count > 1, options.videoAdaptable {
                    let bitRateState = VideoAdaptationState.BitRateState(bitRate: first.bitRate, time: CACurrentMediaTime())
                    videoAdaptation = VideoAdaptationState(bitRates: bitRates.sorted(by: <), duration: duration, fps: first.nominalFrameRate, bitRateStates: [bitRateState])
                }
            }
        }

        let audios = assetTracks.filter { $0.mediaType == .audio }
        let wantedStreamNb: Int32
        if audios.count > 0, let index = options.wantedAudio(infos: audios.map { ($0.bitRate, $0.language) }) {
            wantedStreamNb = audios[index].trackID
        } else {
            wantedStreamNb = -1
        }
        let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, wantedStreamNb, videoIndex, nil, 0)
        if let first = assetTracks.first(where: { $0.mediaType == .audio && $0.trackID == index }) {
            first.stream.pointee.discard = AVDISCARD_DEFAULT
            let track = options.syncDecodeAudio ? FFPlayerItemTrack<AudioFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<AudioFrame>(assetTrack: first, options: options)
            track.delegate = self
            allTracks.append(track)
            audioTrack = track
            isAudioStalled = false
        }
    }

    private func read() {
        readOperation = BlockOperation { [weak self] in
            guard let self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_read"
            Thread.current.stackSize = KSPlayerManager.stackSize
            self.readThread()
        }
        readOperation?.queuePriority = .veryHigh
        readOperation?.qualityOfService = .userInteractive
        if let openOperation {
            readOperation?.addDependency(openOperation)
        }
        if let readOperation {
            operationQueue.addOperation(readOperation)
        }
    }

    private func readThread() {
        allTracks.forEach { $0.decode() }
        while [MESourceState.paused, .seeking, .reading].contains(state) {
            if state == .paused {
                condition.wait()
            }
            if state == .seeking {
                let time = currentPlaybackTime + startTime
                allTracks.forEach { $0.seek(time: time) }
                let timeStamp = Int64(time * TimeInterval(AV_TIME_BASE))
                // can not seek to key frame
//                let result = avformat_seek_file(formatCtx, -1, Int64.min, timeStamp, Int64.max, options.seekFlags)
                let result = av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                if state == .closed {
                    break
                }
                isSeek = true
                allTracks.forEach { $0.seek(time: time) }
                seekingCompletionHandler?(result >= 0)
                seekingCompletionHandler = nil
                state = .reading
            } else if state == .reading {
                autoreleasepool {
                    reading()
                }
            }
        }
    }

    private func reading() {
        let packet = Packet()
        let readResult = av_read_frame(formatCtx, packet.corePacket)
        if state == .closed {
            return
        }
        if readResult == 0 {
            if formatCtx?.pointee.pb.pointee.eof_reached == 1 {
                // todo need reconnect
            }
            if packet.corePacket.pointee.size <= 0 {
                return
            }
            packet.fill()
            let first = assetTracks.first { $0.trackID == packet.corePacket.pointee.stream_index }
            if let first, first.isEnabled {
                packet.assetTrack = first
                if first.mediaType == .video {
                    if options.readVideoTime == 0 {
                        options.readVideoTime = CACurrentMediaTime()
                    }
                    videoTrack?.putPacket(packet: packet)
                } else if first.mediaType == .audio {
                    if options.readAudioTime == 0 {
                        options.readAudioTime = CACurrentMediaTime()
                    }
                    audioTrack?.putPacket(packet: packet)
                } else {
                    first.subtitle?.putPacket(packet: packet)
                }
            }
        } else {
            if readResult == AVError.eof.code || formatCtx?.pointee.pb.pointee.eof_reached == 1 {
                if options.isLoopPlay, allTracks.allSatisfy({ !$0.isLoopModel }) {
                    allTracks.forEach { $0.isLoopModel = true }
                    _ = av_seek_frame(formatCtx, -1, 0, AVSEEK_FLAG_BACKWARD)
                } else {
                    allTracks.forEach { $0.isEndOfFile = true }
                    state = .finished
                }
            } else {
                //                        if IS_AVERROR_INVALIDDATA(readResult)
                error = .init(errorCode: .readFrame, ffmpegErrnum: readResult)
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
        guard let formatCtx else {
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
            guard let self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_open"
            Thread.current.stackSize = KSPlayerManager.stackSize
            self.openThread()
        }
        openOperation?.queuePriority = .veryHigh
        openOperation?.qualityOfService = .userInteractive
        if let openOperation {
            operationQueue.addOperation(openOperation)
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
        if let readOperation {
            readOperation.cancel()
            closeOperation.addDependency(readOperation)
        } else if let openOperation {
            openOperation.cancel()
            closeOperation.addDependency(openOperation)
        }
        operationQueue.addOperation(closeOperation)
        self.closeOperation = closeOperation
    }

    func seek(time: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            seek(time: time) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func seek(time: TimeInterval, completion: @escaping ((Bool) -> Void)) {
        if state == .reading || state == .paused {
            state = .seeking
            currentPlaybackTime = time
            seekingCompletionHandler = completion
            condition.broadcast()
        } else if state == .finished {
            state = .seeking
            currentPlaybackTime = time
            seekingCompletionHandler = completion
            read()
        }
        isAudioStalled = audioTrack == nil
    }
}

extension MEPlayerItem: CodecCapacityDelegate {
    func codecDidChangeCapacity() {
        let loadingState = options.playable(capacitys: videoAudioTracks, isFirst: isFirst, isSeek: isSeek)
        delegate?.sourceDidChange(loadingState: loadingState)
        if loadingState.isPlayable {
            isFirst = false
            isSeek = false
            if loadingState.loadedTime > options.maxBufferDuration {
                adaptableVideo(loadingState: loadingState)
                pause()
            } else if loadingState.loadedTime < options.maxBufferDuration / 2 {
                resume()
            }
        } else {
            resume()
            adaptableVideo(loadingState: loadingState)
        }
    }

    func codecDidFinished(track: some CapacityProtocol) {
        if track.mediaType == .audio {
            isAudioStalled = true
        }
        let allSatisfy = videoAudioTracks.allSatisfy { $0.isEndOfFile && $0.frameCount == 0 && $0.packetCount == 0 }
        delegate?.sourceDidFinished(type: track.mediaType, allSatisfy: allSatisfy)
        if allSatisfy {
            timer.fireDate = Date.distantFuture
            if options.isLoopPlay {
                isAudioStalled = audioTrack == nil
                audioTrack?.isLoopModel = false
                videoTrack?.isLoopModel = false
                if state == .finished {
                    state = .reading
                    read()
                }
            }
        }
    }

    private func adaptableVideo(loadingState: LoadingState) {
        if options.videoDisable || videoAdaptation == nil || loadingState.isEndOfFile || loadingState.isSeek || state == .seeking {
            return
        }
        guard let track = videoTrack else {
            return
        }
        videoAdaptation?.loadedCount = track.packetCount + track.frameCount
        videoAdaptation?.currentPlaybackTime = currentPlaybackTime
        videoAdaptation?.isPlayable = loadingState.isPlayable
        guard let (oldBitRate, newBitrate) = options.adaptable(state: videoAdaptation), oldBitRate != newBitrate,
              let newAssetTrack = assetTracks.first(where: { $0.mediaType == .video && $0.bitRate == newBitrate })
        else {
            return
        }
        assetTracks.first { $0.mediaType == .video && $0.bitRate == oldBitRate }?.isEnabled = false
        newAssetTrack.isEnabled = true
        findBestAudio(videoTrack: newAssetTrack)
        let bitRateState = VideoAdaptationState.BitRateState(bitRate: newBitrate, time: CACurrentMediaTime())
        videoAdaptation?.bitRateStates.append(bitRateState)
        delegate?.sourceDidChange(oldBitRate: oldBitRate, newBitrate: newBitrate)
    }

    private func findBestAudio(videoTrack: AssetTrack) {
        guard videoAdaptation != nil, let first = assetTracks.first(where: { $0.mediaType == .audio && $0.isEnabled }) else {
            return
        }
        let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, videoTrack.trackID, nil, 0)
        if index != first.trackID {
            first.isEnabled = true
            assetTracks.first { $0.mediaType == .audio && $0.trackID == index }?.isEnabled = false
        }
    }
}

extension MEPlayerItem: OutputRenderSourceDelegate {
    func setVideo(time: CMTime) {
        if state == .seeking {
            return
        }
        videoMediaTime = CACurrentMediaTime()
        if isAudioStalled {
            currentPlaybackTime = time.seconds - options.audioDelay - startTime
        }
    }

    func setAudio(time: CMTime) {
        if state == .seeking {
            return
        }
        if !isAudioStalled {
            currentPlaybackTime = time.seconds - startTime
        }
    }

    func getVideoOutputRender() -> VideoVTBFrame? {
        guard let videoTrack else {
            return nil
        }
        var desire = currentPlaybackTime + options.audioDelay + startTime
        let predicate: (VideoVTBFrame) -> Bool = { [weak self] frame -> Bool in
            guard let self else { return true }
            desire = self.currentPlaybackTime + self.options.audioDelay + self.startTime
            if self.isAudioStalled {
                desire += max(CACurrentMediaTime() - self.videoMediaTime, 0) + self.videoClockDelay
            }
            return frame.seconds <= desire
        }
        let frame = videoTrack.getOutputRender(where: predicate)
        if let frame {
            videoClockDelay = desire - frame.seconds
            if frame.seconds + 0.4 < desire {
                KSLog("dropped video frame frameCount: \(videoTrack.frameCount) frameMaxCount: \(videoTrack.frameMaxCount)")
                _ = videoTrack.getOutputRender(where: nil)
            }
        } else {
            KSLog("not video frame frameCount: \(videoTrack.frameCount) frameMaxCount: \(videoTrack.frameMaxCount)")
        }
        return options.videoDisable ? nil : frame
    }

    func getAudioOutputRender() -> AudioFrame? {
        audioTrack?.getOutputRender(where: nil)
    }
}

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
