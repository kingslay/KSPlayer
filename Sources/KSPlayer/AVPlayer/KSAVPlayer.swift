import AVFoundation
import AVKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
public typealias UIImage = NSImage
#endif
import Combine
import CoreGraphics
public final class KSAVPlayerView: UIView {
    public let player = AVQueuePlayer()
    override public init(frame: CGRect) {
        super.init(frame: frame)
        #if !canImport(UIKit)
        layer = AVPlayerLayer()
        #endif
        playerLayer.player = player
        player.automaticallyWaitsToMinimizeStalling = false
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var contentMode: UIViewContentMode {
        get {
            switch playerLayer.videoGravity {
            case .resize:
                return .scaleToFill
            case .resizeAspect:
                return .scaleAspectFit
            case .resizeAspectFill:
                return .scaleAspectFill
            default:
                return .scaleAspectFit
            }
        }
        set {
            switch newValue {
            case .scaleToFill:
                playerLayer.videoGravity = .resize
            case .scaleAspectFit:
                playerLayer.videoGravity = .resizeAspect
            case .scaleAspectFill:
                playerLayer.videoGravity = .resizeAspectFill
            case .center:
                playerLayer.videoGravity = .resizeAspect
            default:
                break
            }
        }
    }

    #if canImport(UIKit)
    override public class var layerClass: AnyClass { AVPlayerLayer.self }
    #endif
    fileprivate var playerLayer: AVPlayerLayer {
        // swiftlint:disable force_cast
        layer as! AVPlayerLayer
        // swiftlint:enable force_cast
    }
}

public class KSAVPlayer {
    private var cancellable: AnyCancellable?
    private var options: KSOptions {
        didSet {
            player.currentItem?.preferredForwardBufferDuration = options.preferredForwardBufferDuration
            cancellable = options.$preferredForwardBufferDuration.sink { [weak self] newValue in
                self?.player.currentItem?.preferredForwardBufferDuration = newValue
            }
        }
    }

    private let playerView = KSAVPlayerView()
    private var urlAsset: AVURLAsset
    private var shouldSeekTo = TimeInterval(0)
    private var playerLooper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var bufferFullObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var loopCountObservation: NSKeyValueObservation?
    private var loopStatusObservation: NSKeyValueObservation?
    private var error: Error? {
        didSet {
            if let error {
                delegate?.finish(player: self, error: error)
            }
        }
    }

    @available(tvOS 14.0, *)
    public func pipController() -> AVPictureInPictureController? {
        AVPictureInPictureController(playerLayer: playerView.playerLayer)
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
    public var playbackCoordinator: AVPlaybackCoordinator {
        playerView.player.playbackCoordinator
    }

    public private(set) var bufferingProgress = 0 {
        didSet {
            delegate?.changeBuffering(player: self, progress: bufferingProgress)
        }
    }

    public weak var delegate: MediaPlayerDelegate?
    public private(set) var duration: TimeInterval = 0
    public private(set) var playableTime: TimeInterval = 0

    public var playbackRate: Float = 1 {
        didSet {
            if playbackState == .playing {
                player.rate = playbackRate
            }
        }
    }

    public var playbackVolume: Float = 1.0 {
        didSet {
            if player.volume != playbackVolume {
                player.volume = playbackVolume
            }
        }
    }

    public private(set) var loadState = MediaLoadState.idle {
        didSet {
            if loadState != oldValue {
                playOrPause()
                if loadState == .loading || loadState == .idle {
                    bufferingProgress = 0
                }
            }
        }
    }

    public private(set) var playbackState = MediaPlaybackState.idle {
        didSet {
            if playbackState != oldValue {
                playOrPause()
                if playbackState == .finished {
                    delegate?.finish(player: self, error: nil)
                }
            }
        }
    }

    public private(set) var isReadyToPlay = false {
        didSet {
            if isReadyToPlay != oldValue {
                if isReadyToPlay {
                    options.readyTime = CACurrentMediaTime()
                    delegate?.readyToPlay(player: self)
                }
            }
        }
    }

    public required init(url: URL, options: KSOptions) {
        KSOptions.setAudioSession()
        urlAsset = AVURLAsset(url: url, options: options.avOptions)
        self.options = options
        itemObservation = player.observe(\.currentItem) { [weak self] player, _ in
            guard let self else { return }
            self.observer(playerItem: player.currentItem)
        }
    }
}

extension KSAVPlayer {
    public var player: AVQueuePlayer { playerView.player }
    public var playerLayer: AVPlayerLayer { playerView.playerLayer }
    @objc private func moviePlayDidEnd(notification _: Notification) {
        if !options.isLoopPlay {
            playbackState = .finished
        }
    }

