//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import SwiftUI

public class KSVideoViewModel: ObservableObject {
    fileprivate var timemodel = ControllerTimeModel()
    public var playerCoordinator = KSVideoPlayer.Coordinator()
}

@available(iOS 15, tvOS 15, macOS 12, *)
public struct KSVideoPlayerView: View {
    private let subtitleDataSouce: SubtitleDataSouce?
    public let options: KSOptions
    @Environment(\.dismiss) private var dismiss
    @State var isMaskShow = true {
        didSet {
            #if os(macOS)
            isMaskShow ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
            #endif
        }
    }

    @StateObject private var viewModel = KSVideoViewModel()
    @State public var url: URL {
        didSet {
            #if os(macOS)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            #endif
        }
    }

    public init(url: URL, options: KSOptions, subtitleDataSouce: SubtitleDataSouce? = nil) {
        _url = .init(initialValue: url)
        #if os(macOS)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        #endif
        self.options = options
        let key = "playtime_\(url)"
        options.startPlayTime = UserDefaults.standard.double(forKey: key)
        self.subtitleDataSouce = subtitleDataSouce
    }

    public var body: some View {
        ZStack {
            KSVideoPlayer(coordinator: viewModel.playerCoordinator, url: url, options: options).onPlay { current, total in
                viewModel.timemodel.currentTime = Int(current)
                viewModel.timemodel.totalTime = Int(max(max(0, total), current))
            }
            .onStateChanged { playerLayer, state in
                if state == .bufferFinished {
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
            }
            #endif
            .onAppear {
                if let subtitleDataSouce {
                    viewModel.playerCoordinator.subtitleModel.addSubtitle(dataSouce: subtitleDataSouce)
                }
            }
            .onDisappear {
                if let playerLayer = viewModel.playerCoordinator.playerLayer {
                    let key = "playtime_\(url)"
                    if playerLayer.player.duration > 0, playerLayer.player.currentPlaybackTime > 0, playerLayer.state != .playedToTheEnd {
                        UserDefaults.standard.set(playerLayer.player.currentPlaybackTime, forKey: key)
                    } else {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    if !playerLayer.isPipActive {
                        playerLayer.pause()
                        viewModel.playerCoordinator.playerLayer = nil
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            VideoSubtitleView(model: viewModel.playerCoordinator.subtitleModel)
            VideoControllerView(config: viewModel.playerCoordinator)
            #if !os(iOS)
                .onMoveCommand { direction in
                    isMaskShow = true
                    #if os(macOS)
                    switch direction {
                    case .left:
                        viewModel.playerCoordinator.skip(interval: -15)
                    case .right:
                        viewModel.playerCoordinator.skip(interval: 15)
                    case .up:
                        viewModel.playerCoordinator.playerLayer?.player.playbackVolume += 1
                    case .down:
                        viewModel.playerCoordinator.playerLayer?.player.playbackVolume -= 1
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
                VideoTimeShowView(config: viewModel.playerCoordinator, model: viewModel.timemodel)
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
        runInMainqueue {
            if url.isAudio || url.isMovie {
                self.url = url
            } else {
                let info = URLSubtitleInfo(url: url)
                viewModel.playerCoordinator.subtitleModel.selectedSubtitleInfo = info
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
class ControllerTimeModel: ObservableObject {
    // 改成int才不会频繁更新
    @Published
    var currentTime = 0
    @Published
    var totalTime = 1
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoControllerView: View {
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
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
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject fileprivate var model: ControllerTimeModel
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

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSubtitleView: View {
    @ObservedObject fileprivate var model: SubtitleModel
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
            }
            if let text = model.part?.text {
                Text(AttributedString(text))
                    .multilineTextAlignment(.center)
                    .font(Font(model.textFont))
                    .foregroundColor(Color(model.textColor)).shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                    .background(Color(model.textBackgroundColor))
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
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
    var body: some View {
        config.selectedAudioTrack = (config.playerLayer?.player.isMuted ?? false) ? nil : config.audioTracks.first { $0.isEnabled }
        config.selectedVideoTrack = config.videoTracks.first { $0.isEnabled }
        let subtitleTracks = config.subtitleModel.subtitleInfos
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
                    config.subtitleModel.selectedSubtitleInfo?.subtitleID
                }, set: { value in
                    config.subtitleModel.selectedSubtitleInfo = subtitleTracks.first { $0.subtitleID == value }
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
                Picker("subtitle text color", selection: $config.subtitleModel.textColor) {
                    ForEach([UIColor.white, .red, .orange], id: \.self) { color in
                        Text("text color").foregroundColor(Color(color)).background(Color(config.subtitleModel.textBackgroundColor)).tag(color)
                    }
                }
                Picker("subtitle text color", selection: $config.subtitleModel.textBackgroundColor) {
                    ForEach([UIColor.clear, .black, .gray], id: \.self) { color in
                        Text("text background color").foregroundColor(Color(config.subtitleModel.textColor)).background(Color(color)).tag(color)
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
