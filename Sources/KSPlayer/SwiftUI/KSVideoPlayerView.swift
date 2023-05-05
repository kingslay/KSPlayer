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
    @StateObject public var subtitleModel = SubtitleModel()
    @StateObject public var playerCoordinator = KSVideoPlayer.Coordinator()
    @State public var url: URL
    private let subtitleURLs: [URL]
    public let options: KSOptions
    @State var isMaskShow = true
    @State private var model = ControllerTimeModel()
    @Environment(\.dismiss) private var dismiss
    public init(url: URL, options: KSOptions, subtitleURLs: [URL] = [URL]()) {
        _url = .init(initialValue: url)
        self.options = options
        self.subtitleURLs = subtitleURLs
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
                        if let part = subtitleModel.part, part.end > part.start, !(part == time) {
                            subtitleModel.part = nil
                        }
                    }
                } else {
                    subtitleModel.part = nil
                }
            }
            .onStateChanged { playerLayer, state in
                if state == .readyToPlay {
                    subtitleURLs.forEach { url in
                        subtitleModel.addSubtitle(info: URLSubtitleInfo(url: url))
                    }
                    subtitleModel.selectedSubtitleInfo = subtitleModel.subtitleInfos.first
                    if subtitleModel.selectedSubtitleInfo == nil, let track = playerLayer.player.tracks(mediaType: .subtitle).first, playerLayer.options.autoSelectEmbedSubtitle {
                        subtitleModel.selectedSubtitleInfo = track as? (any SubtitleInfo)
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
            try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil).forEach {
                if $0.isSubtitle {
                    subtitleModel.addSubtitle(info: URLSubtitleInfo(url: url))
                }
            }
            subtitleModel.selectedSubtitleInfo = subtitleModel.subtitleInfos.first
        } else {
            let info = URLSubtitleInfo(url: url)
            subtitleModel.selectedSubtitleInfo = info
            subtitleModel.addSubtitle(info: info)
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
                        Image(systemName: "xmark")
                            .font(.system(.title))
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
                        Image(systemName: "ellipsis.circle").font(.system(.title))
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
    public private(set) var subtitleInfos = [any SubtitleInfo & Hashable]()
    @Published public var selectedSubtitleInfo: (any SubtitleInfo)? {
        didSet {
            oldValue?.disableSubtitle()
            if let selectedSubtitleInfo {
                selectedSubtitleInfo.enableSubtitle {
                    self.selectedSubtitle = try? $0.get()
                }
            } else {
                selectedSubtitle = nil
            }
        }
    }

    @Published public var textFont: Font = .largeTitle
    @Published public var textColor: Color = .white
    @Published public var textPositionFromBottom = 0
    @Published fileprivate var part: SubtitlePart?
    public func addSubtitle(info: any SubtitleInfo) {
        if subtitleInfos.first(where: { $0.subtitleID == info.subtitleID }) == nil {
            subtitleInfos.append(info)
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSubtitleView: View {
    @StateObject fileprivate var model: SubtitleModel
    var body: some View {
        VStack {
            Spacer()
            if let image = model.part?.image {
                GeometryReader { geometry in
                    let fitRect = image.fitRect(geometry.size)
                    if #available(macOS 13.0, iOS 16.0, *) {
                        #if os(tvOS)
                        Image(uiImage: image)
                            .resizable()
                            .offset(CGSize(width: fitRect.origin.x, height: fitRect.origin.y))
                            .frame(width: fitRect.size.width, height: fitRect.size.height)
                        #else
                        LiveTextImage(uiImage: image)
                            .offset(CGSize(width: fitRect.origin.x, height: fitRect.origin.y))
                            .frame(width: fitRect.size.width, height: fitRect.size.height)
                        #endif
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .offset(CGSize(width: fitRect.origin.x, height: fitRect.origin.y))
                            .frame(width: fitRect.size.width, height: fitRect.size.height)
                    }
                }
                .scaledToFit()
                .padding()
            } else if let text = model.part?.text {
                Text(AttributedString(text))
                    .multilineTextAlignment(.center)
                    .font(model.textFont)
                    .foregroundColor(model.textColor).shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                    .padding(.bottom, CGFloat(model.textPositionFromBottom))
                #if !os(tvOS)
                    .textSelection(.enabled)
                #endif
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
        // 要在这里增加内嵌字幕。因为有些内嵌字幕是放在视频流的。所以会比readyToPlay回调晚。
        config.playerLayer?.player.tracks(mediaType: .subtitle).forEach {
            if let info = $0 as? any SubtitleInfo {
                subtitleModel.addSubtitle(info: info)
            }
        }
        let subtitleTracks = subtitleModel.subtitleInfos
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
                    subtitleModel.selectedSubtitleInfo?.subtitleID
                }, set: { value in
                    subtitleModel.selectedSubtitleInfo = subtitleTracks.first { $0.subtitleID == value }
                })) {
                    Text("None").tag(nil as String?)
                    ForEach(subtitleTracks, id: \.subtitleID) { track in
                        Text(track.name).tag(track.subtitleID as String?)
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

@available(iOS 15, tvOS 15, macOS 12, *)
struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
//        let url = URL(fileURLWithPath: Bundle.main.path(forResource: "h264", ofType: "mp4")!)
        let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
        KSVideoPlayerView(url: url, options: KSOptions())
    }
}
