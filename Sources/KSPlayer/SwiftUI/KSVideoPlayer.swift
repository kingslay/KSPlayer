//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import SwiftUI

@available(iOS 15, tvOS 15, macOS 12, *)
public struct KSVideoPlayerView: View {
    @State private var isPlay: Bool
    @State private var isMuted = false
    @State private var currentTime = TimeInterval(0)
    @State private var totalTime = TimeInterval(1)
    private let url: URL
    private let options: KSOptions
    public init(url: URL, options: KSOptions) {
        self.url = url
        self.options = options
        _isPlay = .init(initialValue: options.isAutoPlay)
    }

    public var body: some View {
        ZStack {
            KSVideoPlayer(url: url, options: options, isPlay: $isPlay).onPlay { current, total in
                currentTime = current
                totalTime = total
            }.mute(isMuted)
            VideoControllerView(isPlay: $isPlay, isMuted: $isMuted, currentTime: $currentTime, totalTime: _totalTime)
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
public struct VideoControllerView: View {
    @Binding private var isPlay: Bool
    @Binding private var isMuted: Bool
    @Binding private var currentTime: TimeInterval
    @State private var totalTime: TimeInterval
    private let backgroundColor = Color(red: 0.145, green: 0.145, blue: 0.145).opacity(0.6)
    public init(isPlay: Binding<Bool>, isMuted: Binding<Bool>, currentTime: Binding<TimeInterval>, totalTime: State<TimeInterval>) {
        _isPlay = isPlay
        _isMuted = isMuted
        _currentTime = currentTime
        _totalTime = totalTime
    }

    public var body: some View {
        VStack {
            HStack {
                Spacer(minLength: 5)
                HStack {
                    Button(action: {}, label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }).background(backgroundColor)
                    Spacer()
                    Button(action: {
                        isMuted.toggle()
                    }, label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }).background(backgroundColor)
                }
                Spacer(minLength: 5)
            }
            Spacer()
            HStack(spacing: 8) {
                Spacer(minLength: 5)
                Button(action: {
                    isPlay.toggle()
                }, label: {
                    Image(systemName: isPlay ? "pause.fill" : "play.fill")
                }).frame(width: 15)
                Text(currentTime.toString(for: .minOrHour)).font(Font.custom("SFProText-Regular", size: 11)).foregroundColor(.secondary)
                ProgressView(value: currentTime, total: totalTime)
                Text("-" + (totalTime - currentTime).toString(for: .minOrHour)).font(Font.custom("SFProText-Regular", size: 11)).foregroundColor(.secondary)
                Button(action: {}, label: {
                    Image(systemName: "ellipsis")
                })
                Spacer(minLength: 5)
            }.frame(height: 32).background(backgroundColor)
                .cornerRadius(8).padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
        }.foregroundColor(.primary)
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
public struct KSVideoPlayer {
    struct Handler {
        var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: ((Error?) -> Void)?
        var onStateChanged: ((KSPlayerState) -> Void)?
        var onBufferChanged: ((Int, TimeInterval) -> Void)?
    }

    private let url: URL
    private let options: KSOptions
    @Binding private var isPlay: Bool
    @Binding private var time: CMTime
    private var isMuted: Bool = false
    fileprivate var handler: Handler = .init()
    public init(url: URL, options: KSOptions, isPlay: Binding<Bool> = .constant(true), time: Binding<CMTime> = .constant(.zero)) {
        self.url = url
        self.options = options
        _isPlay = isPlay
        _time = time
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer {
    /// Whether the video is muted, only for this instance.
    func mute(_ value: Bool) -> Self {
        var view = self
        view.isMuted = value
        return view
    }

    func onBufferChanged(_ handler: @escaping (Int, TimeInterval) -> Void) -> Self {
        var view = self
        view.handler.onBufferChanged = handler
        return view
    }

    /// Playing to the end.
    func onFinish(_ handler: @escaping (Error?) -> Void) -> Self {
        var view = self
        view.handler.onFinish = handler
        return view
    }

    func onPlay(_ handler: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        var view = self
        view.handler.onPlay = handler
        return view
    }

    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (KSPlayerState) -> Void) -> Self {
        var view = self
        view.handler.onStateChanged = handler
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
    public func makeUIView(context: Context) -> UIViewType {
        makeView(context: context)
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        updateView(uiView, context: context)
    }

    public static func dismantleUIView(_ uiView: UIViewType, coordinator _: Coordinator) {
        uiView.pause()
    }
    #else
    public typealias NSViewType = KSPlayerLayer
    public func makeNSView(context: Context) -> NSViewType {
        makeView(context: context)
    }

    public func updateNSView(_ uiView: NSViewType, context: Context) {
        updateView(uiView, context: context)
    }

    public static func dismantleNSView(_ uiView: NSViewType, coordinator _: Coordinator) {
        uiView.pause()
    }
    #endif

    private func makeView(context: Context) -> KSPlayerLayer {
        let playerLayer = KSPlayerLayer()
        playerLayer.set(url: url, options: options)
        playerLayer.delegate = context.coordinator
        return playerLayer
    }

    private func updateView(_ view: KSPlayerLayer, context _: Context) {
        isPlay ? view.play() : view.pause()
        view.player?.isMuted = isMuted
    }

    public final class Coordinator: KSPlayerLayerDelegate {
        private let videoPlayer: KSVideoPlayer

        init(_ videoPlayer: KSVideoPlayer) {
            self.videoPlayer = videoPlayer
        }

        public func player(layer _: KSPlayerLayer, state: KSPlayerState) {
            videoPlayer.handler.onStateChanged?(state)
        }

        public func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
            videoPlayer.handler.onPlay?(currentTime, totalTime)
        }

        public func player(layer _: KSPlayerLayer, finish error: Error?) {
            videoPlayer.handler.onFinish?(error)
        }

        public func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
            videoPlayer.handler.onBufferChanged?(bufferedCount, consumeTime)
        }
    }
}
