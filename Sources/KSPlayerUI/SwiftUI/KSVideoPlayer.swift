//
//  KSVideoPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2023/2/11.
//
import Combine
import Foundation
import KSPlayer
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit

public typealias UIHostingController = NSHostingController
public typealias UIViewRepresentable = NSViewRepresentable
#endif

@MainActor
public struct KSVideoPlayer {
    @ObservedObject
    public var coordinator: Coordinator
    public let url: URL
    public let options: KSOptions
    public init(coordinator: Coordinator, url: URL, options: KSOptions) {
        self.coordinator = coordinator
        self.url = url
        self.options = options
    }

    public init(playerLayer: KSPlayerLayer) {
        self.init(coordinator: Coordinator(playerLayer: playerLayer), url: playerLayer.url, options: playerLayer.options)
    }

    public init?(coordinator: Coordinator) {
        if let playerLayer = coordinator.playerLayer {
            self.init(playerLayer: playerLayer)
        } else {
            return nil
        }
    }
}

extension KSVideoPlayer: Equatable {
    public nonisolated static func == (lhs: KSVideoPlayer, rhs: KSVideoPlayer) -> Bool {
        lhs.url == rhs.url
    }
}

@MainActor
public extension KSVideoPlayer {
    func onBufferChanged(_ handler: @escaping (Int, TimeInterval) -> Void) -> Self {
        coordinator.onBufferChanged = handler
        return self
    }

    /// Playing to the end.
    func onFinish(_ handler: @escaping (KSPlayerLayer, Error?) -> Void) -> Self {
        coordinator.onFinish = handler
        return self
    }

    func onPlay(_ handler: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        coordinator.onPlay = handler
        return self
    }

    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (KSPlayerLayer, KSPlayerState) -> Void) -> Self {
        coordinator.onStateChanged = handler
        return self
    }
}

