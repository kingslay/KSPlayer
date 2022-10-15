//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import AVKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public class KSMEPlayer: NSObject {
    private var loopCount = 1
    private var playerItem: MEPlayerItem
    public let audioOutput = AudioEnginePlayer()
    public let videoOutput: MetalPlayView?
    private var options: KSOptions
    private var bufferingCountDownTimer: Timer?
    public private(set) var bufferingProgress = 0 {
        didSet {
            delegate?.changeBuffering(player: self, progress: bufferingProgress)
        }
    }

    @available(tvOS 14.0, *)
    public func pipController() -> AVPictureInPictureController? {
        if #available(iOS 15.0, tvOS 15.0, macOS 12.0, *), let videoOutput {
            let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: videoOutput.displayLayer, playbackDelegate: self)
            return AVPictureInPictureController(contentSource: contentSource)
        } else {
            return nil
        }
    }

    private lazy var _playbackCoordinator: Any? = {
        if #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) {
            let coordinator = AVDelegatingPlaybackCoordinator(playbackControlDelegate: self)
            coordinator.suspensionReasonsThatTriggerWaiting = [.stallRecovery]
            return coordinator
        } else {
            return nil
        }
    }()

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
    public var playbackCoordinator: AVPlaybackCoordinator {
        // swiftlint:disable force_cast
        _playbackCoordinator as! AVPlaybackCoordinator
        // swiftlint:enable force_cast
    }

    public private(set) var playableTime = TimeInterval(0)
    public weak var delegate: MediaPlayerDelegate?
    public private(set) var isReadyToPlay = false
    public var allowsExternalPlayback: Bool = false
    public var usesExternalPlaybackWhileExternalScreenIsActive: Bool = false

    public var playbackRate: Float = 1 {
        didSet {
            audioOutput.playbackRate = playbackRate
        }
    }

    public private(set) var loadState = MediaLoadState.idle {
        didSet {
            if loadState != oldValue {
                playOrPause()
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

    public required init(url: URL, options: KSOptions) {
        playerItem = MEPlayerItem(url: url, options: options)
        if options.videoDisable {
            videoOutput = nil
        } else {
            videoOutput = MetalPlayView(options: options)
        }
        self.options = options
        super.init()
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput?.renderSource = playerItem
    }

    deinit {
        videoOutput?.invalidate()
        playerItem.shutdown()
    }
}

// MARK: - private functions

extension KSMEPlayer {
    private func playOrPause() {
        runInMainqueue { [weak self] in
            guard let self else { return }
            let isPaused = !(self.playbackState == .playing && self.loadState == .playable)
            self.audioOutput.isPaused = isPaused
            self.videoOutput?.isPaused = isPaused
            self.delegate?.changeLoadState(player: self)
        }
    }
}

extension KSMEPlayer: MEPlayerDelegate {
    func sourceDidOpened() {
        isReadyToPlay = true
        options.readyTime = CACurrentMediaTime()
        runInMainqueue { [weak self] in
            guard let self else { return }
            self.videoOutput?.drawableSize = self.naturalSize
            self.view?.centerRotate(byDegrees: self.playerItem.rotation)
            self.videoOutput?.isPaused = false
            self.delegate?.readyToPlay(player: self)
        }
    }

    func sourceDidFailed(error: NSError?) {
        runInMainqueue { [weak self] in
            guard let self else { return }
            self.delegate?.finish(player: self, error: error)
        }
    }

    func sourceDidFinished(type: AVFoundation.AVMediaType, allSatisfy: Bool) {
        runInMainqueue { [weak self] in
            guard let self else { return }
            if allSatisfy {
                if self.options.isLoopPlay {
                    self.loopCount += 1
                    self.delegate?.playBack(player: self, loopCount: self.loopCount)
                    self.audioOutput.isPaused = false
                    self.videoOutput?.isPaused = false
                } else {
                    self.playbackState = .finished
                    if type == .audio {
                        self.audioOutput.isPaused = true
                    } else if type == .video {
                        self.videoOutput?.isPaused = true
                    }
                }
            }
        }
    }

    func sourceDidChange(loadingState: LoadingState) {
        if loadingState.isEndOfFile {
            playableTime = duration
        } else {
            playableTime = currentPlaybackTime + loadingState.loadedTime
        }
        if loadState == .playable {
            if !loadingState.isEndOfFile, loadingState.packetCount == 0, loadingState.frameCount == 0 {
                loadState = .loading
                if playbackState == .playing {
                    runInMainqueue { [weak self] in
                        // 在主线程更新进度
                        self?.bufferingProgress = 0
                    }
                }
            }
        } else {
            if loadingState.isFirst {
                if videoOutput?.pixelBuffer == nil {
                    videoOutput?.readNextFrame()
                }
            }
            var progress = 100
            if loadingState.isPlayable {
                loadState = .playable
            } else {
                progress = min(100, Int(loadingState.progress))
            }
            if playbackState == .playing {
                runInMainqueue { [weak self] in
                    // 在主线程更新进度
                    self?.bufferingProgress = progress
                }
            }
        }
    }

    func sourceDidChange(oldBitRate: Int64, newBitrate: Int64) {
        KSLog("oldBitRate \(oldBitRate) change to newBitrate \(newBitrate)")
    }
}

extension KSMEPlayer: MediaPlayerProtocol {
    public var playbackVolume: Float {
        get {
            audioOutput.volume
        }
        set {
            audioOutput.volume = newValue
        }
    }

    public var attackTime: Float {
        get {
            audioOutput.attackTime
        }
        set {
            audioOutput.attackTime = newValue
        }
    }

    public var releaseTime: Float {
        get {
            audioOutput.releaseTime
        }
        set {
            audioOutput.releaseTime = newValue
        }
    }

    public var threshold: Float {
        get {
            audioOutput.threshold
        }
        set {
            audioOutput.threshold = newValue
        }
    }

    public var expansionRatio: Float {
        get {
            audioOutput.expansionRatio
        }
        set {
            audioOutput.expansionRatio = newValue
        }
    }

    public var overallGain: Float {
        get {
            audioOutput.overallGain
        }
        set {
            audioOutput.overallGain = newValue
        }
    }

    public var isPlaying: Bool { playbackState == .playing }

    public var naturalSize: CGSize {
        options.display == .plane ? (playerItem.rotation == 90 || playerItem.rotation == 270 ? playerItem.naturalSize.reverse : playerItem.naturalSize) : UIScreen.size
    }

    public var isExternalPlaybackActive: Bool { false }

    public var view: UIView? { videoOutput }

    public func replace(url: URL, options: KSOptions) {
        KSLog("replaceUrl \(self)")
        shutdown()
        playerItem.delegate = nil
        playerItem = MEPlayerItem(url: url, options: options)
        self.options = options
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput?.renderSource = playerItem
        videoOutput?.options = options
        if KSOptions.isClearVideoWhereReplace {
            videoOutput?.clear()
        }
    }

    public var currentPlaybackTime: TimeInterval {
        get {
            playerItem.currentPlaybackTime
        }
        set {
            Task {
                await seek(time: newValue)
            }
        }
    }

    public var duration: TimeInterval { playerItem.duration }

    public var seekable: Bool { playerItem.seekable }

    public func seek(time: TimeInterval) async -> Bool {
        let time = max(time, 0)
        playbackState = .seeking
        runInMainqueue { [weak self] in
            self?.bufferingProgress = 0
        }
        let seekTime: TimeInterval
        if time >= duration, options.isLoopPlay {
            seekTime = 0
        } else {
            seekTime = time
        }
        return await playerItem.seek(time: seekTime)
    }

    public func prepareToPlay() {
        KSLog("prepareToPlay \(self)")
        options.prepareTime = CACurrentMediaTime()
        playerItem.prepareToPlay()
        bufferingProgress = 0
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
        playbackState = .stopped
        loadState = .idle
        isReadyToPlay = false
        loopCount = 0
        playerItem.shutdown()
        options.prepareTime = 0
        options.dnsStartTime = 0
        options.tcpStartTime = 0
        options.tcpConnectedTime = 0
        options.openTime = 0
        options.findTime = 0
        options.readyTime = 0
        options.readAudioTime = 0
        options.readVideoTime = 0
        options.decodeAudioTime = 0
        options.decodeVideoTime = 0
    }

    public var contentMode: UIViewContentMode {
        get {
            view?.contentMode ?? .center
        }
        set {
            view?.contentMode = newValue
        }
    }

    public func thumbnailImageAtCurrentTime() async -> UIImage? {
        await videoOutput?.pixelBuffer?.cgImage()?.image()
    }

    public func enterBackground() {}

    public func enterForeground() {}

    public var isMuted: Bool {
        get {
            audioOutput.isMuted
        }
        set {
            audioOutput.isMuted = newValue
        }
    }

    public func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack] {
        playerItem.assetTracks.filter { $0.mediaType == mediaType }
    }

    public func select(track: MediaPlayerTrack) {
        playerItem.select(track: track)
    }
}

@available(tvOS 14.0, *)
extension KSMEPlayer: AVPictureInPictureSampleBufferPlaybackDelegate {
    public func pictureInPictureController(_: AVPictureInPictureController, setPlaying playing: Bool) {
        playing ? play() : pause()
    }

    public func pictureInPictureControllerTimeRangeForPlayback(_: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: currentPlaybackTime, end: currentPlaybackTime + playableTime)
    }

    public func pictureInPictureControllerIsPlaybackPaused(_: AVPictureInPictureController) -> Bool {
        !isPlaying
    }

    public func pictureInPictureController(_: AVPictureInPictureController, didTransitionToRenderSize _: CMVideoDimensions) {}
    public func pictureInPictureController(_: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {
        _ = await seek(time: currentPlaybackTime + skipInterval.seconds)
    }

    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_: AVPictureInPictureController) -> Bool {
        false
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
extension KSMEPlayer: AVPlaybackCoordinatorPlaybackControlDelegate {
    public func playbackCoordinator(_: AVDelegatingPlaybackCoordinator, didIssue playCommand: AVDelegatingPlaybackCoordinatorPlayCommand, completionHandler: @escaping () -> Void) {
        guard playCommand.expectedCurrentItemIdentifier == (playbackCoordinator as? AVDelegatingPlaybackCoordinator)?.currentItemIdentifier else {
            completionHandler()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            if self.playbackState != .playing {
                self.play()
            }
            completionHandler()
        }
    }

    public func playbackCoordinator(_: AVDelegatingPlaybackCoordinator, didIssue pauseCommand: AVDelegatingPlaybackCoordinatorPauseCommand, completionHandler: @escaping () -> Void) {
        guard pauseCommand.expectedCurrentItemIdentifier == (playbackCoordinator as? AVDelegatingPlaybackCoordinator)?.currentItemIdentifier else {
            completionHandler()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            if self.playbackState != .paused {
                self.pause()
            }
            completionHandler()
        }
    }

    public func playbackCoordinator(_: AVDelegatingPlaybackCoordinator, didIssue seekCommand: AVDelegatingPlaybackCoordinatorSeekCommand) async {
        guard seekCommand.expectedCurrentItemIdentifier == (playbackCoordinator as? AVDelegatingPlaybackCoordinator)?.currentItemIdentifier else {
            return
        }
        let seekTime = fmod(seekCommand.itemTime.seconds, duration)
        if abs(currentPlaybackTime - seekTime) < CGFLOAT_EPSILON {
            return
        }
        _ = await seek(time: seekTime)
    }

    public func playbackCoordinator(_: AVDelegatingPlaybackCoordinator, didIssue bufferingCommand: AVDelegatingPlaybackCoordinatorBufferingCommand, completionHandler: @escaping () -> Void) {
        guard bufferingCommand.expectedCurrentItemIdentifier == (playbackCoordinator as? AVDelegatingPlaybackCoordinator)?.currentItemIdentifier else {
            completionHandler()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            guard self.loadState != .playable, let countDown = bufferingCommand.completionDueDate?.timeIntervalSinceNow else {
                completionHandler()
                return
            }
            self.bufferingCountDownTimer?.invalidate()
            self.bufferingCountDownTimer = nil
            self.bufferingCountDownTimer = Timer(timeInterval: countDown, repeats: false) { _ in
                completionHandler()
            }
        }
    }
}

public extension KSMEPlayer {
    var subtitleDataSouce: SubtitleDataSouce? { playerItem }
}
