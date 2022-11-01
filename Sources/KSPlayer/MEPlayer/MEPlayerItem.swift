//
//  MEPlayerItem.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import FFmpeg
import Libavfilter
import Libavformat
import VideoToolbox

final class MEPlayerItem {
    private let url: URL
    private let options: KSOptions
    private let operationQueue = OperationQueue()
    private let condition = NSCondition()
    private var formatCtx: UnsafeMutablePointer<AVFormatContext>? {
        didSet {
            options.formatCtx = formatCtx
        }
    }

    private var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var outputPacket: UnsafeMutablePointer<AVPacket>?
    private var streamMapping = [Int: Int]()
    private var openOperation: BlockOperation?
    private var readOperation: BlockOperation?
    private var closeOperation: BlockOperation?
    private var seekingCompletionHandler: ((Bool) -> Void)?
    // 没有音频数据可以渲染
    private var isAudioStalled = true
    private var videoMediaTime = CACurrentMediaTime()
    private var isFirst = true
    private var isSeek = false
    private var allPlayerItemTracks = [PlayerItemTrackProtocol]()
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

    private var videoTrack: SyncPlayerItemTrack<VideoVTBFrame>?
    private var audioTrack: SyncPlayerItemTrack<AudioFrame>?
    private(set) var assetTracks = [FFmpegAssetTrack]()
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
        av_log_set_callback { ptr, level, format, args in
            guard let format else {
                return
            }
            var log = String(cString: format)
            let arguments: CVaListPointer? = args
            if let arguments {
                log = NSString(format: log, arguments: arguments) as String
            }
            if let ptr {
                let avclass = ptr.assumingMemoryBound(to: UnsafePointer<AVClass>.self).pointee
                if avclass == &ffurl_context_class {
                    let context = ptr.assumingMemoryBound(to: URLContext.self).pointee
                    if let opaque = context.interrupt_callback.opaque {
                        let formatContext = Unmanaged<MEPlayerItem>.fromOpaque(opaque).takeUnretainedValue()
                        formatContext.options.io(log: log)
                    }

                } else if avclass == avfilter_get_class() {
                    let context = ptr.assumingMemoryBound(to: AVFilterContext.self).pointee
                    if let opaque = context.graph?.pointee.opaque {
                        let options = Unmanaged<KSOptions>.fromOpaque(opaque).takeUnretainedValue()
                        options.filter(log: log)
                    }
                }
            }
            // 找不到解码器
            if log.hasPrefix("parser not found for codec") {
                KSLog(log)
            }
            if level <= KSOptions.logLevel.rawValue {
                KSLog(log)
            }
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
        if track.mediaType == .video, let assetTrack = track as? FFmpegAssetTrack {
            findBestAudio(videoTrack: assetTrack)
        }
        if track.mediaType == .subtitle {
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
        options.openTime = CACurrentMediaTime()
        formatCtx.pointee.flags |= AVFMT_FLAG_GENPTS
        av_format_inject_global_side_data(formatCtx)
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
        if let outputURL = options.outputURL {
            openOutput(url: outputURL)
        }
        if videoTrack == nil, audioTrack == nil {
            state = .failed
        } else {
            state = .opened
            if let startPlayTime = options.startPlayTime {
                currentPlaybackTime = startPlayTime
            }
            read()
        }
    }

    private func openOutput(url: URL) {
        let filename = url.isFileURL ? url.path : url.absoluteString
        var ret = avformat_alloc_output_context2(&outputFormatCtx, nil, nil, filename)
        guard let outputFormatCtx, let formatCtx else {
            KSLog(NSError(errorCode: .formatOutputCreate, ffmpegErrnum: ret))
            return
        }
        var index = 0
        var audioIndex: Int?
        var videoIndex: Int?
        let formatName = outputFormatCtx.pointee.oformat.pointee.name.flatMap { String(cString: $0) }
        (0 ..< Int(formatCtx.pointee.nb_streams)).forEach { i in
            if let inputStream = formatCtx.pointee.streams[i] {
                let codecType = inputStream.pointee.codecpar.pointee.codec_type
                if [AVMEDIA_TYPE_AUDIO, AVMEDIA_TYPE_VIDEO, AVMEDIA_TYPE_SUBTITLE].contains(codecType) {
                    if codecType == AVMEDIA_TYPE_AUDIO {
                        if let audioIndex {
                            streamMapping[i] = audioIndex
                            return
                        } else {
                            audioIndex = index
                        }
                    } else if codecType == AVMEDIA_TYPE_VIDEO {
                        if let videoIndex {
                            streamMapping[i] = videoIndex
                            return
                        } else {
                            videoIndex = index
                        }
                    }
                    if let outStream = avformat_new_stream(outputFormatCtx, nil) {
                        streamMapping[i] = index
                        index += 1
                        avcodec_parameters_copy(outStream.pointee.codecpar, inputStream.pointee.codecpar)
                        if codecType == AVMEDIA_TYPE_SUBTITLE, formatName == "mp4" || formatName == "mov" {
                            outStream.pointee.codecpar.pointee.codec_id = AV_CODEC_ID_MOV_TEXT
                        }
                        if inputStream.pointee.codecpar.pointee.codec_id == AV_CODEC_ID_HEVC {
                            outStream.pointee.codecpar.pointee.codec_tag = CMFormatDescription.MediaSubType.hevc.rawValue.bigEndian
                        } else {
                            outStream.pointee.codecpar.pointee.codec_tag = 0
                        }
                    }
                }
            }
        }
        avio_open(&(outputFormatCtx.pointee.pb), filename, AVIO_FLAG_WRITE)
        ret = avformat_write_header(outputFormatCtx, nil)
        guard ret >= 0 else {
            KSLog(NSError(errorCode: .formatWriteHeader, ffmpegErrnum: ret))
            avformat_close_input(&self.outputFormatCtx)
            return
        }
        outputPacket = av_packet_alloc()
    }

    private func createCodec(formatCtx: UnsafeMutablePointer<AVFormatContext>) {
        allPlayerItemTracks.removeAll()
        assetTracks.removeAll()
        videoAdaptation = nil
        videoTrack = nil
        audioTrack = nil
        assetTracks = (0 ..< Int(formatCtx.pointee.nb_streams)).compactMap { i in
            if let coreStream = formatCtx.pointee.streams[i] {
                coreStream.pointee.discard = AVDISCARD_ALL
                if let assetTrack = FFmpegAssetTrack(stream: coreStream) {
                    if assetTrack.startTime == 0, startTime != 0 {
                        assetTrack.startTime = startTime
                    }
                    if !options.subtitleDisable, assetTrack.mediaType == .subtitle {
                        let subtitle = SyncPlayerItemTrack<SubtitleFrame>(assetTrack: assetTrack, options: options)
                        assetTrack.subtitle = subtitle
                        allPlayerItemTracks.append(subtitle)
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
                let track = options.syncDecodeVideo ? SyncPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options)
                track.delegate = self
                allPlayerItemTracks.append(track)
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
            let track = options.syncDecodeAudio ? SyncPlayerItemTrack<AudioFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<AudioFrame>(assetTrack: first, options: options)
            track.delegate = self
            allPlayerItemTracks.append(track)
            audioTrack = track
            isAudioStalled = false
        }
    }

    private func read() {
        readOperation = BlockOperation { [weak self] in
            guard let self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_read"
            Thread.current.stackSize = KSOptions.stackSize
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
        if currentPlaybackTime > 0 {
            state = .seeking
        } else {
            state = .reading
        }
        allPlayerItemTracks.forEach { $0.decode() }
        while [MESourceState.paused, .seeking, .reading].contains(state) {
            if state == .paused {
                condition.wait()
            }
            if state == .seeking {
                let time = currentPlaybackTime + startTime
                allPlayerItemTracks.forEach { $0.seek(time: time) }
                let timeStamp = Int64(time * TimeInterval(AV_TIME_BASE))
                // can not seek to key frame
//                let result = avformat_seek_file(formatCtx, -1, Int64.min, timeStamp, Int64.max, options.seekFlags)
                let result = av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                // When seeking before the beginning of the file, and seeking fails,
                // try again without the backwards flag to make it seek to the
                // beginning.
                if result < 0, options.seekFlags & AVSEEK_FLAG_BACKWARD > 0 {
                    options.seekFlags &= ~AVSEEK_FLAG_BACKWARD
                    av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                }
                if state == .closed {
                    break
                }
                isSeek = true
                allPlayerItemTracks.forEach { $0.seek(time: time) }
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
        guard let corePacket = packet.corePacket else {
            return
        }
        let readResult = av_read_frame(formatCtx, corePacket)
        if state == .closed {
            return
        }
        if readResult == 0 {
            if let outputFormatCtx, let formatCtx {
                let index = Int(corePacket.pointee.stream_index)
                if let outputIndex = streamMapping[index],
                   let inputTb = formatCtx.pointee.streams[index]?.pointee.time_base,
                   let outputTb = outputFormatCtx.pointee.streams[outputIndex]?.pointee.time_base
                {
                    av_packet_ref(outputPacket, corePacket)
                    outputPacket?.pointee.stream_index = Int32(outputIndex)
                    av_packet_rescale_ts(outputPacket, inputTb, outputTb)
                    outputPacket?.pointee.pos = -1
                    let ret = av_interleaved_write_frame(outputFormatCtx, outputPacket)
                    if ret < 0 {
                        KSLog("can not av_interleaved_write_frame")
                    }
                }
            }
            if formatCtx?.pointee.pb?.pointee.eof_reached == 1 {
                // todo need reconnect
            }
            if corePacket.pointee.size <= 0 {
                return
            }
            packet.fill()
            let first = assetTracks.first { $0.trackID == corePacket.pointee.stream_index }
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
            if readResult == AVError.eof.code || formatCtx?.pointee.pb?.pointee.eof_reached == 1 {
                if options.isLoopPlay, allPlayerItemTracks.allSatisfy({ !$0.isLoopModel }) {
                    allPlayerItemTracks.forEach { $0.isLoopModel = true }
                    _ = av_seek_frame(formatCtx, -1, 0, AVSEEK_FLAG_BACKWARD)
                } else {
                    allPlayerItemTracks.forEach { $0.isEndOfFile = true }
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
            Thread.current.stackSize = KSOptions.stackSize
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
        av_packet_free(&outputPacket)
        if let outputFormatCtx {
            av_write_trailer(outputFormatCtx)
        }
        condition.signal()
        // 故意循环引用。等结束了。才释放
        let closeOperation = BlockOperation {
            Thread.current.name = (self.operationQueue.name ?? "") + "_close"
            self.allPlayerItemTracks.forEach { $0.shutdown() }
            KSLog("清空formatCtx")
            avformat_close_input(&self.formatCtx)
            avformat_close_input(&self.outputFormatCtx)
            self.duration = 0
            self.closeOperation = nil
            self.operationQueue.cancelAllOperations()
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
                    currentPlaybackTime = 0
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
              let newFFmpegAssetTrack = assetTracks.first(where: { $0.mediaType == .video && $0.bitRate == newBitrate })
        else {
            return
        }
        assetTracks.first { $0.mediaType == .video && $0.bitRate == oldBitRate }?.isEnabled = false
        newFFmpegAssetTrack.isEnabled = true
        findBestAudio(videoTrack: newFFmpegAssetTrack)
        let bitRateState = VideoAdaptationState.BitRateState(bitRate: newBitrate, time: CACurrentMediaTime())
        videoAdaptation?.bitRateStates.append(bitRateState)
        delegate?.sourceDidChange(oldBitRate: oldBitRate, newBitrate: newBitrate)
    }

    private func findBestAudio(videoTrack: FFmpegAssetTrack) {
        guard videoAdaptation != nil, let first = assetTracks.first(where: { $0.mediaType == .audio && $0.isEnabled }) else {
            return
        }
        let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, videoTrack.trackID, nil, 0)
        if index != first.trackID {
            first.isEnabled = false
            assetTracks.first { $0.mediaType == .audio && $0.trackID == index }?.isEnabled = true
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

    func getVideoOutputRender(force: Bool) -> VideoVTBFrame? {
        guard let videoTrack else {
            return nil
        }
        var desire = currentPlaybackTime + options.audioDelay + startTime
        let predicate: ((VideoVTBFrame) -> Bool)? = force ? nil : { [weak self] frame -> Bool in
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
                let frameCount = videoTrack.frameCount
                if frameCount > 0 {
                    KSLog("dropped video frame frameCount: \(videoTrack.frameCount) frameMaxCount: \(videoTrack.frameMaxCount)")
                    _ = videoTrack.getOutputRender(where: nil)
                }
            }
        }
        return options.videoDisable ? nil : frame
    }

    func getAudioOutputRender() -> AudioFrame? {
        audioTrack?.getOutputRender(where: nil)
    }
}