extension KSVideoPlayer: UIViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        coordinator
    }

    #if canImport(UIKit)
    public typealias UIViewType = UIView
    public func makeUIView(context: Context) -> UIViewType {
        context.coordinator.makeView(url: url, options: options)
    }

    public func updateUIView(_ view: UIViewType, context: Context) {
        updateView(view, context: context)
    }

    /// iOS tvOS真机先调用onDisappear在调用dismantleUIView，但是模拟器就反过来了。
    public static func dismantleUIView(_: UIViewType, coordinator: Coordinator) {
        coordinator.resetPlayer()
    }

    #else
    public typealias NSViewType = UIView
    public func makeNSView(context: Context) -> NSViewType {
        context.coordinator.makeView(url: url, options: options)
    }

    public func updateNSView(_ view: NSViewType, context: Context) {
        updateView(view, context: context)
    }

    /// macOS先调用onDisappear在调用dismantleNSView
    public static func dismantleNSView(_ view: NSViewType, coordinator: Coordinator) {
        coordinator.resetPlayer()
        if KSOptions.lockAspectRatio {
            view.window?.contentAspectRatio = CGSize(width: 16, height: 9)
        }
    }
    #endif

    @MainActor
    private func updateView(_ view: UIView, context: Context) {
        coordinator.playerLayer?.updateUIView(view)
        if context.coordinator.playerLayer?.url != url {
            _ = context.coordinator.makeView(url: url, options: options)
        }
    }

    @MainActor
    public final class Coordinator: ObservableObject {
        @Published
        public var state: KSPlayerState = .initialized

        @Published
        public var isMuted: Bool = false {
            didSet {
                playerLayer?.player.isMuted = isMuted
            }
        }

        @Published
        public var playbackVolume: Float = 1.0 {
            didSet {
                playerLayer?.player.playbackVolume = playbackVolume
            }
        }

        @Published
        public var isScaleAspectFill = false {
            didSet {
                playerLayer?.player.contentMode = isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
                playerLayer?.subtitleView.contentMode = isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
            }
        }

        @Published
        public var isRecord = false {
            didSet {
                if isRecord != oldValue {
                    if isRecord {
                        if let url = KSOptions.recordDir, let playerLayer {
                            if !FileManager.default.fileExists(atPath: url.path) {
                                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                            }
                            if FileManager.default.fileExists(atPath: url.path) {
                                var pathExtension = playerLayer.url.pathExtension
                                // m3u8需要转为ts，不然就会生成很多个ts的片段。
                                if pathExtension == "m3u8" {
                                    pathExtension = "ts"
                                } else if pathExtension.isEmpty {
                                    pathExtension = "ts"
                                }
                                playerLayer.player.startRecord(url: url.appendingPathComponent(Date().description + "." + pathExtension))
                            }
                        }
                    } else {
                        playerLayer?.player.stopRecord()
                    }
                }
            }
        }

        @Published
        public var playbackRate: Float = 1.0 {
            didSet {
                playerLayer?.player.playbackRate = playbackRate
            }
        }

        @Published
        public var isMaskShow = true {
            didSet {
                if isMaskShow != oldValue {
                    mask(show: isMaskShow)
                }
            }
        }

        public var timemodel = ControllerTimeModel()
        /// 在SplitView模式下，第二次进入会先调用makeUIView。然后在调用之前的dismantleUIView.所以如果进入的是同一个View的话，就会导致playerLayer被清空了。最准确的方式是在onDisappear清空playerLayer
        public private(set) var playerLayer: KSPlayerLayer? {
            didSet {
                guard let oldValue else {
                    return
                }
                #if os(macOS)
                // macOS参考系统播放器的行为，关闭窗口的时候，如果是在PIP模式，那要退出PIP
                if oldValue.isPictureInPictureActive {
                    oldValue.pipStop(restoreUserInterface: false)
                    oldValue.player.pipController = nil
                }
                #endif
                if !oldValue.isPictureInPictureActive {
                    // 需要清空delegate，不然会更新state。然后crash
                    oldValue.delegate = nil
                    oldValue.stop()
                }
            }
        }

        private var delayHide: Task<Void, Error>?
        #if os(macOS)
        private var eventMonitor: Any? {
            willSet {
                if let eventMonitor {
                    NSEvent.removeMonitor(eventMonitor)
                }
            }
        }
        #endif
        public var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        public var onFinish: ((KSPlayerLayer, Error?) -> Void)?
        public var onStateChanged: ((KSPlayerLayer, KSPlayerState) -> Void)?
        public var onBufferChanged: ((Int, TimeInterval) -> Void)?
        public var onURLChanged: ((KSPlayerLayer, URL) -> Void)?
        public init(playerLayer: KSPlayerLayer) {
            self.playerLayer = playerLayer
            playerLayer.delegate = self
            state = playerLayer.state
        }

        public init() {}

        public func makeView(url: URL, options: KSOptions) -> UIView {
            // 不要addLocalMonitorForEvents(matching: [.mouseMoved])不然光标在外面移动的时候，也会调用updateNSView
            if let playerLayer {
                playerLayer.delegate = self
                if playerLayer.url != url {
                    playerLayer.set(url: url, options: options)
                }
                return playerLayer.makeUIView()
            } else {
                let playerLayer = KSOptions.playerLayerType.init(url: url, options: options, delegate: self)
                self.playerLayer = playerLayer
                return playerLayer.makeUIView()
            }
        }

        public func resetPlayer() {
            #if os(macOS)
            eventMonitor = nil
            #endif
            onStateChanged = nil
            onPlay = nil
            onFinish = nil
            onBufferChanged = nil
            delayHide?.cancel()
            delayHide = nil
            playerLayer = nil
            #if DEBUG
            timemodel.preLoadProtocol = nil
            #endif
        }

        public func skip(interval: Int) {
            if let playerLayer {
                seek(time: playerLayer.player.currentPlaybackTime + TimeInterval(interval))
            }
        }

        public func seek(time: TimeInterval) {
            playerLayer?.seek(time: TimeInterval(time))
        }

        public func mask(show: Bool, autoHide: Bool = true) {
            isMaskShow = show
            if show {
                delayHide?.cancel()
                // 播放的时候才自动隐藏
                if state == .bufferFinished, autoHide {
                    delayHide = Task { @MainActor [weak self] in
                        try await Task.sleep(nanoseconds: UInt64(KSOptions.animateDelayTimeInterval * 1_000_000_000.0))
                        guard let self else { return }
                        if state == .bufferFinished {
                            isMaskShow = false
                        }
                    }
                }
            }
            #if os(macOS)
            show ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
            // 不要在这里隐藏状态栏，因为业务会把播放器嵌入到某个view里面，可能需要一直显示状态栏
            #endif
        }

        #if DEBUG
        /// macOS会在第一次退出播放器界面就销毁对象，tvOS要在第二次退出销毁，iOS要在第三次调用才会销毁
        deinit {
            KSLog("KSVideoPlayer.Coordinator deinit")
        }
        #endif
    }
}

