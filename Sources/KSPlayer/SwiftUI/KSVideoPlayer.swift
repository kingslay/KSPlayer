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
    @State private var model = ControllerViewModel()
    @State private var subtitleModel = SubtitleModel()
    private let url: URL
    public let options: KSOptions
    private let player: KSVideoPlayer
    public init(url: URL, options: KSOptions) {
        self.options = options
        self.url = url
        player = KSVideoPlayer(url: url, options: options)
    }

    public var body: some View {
        ZStack {
            player.onPlay { current, total in
                model.currentTime = current
                model.totalTime = max(max(0, total), current)
                if let subtile = subtitleModel.selectedSubtitle {
                    let time = current + options.subtitleDelay
                    if let part = subtile.search(for: time) {
                        subtitleModel.endTime = part.end
                        if let image = part.image {
                            subtitleModel.image = image
                        } else {
                            subtitleModel.text = part.text
                        }
                    } else {
                        if time > subtitleModel.endTime {
                            subtitleModel.image = nil
                            subtitleModel.text = nil
                        }
                    }
                } else {
                    subtitleModel.image = nil
                    subtitleModel.text = nil
                }
            }
            .onStateChanged { layer, state in
                if state == .readyToPlay, let player = layer.player {
                    subtitleModel.tracks = player.tracks(mediaType: .subtitle)
                    guard let track = subtitleModel.tracks.first, let info = track.subtitle, options.autoSelectEmbedSubtitle else {
                        return
                    }
                    player.select(track: track)
                    _subtitleModel.selecte(info: info)
                }
            }
            #if os(tvOS)
            .onSwipe { direction in
                if direction == .down {
                    model.isMaskShow.toggle()
                } else if direction == .left {
                    player.config.seek(time: model.currentTime - 15)
                } else if direction == .right {
                    player.config.seek(time: model.currentTime + 15)
                }
            }
            #endif
            .background(.black)
            .edgesIgnoringSafeArea(.all)
            .onDisappear {
                player.config.coordinator.playerLayer?.pause()
            }
            VideoSubtitleView(model: $subtitleModel)
            VideoControllerView(config: player.config, model: $model).opacity(model.isMaskShow ? 1 : 0)
        }
        .confirmationDialog(Text("Setting"), isPresented: $model.isShowSetting) {
            Button {} label: {
                Text("Audio Setting")
            }
            Button {
                model.isShowSubtitleSetting.toggle()
            } label: {
                Text("Subtitle Setting")
            }
        }
        .confirmationDialog(Text("Subtitle Select"), isPresented: $model.isShowSubtitleSetting) {
            ForEach(subtitleModel.tracks, id: \.trackID) { track in
                Button(track.name) {
                    player.config.coordinator.playerLayer?.player?.select(track: track)
                    _subtitleModel.selecte(info: track.subtitle)
                }.background(subtitleModel.selectedInfo?.subtitleID == String(track.trackID) ? .red : .white)
            }
            Button("dismiss Subtitle", role: .cancel) {
                _subtitleModel.selecte(info: nil)
            }
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
                    player.config.coordinator.playerLayer?.set(url: url, options: options)
                }
            }
            return true
        }
        #endif
    }
}

struct ControllerViewModel {
    var currentTime = TimeInterval(0)
    var totalTime = TimeInterval(1)
    var isMaskShow = true
    var isShowSetting = false
    var isShowSubtitleSetting = false
}

