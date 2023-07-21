//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct KSVideoPlayerView: View {
    private let subtitleDataSouce: SubtitleDataSouce?
    private let onPlayerDisappear: ((KSPlayerLayer?) -> Void)?
    @State private var delayItem: DispatchWorkItem?
    @State private var overView = false
    @StateObject private var playerCoordinator = KSVideoPlayer.Coordinator()
    @Environment(\.dismiss) private var dismiss
    public let options: KSOptions
    @State public var url: URL {
        didSet {
            #if os(macOS)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            #endif
        }
    }

    @State var isMaskShow = true {
        didSet {
            if isMaskShow != oldValue {
                if isMaskShow {
                    delayItem?.cancel()
                    // 播放的时候才自动隐藏
                    guard playerCoordinator.state == .bufferFinished else { return }
                    delayItem = DispatchWorkItem {
                        isMaskShow = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + KSOptions.animateDelayTimeInterval,
                                                  execute: delayItem!)
                }
                #if os(macOS)
                isMaskShow ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
                if let window = playerCoordinator.playerLayer?.player.view?.window {
                    window.standardWindowButton(.zoomButton)?.isHidden = !isMaskShow
                    window.standardWindowButton(.closeButton)?.isHidden = !isMaskShow
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = !isMaskShow
//                    window.standardWindowButton(.closeButton)?.superview?.isHidden = !isMaskShow
                }
                #endif
            }
        }
    }

    public init(url: URL, options: KSOptions, subtitleDataSouce: SubtitleDataSouce? = nil, onPlayerDisappear: ((KSPlayerLayer?) -> Void)? = nil) {
        _url = .init(initialValue: url)
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
                .onStateChanged { _, state in
                    if state == .bufferFinished {
                        isMaskShow = false
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
            #if !os(tvOS) && !os(macOS)
                .onTapGesture {
                isMaskShow.toggle()
            }
            #endif
            .onAppear {
                if let subtitleDataSouce {
                    playerCoordinator.subtitleModel.addSubtitle(dataSouce: subtitleDataSouce)
                }
                #if os(macOS)
                NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
                    isMaskShow = overView
                    return $0
                }
                #endif
            }
            .onDisappear {
                delayItem?.cancel()
                onPlayerDisappear?(playerCoordinator.playerLayer)
                if let playerLayer = playerCoordinator.playerLayer {
                    if !playerLayer.isPipActive {
                        playerCoordinator.resetPlayer()
                    }
                }
            }
            .ignoresSafeArea()
            VideoSubtitleView(model: playerCoordinator.subtitleModel)
            VStack {
                Spacer()
                VStack {
                    VideoControllerView(config: playerCoordinator)
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
                    // 设置opacity为0，还是会去更新View。所以只能这样了
                    if isMaskShow {
                        VideoTimeShowView(config: playerCoordinator, model: playerCoordinator.timemodel)
                    }
                }
                .padding()
                .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .opacity(isMaskShow ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
        .foregroundColor(.white)
        .persistentSystemOverlays(.hidden)
        .toolbar(isMaskShow ? .visible : .hidden, for: .automatic)
        #if os(macOS)
            .navigationTitle(url.lastPathComponent)
            .onTapGesture(count: 2) {
                guard let view = playerCoordinator.playerLayer?.player.view else {
                    return
                }
                view.window?.toggleFullScreen(nil)
                view.needsLayout = true
                view.layoutSubtreeIfNeeded()
            }
            .onExitCommand {
                playerCoordinator.playerLayer?.player.view?.exitFullScreenMode()
            }
        #else
        #endif
        #if !os(tvOS)
        .onHover {
            overView = $0
            isMaskShow = overView
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

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoControllerView: View {
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
    public var body: some View {
        HStack {
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
                ProgressView().opacity(config.state == .buffering ? 1 : 0)
            }
            .font(.system(.title2))
            Spacer()
            HStack {
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
            }
            .font(.system(.largeTitle))
            Spacer()
            HStack {
                Button {
                    config.playerLayer?.isPipActive.toggle()
                } label: {
                    Image(systemName: config.playerLayer?.isPipActive ?? false ? "pip.exit" : "pip.enter")
                }
                #if os(tvOS)
                Image(systemName: "ellipsis.circle")
                    .contextMenu {
                        VideoSettingView(config: config, subtitleModel: config.subtitleModel)
                    }
                #else
                Menu {
                    VideoSettingView(config: config, subtitleModel: config.subtitleModel)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .pickerStyle(.menu)
                .menuIndicator(.hidden)
                #endif
            }
            .font(.system(.title2))
        }
        #if os(tvOS)
//            .focusSection()
        .onPlayPauseCommand {
            if config.state.isPlaying {
                config.playerLayer?.pause()
            } else {
                config.playerLayer?.play()
            }
        }
        #else
        .buttonStyle(.borderless)
        #endif
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoTimeShowView: View {
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject fileprivate var model: ControllerTimeModel
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
        }
    }
}

extension EventModifiers {
    static let none = Self()
}

@available(iOS 16, tvOS 16, macOS 13, *)
struct VideoSubtitleView: View {
    @ObservedObject fileprivate var model: SubtitleModel
    var body: some View {
        VStack {
            if let image = model.part?.image {
                Spacer()
                GeometryReader { geometry in
                    let fitRect = image.fitRect(geometry.size)
                    imageView(image)
                        .offset(CGSize(width: fitRect.origin.x, height: fitRect.origin.y))
                        .frame(width: fitRect.size.width, height: fitRect.size.height)
                }
                // 不能加scaledToFit。不然的话图片的缩放比率会有问题。
//                .scaledToFit()
                .padding()
            }
            if let text = model.part?.text {
                if SubtitleModel.textYAlign == .bottom {
                    Spacer()
                }
                Text(AttributedString(text))
                    .font(Font(SubtitleModel.textFont))
                    .shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                    .foregroundColor(SubtitleModel.textColor)
                    .background(SubtitleModel.textBackgroundColor)
                    .multilineTextAlignment(SubtitleModel.textXAlign)
                    .padding(SubtitleModel.edgeInsets)
                    .italic(SubtitleModel.textItalic)
                #if !os(tvOS)
                    .textSelection(.enabled)
                #endif
                if SubtitleModel.textYAlign == .top {
                    Spacer()
                }
            }
        }
    }

    private func imageView(_ image: UIImage) -> some View {
        #if os(tvOS)
        return Image(uiImage: image)
            .resizable()
        #else
        return LiveTextImage(uiImage: image)
        #endif
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSettingView: View {
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject fileprivate var subtitleModel: SubtitleModel
    var body: some View {
        Picker(selection: $config.playbackRate) {
            ForEach([0.5, 1.0, 1.25, 1.5, 2.0] as [Float]) { value in
                // 需要有一个变量text。不然会自动帮忙加很多0
                let text = "\(value) x"
                Text(text).tag(value)
            }
        } label: {
            Label("Playback Speed", systemImage: "speedometer")
        }
        if config.audioTracks.count > 0 {
            Picker(selection: Binding {
                config.selectedAudioTrack?.trackID
            } set: { value in
                config.selectedAudioTrack = config.audioTracks.first { $0.trackID == value }
            }) {
                ForEach(config.audioTracks, id: \.trackID) { track in
                    Text(track.description).tag(track.trackID as Int32?)
                }
            } label: {
                Label("Audio track", systemImage: "waveform")
            }
        }
        if config.videoTracks.count > 0 {
            Picker(selection: Binding {
                config.selectedVideoTrack?.trackID
            } set: { value in
                config.selectedVideoTrack = config.videoTracks.first { $0.trackID == value }
            }) {
                ForEach(config.videoTracks, id: \.trackID) { track in
                    Text(track.description).tag(track.trackID as Int32?)
                }
            } label: {
                Label("Video track", systemImage: "video.fill")
            }
        }
        if config.subtitleModel.subtitleInfos.count > 0 {
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
        }
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