extension KSVideoPlayer.Coordinator: KSPlayerLayerDelegate {
    public func player(layer: KSPlayerLayer, state: KSPlayerState) {
        Task { @MainActor in
            self.state = state
        }
        onStateChanged?(layer, state)
        if state == .readyToPlay {
            playbackRate = layer.player.playbackRate
            timemodel.fileSize = layer.player.fileSize
            #if DEBUG
            timemodel.preLoadProtocol = layer.player.ioContext as? any PreLoadProtocol
            #endif
            isMaskShow = false
        } else if state != .preparing, !state.isPlaying, !isMaskShow {
            isMaskShow = true
        }
    }

    public func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        onPlay?(currentTime, totalTime)
        guard var current = Int(exactly: ceil(currentTime)), var total = Int(exactly: ceil(totalTime)), var playable = Int(exactly: ceil(layer.player.playableTime)) else {
            return
        }
        if layer.state.isPlaying {
            current = max(0, current)
            total = max(0, total)
            if total == 0 {
                total = current
            } else {
                current = min(current, total)
            }
            if timemodel.currentTime != current {
//                KSLog(level: .info, "[subtitle] currentTime=\(timemodel.currentTime) newTime=\(current)")
                timemodel.currentTime = current
            }
            if timemodel.totalTime != total {
                timemodel.totalTime = total
            }
        }
        playable = max(0, playable)
        if timemodel.bufferTime != playable {
            timemodel.bufferTime = playable
        }
    }

    public func player(layer: KSPlayerLayer, finish error: Error?) {
        onFinish?(layer, error)
    }

    public func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        onBufferChanged?(bufferedCount, consumeTime)
    }

    public func player(layer: KSPlayerLayer, url: URL) {
#if DEBUG
        timemodel.preLoadProtocol = nil
#endif
        onURLChanged?(layer, url)
    }
}

/// 这是一个频繁变化的model。View要少用这个
public class ControllerTimeModel: ObservableObject {
    /// 改成int就变成1秒更新一次UI，不改的话，那就1毫秒更新一次UI
    @Published
    public var currentTime = 0
    @Published
    public var totalTime = 1
    @Published
    public var bufferTime = 0
    public var fileSize = Int64(1)
    #if DEBUG
    public var preLoadProtocol: PreLoadProtocol?
    #endif
}

#if DEBUG
struct KSVideoPlayer_Previews: PreviewProvider {
    static var previews: some View {
        KSOptions.firstPlayerType = KSMEPlayer.self
        let url = URL(string: "https://raw.githubusercontent.com/kingslay/TestVideo/main/h264.mp4")!
        let coordinator = KSVideoPlayer.Coordinator()
        return KSVideoPlayer(coordinator: coordinator, url: url, options: KSOptions())
    }
}
#endif
