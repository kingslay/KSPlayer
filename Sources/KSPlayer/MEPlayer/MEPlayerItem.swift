//
//  MEPlayerItem.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import FFmpegKit
import Libavcodec
import Libavfilter
import Libavformat

final class MEPlayerItem {
    private let url: URL
    private let options: KSOptions
    private let operationQueue = OperationQueue()
    private let condition = NSCondition()
    private var formatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var outputPacket: UnsafeMutablePointer<AVPacket>?
    private var streamMapping = [Int: Int]()
    private var openOperation: BlockOperation?
    private var readOperation: BlockOperation?
    private var closeOperation: BlockOperation?
    private var seekingCompletionHandler: ((Bool) -> Void)?
    // 没有音频数据可以渲染
    private var isAudioStalled = true
    private var audioClock = KSClock()
    private var videoClock = KSClock()
    private var isFirst = true
    private var isSeek = false
    private var allPlayerItemTracks = [PlayerItemTrackProtocol]()
    private var maxFrameDuration = 10.0
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
    var currentPlaybackTime: TimeInterval {
        state == .seeking ? seekTime : mainClock().positionTime
    }

    private var seekTime = TimeInterval(0)
    private(set) var startTime = TimeInterval(0)
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

    private lazy var timer: Timer = .scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
        self?.codecDidChangeCapacity()
    }

    private static var onceInitial: Void = {
        var result = SSL_library_init()
        result = avformat_network_init()
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
                if avclass.pointee.category == AV_CLASS_CATEGORY_NA, avclass == &ffurl_context_class {
                    let context = ptr.assumingMemoryBound(to: URLContext.self).pointee
                    if let opaque = context.interrupt_callback.opaque {
                        let playerItem = Unmanaged<MEPlayerItem>.fromOpaque(opaque).takeUnretainedValue()
                        playerItem.options.io(log: log)
                        if log.starts(with: "Will reconnect at") {
                            playerItem.videoTrack?.seekTime = playerItem.currentPlaybackTime
                            playerItem.audioTrack?.seekTime = playerItem.currentPlaybackTime
                        }
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
            KSLog(level: LogLevel(rawValue: level) ?? KSOptions.logLevel, log)
        }
    }()

    weak var delegate: MEPlayerDelegate?
    init(url: URL, options: KSOptions) {
        self.url = url
        self.options = options
        timer.fireDate = Date.distantFuture
        operationQueue.name = "KSPlayer_" + String(describing: self).components(separatedBy: ".").last!
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
        _ = MEPlayerItem.onceInitial
    }

    func select(track: some MediaPlayerTrack) {
        if track.isEnabled {
            return
        }
        assetTracks.filter { $0.mediaType == track.mediaType }.forEach {
            if $0.mediaType == .subtitle, !$0.isImageSubtitle {
                return
            }
            $0.isEnabled = false
        }
        track.isEnabled = true
        guard let assetTrack = track as? FFmpegAssetTrack else {
            return
        }
        if assetTrack.mediaType == .video {
            findBestAudio(videoTrack: assetTrack)
        } else if assetTrack.mediaType == .subtitle {
            if assetTrack.isImageSubtitle {
                if !options.isSeekImageSubtitle {
                    return
                }
            } else {
                return
            }
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
//        formatCtx.pointee.io_close2 = { formatCtx, pb -> Int32 in
//            return 0
//
//        }
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
        // 如果要自定义协议的话，那就用avio_alloc_context，对formatCtx.pointee.pb赋值
        var result = avformat_open_input(&self.formatCtx, urlString, nil, &avOptions)
        av_dict_free(&avOptions)
        if result == AVError.eof.code {
            state = .finished
            delegate?.sourceDidFinished()
            return
        }
        guard result == 0 else {
            error = .init(errorCode: .formatOpenInput, avErrorCode: result)
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
            error = .init(errorCode: .formatFindStreamInfo, avErrorCode: result)
            avformat_close_input(&self.formatCtx)
            return
        }
        maxFrameDuration = formatCtx.pointee.iformat.pointee.flags & AVFMT_TS_DISCONT != 0 ? 10.0 : 3600.0
        options.findTime = CACurrentMediaTime()
        options.formatName = String(cString: formatCtx.pointee.iformat.pointee.name)
        if formatCtx.pointee.start_time != Int64.min {
            startTime = CMTime(value: formatCtx.pointee.start_time, timescale: AV_TIME_BASE).seconds
        }
        mainClock().positionTime = startTime
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
            read()
        }
    }

    private func openOutput(url: URL) {
        let filename = url.isFileURL ? url.path : url.absoluteString
        var ret = avformat_alloc_output_context2(&outputFormatCtx, nil, nil, filename)
        guard let outputFormatCtx, let formatCtx else {
            KSLog(NSError(errorCode: .formatOutputCreate, avErrorCode: ret))
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
            KSLog(NSError(errorCode: .formatWriteHeader, avErrorCode: ret))
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
                    assetTrack.startTime = startTime
                    if !options.subtitleDisable, assetTrack.mediaType == .subtitle {
                        let subtitle = SyncPlayerItemTrack<SubtitleFrame>(assetTrack: assetTrack, options: options)
                        assetTrack.isEnabled = !assetTrack.isImageSubtitle
                        assetTrack.subtitle = subtitle
                        allPlayerItemTracks.append(subtitle)
                    }
                    return assetTrack
                }
            }
            return nil
        }
        if options.autoSelectEmbedSubtitle {
            assetTracks.first { $0.mediaType == .subtitle }?.isEnabled = true
        }
        var videoIndex: Int32 = -1
        if !options.videoDisable {
            let videos = assetTracks.filter { $0.mediaType == .video }
            let bitRates = videos.map(\.bitRate)
            let wantedStreamNb: Int32
            if !videos.isEmpty, let index = options.wantedVideo(bitRates: bitRates) {
                wantedStreamNb = videos[index].trackID
            } else {
                wantedStreamNb = -1
            }
            videoIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, wantedStreamNb, -1, nil, 0)
            if let first = videos.first(where: { $0.trackID == videoIndex }) {
                first.isEnabled = true
                let rotation = first.rotation
                if rotation > 0, options.autoRotate {
                    options.hardwareDecode = false
                    if abs(rotation - 90) <= 1 {
                        options.videoFilters.append("transpose=clock")
                    } else if abs(rotation - 180) <= 1 {
                        options.videoFilters.append("hflip")
                        options.videoFilters.append("vflip")
                    } else if abs(rotation - 270) <= 1 {
                        options.videoFilters.append("transpose=cclock")
                    } else if abs(rotation) > 1 {
                        options.videoFilters.append("rotate=\(rotation)*PI/180")
                    }
                }
                naturalSize = abs(rotation - 90) <= 1 || abs(rotation - 270) <= 1 ? first.naturalSize.reverse : first.naturalSize
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
        if !audios.isEmpty, let index = options.wantedAudio(infos: audios.map { ($0.bitRate, $0.language) }) {
            wantedStreamNb = audios[index].trackID
        } else {
            wantedStreamNb = -1
        }
        let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, wantedStreamNb, videoIndex, nil, 0)
        if let first = audios.first(where: {
            index > 0 ? $0.trackID == index : true
        }) {
            first.isEnabled = true
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
        if let readOperation {
            operationQueue.addOperation(readOperation)
        }
    }

    private func readThread() {
        if state == .opened {
            if options.startPlayTime > 0 {
                seekTime = options.startPlayTime + startTime
                state = .seeking
            } else {
                state = .reading
            }
        }
        allPlayerItemTracks.forEach { $0.decode() }
        while [MESourceState.paused, .seeking, .reading].contains(state) {
            if state == .paused {
                condition.wait()
            }
            if state == .seeking {
                let time = seekTime
                let timeStamp = Int64(time * TimeInterval(AV_TIME_BASE))
                let startTime = CACurrentMediaTime()
                // can not seek to key frame
//                let result = avformat_seek_file(formatCtx, -1, Int64.min, timeStamp, Int64.max, options.seekFlags)
                var result = av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                // When seeking before the beginning of the file, and seeking fails,
                // try again without the backwards flag to make it seek to the
                // beginning.
                if result < 0, options.seekFlags & AVSEEK_FLAG_BACKWARD > 0 {
                    options.seekFlags &= ~AVSEEK_FLAG_BACKWARD
                    result = av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                }
                KSLog("seek to \(time) spend Time: \(CACurrentMediaTime() - startTime)")
                if state == .closed {
                    break
                }
                isSeek = true
                allPlayerItemTracks.forEach { $0.seek(time: time) }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.seekingCompletionHandler?(result >= 0)
                    self.seekingCompletionHandler = nil
                }
                mainClock().positionTime = time
                videoClock.positionTime = time
                videoClock.duration = 0
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
                    _ = av_seek_frame(formatCtx, -1, Int64(startTime), AVSEEK_FLAG_BACKWARD)
                } else {
                    allPlayerItemTracks.forEach { $0.isEndOfFile = true }
                    state = .finished
                }
            } else {
                //                        if IS_AVERROR_INVALIDDATA(readResult)
                error = .init(errorCode: .readFrame, avErrorCode: readResult)
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

extension MEPlayerItem {
    var metadata: [String: String] {
        toDictionary(formatCtx?.pointee.metadata)
    }

    var bytesRead: Int64 {
        formatCtx?.pointee.pb.pointee.bytes_read ?? 0
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
        // 故意循环引用。等结束了。才释放
        let closeOperation = BlockOperation {
            Thread.current.name = (self.operationQueue.name ?? "") + "_close"
            self.allPlayerItemTracks.forEach { $0.shutdown() }
            KSLog("清空formatCtx")
            self.formatCtx?.pointee.interrupt_callback.opaque = nil
            self.formatCtx?.pointee.interrupt_callback.callback = nil
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
        condition.signal()
        if options.syncDecodeVideo || options.syncDecodeAudio {
            DispatchQueue.global().async { [weak self] in
                self?.allPlayerItemTracks.forEach { $0.shutdown() }
            }
        }
        self.closeOperation = closeOperation
    }

    func seek(time: TimeInterval, completion: @escaping ((Bool) -> Void)) {
        if state == .reading || state == .paused {
            seekTime = time
            state = .seeking
            seekingCompletionHandler = completion
            condition.broadcast()
            allPlayerItemTracks.forEach { $0.seek(time: time) }
        } else if state == .finished {
            seekTime = time
            state = .seeking
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
        if allSatisfy {
            delegate?.sourceDidFinished()
            timer.fireDate = Date.distantFuture
            if options.isLoopPlay {
                isAudioStalled = audioTrack == nil
                audioTrack?.isLoopModel = false
                videoTrack?.isLoopModel = false
                if state == .finished {
                    seek(time: startTime) { _ in }
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
    func mainClock() -> KSClock {
        isAudioStalled ? videoClock : audioClock
    }

    func setVideo(time: CMTime, duration: CMTime) {
        videoClock.positionTime = time.seconds
        videoClock.duration = duration.seconds
    }

    func setAudio(time: CMTime) {
        audioClock.positionTime = time.seconds
    }

    func getVideoOutputRender(force: Bool) -> VideoVTBFrame? {
        guard let videoTrack, videoTrack.frameCount > 0 else {
            return nil
        }
        let type = force ? .next : options.videoClockSync(main: mainClock(), video: videoClock)
        switch type {
        case .remain:
            return nil
        case .next:
            return videoTrack.getOutputRender(where: nil)
        case .dropNext:
            _ = videoTrack.getOutputRender(where: nil)
            return videoTrack.getOutputRender(where: nil)
        case .flush:
            videoTrack.outputRenderQueue.flush()
            return nil
        case .seek:
            videoTrack.outputRenderQueue.flush()
            videoTrack.seekTime = currentPlaybackTime
            return nil
        }
    }

    func getAudioOutputRender() -> AudioFrame? {
        audioTrack?.getOutputRender(where: nil)
    }
}
