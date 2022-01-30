//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import SwiftUI

@available(iOS 13, tvOS 13, macOS 10.15, *)
public struct KSVideoPlayer {
    private let url: URL
    private let options: KSOptions
    @Binding private var play: Bool
    @Binding private var time: CMTime
    private var config = Config()
    public init(url: URL, options: KSOptions, play: Binding<Bool> = .constant(true), time: Binding<CMTime> = .constant(.zero)) {
        self.url = url
        self.options = options
        _play = play
        _time = time
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer {
    struct Config {
        struct Handler {
            var onPlay: ((TimeInterval, TimeInterval) -> Void)?
            var onFinish: ((Error?) -> Void)?
            var onStateChanged: ((KSPlayerState) -> Void)?
            var onBufferChanged: ((Int, TimeInterval) -> Void)?
        }

        fileprivate var handler: Handler = .init()
        var autoReplay: Bool = false
        var isMuted: Bool = false
    }

    /// Whether the video is muted, only for this instance.
    func mute(_ value: Bool) -> Self {
        var view = self
        view.config.isMuted = value
        return view
    }

    func onBufferChanged(_ handler: @escaping (Int, TimeInterval) -> Void) -> Self {
        var view = self
        view.config.handler.onBufferChanged = handler
        return view
    }

    /// Playing to the end.
    func onFinish(_ handler: @escaping (Error?) -> Void) -> Self {
        var view = self
        view.config.handler.onFinish = handler
        return view
    }

    func onPlay(_ handler: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        var view = self
        view.config.handler.onPlay = handler
        return view
    }

    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (KSPlayerState) -> Void) -> Self {
        var view = self
        view.config.handler.onStateChanged = handler
        return view
    }
}

#if !canImport(UIKit)
@available(macOS 10.15, *)
typealias UIViewRepresentable = NSViewRepresentable
#endif
@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer: UIViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    #if canImport(UIKit)
    public typealias UIViewType = KSPlayerLayer
    public func makeUIView(context _: Context) -> UIViewType {
        KSPlayerLayer()
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.set(url: url, options: options)
        uiView.delegate = context.coordinator
        uiView.player?.isMuted = config.isMuted
    }

    public static func dismantleUIView(_ uiView: UIViewType, coordinator _: Coordinator) {
        uiView.pause()
    }
    #else
    public typealias NSViewType = KSPlayerLayer
    public func makeNSView(context _: Context) -> NSViewType {
        KSPlayerLayer()
    }

    public func updateNSView(_ uiView: NSViewType, context: Context) {
        uiView.set(url: url, options: options)
        uiView.delegate = context.coordinator
        uiView.player?.isMuted = config.isMuted
    }
    #endif

    public class Coordinator: KSPlayerLayerDelegate {
        private let KSVideoPlayer: KSVideoPlayer

        init(_ KSVideoPlayer: KSVideoPlayer) {
            self.KSVideoPlayer = KSVideoPlayer
        }

        public func player(layer _: KSPlayerLayer, state: KSPlayerState) {
            KSVideoPlayer.config.handler.onStateChanged?(state)
        }

        public func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
            KSVideoPlayer.config.handler.onPlay?(currentTime, totalTime)
        }

        public func player(layer _: KSPlayerLayer, finish error: Error?) {
            KSVideoPlayer.config.handler.onFinish?(error)
        }

        public func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
            KSVideoPlayer.config.handler.onBufferChanged?(bufferedCount, consumeTime)
        }
    }
}
