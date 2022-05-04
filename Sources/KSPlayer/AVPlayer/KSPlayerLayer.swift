//
//  KSPlayerLayerView.swift
//  Pods
//
//  Created by kintan on 16/4/28.
//
//
import AVFoundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
/**
 Player status emun
 - notSetURL:      not set url yet
 - readyToPlay:    player ready to play
 - buffering:      player buffering
 - bufferFinished: buffer finished
 - playedToTheEnd: played to the End
 - error:          error with playing
 */
public enum KSPlayerState: CustomStringConvertible {
    case notSetURL
    case readyToPlay
    case buffering
    case bufferFinished
    case paused
    case playedToTheEnd
    case error
    public var description: String {
        switch self {
        case .notSetURL:
            return "notSetURL"
        case .readyToPlay:
            return "readyToPlay"
        case .buffering:
            return "buffering"
        case .bufferFinished:
            return "bufferFinished"
        case .paused:
            return "paused"
        case .playedToTheEnd:
            return "playedToTheEnd"
        case .error:
            return "error"
        }
    }

    public var isPlaying: Bool { self == .buffering || self == .bufferFinished }
}

public protocol KSPlayerLayerDelegate: AnyObject {
    func player(layer: KSPlayerLayer, state: KSPlayerState)
    func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(layer: KSPlayerLayer, finish error: Error?)
    func player(layer: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval)
}

open class KSPlayerLayer: UIView {
    public weak var delegate: KSPlayerLayerDelegate?
    @KSObservable
    public var bufferingProgress: Int = 0
    @KSObservable
    public var loopCount: Int = 0
    private var isWirelessRouteActive = false
    private var options: KSOptions?
    private var bufferedCount = 0
    private var shouldSeekTo: TimeInterval = 0
    private var startTime: TimeInterval = 0
    private var url: URL? {
        didSet {
            guard let url = url, let options = options else {
                player = nil
                return
            }
            let firstPlayerType: MediaPlayerProtocol.Type
            if isWirelessRouteActive {
                // airplay的话，默认使用KSAVPlayer
                firstPlayerType = KSAVPlayer.self
            } else if options.display != .plane {
                // AR模式只能用KSMEPlayer
                // swiftlint:disable force_cast
                firstPlayerType = NSClassFromString("KSPlayer.KSMEPlayer") as! MediaPlayerProtocol.Type
                // swiftlint:enable force_cast
            } else {
                firstPlayerType = KSPlayerManager.firstPlayerType
            }
            if let player = player, type(of: player) == firstPlayerType {
                if url == oldValue {
                    if options.isAutoPlay {
                        play()
                    }
                } else {
                    resetPlayer()
                    player.replace(url: url, options: options)
                    prepareToPlay()
                }
            } else {
                resetPlayer()
                player = firstPlayerType.init(url: url, options: options)
            }
        }
    }

