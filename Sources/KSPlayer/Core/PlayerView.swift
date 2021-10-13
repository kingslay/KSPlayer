//
//  PlayerController.swift
//  VoiceNote
//
//  Created by kintan on 2018/8/16.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import AVFoundation

public enum PlayerButtonType: Int {
    case play = 101
    case pause = 102
    case back = 103
    case srt = 104
    case landscape = 105
    case replay = 106
    case lock = 107
    case rate = 108
    case definition = 109
    case pictureInPicture = 110
}

public protocol PlayerControllerDelegate: AnyObject {
    func playerController(state: KSPlayerState)
    func playerController(currentTime: TimeInterval, totalTime: TimeInterval)
    func playerController(finish error: Error?)
    func playerController(maskShow: Bool)
    func playerController(action: PlayerButtonType)
    // bufferedCount: 0代表首次加载
    func playerController(bufferedCount: Int, consumeTime: TimeInterval)
}

open class PlayerView: UIView, KSPlayerLayerDelegate, KSSliderDelegate {
    public typealias ControllerDelegate = PlayerControllerDelegate
    public let playerLayer = KSPlayerLayer()
    public weak var delegate: ControllerDelegate?
    public let toolBar = PlayerToolBar()
    // Closure fired when play time changed
    public var playTimeDidChange: ((TimeInterval, TimeInterval) -> Void)?
    public var backBlock: (() -> Void)?
    public convenience init() {
        #if os(macOS)
        self.init(frame: .zero)
        #else
        self.init(frame: UIScreen.main.bounds)
        #endif
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        #if !os(macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted), name: AVAudioSession.interruptionNotification, object: nil)
        #endif
        playerLayer.delegate = self
        toolBar.timeSlider.delegate = self
        toolBar.addTarget(self, action: #selector(onButtonPressed(_:)))
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func onButtonPressed(_ button: UIButton) {
        guard let type = PlayerButtonType(rawValue: button.tag) else { return }
        onButtonPressed(type: type, button: button)
    }

    open func onButtonPressed(type: PlayerButtonType, button: UIButton) {
        var type = type
        if type == .play, button.isSelected {
            type = .pause
        }
        switch type {
        case .back:
            backBlock?()
        case .play, .replay:
            play()
        case .pause:
            pause()
        default:
            break
        }
        delegate?.playerController(action: type)
    }

    open func play() {
        becomeFirstResponder()
        if playerLayer.state == .playedToTheEnd {
            seek(time: 0)
        } else {
            playerLayer.play()
        }
    }

    open func pause() {
        playerLayer.pause()
    }

    open func seek(time: TimeInterval, completion handler: ((Bool) -> Void)? = nil) {
        playerLayer.seek(time: time, autoPlay: KSOptions.isSeekedAutoPlay, completion: handler)
    }

    open func resetPlayer() {
        playerLayer.resetPlayer()
        totalTime = 0.0
    }

    open func set(url: URL, options: KSOptions) {
        toolBar.currentTime = 0
        totalTime = 0
        playerLayer.set(url: url, options: options)
    }

    // MARK: - KSSliderDelegate

    open func slider(value: Double, event: ControlEvents) {
        if event == .valueChanged {
            toolBar.currentTime = value
        } else if event == .touchUpInside {
            seek(time: value)
        }
    }

    // MARK: - KSPlayerLayerDelegate

    open func player(layer: KSPlayerLayer, state: KSPlayerState) {
        delegate?.playerController(state: state)
        if state == .readyToPlay {
            totalTime = layer.player?.duration ?? totalTime
        } else if state == .playedToTheEnd || state == .paused || state == .error {
            toolBar.playButton.isSelected = false
        } else if state.isPlaying {
            toolBar.playButton.isSelected = true
        }
    }

    open func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        delegate?.playerController(currentTime: currentTime, totalTime: totalTime)
        playTimeDidChange?(currentTime, totalTime)
        toolBar.currentTime = currentTime
        self.totalTime = totalTime
    }

    open func player(layer _: KSPlayerLayer, finish error: Error?) {
        delegate?.playerController(finish: error)
    }

    open func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        delegate?.playerController(bufferedCount: bufferedCount, consumeTime: consumeTime)
    }
}

extension PlayerView {
    public var totalTime: TimeInterval {
        get {
            toolBar.totalTime
        }
        set {
            toolBar.totalTime = newValue
        }
    }

    @objc private func audioInterrupted(notification: Notification) {
        if let callBegin = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? Bool {
            if callBegin {
                pause()
            }
        }
    }
}

extension UIView {
    var viewController: UIViewController? {
        var next = next
        while next != nil {
            if let viewController = next as? UIViewController {
                return viewController
            }
            next = next?.next
        }
        return nil
    }
}
