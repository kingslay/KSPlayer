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
    private let subtitleDataSouce: SubtitleDataSouce?
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
            #if os(macOS)
            isMaskShow ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
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
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
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
                NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseMoved]) {
                    isMaskShow = true
                    return $0
                }
                NSEvent.addLocalMonitorForEvents(matching: [.mouseExited]) {
                    isMaskShow = false
                    return $0
                }
                #endif
            }
            .onDisappear {
                if let playerLayer = playerCoordinator.playerLayer {
                    let key = "playtime_\(url)"
                    if playerLayer.player.duration > 0, playerLayer.player.currentPlaybackTime > 0, playerLayer.state != .playedToTheEnd {
                        UserDefaults.standard.set(playerLayer.player.currentPlaybackTime, forKey: key)
                    } else {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    if !playerLayer.isPipActive {
                        playerLayer.pause()
                        playerCoordinator.playerLayer = nil
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
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
        .foregroundColor(.white)
        #if os(macOS)
            .navigationTitle(url.lastPathComponent)
            .onTapGesture(count: 2) {
                NSApplication.shared.keyWindow?.toggleFullScreen(self)
            }
        #else
//            .navigationBarHidden(true)
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
                playerCoordinator.subtitleModel.selectedSubtitleInfo = info
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
                ProgressView().opacity(config.isLoading ? 1 : 0)
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
                    config.isPlay.toggle()
                } label: {
                    Image(systemName: config.isPlay ? "pause.fill" : "play.fill")
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
                .pickerStyle(.menu)
                .menuIndicator(.hidden)
                .frame(width: 40)
                #endif
            }
            .font(.system(.title2))
        }
        #if os(tvOS)
//            .focusSection()
        .onPlayPauseCommand {
            config.isPlay.toggle()
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
                        config.isPlay = false
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

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSubtitleView: View {
    @ObservedObject fileprivate var model: SubtitleModel
    var body: some View {
        VStack {
            if let image = model.part?.image {
                Spacer()
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
                #if !os(tvOS)
                    .textSelection(.enabled)
                #endif
//                    .italic(SubtitleModel.textItalic)
                if SubtitleModel.textYAlign == .top {
                    Spacer()
                }
            }
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoSettingView: View {
    @ObservedObject fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject fileprivate var subtitleModel: SubtitleModel
    var body: some View {
        Picker(selection: Binding {
            config.playerLayer?.player.playbackRate ?? 1.0
        } set: { value in
            config.playerLayer?.player.playbackRate = value
        }) {
            ForEach([Float(0.5), 1.0, 1.25, 1.5, 2.0], id: \.self) { value in
                Text(String(format: "%.2fx", value)).tag(value)
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

@available(iOS 15, tvOS 15, macOS 12, *)
struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
        KSVideoPlayerView(url: url, options: KSOptions())
    }
}