    private var urls = [URL]()
    private var isAutoPlay = false
    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        guard let self = self, let player = self.player, player.isPreparedToPlay else {
            return
        }
        self.delegate?.player(layer: self, currentTime: player.currentPlaybackTime, totalTime: player.duration)
        if player.playbackState == .playing, player.loadState == .playable, self.state == .buffering {
            // 一个兜底保护，正常不能走到这里
            self.state = .bufferFinished
        }
        if player.isPlaying {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentPlaybackTime
        }
    }

    public var player: MediaPlayerProtocol? {
        didSet {
            oldValue?.view.removeFromSuperview()
            if let player = player {
                KSLog("player is \(player)")
                player.delegate = self
                player.contentMode = .scaleAspectFit
                if let oldValue = oldValue {
                    player.playbackRate = oldValue.playbackRate
                    player.playbackVolume = oldValue.playbackVolume
                }
                addSubview(player.view)
                prepareToPlay()
            }
        }
    }

    /// 播发器的几种状态
    public private(set) var state = KSPlayerState.notSetURL {
        didSet {
            if state != oldValue {
                KSLog("playerStateDidChange - \(state)")
                delegate?.player(layer: self, state: state)
            }
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        registerRemoteControllEvent()
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(enterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(wirelessRouteActiveDidChange(notification:)), name: .MPVolumeViewWirelessRouteActiveDidChange, object: nil)
        #endif
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func set(url: URL, options: KSOptions) {
        isAutoPlay = options.isAutoPlay
        self.options = options
        runInMainqueue {
            self.url = url
        }
    }

    public func set(urls: [URL], options: KSOptions) {
        isAutoPlay = options.isAutoPlay
        self.options = options
        self.urls.removeAll()
        self.urls.append(contentsOf: urls)
        url = urls.first
    }

    open func play() {
        UIApplication.shared.isIdleTimerDisabled = true
        isAutoPlay = true
        if let player = player {
            if player.isPreparedToPlay {
                if state == .playedToTheEnd {
                    player.seek(time: 0) { finished in
                        if finished {
                            player.play()
                        }
                    }
                } else {
                    player.play()
                }
                timer.fireDate = Date.distantPast
            } else {
                if state == .error {
                    player.prepareToPlay()
                }
            }
            state = player.loadState == .playable ? .bufferFinished : .buffering
        } else {
            state = .buffering
        }
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    open func pause() {
        isAutoPlay = false
        player?.pause()
        timer.fireDate = Date.distantFuture
        state = .paused
        UIApplication.shared.isIdleTimerDisabled = false
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }

    open func resetPlayer() {
        KSLog("resetPlayer")
        state = .notSetURL
        bufferedCount = 0
        shouldSeekTo = 0
        player?.playbackRate = 1
        player?.playbackVolume = 1
        UIApplication.shared.isIdleTimerDisabled = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #if os(tvOS)
        UIApplication.shared.keyWindow?.avDisplayManager.preferredDisplayCriteria = nil
        #endif
    }

    open func seek(time: TimeInterval, autoPlay: Bool, completion handler: ((Bool) -> Void)? = nil) {
        if time.isInfinite || time.isNaN {
            return
        }
        if autoPlay {
            state = .buffering
        }
        if let player = player, player.isPreparedToPlay {
            player.seek(time: time) { [weak self] finished in
                guard let self = self else { return }
                if finished, autoPlay {
                    self.play()
                }
                handler?(finished)
            }
        } else {
            isAutoPlay = autoPlay
            shouldSeekTo = time
        }
    }

    override open func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview == player?.view {
            subview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                subview.leftAnchor.constraint(equalTo: leftAnchor),
                subview.topAnchor.constraint(equalTo: topAnchor),
                subview.centerXAnchor.constraint(equalTo: centerXAnchor),
                subview.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }
}

// MARK: - MediaPlayerDelegate

extension KSPlayerLayer: MediaPlayerDelegate {
    public func preparedToPlay(player: MediaPlayerProtocol) {
        updateNowPlayingInfo()
        state = .readyToPlay
        for track in player.tracks(mediaType: .video) where track.isEnabled {
            #if os(tvOS)
            setDisplayCriteria(track: track)
            #endif
        }
        if isAutoPlay {
            if shouldSeekTo > 0 {
                seek(time: shouldSeekTo, autoPlay: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.shouldSeekTo = 0
                }
            } else {
                play()
            }
        }
    }

    public func changeLoadState(player: MediaPlayerProtocol) {
        guard player.playbackState != .seeking else { return }
        if player.loadState == .playable, startTime > 0 {
            let diff = CACurrentMediaTime() - startTime
            delegate?.player(layer: self, bufferedCount: bufferedCount, consumeTime: diff)
            if bufferedCount == 0 {
                var dic = ["firstTime": diff]
                if let options = options {
                    dic["prepareTime"] = options.starTime - startTime
                    dic["openTime"] = options.openTime - options.starTime
                    dic["findTime"] = options.findTime - options.starTime
                    dic["readVideoTime"] = options.readVideoTime - options.starTime
                    dic["readAudioTime"] = options.readAudioTime - options.starTime
                    dic["decodeVideoTime"] = options.decodeVideoTime - options.starTime
                    dic["decodeAudioTime"] = options.decodeAudioTime - options.starTime
                }
                KSLog(dic)
            }
            bufferedCount += 1
            startTime = 0
        }
        guard state.isPlaying else { return }
        if player.loadState == .playable {
            state = .bufferFinished
        } else {
            if state == .bufferFinished {
                startTime = CACurrentMediaTime()
            }
            state = .buffering
        }
    }

    public func changeBuffering(player _: MediaPlayerProtocol, progress: Int) {
        bufferingProgress = progress
    }

    public func playBack(player _: MediaPlayerProtocol, loopCount: Int) {
        self.loopCount = loopCount
    }

    public func finish(player: MediaPlayerProtocol, error: Error?) {
        if let error = error {
            if type(of: player) != KSPlayerManager.secondPlayerType, let secondPlayerType = KSPlayerManager.secondPlayerType, let url = url, let options = options {
                self.player = secondPlayerType.init(url: url, options: options)
                return
            }
            state = .error
            KSLog(error as CustomStringConvertible)
        } else {
            let duration = player.duration
            delegate?.player(layer: self, currentTime: duration, totalTime: duration)
            state = .playedToTheEnd
        }
        timer.fireDate = Date.distantFuture
        bufferedCount = 1
        delegate?.player(layer: self, finish: error)
        if error == nil {
            nextPlayer()
        }
    }
}

// MARK: - private functions

extension KSPlayerLayer {
    #if os(tvOS)
    private enum DynamicRange: Int32 {
        case SDR = 0
        case HDR = 2
        // swiftlint:disable identifier_name
        case DV = 5
        // swiftlint:enable identifier_name
    }

    private func setDisplayCriteria(track: MediaPlayerTrack) {
        let dynamicRange: DynamicRange
        let fps = track.nominalFrameRate
        if track.codecType.string == "ehvd" {
            dynamicRange = .DV
        } else if let colorPrimaries = track.colorPrimaries, /// HDR
                  colorPrimaries.contains("2020") {
            dynamicRange = .HDR
        } else {
            dynamicRange = .SDR
        }
        guard let displayManager = UIApplication.shared.keyWindow?.avDisplayManager else {
            return
        }
        if displayManager.isDisplayCriteriaMatchingEnabled,
           !displayManager.isDisplayModeSwitchInProgress {
            if let criteria = options?.preferredDisplayCriteria(refreshRate: fps, videoDynamicRange: dynamicRange.rawValue) {
                displayManager.preferredDisplayCriteria = criteria
            }

        }
    }
    #endif

    private func prepareToPlay() {
        startTime = CACurrentMediaTime()
        bufferedCount = 0
        player?.prepareToPlay()
        if isAutoPlay {
            state = .buffering
        } else {
            state = .notSetURL
        }
    }

    private func updateNowPlayingInfo() {
        guard let player = player else { return }
        if MPNowPlayingInfoCenter.default().nowPlayingInfo == nil {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyPlaybackDuration: player.duration]
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = player.duration
        }
        var current: [MPNowPlayingInfoLanguageOption] = []
        var langs: [MPNowPlayingInfoLanguageOptionGroup] = []
        for track in player.tracks(mediaType: .audio) {
            if let lang = track.language {
                let audioLang = MPNowPlayingInfoLanguageOption(type: .audible, languageTag: lang, characteristics: nil, displayName: track.name, identifier: track.name)
                let audioGroup = MPNowPlayingInfoLanguageOptionGroup(languageOptions: [audioLang], defaultLanguageOption: nil, allowEmptySelection: false)
                langs.append(audioGroup)
                if track.isEnabled {
                    current.append(audioLang)
                }
            }
        }
        if langs.count > 0 {
            MPRemoteCommandCenter.shared().enableLanguageOptionCommand.isEnabled = true
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyAvailableLanguageOptions] = langs
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyCurrentLanguageOptions] = current
    }

    private func nextPlayer() {
        if urls.count > 1, let url = url, let index = urls.firstIndex(of: url), index < urls.count - 1 {
            isAutoPlay = true
            self.url = urls[index + 1]
        }
    }

    private func previousPlayer() {
        if urls.count > 1, let url = url, let index = urls.firstIndex(of: url), index > 0 {
            isAutoPlay = true
            self.url = urls[index - 1]
        }
    }

    private func registerRemoteControllEvent() {
        let remoteCommand = MPRemoteCommandCenter.shared()
        remoteCommand.playCommand.addTarget { [weak self] _ in
            guard let self = self else {
                return .commandFailed
            }
            self.play()
            return .success
        }
        remoteCommand.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else {
                return .commandFailed
            }
            self.pause()
            return .success
        }
        remoteCommand.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else {
                return .commandFailed
            }
            if self.state.isPlaying {
                self.pause()
            } else {
                self.play()
            }
            return .success
        }
        remoteCommand.stopCommand.addTarget { [weak self] _ in
            guard let self = self else {
                return .commandFailed
            }
            self.player?.shutdown()
            return .success
        }
        remoteCommand.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else {
                return .commandFailed
            }
            self.nextPlayer()
            return .success
        }
        remoteCommand.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else {
                return .commandFailed
            }
            self.previousPlayer()
            return .success
        }
        remoteCommand.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangeRepeatModeCommandEvent else {
                return .commandFailed
            }
            self.options?.isLoopPlay = event.repeatType != .off
            return .success
        }
        remoteCommand.changeShuffleModeCommand.isEnabled = false
        // remoteCommand.changeShuffleModeCommand.addTarget {})
        remoteCommand.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1, 1.5, 2]
        remoteCommand.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            self.player?.playbackRate = event.playbackRate
            return .success
        }
        remoteCommand.skipForwardCommand.preferredIntervals = [15]
        remoteCommand.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            self.seek(time: self.player?.currentPlaybackTime ?? 0 + event.interval, autoPlay: self.options?.isSeekedAutoPlay ?? false)
            return .success
        }
        remoteCommand.skipBackwardCommand.preferredIntervals = [15]
        remoteCommand.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            self.seek(time: self.player?.currentPlaybackTime ?? 0 - event.interval, autoPlay: self.options?.isSeekedAutoPlay ?? false)
            return .success
        }
        remoteCommand.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(time: event.positionTime, autoPlay: self.options?.isSeekedAutoPlay ?? false)
            return .success
        }
        remoteCommand.enableLanguageOptionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangeLanguageOptionCommandEvent else {
                return .commandFailed
            }
            let selectLang = event.languageOption
            if selectLang.languageOptionType == .audible,
               let trackToSelect = self.player?.tracks(mediaType: .audio).first(where: { $0.name == selectLang.displayName }) {
                self.player?.select(track: trackToSelect)
            }
            return .success
        }
    }

    @objc private func enterBackground() {
        guard let player = player, state.isPlaying, !player.isExternalPlaybackActive else {
            return
        }

        if #available(tvOS 14.0, *) {
            if player.pipController?.isPictureInPictureActive ?? false {
                return
            }
        }

        if KSPlayerManager.canBackgroundPlay {
            player.enterBackground()
            return
        }
        pause()
    }

    @objc private func enterForeground() {
        if KSPlayerManager.canBackgroundPlay {
            player?.enterForeground()
        }
    }

    #if canImport(UIKit)
    @objc private func wirelessRouteActiveDidChange(notification: Notification) {
        guard let volumeView = notification.object as? MPVolumeView, isWirelessRouteActive != volumeView.isWirelessRouteActive else { return }
        if volumeView.isWirelessRouteActive {
            if !(player?.allowsExternalPlayback ?? false) {
                isWirelessRouteActive = true
            }
            player?.usesExternalPlaybackWhileExternalScreenIsActive = true
        }
        isWirelessRouteActive = volumeView.isWirelessRouteActive
    }
    #endif
}