    @objc private func playerItemFailedToPlayToEndTime(notification: Notification) {
        var playError: Error?
        if let userInfo = notification.userInfo {
            if let error = userInfo["error"] as? Error {
                playError = error
            } else if let error = userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError {
                playError = error
            } else if let errorCode = (userInfo["error"] as? NSNumber)?.intValue {
                playError = NSError(domain: "AVMoviePlayer", code: errorCode, userInfo: nil)
            }
        }
        delegate?.finish(player: self, error: playError)
    }

    private func updateStatus(item: AVPlayerItem) {
        if item.status == .readyToPlay {
            options.findTime = CACurrentMediaTime()
            let videoTracks = item.tracks.filter { $0.assetTrack?.mediaType.rawValue == AVMediaType.video.rawValue }
            if videoTracks.isEmpty || videoTracks.allSatisfy({ $0.assetTrack?.isPlayable == false }) {
                error = NSError(errorCode: .videoTracksUnplayable)
                return
            }
            // 默认选择第一个声道
            item.tracks.filter { $0.assetTrack?.mediaType.rawValue == AVMediaType.audio.rawValue }.dropFirst().forEach { $0.isEnabled = false }
            duration = item.duration.seconds
            isReadyToPlay = true
        } else if item.status == .failed {
            error = item.error
        }
    }

    private func updatePlayableDuration(item: AVPlayerItem) {
        let first = item.loadedTimeRanges.first { CMTimeRangeContainsTime($0.timeRangeValue, time: item.currentTime()) }
        if let first {
            playableTime = first.timeRangeValue.end.seconds
            guard playableTime > 0 else { return }
            let loadedTime = playableTime - currentPlaybackTime
            guard loadedTime > 0 else { return }
            bufferingProgress = Int(min(loadedTime * 100 / item.preferredForwardBufferDuration, 100))
            if bufferingProgress >= 100 {
                loadState = .playable
            }
        }
    }

    private func playOrPause() {
        if playbackState == .playing {
            if loadState == .playable {
                player.play()
                player.rate = playbackRate
            }
        } else {
            player.pause()
        }
        delegate?.changeLoadState(player: self)
    }

    private func replaceCurrentItem(playerItem: AVPlayerItem?) {
        player.currentItem?.cancelPendingSeeks()
        if options.isLoopPlay {
            loopCountObservation?.invalidate()
            loopStatusObservation?.invalidate()
            playerLooper?.disableLooping()
            guard let playerItem else {
                playerLooper = nil
                return
            }
            playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
            loopCountObservation = playerLooper?.observe(\.loopCount) { [weak self] playerLooper, _ in
                guard let self else { return }
                self.delegate?.playBack(player: self, loopCount: playerLooper.loopCount)
            }
            loopStatusObservation = playerLooper?.observe(\.status) { [weak self] playerLooper, _ in
                guard let self else { return }
                if playerLooper.status == .failed {
                    self.error = playerLooper.error
                }
            }
        } else {
            player.replaceCurrentItem(with: playerItem)
        }
    }

    private func observer(playerItem: AVPlayerItem?) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        statusObservation?.invalidate()
        loadedTimeRangesObservation?.invalidate()
        bufferEmptyObservation?.invalidate()
        likelyToKeepUpObservation?.invalidate()
        bufferFullObservation?.invalidate()
        guard let playerItem else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(moviePlayDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        statusObservation = playerItem.observe(\.status) { [weak self] item, _ in
            guard let self else { return }
            self.updateStatus(item: item)
        }
        loadedTimeRangesObservation = playerItem.observe(\.loadedTimeRanges) { [weak self] item, _ in
            guard let self else { return }
            // 计算缓冲进度
            self.updatePlayableDuration(item: item)
        }

        let changeHandler: (AVPlayerItem, NSKeyValueObservedChange<Bool>) -> Void = { [weak self] _, _ in
            guard let self else { return }
            // 在主线程更新进度
            if playerItem.isPlaybackBufferEmpty {
                self.loadState = .loading
            } else if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
                self.loadState = .playable
            }
        }
        bufferEmptyObservation = playerItem.observe(\.isPlaybackBufferEmpty, changeHandler: changeHandler)
        likelyToKeepUpObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: changeHandler)
        bufferFullObservation = playerItem.observe(\.isPlaybackBufferFull, changeHandler: changeHandler)
    }
}

