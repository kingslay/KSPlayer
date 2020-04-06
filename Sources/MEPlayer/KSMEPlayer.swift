//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public class KSMEPlayer {
    private var loopCount = 1
    private let audioOutput = AudioOutput()
    // 为了及时显示页面
    private var needRefreshView = true
    private var playerItem: MEPlayerItem
    private let videoOutput = VideoOutput()
    private var options: KSOptions
    public private(set) var bufferingProgress = 0 {
        didSet {
            delegate?.changeBuffering(player: self, progress: bufferingProgress)
        }
    }

    public private(set) var playableTime = TimeInterval(0)
    public weak var delegate: MediaPlayerDelegate?
    public private(set) var isPreparedToPlay = false
    public var allowsExternalPlayback: Bool = false
    public var usesExternalPlaybackWhileExternalScreenIsActive: Bool = false

    public var playbackRate: Float = 1 {
        didSet {
            audioOutput.audioPlayer.playbackRate = playbackRate
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
        self.options = options
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput.renderSource = playerItem
        videoOutput.renderView.display = options.display
        setAudioSession()
    }

    deinit {
        audioOutput.pause()
        videoOutput.invalidate()
    }
}

// MARK: - private functions

extension KSMEPlayer {
    private func playOrPause() {
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            if self.playbackState == .playing, self.loadState == .playable {
                self.audioOutput.play()
                self.videoOutput.play()
            } else {
                self.audioOutput.pause()
                self.videoOutput.pause()
            }
            self.delegate?.changeLoadState(player: self)
        }
    }
}

extension KSMEPlayer: MEPlayerDelegate {
    func sourceDidOpened() {
        isPreparedToPlay = true
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            if self.options.isAutoPlay {
                self.play()
            }
            if self.playerItem.rotation != 0.0 {
                #if os(macOS)
                self.view.backingLayer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                self.view.rotate(byDegrees: CGFloat(-self.playerItem.rotation))
                #else
                self.view.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi * self.playerItem.rotation / 180.0))
                #endif
            }
            self.delegate?.preparedToPlay(player: self)
        }
    }

    func sourceDidFailed(error: NSError?) {
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            self.delegate?.finish(player: self, error: error)
        }
    }

    func sourceDidFinished(type: AVFoundation.AVMediaType, allSatisfy: Bool) {
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            if type == .audio {
                self.audioOutput.pause()
            } else if type == .video {
                self.videoOutput.pause()
            }
            if allSatisfy {
                if self.options.isLoopPlay {
                    self.loopCount += 1
                    self.delegate?.playBack(player: self, loopCount: self.loopCount)
                    self.audioOutput.play()
                    self.videoOutput.play()
                } else {
                    self.playbackState = .finished
                }
            }
        }
    }

    func sourceDidChange(capacity: Capacity) {
        if capacity.isFinished {
            playableTime = duration
            loadState = .playable
        } else {
            playableTime = currentPlaybackTime + capacity.loadedTime
            if loadState == .playable {
                if capacity.loadedCount == 0 {
                    loadState = .loading
                    if playbackState == .playing {
                        runInMainqueue { [weak self] in
                            // 在主线程更新进度
                            self?.bufferingProgress = 0
                        }
                    }
                }
            } else {
                var progress = 100
                if capacity.isPlayable {
                    loadState = .playable
                } else {
                    progress = capacity.bufferingProgress
                }
                if playbackState == .playing {
                    runInMainqueue { [weak self] in
                        // 在主线程更新进度
                        self?.bufferingProgress = progress
                    }
                }
            }
        }
        if needRefreshView, playbackState != .playing {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.needRefreshView, let render = self.playerItem.getOutputRender(type: .video) {
                    self.needRefreshView = false
                    self.videoOutput.renderView.set(render: render)
                }
            }
        }
    }
}

extension KSMEPlayer: MediaPlayerProtocol {
    public var preferredForwardBufferDuration: TimeInterval {
        get {
            options.preferredForwardBufferDuration
        }
        set {
            options.preferredForwardBufferDuration = newValue
        }
    }

    public var playbackVolume: Float {
        get {
            audioOutput.audioPlayer.volume
        }
        set {
            audioOutput.audioPlayer.volume = newValue
        }
    }

    public var isPlaying: Bool { playbackState == .playing }

    public var naturalSize: CGSize {
        playerItem.rotation == 90 || playerItem.rotation == 270 ? playerItem.naturalSize.reverse : playerItem.naturalSize
    }

    public var isExternalPlaybackActive: Bool { false }

    public var view: UIView { videoOutput.renderView }

    public func replace(url: URL, options: KSOptions) {
        KSLog("replaceUrl \(self)")
        shutdown()
        audioOutput.shutdown()
        videoOutput.shutdown()
        playerItem.delegate = nil
        playerItem = MEPlayerItem(url: url, options: options)
        self.options = options
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput.renderSource = playerItem
        videoOutput.renderView.display = options.display
    }

    public var currentPlaybackTime: TimeInterval {
        get {
            playerItem.currentPlaybackTime
        }
        set {
            seek(time: newValue)
        }
    }

    public var duration: TimeInterval { playerItem.duration }

    public var seekable: Bool { playerItem.seekable }

    public func seek(time: TimeInterval, completion handler: ((Bool) -> Void)? = nil) {
        let oldPlaybackState = playbackState
        playbackState = .seeking
        runInMainqueue { [weak self] in
            self?.bufferingProgress = 0
        }
        playerItem.seek(time: time) { [weak self] result in
            guard let self = self else { return }
            self.videoOutput.flush()
            self.audioOutput.flush()
            runInMainqueue { [weak self] in
                guard let self = self else { return }
                self.playbackState = oldPlaybackState
                handler?(result)
                if self.playbackState != .playing {
                    self.needRefreshView = true
                }
            }
        }
    }

    public func prepareToPlay() {
        KSLog("prepareToPlay \(self)")
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
        isPreparedToPlay = false
        needRefreshView = true
        loopCount = 0
        playerItem.shutdown()
    }

    public var contentMode: UIViewContentMode {
        set {
            view.contentMode = newValue
        }
        get {
            view.contentMode
        }
    }

    public func thumbnailImageAtCurrentTime(handler: @escaping (UIImage?) -> Void) {
        videoOutput.thumbnailImageAtCurrentTime(handler: handler)
    }

    public func enterBackground() {
        videoOutput.isOutput = false
    }

    public func enterForeground() {
        videoOutput.isOutput = true
    }

    public var isMuted: Bool {
        set {
            audioOutput.audioPlayer.isMuted = newValue
            setAudioSession(isMuted: newValue)
        }
        get {
            audioOutput.audioPlayer.isMuted
        }
    }
}

extension KSMEPlayer {
    public var subtitleDataSouce: SubtitleDataSouce? { playerItem }

    public var subtitles: [KSSubtitleProtocol] { playerItem.subtitleTracks }
}
