//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import AVKit
import SwiftUI
@available(iOS 15, tvOS 15, macOS 12, *)
public struct KSVideoPlayerView: View {
    @State private var model = VideoControllerView.ControllerViewModel()
    private let url: URL
    private let player = KSVideoPlayer()
    public let options: KSOptions
    public init(url: URL, options: KSOptions) {
        self.options = options
        self.url = url
    }

    public var body: some View {
        player.playerLayer.set(url: url, options: options)
        let config = VideoControllerView.Config(isPlay: options.isAutoPlay, playerLayer: player.playerLayer)
        let controllerView = VideoControllerView(config: config, model: $model)
        return ZStack {
            player.onPlay { current, total in
                model.currentTime = current
                model.totalTime = max(max(0, total), current)
            }
            #if os(tvOS)
            .onSwipe { direction in
                if direction == .down {
                    model.isMaskShow.toggle()
                } else if direction == .left {
                    config.playerLayer.seek(time: model.currentTime - 15, autoPlay: true)
                } else if direction == .right {
                    config.playerLayer.seek(time: model.currentTime + 15, autoPlay: true)
                }
            }
            #endif
            .background(.black)
            .edgesIgnoringSafeArea(.all)
            .onDisappear {
                player.playerLayer.pause()
            }
            controllerView.opacity(model.isMaskShow ? 1 : 0)
        }
        #if !os(macOS)
        .navigationBarHidden(true)
        #endif
        #if !os(tvOS)
        .onTapGesture {
            model.isMaskShow.toggle()
        }
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String), url.isAudio || url.isMovie {
                    player.playerLayer.set(url: url, options: options)
                }
            }
            return true
        }
        #endif
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoControllerView: View {
    public struct Config {
        fileprivate let playerLayer: KSPlayerLayer
        init(isPlay: Bool, playerLayer: KSPlayerLayer) {
            self.isPlay = isPlay
            self.playerLayer = playerLayer
        }

        var isPlay: Bool {
            didSet {
                isPlay ? playerLayer.play() : playerLayer.pause()
            }
        }

        var isMuted: Bool = false {
            didSet {
                playerLayer.player?.isMuted = isMuted
            }
        }

        var isPipActive = false {
            didSet {
                if let pipController = playerLayer.player?.pipController, isPipActive != pipController.isPictureInPictureActive {
                    if pipController.isPictureInPictureActive {
                        pipController.stopPictureInPicture()
                    } else {
                        pipController.startPictureInPicture()
                    }
                }
            }
        }

        var isScaleAspectFill = false {
            didSet {
                playerLayer.player?.contentMode = isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
            }
        }
    }

    struct ControllerViewModel {
        var currentTime = TimeInterval(0)
        var totalTime = TimeInterval(1)
        var isMaskShow: Bool = true
    }

    @State private var config: Config
    @Binding private var model: ControllerViewModel
    private let backgroundColor = Color(red: 0.145, green: 0.145, blue: 0.145).opacity(0.6)
    @Environment(\.dismiss) private var dismiss
    init(config: Config, model: Binding<ControllerViewModel>) {
        _config = .init(initialValue: config)
        _model = model
    }

    public var body: some View {
        VStack {
            HStack {
                HStack {
                    Button {
                        #if os(tvOS)
                        model.isMaskShow = false
                        #else
                        dismiss()
                        #endif
                    } label: {
                        Image(systemName: "xmark")
                    }
                    Button {
                        config.isPipActive.toggle()
                    } label: {
                        Image(systemName: config.isPipActive ? "pip.exit" : "pip.enter")
                    }
                    Button {
                        config.isScaleAspectFill.toggle()
                    } label: {
                        Image(systemName: config.isScaleAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
                    }
                }
                .padding()
                .background(backgroundColor, ignoresSafeAreaEdges: []).cornerRadius(8)
                Spacer()
                Button {
                    config.isMuted.toggle()
                } label: {
                    Image(systemName: config.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .padding()
                .background(backgroundColor, ignoresSafeAreaEdges: []).cornerRadius(8)
            }
            #if os(tvOS)
            .focusSection()
            #endif
            Spacer()
            HStack {
                Button {
                    config.playerLayer.seek(time: model.currentTime - 15, autoPlay: true)
                } label: {
                    Image(systemName: "gobackward.15")
                }
                #if !os(tvOS)
                .keyboardShortcut(.leftArrow)
                #endif
                Button {
                    config.isPlay.toggle()
                } label: {
                    Image(systemName: config.isPlay ? "pause.fill" : "play.fill")
                }
                #if !os(tvOS)
                .keyboardShortcut(.space, modifiers: .option)
                #endif
                Button {
                    config.playerLayer.seek(time: model.currentTime + 15, autoPlay: true)
                } label: {
                    Image(systemName: "goforward.15")
                }
                #if !os(tvOS)
                .keyboardShortcut(.rightArrow)
                #endif
                Text(model.currentTime.toString(for: .minOrHour)).font(.caption2.monospacedDigit())
                Slider(value: Binding {
                    model.currentTime
                } set: { newValue in
                    config.playerLayer.seek(time: newValue, autoPlay: true)
                }, in: 0 ... model.totalTime)
                    .frame(maxHeight: 20)
                Text("-" + (model.totalTime - model.currentTime).toString(for: .minOrHour)).font(.caption2.monospacedDigit())
                Button {} label: {
                    Image(systemName: "ellipsis")
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .foregroundColor(.white)
        #if os(macOS)
            .focusable()
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    config.playerLayer.seek(time: model.currentTime - 15, autoPlay: true)
                case .right:
                    config.playerLayer.seek(time: model.currentTime + 15, autoPlay: true)
                case .up:
                    config.playerLayer.player?.playbackVolume += 1
                case .down:
                    config.playerLayer.player?.playbackVolume -= 1
                @unknown default:
                    break
                }
            }
        #endif
        #if os(tvOS)
        .onPlayPauseCommand {
            config.isPlay.toggle()
        }
        #endif
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
public struct KSVideoPlayer {
    struct Handler {
        var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: ((Error?) -> Void)?
        var onStateChanged: ((KSPlayerState) -> Void)?
        var onBufferChanged: ((Int, TimeInterval) -> Void)?
        #if canImport(UIKit)
        var onSwipe: ((UISwipeGestureRecognizer.Direction) -> Void)?
        #endif
    }

    public let playerLayer = KSPlayerLayer()
    fileprivate var handler = Handler()
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer {
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

    #if canImport(UIKit)
    func onSwipe(_ handler: @escaping (UISwipeGestureRecognizer.Direction) -> Void) -> Self {
        var view = self
        view.handler.onSwipe = handler
        return view
    }
    #endif
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
        let view = makeView(context: context)
        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        return view
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        updateView(uiView, context: context)
    }

    #else
    public typealias NSViewType = KSPlayerLayer
    public func makeNSView(context: Context) -> NSViewType {
        makeView(context: context)
    }

    public func updateNSView(_ uiView: NSViewType, context: Context) {
        updateView(uiView, context: context)
    }
    #endif
    private func makeView(context: Context) -> KSPlayerLayer {
        playerLayer.delegate = context.coordinator
        return playerLayer
    }

    private func updateView(_: KSPlayerLayer, context _: Context) {}

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

        #if canImport(UIKit)
        @objc fileprivate func swipeGestureAction(_ recognizer: UISwipeGestureRecognizer) {
            videoPlayer.handler.onSwipe?(recognizer.direction)
        }
        #endif
    }
}

#if os(tvOS)
import Combine
@available(tvOS 13.0, *)
struct Slider: UIViewRepresentable {
    private let process: Binding<Float>
    init(value: Binding<Double>, in bounds: ClosedRange<Double> = 0 ... 1, onEditingChanged _: @escaping (Bool) -> Void = { _ in }) {
        process = Binding {
            Float((value.wrappedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
        } set: { newValue in
            value.wrappedValue = (bounds.upperBound - bounds.lowerBound) * Double(newValue) + bounds.lowerBound
        }
    }

    typealias UIViewType = TVSlide
    func makeUIView(context _: Context) -> UIViewType {
        TVSlide(process: process)
    }

    func updateUIView(_ view: UIViewType, context _: Context) {
        view.process = process
    }
}

@available(tvOS 13.0, *)
class TVSlide: UIControl {
    private let processView = UIProgressView()
    private var isTouch = false
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(actionPanGesture(sender:)))
    var process: Binding<Float> {
        willSet {
            if !isTouch, newValue.wrappedValue != processView.progress {
                processView.progress = newValue.wrappedValue
            }
        }
    }

    init(process: Binding<Float>) {
        self.process = process
        super.init(frame: .zero)
        processView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(processView)
        NSLayoutConstraint.activate([
            processView.topAnchor.constraint(equalTo: topAnchor),
            processView.leadingAnchor.constraint(equalTo: leadingAnchor),
            processView.trailingAnchor.constraint(equalTo: trailingAnchor),
            processView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        addGestureRecognizer(panGestureRecognizer)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTapGesture(sender:)))
        addGestureRecognizer(tapGestureRecognizer)
        processView.tintColor = .blue
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func actionTapGesture(sender _: UITapGestureRecognizer) {
        panGestureRecognizer.isEnabled.toggle()
        processView.tintColor = panGestureRecognizer.isEnabled ? .blue : .white
    }

    @objc private func actionPanGesture(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self)
        if abs(translation.y) > abs(translation.x) {
            return
        }
        let touchPoint = sender.location(in: self)
        let value = Float(touchPoint.x / frame.size.width)
        switch sender.state {
        case .began, .possible:
            isTouch = true
        case .changed:
            processView.progress = value
        case .ended:
            process.wrappedValue = value
            isTouch = false
        case .cancelled:
            isTouch = false
        case .failed:
            isTouch = false
        @unknown default:
            break
        }
    }
}
#endif
