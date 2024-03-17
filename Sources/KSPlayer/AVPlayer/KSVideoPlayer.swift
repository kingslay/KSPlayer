//
//  KSVideoPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2023/2/11.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit

public typealias UIViewRepresentable = NSViewRepresentable
#endif

public struct KSVideoPlayer {
    @ObservedObject
    public private(set) var coordinator: Coordinator
    public let url: URL
    public let options: KSOptions
    public init(coordinator: Coordinator, url: URL, options: KSOptions) {
        self.coordinator = coordinator
        self.url = url
        self.options = options
    }
}

extension KSVideoPlayer: UIViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        coordinator
    }

    #if canImport(UIKit)
    public typealias UIViewType = UIView
    public func makeUIView(context: Context) -> UIViewType {
        let view = context.coordinator.makeView(url: url, options: options)
        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        let swipeUp = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)
        return view
    }

    public func updateUIView(_ view: UIViewType, context: Context) {
        updateView(view, context: context)
    }

    // iOS tvOS真机先调用onDisappear在调用dismantleUIView，但是模拟器就反过来了。
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

    // macOS先调用onDisappear在调用dismantleNSView
    public static func dismantleNSView(_ view: NSViewType, coordinator: Coordinator) {
        coordinator.resetPlayer()
        view.window?.aspectRatio = CGSize(width: 16, height: 9)
    }
    #endif

    private func updateView(_: UIView, context: Context) {
        if context.coordinator.playerLayer?.url != url {
            _ = context.coordinator.makeView(url: url, options: options)
        }
    }

    @MainActor
    public final class Coordinator: ObservableObject {
        @Published
        public var state = KSPlayerState.prepareToPlay
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
            }
        }

        @Published
        public var playbackRate: Float = 1.0 {
            didSet {
                playerLayer?.player.playbackRate = playbackRate
            }
        }

        @Published
        @MainActor
        public var isMaskShow = true {
            didSet {
                if isMaskShow != oldValue {
                    if isMaskShow {
                        delayItem?.cancel()
                        // 播放的时候才自动隐藏
                        guard state == .bufferFinished else { return }
                        delayItem = DispatchWorkItem { [weak self] in
                            self?.isMaskShow = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + KSOptions.animateDelayTimeInterval,
                                                      execute: delayItem!)
                    }
                    #if os(macOS)
                    isMaskShow ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
                    if let window = playerLayer?.player.view?.window {
                        if !window.styleMask.contains(.fullScreen) {
                            window.standardWindowButton(.closeButton)?.superview?.superview?.isHidden = !isMaskShow
                            //                    window.standardWindowButton(.zoomButton)?.isHidden = !isMaskShow
                            //                    window.standardWindowButton(.closeButton)?.isHidden = !isMaskShow
                            //                    window.standardWindowButton(.miniaturizeButton)?.isHidden = !isMaskShow
                            //                    window.titleVisibility = isMaskShow ? .visible : .hidden
                        }
                    }
                    #endif
                }
            }
        }

        public var subtitleModel = SubtitleModel()
        public var timemodel = ControllerTimeModel()
        // 在SplitView模式下，第二次进入会先调用makeUIView。然后在调用之前的dismantleUIView.所以如果进入的是同一个View的话，就会导致playerLayer被清空了。最准确的方式是在onDisappear清空playerLayer
        public var playerLayer: KSPlayerLayer? {
            didSet {
                oldValue?.delegate = nil
                oldValue?.pause()
            }
        }

        private var delayItem: DispatchWorkItem?
        public var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        public var onFinish: ((KSPlayerLayer, Error?) -> Void)?
        public var onStateChanged: ((KSPlayerLayer, KSPlayerState) -> Void)?
        public var onBufferChanged: ((Int, TimeInterval) -> Void)?
        #if canImport(UIKit)
        fileprivate var onSwipe: ((UISwipeGestureRecognizer.Direction) -> Void)?
        @objc fileprivate func swipeGestureAction(_ recognizer: UISwipeGestureRecognizer) {
            onSwipe?(recognizer.direction)
        }
        #endif

        public init() {}

        public func makeView(url: URL, options: KSOptions) -> UIView {
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.subtitleModel.url = url
                }
            }
            if let playerLayer {
                if playerLayer.url == url {
                    return playerLayer.player.view ?? UIView()
                }
                playerLayer.delegate = nil
                playerLayer.set(url: url, options: options)
                playerLayer.delegate = self
                return playerLayer.player.view ?? UIView()
            } else {
                let playerLayer = KSPlayerLayer(url: url, options: options)
                playerLayer.delegate = self
                self.playerLayer = playerLayer
                return playerLayer.player.view ?? UIView()
            }
        }

        public func resetPlayer() {
            onStateChanged = nil
            onPlay = nil
            onFinish = nil
            onBufferChanged = nil
            #if canImport(UIKit)
            onSwipe = nil
            #endif
            playerLayer = nil
            delayItem?.cancel()
            delayItem = nil
            DispatchQueue.main.async { [weak self] in
                self?.subtitleModel.url = nil
            }
        }

        public func skip(interval: Int) {
            if let playerLayer {
                seek(time: playerLayer.player.currentPlaybackTime + TimeInterval(interval))
            }
        }

        public func seek(time: TimeInterval) {
            playerLayer?.seek(time: TimeInterval(time))
        }
    }
}

