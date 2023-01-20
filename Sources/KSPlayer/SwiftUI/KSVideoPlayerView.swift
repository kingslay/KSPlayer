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
    @StateObject public var subtitleModel = SubtitleModel()
    @StateObject public var playerCoordinator = KSVideoPlayer.Coordinator()
    @State public var url: URL
    public let options: KSOptions
    @State var isMaskShow = true
    @State private var model = ControllerTimeModel()
    @Environment(\.dismiss) private var dismiss
    public init(url: URL, options: KSOptions) {
        _url = .init(initialValue: url)
        self.options = options
    }

    public var body: some View {
        ZStack {
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options).onPlay { current, total in
                model.currentTime = Int(current)
                model.totalTime = Int(max(max(0, total), current))
                if let subtile = subtitleModel.selectedSubtitle {
                    let time = current + options.subtitleDelay
                    if let part = subtile.search(for: time) {
                        subtitleModel.part = part
                    } else {
                        if let part = subtitleModel.part, part.end > part.start, time > part.end {
                            subtitleModel.part = nil
                        }
                    }
                } else {
                    subtitleModel.part = nil
                }
            }
            .onStateChanged { playerLayer, state in
                if state == .readyToPlay {
                    if let track = playerLayer.player.tracks(mediaType: .subtitle).first, playerLayer.options.autoSelectEmbedSubtitle {
                        playerCoordinator.selectedSubtitleTrack = track
                    }
                } else if state == .bufferFinished {
                    if isMaskShow {
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + KSOptions.animateDelayTimeInterval) {
                            isMaskShow = playerLayer.state != .bufferFinished
                        }
                    }
                } else {
                    isMaskShow = true
                }
            }
            #if canImport(UIKit)
            .onSwipe { direction in
                isMaskShow = true
                if direction == .left {
                    playerCoordinator.skip(interval: -15)
                } else if direction == .right {
                    playerCoordinator.skip(interval: 15)
                }
            }
            #endif
            #if !os(tvOS)
            .onTapGesture {
                isMaskShow.toggle()
                #if os(macOS)
                isMaskShow ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
                #endif
            }
            #endif
            .onReceive(playerCoordinator.$selectedSubtitleTrack) { track in
                guard let subtitle = track as? SubtitleInfo else {
                    subtitleModel.selectedSubtitle = nil
                    return
                }
                subtitle.enableSubtitle { result in
                    subtitleModel.selectedSubtitle = try? result.get()
                }
            }
            .onDisappear {
                if let playerLayer = playerCoordinator.playerLayer {
                    if !playerLayer.isPipActive {
                        playerCoordinator.playerLayer?.pause()
                        playerCoordinator.playerLayer = nil
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            VideoSubtitleView(model: subtitleModel)
            VideoControllerView(config: playerCoordinator).environmentObject(subtitleModel)
            #if !os(iOS)
                .onMoveCommand { direction in
                    isMaskShow = true
                    #if os(macOS)
                    switch direction {
                    case .left:
                        playerCoordinator.skip(interval: -15)
                    case .right:
                        playerCoordinator.skip(interval: 15)
                    case .up:
                        playerCoordinator.playerLayer?.player.playbackVolume += 1
                    case .down:
                        playerCoordinator.playerLayer?.player.playbackVolume -= 1
                    @unknown default:
                        break
                    }
                    #endif
                }
                .onExitCommand {
                    if isMaskShow {
                        isMaskShow = false
                    } else {
                        dismiss()
                    }
                }
            #endif
                .opacity(isMaskShow ? 1 : 0)
            // 设置opacity为0，还是会去更新View。所以只能这样了
            if isMaskShow {
                VideoTimeShowView(config: playerCoordinator, model: $model)
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
            .navigationTitle(url.lastPathComponent)
            .onTapGesture(count: 2) {
                NSApplication.shared.keyWindow?.toggleFullScreen(self)
            }
        #else
            .navigationBarHidden(true)
        #endif
        #if !os(tvOS)
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                if let data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                    openURL(url)
                }
            }
            return true
        }
        #endif
    }

    public func openURL(_ url: URL) {
        if url.isAudio || url.isMovie {
            self.url = url
        } else {
            let info = URLSubtitleInfo(subtitleID: url.path, name: url.lastPathComponent)
            info.downloadURL = url
            info.enableSubtitle {
                subtitleModel.selectedSubtitle = try? $0.get()
            }
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
extension KSVideoPlayerView: Equatable {
    public static func == (lhs: KSVideoPlayerView, rhs: KSVideoPlayerView) -> Bool {
        lhs.url == rhs.url
    }
}

/// 这是一个频繁变化的model。View要少用这个
struct ControllerTimeModel {
    // 改成int才不会频繁更新
    var currentTime = 0
    var totalTime = 1
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoControllerView: View {
    @StateObject fileprivate var config: KSVideoPlayer.Coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var isShowSetting = false
    public var body: some View {
        VStack {
            HStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").font(.system(.title))
                    }
                    Button {
                        config.playerLayer?.isPipActive.toggle()
                    } label: {
                        Image(systemName: config.playerLayer?.isPipActive ?? false ? "pip.exit" : "pip.enter")
                    }
                    Button {
                        config.isScaleAspectFill.toggle()
                    } label: {
                        Image(systemName: config.isScaleAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
                    }
                }
                Spacer()
                ProgressView().opacity(config.isLoading ? 1 : 0)
                Spacer()
                HStack {
                    Button {
                        config.isMuted.toggle()
                    } label: {
                        Image(systemName: config.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    #if !os(tvOS)
                    AirPlayView().fixedSize()
                    #endif
                    Button {
                        isShowSetting.toggle()
                    } label: {
                        Image(systemName: "ellipsis.circle").frame(minWidth: 20, minHeight: 20)
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button {
                    config.skip(interval: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                }
                #if !os(tvOS)
                .keyboardShortcut(.leftArrow, modifiers: .none)
                #endif
                Spacer()
                Button {
                    config.isPlay.toggle()
                } label: {
                    Image(systemName: config.isPlay ? "pause.fill" : "play.fill")
                }
                #if !os(tvOS)
                .keyboardShortcut(.space, modifiers: .none)
                #endif
                Spacer()
                Button {
                    config.skip(interval: 15)
                } label: {
                    Image(systemName: "goforward.15")
                }
                #if !os(tvOS)
                .keyboardShortcut(.rightArrow, modifiers: .none)
                #endif
                Spacer()
            }
            .font(.system(.title))
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isShowSetting) {
            VideoSettingView(config: config)
        }
        .foregroundColor(.white)
        #if os(tvOS)
            //             can not add focusSection
            .focusSection()
            .onPlayPauseCommand {
                config.isPlay.toggle()
            }
        #endif
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoTimeShowView: View {
    @StateObject fileprivate var config: KSVideoPlayer.Coordinator
    @Binding fileprivate var model: ControllerTimeModel
    public var body: some View {
        VStack {
            Spacer()
            Slider(value: Binding {
                Double(model.currentTime)
            } set: { newValue, _ in
                model.currentTime = Int(newValue)
            }, in: 0 ... Double(model.totalTime)) { onEditingChanged in
                if onEditingChanged {
                    config.isPlay = false
                } else {
                    config.seek(time: TimeInterval(model.currentTime))
                }
            }
            .frame(maxHeight: 20)
            HStack {
                Text(model.currentTime.toString(for: .minOrHour)).font(.caption2.monospacedDigit())
                Spacer()
                Text("-" + (model.totalTime - model.currentTime).toString(for: .minOrHour)).font(.caption2.monospacedDigit())
            }
        }
        .padding()
        .foregroundColor(.white)
    }
}

extension EventModifiers {
    static let none = Self()
}

public class SubtitleModel: ObservableObject {
    public var selectedSubtitle: KSSubtitleProtocol?
    @Published public var textFont: Font = .largeTitle
    @Published public var textColor: Color = .white
    @Published public var textPositionFromBottom = 0
    @Published fileprivate var part: SubtitlePart?
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSubtitleView: View {
    @StateObject fileprivate var model: SubtitleModel
    var body: some View {
        VStack {
            Spacer()
            if let image = model.part?.image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                #endif
            } else if let text = model.part?.text {
                Text(AttributedString(text))
                    .multilineTextAlignment(.center)
                    .font(model.textFont)
                    .foregroundColor(model.textColor).shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                    .padding(.bottom, CGFloat(model.textPositionFromBottom))
            }
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var presentSubtileDelayAlert = false
    @State private var presentSubtileDelay = ""
    @EnvironmentObject private var subtitleModel: SubtitleModel
    @StateObject fileprivate var config: KSVideoPlayer.Coordinator
    var body: some View {
        config.selectedAudioTrack = (config.playerLayer?.player.isMuted ?? false) ? nil : config.audioTracks.first { $0.isEnabled }
        config.selectedVideoTrack = config.videoTracks.first { $0.isEnabled }
        let subtitleTracks = config.playerLayer?.player.tracks(mediaType: .subtitle) ?? []
        return TabView {
            List {
                Picker("audio tracks", selection: Binding(get: {
                    config.selectedAudioTrack?.trackID
                }, set: { value in
                    config.selectedAudioTrack = config.audioTracks.first { $0.trackID == value }
                })) {
                    Text("None").tag(nil as Int32?)
                    ForEach(config.audioTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                }
            }
            .tabItem {
                Text("audio")
            }
            List {
                Picker("subtitle tracks", selection: Binding(get: {
                    config.selectedSubtitleTrack?.trackID
                }, set: { value in
                    config.selectedSubtitleTrack = subtitleTracks.first { $0.trackID == value }
                })) {
                    Text("None").tag(nil as Int32?)
                    ForEach(subtitleTracks, id: \.trackID) { track in
                        Text(track.name).tag(track.trackID as Int32?)
                    }
                }
                Button("subtile delay") {
                    presentSubtileDelayAlert = true
                }
                .alert("subtile delay", isPresented: $presentSubtileDelayAlert, actions: {
                    TextField("delay second", text: $presentSubtileDelay)
                        .foregroundColor(.black)
                    #if !os(macOS)
                        .keyboardType(.numberPad)
                    #endif
                    Button("OK", action: {
                        config.playerLayer?.options.subtitleDelay = Double(presentSubtileDelay) ?? 0
                    })
                    Button("Cancel", role: .cancel, action: {})
                })
                Picker("subtitle text color", selection: $subtitleModel.textColor) {
                    ForEach([Color.red, Color.white, Color.orange], id: \.description) { color in
                        Text(color.description).tag(color)
                    }
                }
            }
            .tabItem {
                Text("subtitle")
            }
            List {
                Picker("video tracks", selection: Binding(get: {
                    config.selectedVideoTrack?.trackID
                }, set: { value in
                    config.selectedVideoTrack = config.videoTracks.first { $0.trackID == value }
                })) {
                    Text("None").tag(nil as Int32?)
                    ForEach(config.videoTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                }
            }
            .tabItem {
                Text("video")
            }
        }
        .toolbar {
            Button("Done") {
                dismiss()
            }
        }
        #if os(macOS)
        .frame(width: UIScreen.size.width / 4, height: UIScreen.size.height / 4)
        #endif
    }
}

public struct AirPlayView: UIViewRepresentable {
    #if canImport(UIKit)
    public typealias UIViewType = AVRoutePickerView
    public func makeUIView(context _: Context) -> UIViewType {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        return routePickerView
    }

    public func updateUIView(_: UIViewType, context _: Context) {}
    #else
    public typealias NSViewType = AVRoutePickerView
    public func makeNSView(context _: Context) -> NSViewType {
        let routePickerView = AVRoutePickerView()
        return routePickerView
    }

    public func updateNSView(_: NSViewType, context _: Context) {}
    #endif
}

#if os(tvOS)
import Combine
@available(tvOS 15.0, *)
public struct Slider: View {
    private let process: Binding<Float>
    private let onEditingChanged: (Bool) -> Void
    @FocusState private var isFocused: Bool
    init(value: Binding<Double>, in bounds: ClosedRange<Double> = 0 ... 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        process = Binding {
            Float((value.wrappedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
        } set: { newValue in
            value.wrappedValue = (bounds.upperBound - bounds.lowerBound) * Double(newValue) + bounds.lowerBound
        }
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        TVOSSlide(process: process, isFocused: _isFocused, onEditingChanged: onEditingChanged)
            .focused($isFocused)
    }
}

@available(tvOS 15.0, *)
public struct TVOSSlide: UIViewRepresentable {
    let process: Binding<Float>
    @FocusState var isFocused: Bool
    let onEditingChanged: (Bool) -> Void
    public typealias UIViewType = TVSlide
    public func makeUIView(context _: Context) -> UIViewType {
        TVSlide(process: process, onEditingChanged: onEditingChanged)
    }

    public func updateUIView(_ view: UIViewType, context _: Context) {
        if isFocused {
            if view.processView.tintColor == .white {
                view.processView.tintColor = .red
            }
        } else {
            view.processView.tintColor = .white
        }
        view.process = process
    }
}

public class TVSlide: UIControl {
    let processView = UIProgressView()
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(actionPanGesture(sender:)))
    private var beganProgress = Float(0.0)
    private let onEditingChanged: (Bool) -> Void
    fileprivate var process: Binding<Float> {
        willSet {
            if newValue.wrappedValue != processView.progress {
                processView.progress = newValue.wrappedValue
            }
        }
    }

    private var preMoveDirection: UISwipeGestureRecognizer.Direction?
    private var preMoveTime = CACurrentMediaTime()
    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        guard let self, let preMoveDirection = self.preMoveDirection, preMoveDirection == .left || preMoveDirection == .right, self.process.wrappedValue < 0.99, self.process.wrappedValue > 0.01 else {
            return
        }
        self.onEditingChanged(true)
        self.process.wrappedValue += Float(preMoveDirection == .right ? 0.01 : -0.01)
    }

    public init(process: Binding<Float>, onEditingChanged: @escaping (Bool) -> Void) {
        self.process = process
        self.onEditingChanged = onEditingChanged
        super.init(frame: .zero)
        processView.translatesAutoresizingMaskIntoConstraints = false
        processView.tintColor = .white
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
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureAction(_:)))
        swipeDown.direction = .down
        addGestureRecognizer(swipeDown)
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureAction(_:)))
        swipeLeft.direction = .left
        addGestureRecognizer(swipeLeft)
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureAction(_:)))
        swipeRight.direction = .right
        addGestureRecognizer(swipeRight)
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureAction(_:)))
        swipeUp.direction = .up
        addGestureRecognizer(swipeUp)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func actionTapGesture(sender _: UITapGestureRecognizer) {
        panGestureRecognizer.isEnabled.toggle()
        processView.tintColor = panGestureRecognizer.isEnabled ? .blue : .red
    }

    @objc private func actionPanGesture(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self)
        if abs(translation.y) > abs(translation.x) {
            return
        }

        switch sender.state {
        case .began, .possible:
            beganProgress = processView.progress
        case .changed:
            let value = beganProgress + Float(translation.x) / 5 / Float(frame.size.width)
            process.wrappedValue = value
            onEditingChanged(true)
        case .ended:
            onEditingChanged(false)
        case .cancelled, .failed:
            process.wrappedValue = beganProgress
            onEditingChanged(false)
        @unknown default:
            break
        }
    }

    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let presse = presses.first else {
            return
        }
        switch presse.type {
        case .leftArrow:
            onEditingChanged(true)
            if preMoveDirection == .left, CACurrentMediaTime() - preMoveTime < 0.2 {
                timer.fireDate = Date.distantPast
                break
            } else {
                timer.fireDate = Date.distantFuture
                process.wrappedValue -= Float(0.01)
                onEditingChanged(false)
            }
            preMoveDirection = .left
            preMoveTime = CACurrentMediaTime()
        case .rightArrow:
            onEditingChanged(true)
            if preMoveDirection == .right, CACurrentMediaTime() - preMoveTime < 0.2 {
                timer.fireDate = Date.distantPast
                break
            } else {
                timer.fireDate = Date.distantFuture
                process.wrappedValue += Float(0.01)
                onEditingChanged(false)
            }
            preMoveDirection = .right
            preMoveTime = CACurrentMediaTime()
        case .upArrow:
            preMoveDirection = .up
            preMoveTime = CACurrentMediaTime()
            timer.fireDate = Date.distantFuture
            onEditingChanged(false)
        case .downArrow:
            preMoveDirection = .down
            preMoveTime = CACurrentMediaTime()
            timer.fireDate = Date.distantFuture
            onEditingChanged(false)
        default: super.pressesBegan(presses, with: event)
        }
    }

    @objc fileprivate func swipeGestureAction(_ recognizer: UISwipeGestureRecognizer) {
        switch recognizer.direction {
        case .left:
            onEditingChanged(true)
            if preMoveDirection == .left, CACurrentMediaTime() - preMoveTime < 0.02 {
                timer.fireDate = Date.distantPast
                break
            } else {
                timer.fireDate = Date.distantFuture
                process.wrappedValue -= Float(0.01)
                onEditingChanged(false)
            }
            preMoveDirection = .left
            preMoveTime = CACurrentMediaTime()
        case .right:
            onEditingChanged(true)
            if preMoveDirection == .right, CACurrentMediaTime() - preMoveTime < 0.02 {
                timer.fireDate = Date.distantPast
                break
            } else {
                timer.fireDate = Date.distantFuture
                process.wrappedValue += Float(0.01)
                onEditingChanged(false)
            }
            preMoveDirection = .right
            preMoveTime = CACurrentMediaTime()
        case .up:
            preMoveDirection = .up
            preMoveTime = CACurrentMediaTime()
            timer.fireDate = Date.distantFuture
            onEditingChanged(false)
        case .down:
            preMoveDirection = .down
            preMoveTime = CACurrentMediaTime()
            timer.fireDate = Date.distantFuture
            onEditingChanged(false)
        default:
            break
        }
    }
}
#endif
