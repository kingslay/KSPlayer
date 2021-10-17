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
    private var videoAudioTracks = [PlayerItemTrackProtocol]()
    private var videoTrack: PlayerItemTrackProtocol?
    private var audioTrack: PlayerItemTrackProtocol? {
        didSet {
            audioTrack?.delegate = self
        }
    }

    private(set) var assetTracks = [TrackProtocol]()
    private var videoAdaptation: VideoAdaptationState?
    private(set) var subtitleTracks = [FFPlayerItemTrack<SubtitleFrame>]()
    var currentPlaybackTime = TimeInterval(0)
    private var startTime = TimeInterval(0)
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

    func select(track: MediaPlayerTrack) {
        if let track = track as? TrackProtocol {
            assetTracks.filter { $0.mediaType == track.mediaType }.forEach { $0.stream.pointee.discard = AVDISCARD_ALL }
            track.stream.pointee.discard = AVDISCARD_DEFAULT
            seek(time: currentPlaybackTime, completion: nil)
        }
    }
}

// MARK: private functions

extension MEPlayerItem {
    private func openThread() {
        options.starTime = CACurrentMediaTime()
        avformat_close_input(&self.formatCtx)
        formatCtx = avformat_alloc_context()
        guard let formatCtx = formatCtx else {
            error = NSError(errorCode: .formatCreate)
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
        result = avformat_find_stream_info(formatCtx, nil)
        guard result == 0 else {
            error = .init(errorCode: .formatFindStreamInfo, ffmpegErrnum: result)
            avformat_close_input(&self.formatCtx)
            return
        }
        options.findTime = CACurrentMediaTime()
        options.formatName = String(cString: formatCtx.pointee.iformat.pointee.name)
        duration = TimeInterval(max(formatCtx.pointee.duration, 0) / Int64(AV_TIME_BASE))
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
        if formatCtx.pointee.start_time != Int64.min {
            startTime = TimeInterval(formatCtx.pointee.start_time / 1_000_000)
        }
        assetTracks = (0 ..< Int(formatCtx.pointee.nb_streams)).compactMap { i in
            if let coreStream = formatCtx.pointee.streams[i] {
                coreStream.pointee.discard = AVDISCARD_ALL
                return AssetTrack(stream: coreStream)
            } else {
                return nil
            }
        }
        var videoIndex: Int32 = -1
        if !options.videoDisable {
            let videos = assetTracks.filter { $0.mediaType == .video }
            let bitRates = videos.map(\.bitRate)
            let wantedStreamNb: Int32
            if videos.count > 0, let index = options.wantedVideo(bitRates: bitRates) {
                wantedStreamNb = videos[index].streamIndex
            } else {
                wantedStreamNb = -1
            }
            videoIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, wantedStreamNb, -1, nil, 0)
            if let first = videos.first(where: { $0.streamIndex == videoIndex }) {
                first.stream.pointee.discard = AVDISCARD_DEFAULT
                rotation = first.rotation
                naturalSize = first.naturalSize
                let track = options.syncDecodeVideo ? FFPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options)
                track.delegate = self
                videoAudioTracks.append(track)
                videoTrack = track
                if videos.count > 1, options.videoAdaptable {
                    let bitRateState = VideoAdaptationState.BitRateState(bitRate: first.bitRate, time: CACurrentMediaTime())
                    videoAdaptation = VideoAdaptationState(bitRates: bitRates.sorted(by: <), duration: duration, fps: first.nominalFrameRate, bitRateStates: [bitRateState])
                }
            }
        }
        if !options.audioDisable {
            let audios = assetTracks.filter { $0.mediaType == .audio }
            let wantedStreamNb: Int32
            if audios.count > 0, let index = options.wantedAudio(infos: audios.map { ($0.bitRate, $0.language) }) {
                wantedStreamNb = audios[index].streamIndex
            } else {
                wantedStreamNb = -1
            }
            let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, wantedStreamNb, videoIndex, nil, 0)
            if let first = assetTracks.first(where: { $0.mediaType == .audio && $0.streamIndex == index }) {
                first.stream.pointee.discard = AVDISCARD_DEFAULT
                let track = options.syncDecodeAudio ? FFPlayerItemTrack<AudioFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<AudioFrame>(assetTrack: first, options: options)
                track.delegate = self
                videoAudioTracks.append(track)
                audioTrack = track
                isAudioStalled = false
            }
        }
        if !options.subtitleDisable {
            subtitleTracks = assetTracks.filter { $0.mediaType == .subtitle }.map {
                FFPlayerItemTrack<SubtitleFrame>(assetTrack: $0, options: options)
            }
            allTracks.append(contentsOf: subtitleTracks)
        }
        allTracks.append(contentsOf: videoAudioTracks)
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
        while [MESourceState.paused, .seeking, .reading].contains(state) {
            if state == .paused {
                condition.wait()
            }
            if state == .seeking {
                let timeStamp = Int64(currentPlaybackTime * TimeInterval(AV_TIME_BASE))
                // can not seek to key frame
//                let result = avformat_seek_file(formatCtx, -1, timeStamp - 2, timeStamp, timeStamp + 2, AVSEEK_FLAG_BACKWARD)
                let result = av_seek_frame(formatCtx, -1, timeStamp, AVSEEK_FLAG_BACKWARD)
                if state == .closed {
                    break
                }
                allTracks.forEach { $0.seek(time: currentPlaybackTime) }
                isSeek = true
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
            if packet.corePacket.pointee.size <= 0 {
                return
            }
            packet.fill()
            let first = assetTracks.first { $0.stream.pointee.index == packet.corePacket.pointee.stream_index }
            if let first = first, first.isEnabled {
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
                    subtitleTracks.first { $0.assetTrack == first }?.putPacket(packet: packet)
                }
            }
        } else {
            if readResult == AVError.eof.code || avio_feof(formatCtx?.pointee.pb) != 0 {
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
            condition.broadcast()
            allTracks.forEach { $0.seek(time: currentPlaybackTime) }
        } else if state == .finished {
            currentPlaybackTime = time
            seekingCompletionHandler = handler
            state = .seeking
            read()
        }
        isAudioStalled = audioTrack == nil
    }
}

