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
    @ObservedObject public var subtitleModel = SubtitleModel()
    @State private var model = ControllerTimeModel()
    public let url: URL
    public let options: KSOptions
    private let player: KSVideoPlayer
    private let subtitleView = VideoSubtitleView()
    @State var isMaskShow = true
    public init(url: URL, options: KSOptions) {
        self.options = options
        self.url = url
        player = KSVideoPlayer(url: url, options: options)
    }

    public var body: some View {
        ZStack {
            player.onPlay { current, total in
                model.currentTime = Int(current)
                model.totalTime = Int(max(max(0, total), current))
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
            .onStateChanged { _, state in
                if state == .readyToPlay {
                    if let track = player.coordinator.subtitleTracks.first, options.autoSelectEmbedSubtitle {
                        player.coordinator.selectedSubtitleTrack = track
                    }
                } else if state == .bufferFinished {
                    if isMaskShow {
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + KSOptions.animateDelayTimeInterval) {
                            isMaskShow = false
                        }
                    }
                }
            }
            #if canImport(UIKit)
            .onSwipe { direction in
                if direction == .down {
                    isMaskShow.toggle()
                } else if direction == .left {
                    player.coordinator.skip(interval: -15)
                } else if direction == .right {
                    player.coordinator.skip(interval: 15)
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
            .onReceive(player.coordinator.$selectedSubtitleTrack) { track in
                guard let subtitle = track as? SubtitleInfo else {
                    subtitleModel.selectedSubtitle = nil
                    return
                }
                subtitle.enableSubtitle { result in
                    subtitleModel.selectedSubtitle = try? result.get()
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onDisappear {
                if let playerLayer = player.coordinator.playerLayer {
                    if !playerLayer.isPipActive {
                        player.coordinator.playerLayer?.pause()
                    }
                }
            }
            subtitleView
            VideoControllerView().opacity(isMaskShow ? 1 : 0)
            // 设置opacity为0，还是会去更新View。所以只能这样了
            if isMaskShow {
                VideoTimeShowView(model: $model)
            }
        }
        .preferredColorScheme(.dark)
        .environmentObject(subtitleModel)
        .environmentObject(player.coordinator)
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
            player.coordinator.playerLayer?.set(url: url, options: options)
        } else {
            let info = URLSubtitleInfo(subtitleID: url.path, name: url.lastPathComponent)
            info.downloadURL = url
            info.enableSubtitle {
                subtitleModel.selectedSubtitle = try? $0.get()
            }
        }
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
    @EnvironmentObject fileprivate var config: KSVideoPlayer.Coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var isShowSetting = false
    public var body: some View {
        VStack {
            HStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").imageScale(.large)
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
//            #if os(tvOS)
            // can not add focusSection
//            .focusSection()
//            #endif
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
            .imageScale(.large)
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isShowSetting) {
            VideoSettingView()
        }
        .foregroundColor(.white)
        #if !os(iOS)
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    config.skip(interval: -15)
                case .right:
                    config.skip(interval: 15)
                case .up:
                    config.playerLayer?.player.playbackVolume += 1
                case .down:
                    config.playerLayer?.player.playbackVolume -= 1
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

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoTimeShowView: View {
    @EnvironmentObject fileprivate var config: KSVideoPlayer.Coordinator
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
    @Published fileprivate var text: NSMutableAttributedString?
    @Published fileprivate var image: UIImage?
    fileprivate var endTime = TimeInterval(0)
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSubtitleView: View {
    @EnvironmentObject fileprivate var model: SubtitleModel
    var body: some View {
        VStack {
            Spacer()
            if let image = model.image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                #endif
            } else if let text = model.text {
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
    @EnvironmentObject private var config: KSVideoPlayer.Coordinator
    var body: some View {
        config.selectedAudioTrack = (config.playerLayer?.player.isMuted ?? false) ? nil : config.audioTracks.first { $0.isEnabled }
        config.selectedVideoTrack = config.videoTracks.first { $0.isEnabled }
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
                    config.selectedSubtitleTrack = config.subtitleTracks.first { $0.trackID == value }
                })) {
                    Text("None").tag(nil as Int32?)
                    ForEach(config.subtitleTracks, id: \.trackID) { track in
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
public struct Slider: UIViewRepresentable {
    private let process: Binding<Float>
    private let onEditingChanged: (Bool) -> Void
    init(value: Binding<Double>, in bounds: ClosedRange<Double> = 0 ... 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        process = Binding {
            Float((value.wrappedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
        } set: { newValue in
            value.wrappedValue = (bounds.upperBound - bounds.lowerBound) * Double(newValue) + bounds.lowerBound
        }
        self.onEditingChanged = onEditingChanged
    }

    public typealias UIViewType = TVSlide
    public func makeUIView(context _: Context) -> UIViewType {
        TVSlide(process: process, onEditingChanged: onEditingChanged)
    }

    public func updateUIView(_ view: UIViewType, context _: Context) {
        view.process = process
    }
}

public class TVSlide: UIControl {
    private let processView = UIProgressView()
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

    public init(process: Binding<Float>, onEditingChanged: @escaping (Bool) -> Void) {
        self.process = process
        self.onEditingChanged = onEditingChanged
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
}
#endif