extension KSVideoPlayer.Coordinator: KSPlayerLayerDelegate {
    public func player(layer: KSPlayerLayer, state: KSPlayerState) {
        self.state = state
        onStateChanged?(layer, state)
        if state == .readyToPlay {
            playbackRate = layer.player.playbackRate
            if let subtitleDataSouce = layer.player.subtitleDataSouce {
                // 要延后增加内嵌字幕。因为有些内嵌字幕是放在视频流的。所以会比readyToPlay回调晚。
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
                    guard let self else { return }
                    self.subtitleModel.addSubtitle(dataSouce: subtitleDataSouce)
                    if self.subtitleModel.selectedSubtitleInfo == nil, layer.options.autoSelectEmbedSubtitle {
                        self.subtitleModel.selectedSubtitleInfo = subtitleDataSouce.infos.first { $0.isEnabled }
                    }
                }
            }
        } else if state == .bufferFinished {
            isMaskShow = false
        } else {
            isMaskShow = true
        }
    }

    public func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        onPlay?(currentTime, totalTime)
        if currentTime >= Double(Int.max) || currentTime <= Double(Int.min) || totalTime >= Double(Int.max) || totalTime <= Double(Int.min) {
            return
        }
        let current = Int(currentTime)
        let total = Int(max(0, totalTime))
        if timemodel.currentTime != current {
            timemodel.currentTime = current
        }
        if timemodel.totalTime != total {
            timemodel.totalTime = total
        }
        _ = subtitleModel.subtitle(currentTime: currentTime)
    }

    public func player(layer: KSPlayerLayer, finish error: Error?) {
        onFinish?(layer, error)
    }

    public func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        onBufferChanged?(bufferedCount, consumeTime)
    }
}

extension KSVideoPlayer: Equatable {
    public static func == (lhs: KSVideoPlayer, rhs: KSVideoPlayer) -> Bool {
        lhs.url == rhs.url
    }
}

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

    #if canImport(UIKit)
    func onSwipe(_ handler: @escaping (UISwipeGestureRecognizer.Direction) -> Void) -> Self {
        coordinator.onSwipe = handler
        return self
    }
    #endif
}

extension View {
    func then(_ body: (inout Self) -> Void) -> Self {
        var result = self
        body(&result)
        return result
    }
}

/// 这是一个频繁变化的model。View要少用这个
public class ControllerTimeModel: ObservableObject {
    // 改成int才不会频繁更新
    @Published
    public var currentTime = 0
    @Published
    public var totalTime = 1
}
