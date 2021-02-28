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
    private var playerItem: MEPlayerItem
    private let videoOutput: MetalPlayView
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
                videoOutput.isPaused = playbackState != .playing
                playOrPause()
                if playbackState == .finished {
                    delegate?.finish(player: self, error: nil)
                }
            }
        }
    }

    public required init(url: URL, options: KSOptions) {
        playerItem = MEPlayerItem(url: url, options: options)
        self.videoOutput = MetalPlayView(options: options)
        self.options = options
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput.renderSource = playerItem
        setAudioSession()
    }

    deinit {
        shutdown()
    }
}

// MARK: - private functions

extension KSMEPlayer {
    private func playOrPause() {
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            self.audioOutput.isPaused = !(self.playbackState == .playing && self.loadState == .playable)
            self.delegate?.changeLoadState(player: self)
        }
    }
}

extension KSMEPlayer: MEPlayerDelegate {
    func sourceDidOpened() {
        isPreparedToPlay = true
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            self.videoOutput.drawableSize = self.options.display == .plane ? self.naturalSize : UIScreen.size
            self.view.centerRotate(byDegrees: self.playerItem.rotation)
            self.videoOutput.isPaused = false
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
                self.audioOutput.isPaused = true
            } else if type == .video {
                self.videoOutput.isPaused = true
            }
            if allSatisfy {
                if self.options.isLoopPlay {
                    self.loopCount += 1
                    self.delegate?.playBack(player: self, loopCount: self.loopCount)
                    self.audioOutput.isPaused = false
                    self.videoOutput.isPaused = false
                } else {
                    self.playbackState = .finished
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

    public var nominalFrameRate: Float {
        Float(playerItem.assetTracks.first { $0.mediaType == .video && $0.isEnabled }?.fps ?? 0)
    }

    public var isExternalPlaybackActive: Bool { false }

    public var view: UIView { videoOutput }

    public func replace(url: URL, options: KSOptions) {
        KSLog("replaceUrl \(self)")
        shutdown()
        playerItem.delegate = nil
        playerItem = MEPlayerItem(url: url, options: options)
        self.options = options
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        videoOutput.renderSource = playerItem
        videoOutput.options = options
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
        guard time >= 0 else {
            return
        }
        let oldPlaybackState = playbackState
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
        playerItem.seek(time: seekTime) { [weak self] result in
            guard let self = self else { return }
            runInMainqueue { [weak self] in
                guard let self = self else { return }
                self.playbackState = oldPlaybackState
                handler?(result)
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
        loopCount = 0
        playerItem.shutdown()
        options.starTime = 0
        options.openTime = 0
        options.findTime = 0
        options.readAudioTime = 0
        options.readVideoTime = 0
        options.decodeAudioTime = 0
        options.decodeVideoTime = 0
    }

    public var contentMode: UIViewContentMode {
        get {
            view.contentMode
        }
        set {
            view.contentMode = newValue
        }
    }

    public func thumbnailImageAtCurrentTime(handler: @escaping (UIImage?) -> Void) {
        let image = videoOutput.toImage()
        handler(image)
    }

    public func enterBackground() {
        playerItem.isBackground = true
    }

    public func enterForeground() {
        playerItem.isBackground = false
    }

    public var isMuted: Bool {
        get {
            audioOutput.audioPlayer.isMuted
        }
        set {
            audioOutput.audioPlayer.isMuted = newValue
        }
    }

    public func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack] {
        playerItem.assetTracks.filter { $0.mediaType == mediaType }
    }

    public func select(track: MediaPlayerTrack) {
        playerItem.select(track: track)
    }
}

extension KSMEPlayer {
    public var subtitleDataSouce: SubtitleDataSouce? { playerItem }

    public var subtitles: [KSSubtitleProtocol] { playerItem.subtitleTracks }
}
