//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import MediaPlayer
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct KSVideoPlayerView: View {
    private let subtitleDataSouce: SubtitleDataSouce?
    private let onPlayerDisappear: ((KSPlayerLayer?) -> Void)?
    @State
    private var title: String
    @State
    private var showDropDownMenu = false
    @StateObject
    private var playerCoordinator = KSVideoPlayer.Coordinator()
    @Environment(\.dismiss)
    private var dismiss
    @FocusState
    private var dropdownFocused: Bool
    public let options: KSOptions
    @State
    public var url: URL {
        didSet {
            #if os(macOS)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            #endif
        }
    }

    public init(url: URL, options: KSOptions, title: String? = nil, subtitleDataSouce: SubtitleDataSouce? = nil, onPlayerDisappear: ((KSPlayerLayer?) -> Void)? = nil) {
        _url = .init(initialValue: url)
        _title = .init(initialValue: title ?? url.lastPathComponent)
        #if os(macOS)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        #endif
        self.options = options
        self.subtitleDataSouce = subtitleDataSouce
        self.onPlayerDisappear = onPlayerDisappear
    }

    public var body: some View {
        ZStack {
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
                .onStateChanged { playerLayer, state in
                    if state == .readyToPlay {
                        if let movieTitle = playerLayer.player.dynamicInfo?.metadata["title"] {
                            title = movieTitle
                        }
                    }
                }
                .onBufferChanged { bufferedCount, consumeTime in
                    print("bufferedCount \(bufferedCount), consumeTime \(consumeTime)")
                }
            #if canImport(UIKit)
                .onSwipe { direction in
                    playerCoordinator.isMaskShow = true
                    if direction == .left {
                        playerCoordinator.skip(interval: -15)
                    } else if direction == .right {
                        playerCoordinator.skip(interval: 15)
                    }
                }
            #endif
                .onAppear {
                    if let subtitleDataSouce {
                        playerCoordinator.subtitleModel.addSubtitle(dataSouce: subtitleDataSouce)
                    }
                    // 不要加这个，不然playerCoordinator无法释放，也可以在onDisappear调用removeMonitor释放
//                    #if os(macOS)
//                    NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
//                        isMaskShow = overView
//                        return $0
//                    }
//                    #endif
                }
                .onDisappear {
                    onPlayerDisappear?(playerCoordinator.playerLayer)
                }
                .ignoresSafeArea()
            #if os(iOS) || os(xrOS)
                .navigationBarTitleDisplayMode(.inline)
            #else
                .focusable()
                .onMoveCommand { direction in
                    switch direction {
                    case .left:
                        playerCoordinator.skip(interval: -15)
                    case .right:
                        playerCoordinator.skip(interval: 15)
                    #if os(macOS)
                    case .up:
                        playerCoordinator.playerLayer?.player.playbackVolume += 0.2
                    case .down:
                        playerCoordinator.playerLayer?.player.playbackVolume -= 0.2
                    #else
                    case .up:
                        showDropDownMenu = false
                    case .down:
                        showDropDownMenu = true
                    #endif
                    @unknown default:
                        break
                    }
                }
            #endif
            VideoSubtitleView(model: playerCoordinator.subtitleModel)
            VStack {
                Spacer()
                ProgressView()
                    .background(.black.opacity(0.2))
                    .opacity(playerCoordinator.state == .buffering ? 1 : 0)
                VStack {
                    #if !os(tvOS)
                    VideoControllerView(config: playerCoordinator)
                    #endif
                    // 设置opacity为0，还是会去更新View。所以只能这样了
                    if playerCoordinator.isMaskShow {
                        VideoTimeShowView(config: playerCoordinator, model: playerCoordinator.timemodel)
                    }
                }
                .padding()
                .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .opacity(playerCoordinator.isMaskShow ? 1 : 0)
            }
            if showDropDownMenu {
                VideoSettingView(config: playerCoordinator, subtitleModel: playerCoordinator.subtitleModel)
                    .frame(width: KSOptions.sceneSize.width * 3 / 4)
                    .focused($dropdownFocused)
                    .onAppear {
                        dropdownFocused = true
                    }
                #if os(macOS) || os(tvOS)
                    .onExitCommand {
                        showDropDownMenu = false
                    }
                #endif
            }
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
        .tint(.white)
        .persistentSystemOverlays(.hidden)
        .toolbar(playerCoordinator.isMaskShow ? .visible : .hidden, for: .automatic)
        .onKeyPressLeftArrow {
            playerCoordinator.skip(interval: -15)
        }
        .onKeyPressRightArrow {
            playerCoordinator.skip(interval: 15)
        }
        .onKeyPressSapce {
            if playerCoordinator.state.isPlaying {
                playerCoordinator.playerLayer?.pause()
            } else {
                playerCoordinator.playerLayer?.play()
            }
        }

        #if os(macOS)
        .onTapGesture(count: 2) {
            guard let view = playerCoordinator.playerLayer else {
                return
            }
            view.window?.toggleFullScreen(nil)
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        }
        .onExitCommand {
            playerCoordinator.playerLayer?.exitFullScreenMode()
        }
        #endif
        .onTapGesture {
            playerCoordinator.isMaskShow.toggle()
        }
        #if os(tvOS)
        .onPlayPauseCommand {
            if playerCoordinator.state.isPlaying {
                playerCoordinator.playerLayer?.pause()
            } else {
                playerCoordinator.playerLayer?.play()
            }
        }
        .onExitCommand {
            if showDropDownMenu {
                showDropDownMenu = false
            } else if playerCoordinator.isMaskShow {
                playerCoordinator.isMaskShow = false
            } else {
                dismiss()
            }
        }
        #else
        .navigationTitle(title)
            .onHover {
                playerCoordinator.isMaskShow = $0
            }
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
        runInMainqueue {
            if url.isAudio || url.isMovie {
                self.url = url
            } else {
                let info = URLSubtitleInfo(url: url)
                playerCoordinator.subtitleModel.selectedSubtitleInfo = info
            }
        }
    }
}

extension View {
    func onKeyPressLeftArrow(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.leftArrow) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    func onKeyPressRightArrow(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.rightArrow) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    func onKeyPressSapce(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.space) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
struct VideoControllerView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @State
    private var showVideoSetting = false
    public var body: some View {
        HStack {
            Button {
                config.isMuted.toggle()
            } label: {
                Image(systemName: config.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            Button {
                config.isScaleAspectFill.toggle()
            } label: {
                Image(systemName: config.isScaleAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
            }
            #if !os(tvOS) && !os(xrOS)
            if config.playerLayer?.player.allowsExternalPlayback == true {
                AirPlayView().fixedSize()
            }
            #endif
            Spacer()
            Button {
                config.skip(interval: -15)
            } label: {
                Image(systemName: "gobackward.15")
            }
            #if !os(tvOS)
            .keyboardShortcut(.leftArrow, modifiers: .none)
            #endif
            Button {
                if config.state.isPlaying {
                    config.playerLayer?.pause()
                } else {
                    config.playerLayer?.play()
                }
            } label: {
                Image(systemName: config.state == .error ? "play.slash.fill" : (config.state.isPlaying ? "pause.fill" : "play.fill"))
            }
            .padding(.horizontal)
            .font(.system(.largeTitle))
            #if !os(tvOS)
                .keyboardShortcut(.space, modifiers: .none)
            #endif
            Button {
                config.skip(interval: 15)
            } label: {
                Image(systemName: "goforward.15")
            }
            #if !os(tvOS)
            .keyboardShortcut(.rightArrow, modifiers: .none)
            #endif
            Spacer()
            Button {
                config.playerLayer?.isPipActive.toggle()
            } label: {
                Image(systemName: config.playerLayer?.isPipActive ?? false ? "pip.exit" : "pip.enter")
            }
            Button {
                showVideoSetting.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            // iOS 模拟器加keyboardShortcut会导致KSVideoPlayer.Coordinator无法释放。真机不会有这个问题
            #if !os(tvOS)
            .keyboardShortcut("s", modifiers: [.command, .shift])
            #endif
        }
        .font(.system(.title2))
        .sheet(isPresented: $showVideoSetting) {
            VideoSettingView(config: config, subtitleModel: config.subtitleModel)
        }
        #if !os(tvOS)
        .buttonStyle(.borderless)
        #endif
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoTimeShowView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject
    fileprivate var model: ControllerTimeModel
    public var body: some View {
        if config.timemodel.totalTime == 0 {
            Text("Live Streaming")
        } else {
            HStack {
                Text(model.currentTime.toString(for: .minOrHour)).font(.caption2.monospacedDigit())
                Slider(value: Binding {
                    Double(model.currentTime)
                } set: { newValue, _ in
                    model.currentTime = Int(newValue)
                }, in: 0 ... Double(model.totalTime)) { onEditingChanged in
                    if onEditingChanged {
                        config.playerLayer?.pause()
                    } else {
                        config.seek(time: TimeInterval(model.currentTime))
                    }
                }
                .frame(maxHeight: 20)
                Text((model.totalTime).toString(for: .minOrHour)).font(.caption2.monospacedDigit())
            }
            .font(.system(.title2))
        }
    }
}

extension EventModifiers {
    static let none = Self()
}

@available(iOS 16, tvOS 16, macOS 13, *)
struct VideoSubtitleView: View {
    @ObservedObject
    fileprivate var model: SubtitleModel
    var body: some View {
        ZStack {
            ForEach(model.parts) { part in
                part.subtitleView
            }
        }
    }

    fileprivate static func imageView(_ image: UIImage) -> some View {
        #if enableFeatureLiveText && canImport(VisionKit) && !targetEnvironment(simulator)
        if #available(macCatalyst 17.0, *) {
            return LiveTextImage(uiImage: image)
        } else {
            return Image(uiImage: image)
                .resizable()
        }
        #else
        return Image(uiImage: image)
            .resizable()
        #endif
    }
}

fileprivate extension SubtitlePart {
    @available(iOS 16, tvOS 16, macOS 13, *)
    var subtitleView: some View {
        VStack {
            if let image {
                Spacer()
                GeometryReader { geometry in
                    let fitRect = image.fitRect(geometry.size)
                    VideoSubtitleView.imageView(image)
                        .offset(CGSize(width: fitRect.origin.x, height: fitRect.origin.y))
                        .frame(width: fitRect.size.width, height: fitRect.size.height)
                }
                // 不能加scaledToFit。不然的话图片的缩放比率会有问题。
//                .scaledToFit()
                .padding()
            } else if let text {
                let textPosition = textPosition ?? SubtitleModel.textPosition
                if textPosition.verticalAlign == .bottom || textPosition.verticalAlign == .center {
                    Spacer()
                }
                Text(AttributedString(text))
                    .font(Font(SubtitleModel.textFont))
                    .shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                    .foregroundColor(SubtitleModel.textColor)
                    .italic(SubtitleModel.textItalic)
                    .background(SubtitleModel.textBackgroundColor)
                    .multilineTextAlignment(.center)
                    .alignmentGuide(textPosition.horizontalAlign) {
                        $0[.leading]
                    }
                    .padding(textPosition.edgeInsets)
                #if !os(tvOS)
                    .textSelection(.enabled)
                #endif
                if textPosition.verticalAlign == .top || textPosition.verticalAlign == .center {
                    Spacer()
                }
            }
        }
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
struct VideoSettingView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject
    fileprivate var subtitleModel: SubtitleModel
    @State
    fileprivate var subtitleTitle: String
    @Environment(\.dismiss)
    private var dismiss
    init(config: KSVideoPlayer.Coordinator, subtitleModel: SubtitleModel) {
        self.config = config
        self.subtitleModel = subtitleModel
        _subtitleTitle = .init(initialValue: subtitleModel.url?.deletingPathExtension().lastPathComponent ?? "")
    }

    var body: some View {
        PlatformView {
            Picker(selection: $config.playbackRate) {
                ForEach([0.5, 1.0, 1.25, 1.5, 2.0] as [Float]) { value in
                    // 需要有一个变量text。不然会自动帮忙加很多0
                    let text = "\(value) x"
                    Text(text).tag(value)
                }
            } label: {
                Label("Playback Speed", systemImage: "speedometer")
            }

            if let audioTracks = config.playerLayer?.player.tracks(mediaType: .audio), !audioTracks.isEmpty {
                Picker(selection: Binding {
                    audioTracks.first { $0.isEnabled }?.trackID
                } set: { value in
                    if let track = audioTracks.first(where: { $0.trackID == value }) {
                        config.playerLayer?.player.select(track: track)
                    }
                }) {
                    ForEach(audioTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                } label: {
                    Label("Audio track", systemImage: "waveform")
                }
            }
            let videoTracks = config.playerLayer?.player.tracks(mediaType: .video)
            if let videoTracks, !videoTracks.isEmpty {
                Picker(selection: Binding {
                    videoTracks.first { $0.isEnabled }?.trackID
                } set: { value in
                    if let track = videoTracks.first(where: { $0.trackID == value }) {
                        config.playerLayer?.player.select(track: track)
                    }
                }) {
                    ForEach(videoTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                } label: {
                    Label("Video Track", systemImage: "video.fill")
                }
                LabeledContent("Video Type", value: (videoTracks.first { $0.isEnabled }?.dynamicRange ?? .sdr).description)
            }
            Picker(selection: Binding {
                subtitleModel.selectedSubtitleInfo?.subtitleID
            } set: { value in
                subtitleModel.selectedSubtitleInfo = subtitleModel.subtitleInfos.first { $0.subtitleID == value }
            }) {
                Text("Off").tag(nil as String?)
                ForEach(subtitleModel.subtitleInfos, id: \.subtitleID) { track in
                    Text(track.name).tag(track.subtitleID as String?)
                }
            } label: {
                Label("Sutitle", systemImage: "captions.bubble")
            }
            TextField("Sutitle delay", value: $subtitleModel.subtitleDelay, format: .number)
            TextField("Title", text: $subtitleTitle)
            Button("Search Sutitle") {
                subtitleModel.searchSubtitle(query: subtitleTitle, languages: ["zh-cn"])
            }
            LabeledContent("Stream Type", value: (videoTracks?.first { $0.isEnabled }?.fieldOrder ?? .progressive).description)
            if let dynamicInfo = config.playerLayer?.player.dynamicInfo {
                DynamicInfoView(dynamicInfo: dynamicInfo)
            }
            if let fileSize = config.playerLayer?.player.fileSize, fileSize > 0 {
                LabeledContent("File Size", value: fileSize.kmFormatted + "B")
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        .toolbar {
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        #endif
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
public struct DynamicInfoView: View {
    @ObservedObject
    fileprivate var dynamicInfo: DynamicInfo
    public var body: some View {
        LabeledContent("Display FPS", value: dynamicInfo.displayFPS, format: .number)
        LabeledContent("Audio Video sync", value: dynamicInfo.audioVideoSyncDiff, format: .number)
        LabeledContent("Dropped Frames", value: dynamicInfo.droppedVideoFrameCount + dynamicInfo.droppedVideoPacketCount, format: .number)
        LabeledContent("Bytes Read", value: dynamicInfo.bytesRead.kmFormatted + "B")
        LabeledContent("Audio bitrate", value: dynamicInfo.audioBitrate.kmFormatted + "bps")
        LabeledContent("Video bitrate", value: dynamicInfo.videoBitrate.kmFormatted + "bps")
    }
}

@available(iOS 15, tvOS 16, macOS 12, *)
public struct PlatformView<Content: View>: View {
    private let content: () -> Content
    public var body: some View {
        #if os(tvOS)
        ScrollView {
            content()
                .padding()
        }
        .pickerStyle(.navigationLink)
        #else
        Form {
            content()
        }
        #if os(macOS)
        .padding()
        #endif
        #endif
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
        KSVideoPlayerView(url: url, options: KSOptions())
    }
}

// struct AVContentView: View {
//    var body: some View {
//        StructAVPlayerView().frame(width: UIScene.main.bounds.width, height: 400, alignment: .center)
//    }
// }
//
// struct StructAVPlayerView: UIViewRepresentable {
//    let playerVC = AVPlayerViewController()
//    typealias UIViewType = UIView
//    func makeUIView(context _: Context) -> UIView {
//        playerVC.view
//    }
//
//    func updateUIView(_: UIView, context _: Context) {
//        playerVC.player = AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!)
//    }
// }