extension MEPlayerItem: CodecCapacityDelegate {
    func codecDidChangeCapacity(track: PlayerItemTrackProtocol) {
        guard let loadingState = options.playable(capacitys: videoAudioTracks, isFirst: isFirst, isSeek: isSeek) else {
            return
        }
        delegate?.sourceDidChange(loadingState: loadingState)
        if loadingState.isPlayable {
            isFirst = false
            isSeek = false
            if loadingState.loadedTime > options.maxBufferDuration {
                adaptable(track: track, loadingState: loadingState)
                pause()
            } else if loadingState.loadedTime < options.maxBufferDuration / 2 {
                resume()
            }
        } else {
            resume()
            adaptable(track: track, loadingState: loadingState)
        }
    }

    func codecDidFinished(track: PlayerItemTrackProtocol) {
        if track.mediaType == .audio {
            isAudioStalled = true
        }
        let allSatisfy = videoAudioTracks.allSatisfy { $0.isEndOfFile && $0.frameCount == 0 && $0.packetCount == 0 }
        delegate?.sourceDidFinished(type: track.mediaType, allSatisfy: allSatisfy)
        if allSatisfy, options.isLoopPlay {
            isAudioStalled = audioTrack == nil
            audioTrack?.isLoopModel = false
            videoTrack?.isLoopModel = false
            if state == .finished {
                state = .reading
                read()
            }
        }
    }

    private func adaptable(track: PlayerItemTrackProtocol, loadingState: LoadingState) {
        guard var videoAdaptation = videoAdaptation, track.mediaType == .video, !loadingState.isEndOfFile else {
            return
        }
        videoAdaptation.loadedCount = track.packetCount + track.frameCount
        videoAdaptation.currentPlaybackTime = currentPlaybackTime
        videoAdaptation.isPlayable = loadingState.isPlayable
        guard let (oldBitRate, newBitrate) = options.adaptable(state: videoAdaptation) else {
            return
        }
        assetTracks.first { $0.mediaType == .video && $0.bitRate == oldBitRate }?.stream.pointee.discard = AVDISCARD_ALL
        if let newAssetTrack = assetTracks.first(where: { $0.mediaType == .video && $0.bitRate == newBitrate }) {
            newAssetTrack.stream.pointee.discard = AVDISCARD_DEFAULT
            if let first = assetTracks.first(where: { $0.mediaType == .audio && $0.isEnabled }) {
                let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, first.streamIndex, newAssetTrack.streamIndex, nil, 0)
                if index != first.streamIndex {
                    first.stream.pointee.discard = AVDISCARD_ALL
                    assetTracks.first { $0.mediaType == .audio && $0.streamIndex == index }?.stream.pointee.discard = AVDISCARD_DEFAULT
                }
            }
        }
        let bitRateState = VideoAdaptationState.BitRateState(bitRate: newBitrate, time: CACurrentMediaTime())
        videoAdaptation.bitRateStates.append(bitRateState)
        delegate?.sourceDidChange(oldBitRate: oldBitRate, newBitrate: newBitrate)
    }
}

extension MEPlayerItem: OutputRenderSourceDelegate {
    func setVideo(time: CMTime) {
        if isAudioStalled {
            currentPlaybackTime = time.seconds - options.audioDelay
            videoMediaTime = CACurrentMediaTime()
        }
    }

    func setAudio(time: CMTime) {
        if !isAudioStalled {
            currentPlaybackTime = time.seconds
        }
    }

    func getOutputRender(type: AVFoundation.AVMediaType) -> MEFrame? {
        if type == .video {
            let predicate: (MEFrame) -> Bool = { [weak self] frame -> Bool in
                guard let self = self else { return true }
                var desire = self.currentPlaybackTime + self.options.audioDelay
                if self.isAudioStalled {
                    desire += max(CACurrentMediaTime() - self.videoMediaTime, 0)
                }
                return frame.cmtime.seconds <= desire
            }
            let frame = videoTrack?.getOutputRender(where: predicate)
            if let frame = frame, frame.seconds + 0.4 < currentPlaybackTime + options.audioDelay {
                _ = videoTrack?.getOutputRender(where: nil)
            }
            return frame
        } else {
            return audioTrack?.getOutputRender(where: nil)
        }
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