struct SubtitleModel {
    var tracks = [MediaPlayerTrack]()
    var selectedInfo: SubtitleInfo?
    var selectedSubtitle: KSSubtitleProtocol?
    var text: NSMutableAttributedString?
    var image: UIImage?
    var endTime = TimeInterval(0)
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
extension State where Value == SubtitleModel {
    func selecte(info: SubtitleInfo?) {
        wrappedValue.selectedSubtitle = nil
        wrappedValue.selectedInfo = info
        info?.enableSubtitle { result in
            wrappedValue.selectedSubtitle = try? result.get()
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoControllerView: View {
    @State private var config: KSVideoPlayer.Config
    @Binding private var model: ControllerViewModel
    private let backgroundColor = Color(red: 0.145, green: 0.145, blue: 0.145).opacity(0.6)
    @Environment(\.dismiss) private var dismiss
    init(config: KSVideoPlayer.Config, model: Binding<ControllerViewModel>) {
        _config = State(initialValue: config)
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
                .background(backgroundColor).cornerRadius(8)
                Spacer()
                Button {
                    config.isMuted.toggle()
                } label: {
                    Image(systemName: config.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .padding()
                .background(backgroundColor).cornerRadius(8)
            }
//            #if os(tvOS)
            // can not add focusSection
//            .focusSection()
//            #endif
            Spacer()
            HStack {
                Button {
                    config.seek(time: model.currentTime - 15)
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
                    config.seek(time: model.currentTime + 15)
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
                    config.seek(time: newValue)
                }, in: 0 ... model.totalTime)
                    .frame(maxHeight: 20)
                Text("-" + (model.totalTime - model.currentTime).toString(for: .minOrHour)).font(.caption2.monospacedDigit())
                Button {
                    model.isShowSetting.toggle()
                } label: {
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
                    config.seek(time: model.currentTime - 15)
                case .right:
                    config.seek(time: model.currentTime + 15)
                case .up:
                    config.coordinator.playerLayer?.player?.playbackVolume += 1
                case .down:
                    config.coordinator.playerLayer?.player?.playbackVolume -= 1
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
struct VideoSubtitleView: View {
    @Binding private var model: SubtitleModel
    init(model: Binding<SubtitleModel>) {
        _model = model
    }

    var body: some View {
        VStack {
            Spacer()
            if let image = model.image {
                #if os(macOS)
                Image(nsImage: image)
                #else
                Image(uiImage: image)
                #endif
            } else if let text = model.text {
                Text(text.string).foregroundColor(.white).shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
            }
        }.padding()
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
public struct KSVideoPlayer {
    public struct Config {
        let coordinator = Coordinator()
        var isPlay: Bool {
            didSet {
                isPlay ? coordinator.playerLayer?.play() : coordinator.playerLayer?.pause()
            }
        }

        var isMuted: Bool = false {
            didSet {
                coordinator.playerLayer?.player?.isMuted = isMuted
            }
        }

        var isPipActive = false {
            didSet {
                if #available(tvOS 14.0, *) {
                    if let pipController = coordinator.playerLayer?.player?.pipController, isPipActive != pipController.isPictureInPictureActive {
                        if pipController.isPictureInPictureActive {
                            pipController.stopPictureInPicture()
                        } else {
                            pipController.startPictureInPicture()
                        }
                    }
                }
            }
        }

        var isScaleAspectFill = false {
            didSet {
                coordinator.playerLayer?.player?.contentMode = isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
            }
        }

        func seek(time: TimeInterval) {
            coordinator.playerLayer?.seek(time: time, autoPlay: true)
        }
    }

    public let config: Config
    private let url: URL
    public let options: KSOptions
    public init(url: URL, options: KSOptions) {
        self.options = options
        self.url = url
        config = Config(isPlay: options.isAutoPlay)
    }
}

#if !canImport(UIKit)
@available(macOS 10.15, *)
typealias UIViewRepresentable = NSViewRepresentable
#endif
@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer: UIViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        config.coordinator
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
        context.coordinator.playerLayer = playerLayer
        return playerLayer
    }

    private func updateView(_: KSPlayerLayer, context _: Context) {}

    public final class Coordinator: KSPlayerLayerDelegate {
        fileprivate weak var playerLayer: KSPlayerLayer?
        fileprivate var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        fileprivate var onFinish: ((KSPlayerLayer, Error?) -> Void)?
        fileprivate var onStateChanged: ((KSPlayerLayer, KSPlayerState) -> Void)?
        fileprivate var onBufferChanged: ((Int, TimeInterval) -> Void)?
        #if canImport(UIKit)
        fileprivate var onSwipe: ((UISwipeGestureRecognizer.Direction) -> Void)?
        #endif
        public func player(layer: KSPlayerLayer, state: KSPlayerState) {
            onStateChanged?(layer, state)
        }

        public func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
            onPlay?(currentTime, totalTime)
        }

        public func player(layer: KSPlayerLayer, finish error: Error?) {
            onFinish?(layer, error)
        }

        public func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
            onBufferChanged?(bufferedCount, consumeTime)
        }

        #if canImport(UIKit)
        @objc fileprivate func swipeGestureAction(_ recognizer: UISwipeGestureRecognizer) {
            onSwipe?(recognizer.direction)
        }
        #endif
    }
}

@available(iOS 13, tvOS 13, macOS 10.15, *)
extension KSVideoPlayer {
    func onBufferChanged(_ handler: @escaping (Int, TimeInterval) -> Void) -> Self {
        config.coordinator.onBufferChanged = handler
        return self
    }

    /// Playing to the end.
    func onFinish(_ handler: @escaping (KSPlayerLayer, Error?) -> Void) -> Self {
        config.coordinator.onFinish = handler
        return self
    }

    func onPlay(_ handler: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        config.coordinator.onPlay = handler
        return self
    }

    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (KSPlayerLayer, KSPlayerState) -> Void) -> Self {
        config.coordinator.onStateChanged = handler
        return self
    }

    #if canImport(UIKit)
    func onSwipe(_ handler: @escaping (UISwipeGestureRecognizer.Direction) -> Void) -> Self {
        config.coordinator.onSwipe = handler
        return self
    }
    #endif
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
