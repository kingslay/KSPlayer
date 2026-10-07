//
//  VideoControllerView.swift
//  KSPlayer
//
//  Created by kintan on 3/18/25.
//

import Foundation
import KSPlayer
import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, *)
struct VideoControllerView: View {
    @ObservedObject
    private var model: KSVideoPlayerModel
    @Environment(\.horizontalSizeClass)
    private var hSizeClass
    @Environment(\.dismiss)
    private var dismiss
    private var playerWidth: CGFloat {
        model.config.playerLayer?.player.view.frame.width ?? 0
    }

    init(model: KSVideoPlayerModel) {
        self.model = model
    }

    var body: some View {
        VStack {
            #if os(tvOS)
            Spacer()
            VStack {
                HStack(spacing: 24) {
                    Text(model.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .frame(minWidth: 100, alignment: .leading)
                        .lineLimit(2)
                        .layoutPriority(100)
                    ProgressView()
                        .opacity([KSPlayerState.initialized, .preparing, .buffering].contains(model.config.state) ? 1 : 0)
                    Spacer()
                        .layoutPriority(2)
                    HStack(spacing: 24) {
                        KSVideoPlayerViewBuilder.preButton(model: model)
                        KSVideoPlayerViewBuilder.playButton(config: model.config)
                        KSVideoPlayerViewBuilder.nextButton(model: model)
                        KSVideoPlayerViewBuilder.muteButton(config: model.config)
                        if let audioTracks = model.config.playerLayer?.player.tracks(mediaType: .audio), !audioTracks.isEmpty {
                            KSVideoPlayerViewBuilder.audioButton(config: model.config, audioTracks: audioTracks)
                        }
                        KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $model.config.playbackRate)
                        KSVideoPlayerViewBuilder.contentModeButton(config: model.config)
                        KSVideoPlayerViewBuilder.recordButton(config: model.config)
                        KSVideoPlayerViewBuilder.pipButton(config: model.config)
                        KSVideoPlayerViewBuilder.subtitleButton(config: model.config)
                        KSVideoPlayerViewBuilder.playListButton(model: model)
                        KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $model.showVideoSetting)
                    }
                }
                .isFocused($model.focusableView, equals: .controller)
                if model.config.isMaskShow {
                    VideoTimeShowView(config: model.config, model: model.config.timemodel, timeFont: .caption2)
                        .isFocused($model.focusableView, equals: .slider)
                }
            }
            .circleGlassButton()
            .padding()
            .background(.black.opacity(0.2))
            .cornerRadius(20)
            #elseif os(macOS)
            Spacer()
            VStack(spacing: 10) {
                HStack {
                    KSVideoPlayerViewBuilder.muteButton(config: model.config)
                    KSVideoPlayerViewBuilder.volumeSlider(config: model.config, volume: $model.config.playbackVolume)
                        .frame(maxWidth: 95)
                    if let audioTracks = model.config.playerLayer?.player.tracks(mediaType: .audio), !audioTracks.isEmpty {
                        KSVideoPlayerViewBuilder.audioButton(config: model.config, audioTracks: audioTracks)
                    }
                    if model.config.playerLayer?.player.allowsExternalPlayback == true {
                        AirPlayView().fixedSize().frame(width: 5)
                    }
                    KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $model.config.playbackRate)
                    Spacer()
                    KSVideoPlayerViewBuilder.preButton(model: model)
                    KSVideoPlayerViewBuilder.backwardButton(config: model.config)
                    KSVideoPlayerViewBuilder.playButton(config: model.config)
                    KSVideoPlayerViewBuilder.forwardButton(config: model.config)
                    KSVideoPlayerViewBuilder.nextButton(model: model)
                    Spacer()
                    KSVideoPlayerViewBuilder.recordButton(config: model.config)
                    KSVideoPlayerViewBuilder.pipButton(config: model.config)
                    KSVideoPlayerViewBuilder.subtitleButton(config: model.config)
                    KSVideoPlayerViewBuilder.playListButton(model: model)
                    KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $model.showVideoSetting)
                }
                .buttonStyle(.borderless)
                // 设置opacity为0，还是会去更新View。所以只能这样了
                if model.config.isMaskShow {
                    VideoTimeShowView(config: model.config, model: model.config.timemodel, timeFont: .caption2)
                }
            }
            .padding()
            .background(.black.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal, playerWidth * 0.15)
            .padding(.vertical, 24)
            #else
            HStack {
                Button {
                    dismiss()
                    #if os(iOS)
                    KSOptions.supportedInterfaceOrientations = nil
                    #endif
                } label: {
                    Image(systemName: "x.circle.fill")
                        .centerControlButtonStyle()
                }
                #if os(visionOS)
                .glassBackgroundEffect()
                #endif
                if let audioTracks = model.config.playerLayer?.player.tracks(mediaType: .audio), !audioTracks.isEmpty {
                    KSVideoPlayerViewBuilder.audioButton(config: model.config, audioTracks: audioTracks)
                    #if os(visionOS)
                    .aspectRatio(1, contentMode: .fit)
                    .glassBackgroundEffect()
                    #endif
                }
                Spacer()
                Text(model.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                #if os(iOS)
                if model.config.playerLayer?.player.allowsExternalPlayback == true {
                    AirPlayView().fixedSize()
                }
                KSVideoPlayerViewBuilder.contentModeButton(config: model.config)
                if model.config.playerLayer?.player.naturalSize.isHorizonal == true {
                    KSVideoPlayerViewBuilder.landscapeButton
                }
                #endif
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
//            .padding(.vertical, 5)
            .background(.black.opacity(0.2))
            Spacer()
            ProgressView()
                .font(.largeTitle)
                .opacity((model.config.state == .buffering || model.config.playerLayer?.player.playbackState == .seeking) ? 1 : 0)
            Spacer()
            #if !os(visionOS)
                VStack {
                    if model.config.isMaskShow {
                        VideoTimeShowView(config: model.config, model: model.config.timemodel, timeFont: .caption2)
                    }
                    if hSizeClass == .compact {
                        HStack(spacing: 18) {
                            KSVideoPlayerViewBuilder.muteButton(config: model.config)
                            KSVideoPlayerViewBuilder.volumeSlider(config: model.config, volume: $model.config.playbackVolume)
                                .frame(maxWidth: 100)
                                .tint(.white.opacity(0.8))
                            KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $model.config.playbackRate)
                            Spacer()
                            KSVideoPlayerViewBuilder.pipButton(config: model.config)
                            KSVideoPlayerViewBuilder.recordButton(config: model.config)
                            KSVideoPlayerViewBuilder.subtitleButton(config: model.config)
                            KSVideoPlayerViewBuilder.playListButton(model: model)
                            KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $model.showVideoSetting)
                        }
                        HStack(spacing: 18) {
                            KSVideoPlayerViewBuilder.preButton(model: model)
                            KSVideoPlayerViewBuilder.backwardButton(config: model.config)
                            KSVideoPlayerViewBuilder.playButton(config: model.config)
                            KSVideoPlayerViewBuilder.forwardButton(config: model.config)
                            KSVideoPlayerViewBuilder.nextButton(model: model)
                        }
                    } else {
                        HStack(spacing: 18) {
                            KSVideoPlayerViewBuilder.muteButton(config: model.config)
                                KSVideoPlayerViewBuilder.volumeSlider(config: model.config, volume: $model.config.playbackVolume)
                                    .frame(maxWidth: 100)
                                    .tint(.white.opacity(0.8))
                            KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $model.config.playbackRate)
                            Spacer()
                            KSVideoPlayerViewBuilder.preButton(model: model)
                            KSVideoPlayerViewBuilder.backwardButton(config: model.config)
                            KSVideoPlayerViewBuilder.playButton(config: model.config)
                            KSVideoPlayerViewBuilder.forwardButton(config: model.config)
                            KSVideoPlayerViewBuilder.nextButton(model: model)
                            Spacer()
                            KSVideoPlayerViewBuilder.pipButton(config: model.config)
                            KSVideoPlayerViewBuilder.recordButton(config: model.config)
                            KSVideoPlayerViewBuilder.subtitleButton(config: model.config)
                            KSVideoPlayerViewBuilder.playListButton(model: model)
                            KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $model.showVideoSetting)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.2))
            #endif
            #endif
        }
        .tint(.white)
        .sheet(isPresented: $model.showVideoSetting) {
            VideoSettingView(model: model)
        }
        #if os(visionOS)
        .ornament(visibility: model.config.isMaskShow ? .visible : .hidden, attachmentAnchor: .scene(.bottom)) {
            VStack(alignment: .leading) {
                HStack {
                    Text(model.title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .frame(minWidth: 100, alignment: .leading)
                    ProgressView()
                        .opacity((model.config.state == .buffering || model.config.playerLayer?.player.playbackState == .seeking) ? 1 : 0)
                }
                HStack(spacing: 16) {
                    KSVideoPlayerViewBuilder.backwardButton(config: model.config)
                    KSVideoPlayerViewBuilder.playButton(config: model.config)
                    KSVideoPlayerViewBuilder.forwardButton(config: model.config)
                    VideoTimeShowView(config: model.config, model: model.config.timemodel, timeFont: .title3)
                    KSVideoPlayerViewBuilder.contentModeButton(config: model.config)
                    KSVideoPlayerViewBuilder.subtitleButton(config: model.config)
                    KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $model.config.playbackRate)
                    KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $model.showVideoSetting)
                }
            }
            .frame(minWidth: playerWidth / 1.5)
            .buttonStyle(.plain)
            .padding(.vertical, 24)
            .padding(.horizontal, 36)
            .glassBackgroundEffect()
        }
        #endif
        // macOS要写在这里才能隐藏，写在外面无法隐藏
        .opacity(model.config.isMaskShow ? 1 : 0)
    }
}