public enum TimeType {
    case min
    case hour
    case minOrHour
    case millisecond
}

public extension TimeInterval {
    func toString(for type: TimeType) -> String {
        var second = ceil(self)
        var min = floor(second / 60)
        second -= min * 60
        switch type {
        case .min:
            return String(format: "%02.0f:%02.0f", min, second)
        case .hour:
            let hour = floor(min / 60)
            min -= hour * 60
            return String(format: "%.0f:%02.0f:%02.0f", hour, min, second)
        case .minOrHour:
            let hour = floor(min / 60)
            if hour > 0 {
                min -= hour * 60
                return String(format: "%.0f:%02.0f:%02.0f", hour, min, second)
            } else {
                return String(format: "%02.0f:%02.0f", min, second)
            }
        case .millisecond:
            var time = Int(self * 100)
            let millisecond = time % 100
            time /= 100
            let sec = time % 60
            time /= 60
            let min = time % 60
            time /= 60
            let hour = time % 60
            if hour > 0 {
                return String(format: "%d:%02d:%02d.%02d", hour, min, sec, millisecond)
            } else {
                return String(format: "%02d:%02d.%02d", min, sec, millisecond)
            }
        }
    }
}

public extension KSPlayerManager {
    static var firstPlayerType: MediaPlayerProtocol.Type = KSAVPlayer.self
    static var secondPlayerType: MediaPlayerProtocol.Type?
}

#if !SWIFT_PACKAGE
extension Bundle {
    static let module = Bundle(for: KSPlayerLayer.self).path(forResource: "KSPlayer_KSPlayer", ofType: "bundle").flatMap { Bundle(path: $0) } ?? Bundle.main
}
#endif
