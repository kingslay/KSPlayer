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
    @State private var currentTime = TimeInterval(0)
    @State private var totalTime = TimeInterval(1)
    @State private var isMaskShow: Bool = true
    @State private var config: KSVideoPlayer.Config
    private let url: URL
    private let options: KSOptions
    public init(url: URL, options: KSOptions) {
        self.url = url
        self.options = options
        _config = .init(initialValue: KSVideoPlayer.Config(isPlay: options.isAutoPlay))
    }

    public var body: some View {
        ZStack {
            KSVideoPlayer(url: url, options: options, config: config).onPlay { current, total in
                currentTime = current
                totalTime = total
            }
            VideoControllerView(config: $config, currentTime: $currentTime, totalTime: _totalTime).opacity(isMaskShow ? 1 : 0)
        }.onTapGesture {
            isMaskShow.toggle()
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
public struct VideoControllerView: View {
    @Binding private var config: KSVideoPlayer.Config
    @Binding private var currentTime: TimeInterval
    @State private var totalTime: TimeInterval
    private let backgroundColor = Color(red: 0.145, green: 0.145, blue: 0.145).opacity(0.6)
    public init(config: Binding<KSVideoPlayer.Config>, currentTime: Binding<TimeInterval>, totalTime: State<TimeInterval>) {
        _config = config
        _currentTime = currentTime
        _totalTime = totalTime
    }

    public var body: some View {
        VStack {
            HStack {
                Spacer().frame(width: 5)
                HStack(spacing: 15) {
                    Button(action: {}, label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    })
                    Button(action: {
                        config.isPipActive.toggle()
                    }, label: {
                        Image(systemName: config.isPipActive ? "pip.exit" : "pip.enter")
                    })
                    Button(action: {
                        config.isScaleAspectFill.toggle()
                    }, label: {
                        Image(systemName: config.isScaleAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
                    })
                }.padding(.all).background(backgroundColor, ignoresSafeAreaEdges: []).cornerRadius(8)

                Spacer()
                Button(action: {
                    config.isMuted.toggle()
                }, label: {
                    Image(systemName: config.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }).padding(.all).background(backgroundColor, ignoresSafeAreaEdges: []).cornerRadius(8)
                Spacer().frame(width: 5)
            }
            Spacer()
            HStack(spacing: 8) {
                Spacer(minLength: 5)
                Button(action: {
                    config.isPlay.toggle()
                }, label: {
                    Image(systemName: config.isPlay ? "pause.fill" : "play.fill")
                }).frame(width: 15)
                Text(currentTime.toString(for: .minOrHour)).font(Font.custom("SFProText-Regular", size: 11)).foregroundColor(.secondary)
                ProgressView(value: currentTime, total: totalTime).foregroundColor(.red)
                Text("-" + (totalTime - currentTime).toString(for: .minOrHour)).font(Font.custom("SFProText-Regular", size: 11)).foregroundColor(.secondary)
                Button(action: {}, label: {
                    Image(systemName: "ellipsis")
                })
                Spacer(minLength: 5)
            }.frame(height: 32).background(backgroundColor)
                .cornerRadius(8).padding(.horizontal)
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
    public struct Config {
        var isPlay: Bool
        var isMuted: Bool = false
        var isPipActive = false
        var isScaleAspectFill = false
    }
    private let url: URL
    private let options: KSOptions
    private var config: Config
    fileprivate var handler: Handler = .init()
    public init(url: URL, options: KSOptions, config: Config) {
        self.url = url
        self.options = options
        self.config = config
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer {
    /// Whether the video is muted, only for this instance.
    func config(_ value: Config) -> Self {
        var view = self
        view.config = value
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

    private func updateView(_ view: KSPlayerLayer, context: Context) {
        config.isPlay ? view.play() : view.pause()
        view.player?.isMuted = config.isMuted
        view.player?.contentMode = config.isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
        if let pipController = view.player?.pipController, config.isPipActive != pipController.isPictureInPictureActive {
            if pipController.isPictureInPictureActive {
                pipController.stopPictureInPicture()
            } else {
                pipController.startPictureInPicture()
            }
        }
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