@available(iOS 15, macOS 12, tvOS 15, *)
struct VideoTimeShowView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject
    fileprivate var model: ControllerTimeModel
    fileprivate var timeFont: Font
    var body: some View {
        if let playerLayer = config.playerLayer, playerLayer.player.seekable {
            HStack {
                Text(model.currentTime.toString(for: .minOrHour))
                PlayerSlider(model: model) { [weak model, weak playerLayer] onEditingChanged in
                    guard let model, let playerLayer else { return }
                    if let onEditingChanged {
                        if onEditingChanged {
                            playerLayer.pause()
                        } else {
                            playerLayer.preview(time: nil)
                            playerLayer.seek(time: TimeInterval(model.currentTime))
                        }
                    } else {
                        playerLayer.preview(time: TimeInterval(model.currentTime))
                    }
                }
                .frame(maxHeight: 20)
                #if os(visionOS)
                .tint(.white.opacity(0.8))
                #endif
                Text((model.totalTime).toString(for: .minOrHour))
            }
            .font(timeFont.monospacedDigit())
        } else {
            Text(String(localized: "Live Streaming", bundle: .module))
        }
    }
}

@available(iOS 16, macOS 13, tvOS 16, *)
struct VideoSettingView: View {
    @ObservedObject
    var model: KSVideoPlayerModel
    @Environment(\.dismiss)
    private var dismiss
    @State
    private var selectedTab: String = "Subtitle"
    var body: some View {
        PlatformView {
            Picker("", selection: $selectedTab) {
                ForEach(["Subtitle", "Video", "Audio", "Info"] + model.extensionInfos.keys, id: \.self) { tab in
                    Text(tab).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            if let playerLayer = model.config.playerLayer {
                switch selectedTab {
                case "Video":
                    VideoView(model: model, playerLayer: playerLayer)
                case "Subtitle":
                    SubtitleView(model: model, playerLayer: playerLayer)
                case "Audio":
                    AudioView(model: model, playerLayer: playerLayer)
                case "Info":
                    InfoView(playerLayer: playerLayer)
                default:
                    #if os(tvOS)
                    ForEach((model.extensionInfos[selectedTab] ?? "").split(separator: "\n\n"), id: \.self) {
                        Text($0 + "\n\n")
                        .focusable()
                    }
                    #else
                    Text(model.extensionInfos[selectedTab] ?? "")
                    #endif
                }
            } else {
                Text(String(localized: "Loading...", bundle: .module))
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst) || os(visionOS)
        .toolbar {
            Button(String(localized: "Done", bundle: .module)) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        #endif
    }

    private struct VideoView: View {
        let model: KSVideoPlayerModel
        let playerLayer: KSPlayerLayer
        @State
        private var colorspace: CFString? = nil
        @State
        private var videoDelay: Double = 0.0 {
            didSet {
                playerLayer.options.videoDelay = videoDelay
            }
        }

        @State
        private var brightness: Float = 1 {
            didSet {
                playerLayer.options.brightness = brightness
            }
        }

        @State
        private var contrast: Float = 1 {
            didSet {
                playerLayer.options.contrast = contrast
            }
        }

        @State
        private var saturation: Float = 1 {
            didSet {
                playerLayer.options.saturation = saturation
            }
        }

        var body: some View {
            if let playList = playerLayer.player.ioContext as? PlayList {
                let list = playList.playlists.filter { $0.duration > 60 * 2 }
                if list.count > 1 {
                    Picker(selection: Binding {
                        playList.currentStream?.name
                    } set: { value in
                        if let value, var components = playerLayer.url.components {
                            if components.scheme == "BDMVIOContext", var queryItems = components.queryItems, let index = queryItems.firstIndex(where: { $0.name == "streamName" }) {
                                queryItems[index].value = value
                                components.queryItems = queryItems
                                model.url = components.url
                            } else if var newURL = URL(string: "BDMVIOContext://") {
                                newURL.append(queryItems: [URLQueryItem(name: "streamName", value: value), URLQueryItem(name: "url", value: playerLayer.url.description)])
                                model.url = newURL
                            }
                        }
                    }) {
                        ForEach(list, id: \.name) { stream in
                            Text(stream.name + " duration=\(Int(stream.duration).toString(for: .minOrHour))").tag(stream.name as String?)
                        }
                    } label: {
                        Label(String(localized: "Stream Name", bundle: .module), systemImage: "video.fill")
                    }
                }
            }
            let videoTracks = playerLayer.player.tracks(mediaType: .video)
            if !videoTracks.isEmpty {
                LabeledContent(String(localized: "Video Type", bundle: .module), value: playerLayer.options.dynamicRange.description)
                LabeledContent(String(localized: "Stream Type", bundle: .module), value: (videoTracks.first { $0.isEnabled }?.fieldOrder ?? .progressive).description)
                LabeledContent(String(localized: "Decode Type", bundle: .module), value: playerLayer.options.videoDecodeType.rawValue)
                Picker(selection: Binding {
                    videoTracks.first { $0.isEnabled }?.trackID
                } set: { value in
                    if let track = videoTracks.first(where: { $0.trackID == value }) {
                        playerLayer.player.select(track: track)
                    }
                }) {
                    ForEach(videoTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                } label: {
                    Label(String(localized: "Video Track", bundle: .module), systemImage: "video.fill")
                }
                Picker(String(localized: "Color Space", bundle: .module), selection: $colorspace) {
                    let colorspaces = [
                        CGColorSpace.itur_2100_PQ,
                        CGColorSpace.itur_2100_HLG,
                        CGColorSpace.itur_2020,
                        CGColorSpace.itur_709_PQ,
                        CGColorSpace.itur_709_HLG,
                        CGColorSpace.itur_709,
                        CGColorSpace.sRGB,
                    ]
                    Text("nil").tag(nil as CFString?)
                    ForEach(colorspaces) { colorspace in
                        Text(colorspace as String).tag(colorspace as CFString?)
                    }
                }
                Picker(String(localized: "Video Display Type", bundle: .module), selection: Binding {
                    if playerLayer.options.display === KSOptions.displayEnumVR {
                        return "VR"
                    } else if playerLayer.options.display === KSOptions.displayEnumVRBox {
                        return "VRBox"
                    } else {
                        return "Plane"
                    }
                } set: { value in
                    if value == "VR" {
                        playerLayer.options.display = KSOptions.displayEnumVR
                    } else if value == "VRBox" {
                        playerLayer.options.display = KSOptions.displayEnumVRBox
                    } else {
                        playerLayer.options.display = KSOptions.displayEnumPlane
                    }
                }) {
                    Text("Plane").tag("Plane")
                    Text("VR").tag("VR")
                    Text("VRBox").tag("VRBox")
                }
                HStack {
                    Text(String(localized: "Video delay", bundle: .module))
                    Spacer()
                    Button {
                        videoDelay -= 0.5
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    Text(String(format: "%.1fs", videoDelay))
                        .monospacedDigit()
                        .frame(minWidth: 60)
                    Button {
                        videoDelay += 0.5
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Text(String(localized: "Brightness", bundle: .module))
                    Spacer()
                    Button {
                        brightness -= 0.1
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    Text(String(format: "%.1f", brightness))
                        .monospacedDigit()
                        .frame(minWidth: 60)
                    Button {
                        brightness += 0.1
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Text(String(localized: "Contrast", bundle: .module))
                    Spacer()
                    Button {
                        contrast -= 0.1
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    Text(String(format: "%.1f", contrast))
                        .monospacedDigit()
                        .frame(minWidth: 60)
                    Button {
                        contrast += 0.1
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Text(String(localized: "Saturation", bundle: .module))
                    Spacer()
                    Button {
                        saturation -= 0.1
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    Text(String(format: "%.1f", saturation))
                        .monospacedDigit()
                        .frame(minWidth: 60)
                    Button {
                        saturation += 0.1
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                .onAppear {
                    videoDelay = playerLayer.options.videoDelay
                    brightness = playerLayer.options.brightness
                    saturation = playerLayer.options.saturation
                    contrast = playerLayer.options.contrast
                    colorspace = playerLayer.options.colorspace?.name
                }
                .onChange(of: colorspace) { colorspace in
                    if let colorspace {
                        playerLayer.options.colorspace = CGColorSpace(name: colorspace)
                    } else {
                        playerLayer.options.colorspace = nil
                    }
                }
            }
        }
    }

    private struct SubtitleView: View {
        @ObservedObject
        var model: KSVideoPlayerModel
        let playerLayer: KSPlayerLayer
        @State
        private var subtitleFileImport = false
        @State
        private var subtitleDelay: Double = 0.0 {
            didSet {
                playerLayer.subtitleModel.subtitleDelay = subtitleDelay
            }
        }

        @State
        private var verticalMargin: CGFloat = KSOptions.textPosition.verticalMargin {
            didSet {
                KSOptions.textPosition.verticalMargin = verticalMargin
            }
        }

        @State
        private var verticalAlign: VerticalAlignment = KSOptions.textPosition.verticalAlign {
            didSet {
                KSOptions.textPosition.verticalAlign = verticalAlign
            }
        }

        @Environment(\.dismiss)
        private var dismiss
        var body: some View {
            #if os(iOS) || os(macOS)
            Toggle(String(localized: "translation", bundle: .module), isOn: Binding {
                playerLayer.subtitleModel.translation
            } set: { value in
                dismiss()
                playerLayer.subtitleModel.translation = value
            })
            #endif
            HStack {
                Text(String(localized: "Subtitle delay", bundle: .module))
                Spacer()
                Button {
                    subtitleDelay -= 0.5
                    playerLayer.subtitleModel.subtitleDelay = subtitleDelay
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.bordered)
                Text(String(format: "%.1fs", subtitleDelay))
                    .monospacedDigit()
                    .frame(minWidth: 60)
                Button {
                    subtitleDelay += 0.5
                    playerLayer.subtitleModel.subtitleDelay = subtitleDelay
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.bordered)
            }
            .onAppear {
                subtitleDelay = playerLayer.subtitleModel.subtitleDelay
            }
            HStack {
                Text(String(localized: "Subtitle Position", bundle: .module))
                Spacer()
                Button {
                    verticalMargin -= 5
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                Text(String(format: "%.0fpt", verticalMargin))
                    .monospacedDigit()
                    .frame(minWidth: 60)
                Button {
                    verticalMargin += 5
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.bordered)
            }
            Picker(selection: Binding {
                verticalAlign
            } set: { value in
                verticalAlign = value
            }) {
                Text(String(localized: "Top", bundle: .module)).tag(VerticalAlignment.top)
                Text(String(localized: "Center", bundle: .module)).tag(VerticalAlignment.center)
                Text(String(localized: "Bottom", bundle: .module)).tag(VerticalAlignment.bottom)
            } label: {
                Label(String(localized: "Subtitle Alignment", bundle: .module), systemImage: "arrow.up.and.down.text.horizontal")
            }
            Picker(selection: Binding {
                playerLayer.subtitleModel.selectedSubtitleInfo?.subtitleID
            } set: { value in
                let info = playerLayer.subtitleModel.subtitleInfos.first { $0.subtitleID == value }
                playerLayer.select(subtitleInfo: info, isSecondary: false)
            }) {
                Text("Off").tag(nil as String?)
                ForEach(playerLayer.subtitleModel.subtitleInfos, id: \.subtitleID) { track in
                    Text(track.name).tag(track.subtitleID as String?)
                }
            } label: {
                Label(String(localized: "Main Subtitle", bundle: .module), systemImage: "text.bubble")
            }
            Picker(selection: Binding {
                playerLayer.subtitleModel.secondarySubtitleInfo?.subtitleID
            } set: { value in
                let info = playerLayer.subtitleModel.subtitleInfos.first { $0.subtitleID == value }
                playerLayer.select(subtitleInfo: info, isSecondary: true)
            }) {
                Text("Off").tag(nil as String?)
                ForEach(playerLayer.subtitleModel.subtitleInfos, id: \.subtitleID) { track in
                    Text(track.name).tag(track.subtitleID as String?)
                }
            } label: {
                Label(String(localized: "Secondary Subtitle", bundle: .module), systemImage: "text.bubble")
            }
            ShowTextField(String(localized: "Subtitle Title", bundle: .module), text: $model.title)
            Button(String(localized: "Search Subtitle", bundle: .module)) {
                playerLayer.subtitleModel.searchSubtitle(query: model.title, languages: [Locale.current.identifier])
            }
            .buttonStyle(.bordered)
            #if !os(tvOS)
            Button(String(localized: "Add External Subtitle", bundle: .module)) {
                subtitleFileImport = true
            }
            .buttonStyle(.bordered)
            .fileImporter(isPresented: $subtitleFileImport, allowedContentTypes: [.data]) { result in
                guard let url = try? result.get(), url.startAccessingSecurityScopedResource() else {
                    return
                }
                if url.isSubtitle {
                    let info = URLSubtitleInfo(url: url)
                    model.config.playerLayer?.select(subtitleInfo: info)
                }
            }
            #endif
        }
    }

    private struct AudioView: View {
        @ObservedObject
        var model: KSVideoPlayerModel
        let playerLayer: KSPlayerLayer
        var body: some View {
            let audioTracks = playerLayer.player.tracks(mediaType: .audio)
            if !audioTracks.isEmpty {
                Picker(selection: Binding {
                    audioTracks.first { $0.isEnabled }?.trackID
                } set: { value in
                    if let track = audioTracks.first(where: { $0.trackID == value }) {
                        playerLayer.player.select(track: track)
                    }
                }) {
                    ForEach(audioTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                } label: {
                    Label(String(localized: "Audio Track", bundle: .module), systemImage: "waveform")
                }
            }
            Picker(selection: $model.config.playbackRate) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 8.0] as [Float]) { value in
                    // 需要有一个变量text。不然会自动帮忙加很多0
                    let text = "\(value) x"
                    Text(text).tag(value)
                }
            } label: {
                Label(String(localized: "Playback Rate", bundle: .module), systemImage: "gauge.with.dots.needle.67percent")
            }
        }
    }

    private struct InfoView: View {
        let playerLayer: KSPlayerLayer
        var body: some View {
            DynamicInfoView(dynamicInfo: playerLayer.player.dynamicInfo)
            let fileSize = playerLayer.player.fileSize
            if fileSize > 0 {
                LabeledContent(String(localized: "File Size", bundle: .module), value: fileSize.kmFormatted + "B")
            }
            LabeledContent(String(localized: "Time Log", bundle: .module), value: playerLayer.options.timeLog.description)
#if os(tvOS)
                .focusable()
#endif
        }
    }
}

@available(iOS 16, macOS 13, tvOS 16, *)
public struct DynamicInfoView: View {
    @ObservedObject
    fileprivate var dynamicInfo: DynamicInfo
    public var body: some View {
        LabeledContent(String(localized: "Display FPS", bundle: .module), value: dynamicInfo.displayFPS, format: .number)
        LabeledContent(String(localized: "Audio Video sync", bundle: .module), value: dynamicInfo.audioVideoSyncDiff, format: .number)
        LabeledContent(String(localized: "Dropped Frames", bundle: .module), value: dynamicInfo.droppedVideoFrameCount + dynamicInfo.droppedVideoPacketCount, format: .number)
        LabeledContent(String(localized: "Bytes Read", bundle: .module), value: dynamicInfo.bytesRead.kmFormatted + "B")
        LabeledContent(String(localized: "Audio bitrate", bundle: .module), value: dynamicInfo.audioBitrate.kmFormatted + "bps")
        LabeledContent(String(localized: "Video bitrate", bundle: .module), value: dynamicInfo.videoBitrate.kmFormatted + "bps")
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct HUDLogView: View {
    @ObservedObject
    public var dynamicInfo: DynamicInfo
    public var body: some View {
        Text(dynamicInfo.hudLogText)
            .foregroundColor(Color.orange)
            .multilineTextAlignment(.leading)
            .padding()
    }
}

private extension DynamicInfo {
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    var hudLogText: String {
        var log = String(localized: "Display FPS", bundle: .module) + ": \(displayFPS)\n"
            + String(localized: "Dropped Frames", bundle: .module) + ": \(droppedVideoFrameCount)\n"
            + String(localized: "Audio Video sync", bundle: .module) + ": \(audioVideoSyncDiff)\n"
            + String(localized: "Network Speed", bundle: .module) + ": \(networkSpeed.kmFormatted)B/s\n"
        #if DEBUG
//        log += String(localized: "Average Audio Video sync", bundle: .module) + ": \(averageAudioVideoSyncDiff)\n"
        #endif
        return log
    }
}

extension CFString: @retroactive Identifiable {}
