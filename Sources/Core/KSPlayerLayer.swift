//
//  KSPlayerLayerView.swift
//  Pods
//
//  Created by kintan on 16/4/28.
//
//
import AVFoundation
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

    public var isPlaying: Bool {
        return self == .buffering || self == .bufferFinished
    }
}

public protocol KSPlayerLayerDelegate: class {
    func player(layer: KSPlayerLayer, state: KSPlayerState)
    func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(layer: KSPlayerLayer, finish error: Error?)
    func player(layer: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval)
}

open class KSPlayerLayer: UIView {
    public let bufferingProgress: KSObservable<Int> = KSObservable(0)
    public let loopCount: KSObservable<Int> = KSObservable(0)
    private var timer: Timer?
    private var playOptions: [String: Any]?
    private var bufferedCount = 0
    private var shouldSeekTo: TimeInterval = 0
    private var startTime: TimeInterval = 0
    private(set) var url: URL?
    public var isWirelessRouteActive = false
    public weak var delegate: KSPlayerLayerDelegate?
    public var isAutoPlay = KSPlayerManager.isAutoPlay {
        didSet {
            player?.isAutoPlay = isAutoPlay
        }
    }

    public var player: MediaPlayerProtocol? {
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.shutdown()
            if let player = player {
                KSLog("player is \(player)")
                player.delegate = self
                player.isAutoPlay = isAutoPlay
                player.isLoopPlay = KSPlayerManager.isLoopPlay
                player.contentMode = .scaleAspectFit
                if let oldValue = oldValue {
                    player.playbackRate = oldValue.playbackRate
                    player.playbackVolume = oldValue.playbackVolume
                }
                addSubview(player.view)
                prepareToPlay()
                #if os(macOS)
                layoutSubtreeIfNeeded()
                #else
                if player is KSAVPlayer {
                    UIApplication.shared.beginReceivingRemoteControlEvents()
                    becomeFirstResponder()
                } else {
                    UIApplication.shared.endReceivingRemoteControlEvents()
                }
                #endif
                player.view.frame = bounds
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

    deinit {
        resetPlayer()
    }

    public func set(url: URL, options: [String: Any]?) {
        self.url = url
        playOptions = options
        if let cookies = playOptions?["Cookie"] as? [HTTPCookie] {
            #if !os(macOS)
            playOptions?[AVURLAssetHTTPCookiesKey] = cookies
            #endif
            var cookieStr = "Cookie: "
            for cookie in cookies {
                cookieStr.append("\(cookie.name)=\(cookie.value); ")
            }
            cookieStr = String(cookieStr.dropLast(2))
            cookieStr.append("\r\n")
            playOptions?["headers"] = cookieStr
        }
        // airplay的话，默认使用KSAVPlayer
        let firstPlayerType = isWirelessRouteActive ? KSAVPlayer.self : KSPlayerManager.firstPlayerType
        if let player = player, type(of: player) == firstPlayerType {
            player.replace(url: url, options: playOptions)
            prepareToPlay()
        } else {
            player = firstPlayerType.init(url: url, options: playOptions)
        }
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(playerTimerAction), userInfo: nil, repeats: true)
        timer?.fireDate = Date.distantFuture
    }

    open func play() {
        UIApplication.shared.isIdleTimerDisabled = true
        isAutoPlay = true
        if let player = player {
            if player.isPreparedToPlay {
                player.play()
                timer?.fireDate = Date.distantPast
            } else {
                if state == .error {
                    player.prepareToPlay()
                }
            }
            state = player.loadState == .playable ? .bufferFinished : .buffering
        } else {
            state = .buffering
        }
    }

    open func pause() {
        isAutoPlay = false
        player?.pause()
        timer?.fireDate = Date.distantFuture
        state = .paused
        UIApplication.shared.isIdleTimerDisabled = false
    }

    open func resetPlayer() {
        KSLog("resetPlayer")
        #if !os(macOS)
        UIApplication.shared.endReceivingRemoteControlEvents()
        #endif
        timer?.invalidate()
        timer = nil
        state = .notSetURL
        bufferedCount = 0
        shouldSeekTo = 0
        isAutoPlay = KSPlayerManager.isAutoPlay
        player?.playbackRate = 1
        player?.playbackVolume = 1
        player?.shutdown()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    open func seek(time: TimeInterval, autoPlay: Bool = KSPlayerManager.isSeekedAutoPlay, completion handler: ((Bool) -> Void)? = nil) {
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

    #if os(macOS)
    open override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        player?.view.frame = bounds
    }

    #else
    open override func layoutSubviews() {
        super.layoutSubviews()
        player?.view.frame = bounds
    }

    open override func remoteControlReceived(with event: UIEvent?) {
        guard let event = event, event.type == .remoteControl else { return }
        switch event.subtype {
        case .remoteControlPlay:
            play()
        case .remoteControlPause:
            pause()
        case .remoteControlBeginSeekingForward:
            player?.playbackRate = 10
        case .remoteControlEndSeekingForward:
            player?.playbackRate = 1
        case .remoteControlBeginSeekingBackward:
            player?.playbackRate = -10
        case .remoteControlEndSeekingBackward:
            player?.playbackRate = 1
        default:
            break
        }
    }
    #endif
}

// MARK: - MediaPlayerDelegate

extension KSPlayerLayer: MediaPlayerDelegate {
    public func preparedToPlay(player: MediaPlayerProtocol) {
        state = .readyToPlay
        if player.isAutoPlay {
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
                KSLog("首屏耗时：\(diff)")
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
        bufferingProgress.value = progress
    }

    public func playBack(player _: MediaPlayerProtocol, loopCount: Int) {
        self.loopCount.value = loopCount
    }

    public func finish(player: MediaPlayerProtocol, error: Error?) {
        if let error = error as NSError? {
            if error.domain == "AVMoviePlayer" || error.domain == AVFoundationErrorDomain, let secondPlayerType = KSPlayerManager.secondPlayerType {
                player.shutdown()
                self.player = secondPlayerType.init(url: url!, options: playOptions)
                return
            }
            state = .error
        } else {
            let duration = player.duration
            if duration.isNormal {
                delegate?.player(layer: self, currentTime: duration, totalTime: duration)
            }
            state = .playedToTheEnd
        }
        timer?.fireDate = Date.distantFuture
        bufferedCount = 1
        delegate?.player(layer: self, finish: error)
    }
}

// MARK: - private functions

extension KSPlayerLayer {
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

    @objc private func playerTimerAction() {
        guard let player = player, player.isPreparedToPlay else { return }
        let currentPlaybackTime = player.currentPlaybackTime
        if currentPlaybackTime.isInfinite || currentPlaybackTime.isNaN {
            return
        }
        delegate?.player(layer: self, currentTime: player.currentPlaybackTime, totalTime: player.duration)
        if player.playbackState == .playing, player.loadState == .playable, state == .buffering {
            // 一个兜底保护，正常不能走到这里
            state = .bufferFinished
        }
    }
}
