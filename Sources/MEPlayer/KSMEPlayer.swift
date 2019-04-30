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

public class KSMEPlayer: NSObject {
    private var loopCount = 1
    private let audioOutput = AudioOutput()
    // 为了及时显示页面
    private var needRefreshView = true
    private var playerItem: MEPlayerItem
    private lazy var videoOutput = VideoOutput(renderView: renderViewType.init())
    public var isAutoPlay = true
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
    open var pixelFormatType: OSType {
        return KSDefaultParameter.bufferPixelFormatType
    }

    open var renderViewType: (PixelRenderView & UIView).Type {
        return KSDefaultParameter.renderViewType
    }

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

    public required init(url: URL, options: [String: Any]? = [:]) {
        playerItem = MEPlayerItem(url: url, options: options)
        super.init()
        playerItem.pixelFormatType = pixelFormatType
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput.renderSource = playerItem
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
            if self.isAutoPlay {
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
                if self.isLoopPlay {
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
    public var isLoopPlay: Bool {
        get {
            return playerItem.isLoopPlay
        }
        set {
            playerItem.isLoopPlay = newValue
        }
    }

    public var preferredForwardBufferDuration: TimeInterval {
        get {
            return KSPlayerManager.preferredForwardBufferDuration
        }
        set {
            KSPlayerManager.preferredForwardBufferDuration = newValue
        }
    }

    public var playbackVolume: Float {
        get {
            return audioOutput.audioPlayer.volume
        }
        set {
            audioOutput.audioPlayer.volume = newValue
        }
    }

    public var isPlaying: Bool {
        return playbackState == .playing
    }

    public var naturalSize: CGSize {
        if playerItem.rotation == 90 || playerItem.rotation == 270 {
            return playerItem.naturalSize.reverse
        } else {
            return playerItem.naturalSize
        }
    }

    public var isExternalPlaybackActive: Bool {
        return false
    }

    public var view: UIView {
        return videoOutput.renderView
    }

    public func replace(url: URL, options: [String: Any]? = nil) {
        KSLog("replaceUrl \(self)")
        shutdown()
        audioOutput.shutdown()
        videoOutput.shutdown()
        playerItem = MEPlayerItem(url: url, options: options)
        playerItem.isLoopPlay = isLoopPlay
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput.renderSource = playerItem
    }

    public var currentPlaybackTime: TimeInterval {
        get {
            return playerItem.currentPlaybackTime
        }
        set {
            seek(time: newValue)
        }
    }

    public var duration: TimeInterval {
        return playerItem.duration
    }

    public var seekable: Bool {
        return playerItem.seekable
    }

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
            return view.contentMode
        }
    }

    public func thumbnailImageAtCurrentTime(handler: @escaping (UIImage?) -> Void) {
        return videoOutput.thumbnailImageAtCurrentTime(handler: handler)
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
            return audioOutput.audioPlayer.isMuted
        }
    }
}

extension KSMEPlayer {
    public var subtitleDataSouce: SubtitleDataSouce? {
        return playerItem
    }

    public var subtitles: [KSSubtitleProtocol] {
        return playerItem.subtitleTracks
    }
}