extension KSAVPlayer: MediaPlayerProtocol {
    public var subtitleDataSouce: SubtitleDataSouce? { nil }
    public var isPlaying: Bool { player.rate > 0 ? true : playbackState == .playing }
    public var view: UIView? { playerView }
    public var allowsExternalPlayback: Bool {
        get {
            player.allowsExternalPlayback
        }
        set {
            player.allowsExternalPlayback = newValue
        }
    }

    public var usesExternalPlaybackWhileExternalScreenIsActive: Bool {
        get {
            #if os(macOS)
            return false
            #else
            return player.usesExternalPlaybackWhileExternalScreenIsActive
            #endif
        }
        set {
            #if !os(macOS)
            player.usesExternalPlaybackWhileExternalScreenIsActive = newValue
            #endif
        }
    }

    public var isExternalPlaybackActive: Bool { player.isExternalPlaybackActive }

    public var naturalSize: CGSize {
        urlAsset.tracks(withMediaType: .video).first { $0.isEnabled }?.naturalSize ?? .zero
    }

    public var currentPlaybackTime: TimeInterval {
        get {
            if shouldSeekTo > 0 {
                return TimeInterval(shouldSeekTo)
            } else {
                // 防止卡主
                return isReadyToPlay ? player.currentTime().seconds : 0
            }
        }
        set {
            Task {
                _ = await seek(time: newValue)
            }
        }
    }

    public var numberOfBytesTransferred: Int64 {
        guard let playerItem = player.currentItem, let accesslog = playerItem.accessLog(), let event = accesslog.events.first else {
            return 0
        }
        return event.numberOfBytesTransferred
    }

    public func thumbnailImageAtCurrentTime() async -> UIImage? {
        guard let playerItem = player.currentItem, isReadyToPlay else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            urlAsset.thumbnailImage(currentTime: playerItem.currentTime()) { result in
                continuation.resume(returning: result)
            }
        }
    }

    public func seek(time: TimeInterval) async -> Bool {
        let time = max(time, 0)
        shouldSeekTo = time
        playbackState = .seeking
        runInMainqueue { [weak self] in
            self?.bufferingProgress = 0
        }
        let tolerance: CMTime = options.isAccurateSeek ? .zero : .positiveInfinity
        let finished = await player.seek(to: CMTime(seconds: time, preferredTimescale: Int32(NSEC_PER_SEC)), toleranceBefore: tolerance, toleranceAfter: tolerance)
        shouldSeekTo = 0
        return finished
    }

    public func prepareToPlay() {
        KSLog("prepareToPlay \(self)")
        options.prepareTime = CACurrentMediaTime()
        runInMainqueue { [weak self] in
            guard let self else { return }
            self.bufferingProgress = 0
            let playerItem = AVPlayerItem(asset: self.urlAsset)
            self.options.openTime = CACurrentMediaTime()
            self.replaceCurrentItem(playerItem: playerItem)
            self.player.actionAtItemEnd = .pause
            self.player.volume = self.playbackVolume
        }
    }

    public func play() {
        KSLog("play \(self)")
        playbackState = .playing
    }

    public func pause() {
        KSLog("pause \(self)")
        playbackState = .paused
    }

    public func shutdown() {
        KSLog("shutdown \(self)")
        isReadyToPlay = false
        playbackState = .stopped
        loadState = .idle
        urlAsset.cancelLoading()
        replaceCurrentItem(playerItem: nil)
    }

    public func replace(url: URL, options: KSOptions) {
        KSLog("replaceUrl \(self)")
        shutdown()
        urlAsset = AVURLAsset(url: url, options: options.avOptions)
        self.options = options
    }

    public var contentMode: UIViewContentMode {
        get {
            playerView.contentMode
        }
        set {
            playerView.contentMode = newValue
        }
    }

    public func enterBackground() {
        playerView.playerLayer.player = nil
    }

    public func enterForeground() {
        playerView.playerLayer.player = playerView.player
    }

    public var seekable: Bool {
        !(player.currentItem?.seekableTimeRanges.isEmpty ?? true)
    }

    public var isMuted: Bool {
        get {
            player.isMuted
        }
        set {
            player.isMuted = newValue
        }
    }

    public func tracks(mediaType: AVMediaType) -> [MediaPlayerTrack] {
        player.currentItem?.tracks.filter { $0.assetTrack?.mediaType == mediaType }.map { AVMediaPlayerTrack(track: $0) } ?? []
    }

    public func select(track: MediaPlayerTrack) {
        player.currentItem?.tracks.filter { $0.assetTrack?.mediaType == track.mediaType }.forEach { $0.isEnabled = false }
        track.setIsEnabled(true)
    }
}

extension AVMediaType {
    var mediaCharacteristic: AVMediaCharacteristic {
        switch self {
        case .video:
            return .visual
        case .audio:
            return .audible
        case .subtitle:
            return .legible
        default:
            return .easyToRead
        }
    }
}

struct AVMediaPlayerTrack: MediaPlayerTrack {
    let description: String
    private let track: AVPlayerItemTrack
    let nominalFrameRate: Float
    let trackID: Int32
    let mediaSubType: CMFormatDescription.MediaSubType
    let rotation: Double = 0
    let bitRate: Int64
    let naturalSize: CGSize
    let name: String
    let language: String?
    let mediaType: AVMediaType
    let depth: Int32
    let fullRangeVideo: Bool
    let colorPrimaries: String?
    let transferFunction: String?
    let yCbCrMatrix: String?
    var dovi: DOVIDecoderConfigurationRecord?
    var audioStreamBasicDescription: AudioStreamBasicDescription?
    let fieldOrder: FFmpegFieldOrder = .unknown
    var isEnabled: Bool {
        get {
            track.isEnabled
        }
        set {
            track.isEnabled = newValue
        }
    }

    init(track: AVPlayerItemTrack) {
        self.track = track
        trackID = track.assetTrack?.trackID ?? 0
        mediaType = track.assetTrack?.mediaType ?? .video
        name = track.assetTrack?.languageCode ?? ""
        language = track.assetTrack?.extendedLanguageTag
        nominalFrameRate = track.assetTrack?.nominalFrameRate ?? 24.0
        naturalSize = track.assetTrack?.naturalSize ?? .zero
        bitRate = Int64(track.assetTrack?.estimatedDataRate ?? 0)
        if let formatDescription = track.assetTrack?.formatDescriptions.first {
            // swiftlint:disable force_cast
            let desc = formatDescription as! CMFormatDescription
            // swiftlint:enable force_cast
            mediaSubType = desc.mediaSubType
            audioStreamBasicDescription = desc.audioStreamBasicDescription
            let dictionary = CMFormatDescriptionGetExtensions(desc) as NSDictionary?
            colorPrimaries = dictionary?[kCVImageBufferColorPrimariesKey] as? String
            transferFunction = dictionary?[kCVImageBufferTransferFunctionKey] as? String
            yCbCrMatrix = dictionary?[kCVImageBufferYCbCrMatrixKey] as? String
            fullRangeVideo = (dictionary?[kCMFormatDescriptionExtension_FullRangeVideo] as? Int32 ?? 0) == 1
            depth = dictionary?[kCMFormatDescriptionExtension_Depth] as? Int32 ?? 24
            description = mediaSubType.rawValue.string
        } else {
            depth = 24
            colorPrimaries = nil
            transferFunction = nil
            yCbCrMatrix = nil
            mediaSubType = CMFormatDescription.MediaSubType(string: "")
            fullRangeVideo = false
            description = ""
        }
    }

    func setIsEnabled(_ isEnabled: Bool) {
        track.isEnabled = isEnabled
    }
}

public extension AVAsset {
    func ceateImageGenerator() -> AVAssetImageGenerator {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        return imageGenerator
    }

    func thumbnailImage(currentTime: CMTime, handler: @escaping (UIImage?) -> Void) {
        let imageGenerator = ceateImageGenerator()
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: currentTime)]) { _, cgImage, _, _, _ in
            if let cgImage {
                handler(UIImage(cgImage: cgImage))
            } else {
                handler(nil)
            }
        }
    }
}

extension CGImage {
    static func combine(images: [(CGRect, CGImage)]) -> CGImage? {
        if images.isEmpty {
            return nil
        }
        if images.count == 1 {
            return images[0].1
        }
        var width = 0
        var height = 0
        for (rect, _) in images {
            width = max(width, Int(rect.maxX))
            height = max(height, Int(rect.maxY))
        }
        let bitsPerComponent = 8
        // RGBA(的bytes) * bitsPerComponent *width
        let bytesPerRow = 4 * 8 * bitsPerComponent * width
        return autoreleasepool {
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let context else {
                return nil
            }
            for (rect, cgImage) in images {
                context.draw(cgImage, in: CGRect(x: rect.origin.x, y: CGFloat(height) - rect.maxY, width: rect.width, height: rect.height))
            }
            let cgImage = context.makeImage()
            return cgImage
        }
    }
}
