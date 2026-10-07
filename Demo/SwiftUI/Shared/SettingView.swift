//
//  SettingView.swift
//  TracyPlayer
//
//  Created by kintan on 2023/6/21.
//

import AVFoundation
import KSPlayer
import KSPlayerUI
import Libavdevice
import MPVPlayer
import SwiftUI

struct SettingView: View {
    var body: some View {
        List {
            NavigationLink(destination: SettingGeneralView()) {
                Label(localized("General"), systemImage: "switch.2")
            }
            NavigationLink(destination: SettingAudioView()) {
                Label(localized("Audio"), systemImage: "waveform")
            }
            NavigationLink(destination: SettingVideoView()) {
                Label(localized("Video"), systemImage: "play.rectangle.fill")
            }
            NavigationLink(destination: SettingSubtitleView()) {
                Label(localized("Subtitle"), systemImage: "captions.bubble")
            }
            NavigationLink(destination: SettingAdvancedView()) {
                Label(localized("Advanced"), systemImage: "gearshape.2.fill")
            }
            if let recordDir = KSOptions.recordDir, FileManager.default.fileExists(atPath: recordDir.path) {
                NavigationLink(value: recordDir) {
                    Label(localized("Record Video"), systemImage: "video.circle")
                }
            }
            #if os(visionOS)
            .padding()
            #endif
        }
        .navigationDestination(for: URL.self) { url in
            if url == KSOptions.recordDir || (url.isFileURL && url.hasDirectoryPath) {
                LocalDirManagerView(localDir: url)
            } else {
                KSVideoPlayerView(url: url)
                #if !os(macOS)
                .toolbar(.hidden, for: .tabBar)
                #endif
            }
        }
    }
}

struct SettingGeneralView: View {
    @Default(\.firstPlayerType)
    private var firstPlayerType
    @Default(\.isAutoPlay)
    private var isAutoPlay
    @Default(\.isShowURLImport)
    private var isShowURLImport
    @Default(\.isSavePlaybackHistory)
    private var isSavePlaybackHistory
    @Default(\.isImmersiveSpace)
    private var isImmersiveSpace
    @UnsafeDefault(\.isSelectMaxBitRateTrack)
    private var isSelectMaxBitRateTrack
    var body: some View {
        Form {
            #if os(visionOS)
            Toggle(localized("Enable Immersive Space"), isOn: $isImmersiveSpace)
            #endif
            Toggle(localized("Auto Play"), isOn: $isAutoPlay)
            Toggle(localized("Show URLImport"), isOn: $isShowURLImport)
            Toggle(localized("Save Playback History"), isOn: $isSavePlaybackHistory)
            Toggle(localized("Is Select Max BitRate Track"), isOn: $isSelectMaxBitRateTrack)
            Picker(localized("First Player Type"), selection: $firstPlayerType) {
                Text("AVPlayer").tag(NSStringFromClass(KSAVPlayer.self))
                Text("KSPlayer").tag(NSStringFromClass(KSMEPlayer.self))
                Text("KSMPVPlayer").tag(NSStringFromClass(KSMPVPlayer.self))
            }
        }
        .formStyle(.grouped)
    }
}

struct SettingAudioView: View {
    @Default(\.audioPlayerType)
    private var audioPlayerType
    @UnsafeDefault(\.audioFilters)
    private var audioFilters
    init() {}
    var body: some View {
        Form {
            ShowTextField(localized("Audio Filters"), text: $audioFilters)
            Picker(localized("Audio Player Type"), selection: $audioPlayerType) {
                Text("AUGraph").tag(NSStringFromClass(AudioGraphPlayer.self))
                Text("AudioUnit").tag(NSStringFromClass(AudioUnitPlayer.self))
                Text("AVAudioEngine").tag(NSStringFromClass(AudioEnginePlayer.self))
                Text("AVSampleBufferAudioRenderer").tag(NSStringFromClass(AudioRendererPlayer.self))
            }
        }
        .formStyle(.grouped)
    }
}

struct SettingVideoView: View {
    @Default(\.isUseDisplayLayer)
    private var isUseDisplayLayer
    @Default(\.deInterlaceAddIdet)
    private var deInterlaceAddIdet
    @Default(\.yadifMode)
    private var yadifMode
    @Default(\.preferredFrame)
    private var preferredFrame
    @Default(\.videoSoftDecodeThreadCount)
    private var videoSoftDecodeThreadCount
    @UnsafeDefault(\.videoDecodeType)
    private var videoDecodeType
    @UnsafeDefault(\.videoFilters)
    private var videoFilters
    @Default(\.audioVideoClockSync)
    private var audioVideoClockSync
    @UnsafeDefault(\.renderUseDispatchSourceTimer)
    private var renderUseDispatchSourceTimer
    @UnsafeDefault(\.isDoubleRefreshRate)
    private var isDoubleRefreshRate
    var body: some View {
        Form {
            LabeledContent(localized("Device HDR Modes"), value: DynamicRange.availableHDRModes.map(\.description).joined(separator: ","))
            LabeledContent(localized("Is HDR Screen"), value: UIApplication.isHDRScreen.description)
            Toggle(localized("Use DisplayLayer"), isOn: $isUseDisplayLayer)
            Toggle(localized("Render Use DispatchSource Timer"), isOn: $renderUseDispatchSourceTimer)
#if os(tvOS)
            Toggle(localized("Double Refresh Rate"), isOn: $isDoubleRefreshRate)
#endif
            Toggle(localized("Enable displayLink preferredFrame"), isOn: $preferredFrame)
            Toggle(localized("Enable deInterlace Add Idet"), isOn: $deInterlaceAddIdet)
            Toggle(localized("Enable audio VideoClock Sync"), isOn: $audioVideoClockSync)
            Picker(localized("Video Decode Type"), selection: $videoDecodeType) {
                Text("hardware").tag(VideoDecodeType.hardware)
                Text("asynchronousHardware").tag(VideoDecodeType.asynchronousHardware)
                Text("videotoolbox").tag(VideoDecodeType.videotoolbox)
                Text("software").tag(VideoDecodeType.software)
            }
            Picker(localized("Yadif Mode"), selection: $yadifMode) {
                Text("Yadif").tag(0)
                Text("Yadif_2x").tag(1)
                Text("Yadif_spatial_skip").tag(2)
                Text("Yadif_2x_spatial_skip").tag(3)
            }
            ShowTextField(localized("Video Filters"), text: $videoFilters)
            ShowValueField(localized("Video Soft Decode Thread Count"), value: $videoSoftDecodeThreadCount, format: .number)
        }
        .formStyle(.grouped)
    }
}

struct SettingSubtitleView: View {
    @UnsafeDefault(\.isSeekImageSubtitle)
    private var isSeekImageSubtitle
    @Default(\.stripSubtitleStyle)
    private var stripSubtitleStyle
    @Default(\.subtitleFontSize)
    private var subtitleFontSize
    @Default(\.textBold)
    private var textBold
    @Default(\.textItalic)
    private var textItalic
    @Default(\.textColor)
    private var textColor
    @Default(\.textShadowColor)
    private var textShadowColor
    @Default(\.textBackgroundColor)
    private var textBackgroundColor
    @Default(\.verticalAlign)
    private var verticalAlign
    @Default(\.horizontalAlign)
    private var horizontalAlign
    @Default(\.leftMargin)
    private var leftMargin
    @Default(\.rightMargin)
    private var rightMargin
    @Default(\.verticalMargin)
    private var verticalMargin
    @Default(\.isASSUseImageRender)
    private var isASSUseImageRender
    @Default(\.isSRTUseImageRender)
    private var isSRTUseImageRender
    @Default(\.showTranslateSourceText)
    private var showTranslateSourceText
    @Default(\.textFontName)
    private var textFontName
    @UnsafeDefault(\.playbackTimeInterval)
    private var playbackTimeInterval
    var body: some View {
        Form {
            Toggle(localized("Seek Image Subtitle"), isOn: $isSeekImageSubtitle)
            Toggle(localized("Is ASS Use Image Render"), isOn: $isASSUseImageRender)
            Toggle(localized("is SRT Use Image Render"), isOn: $isSRTUseImageRender)
            Toggle(localized("Strip Subtitle Style"), isOn: $stripSubtitleStyle)
            Toggle(localized("Show Translate Source Text"), isOn: $showTranslateSourceText)
            ShowOptionValueField(
                localized("Subtitle Time Interval"),
                value: $playbackTimeInterval.option,
                format: .number
            )
            Section("Font") {
                Picker(localized("Font Name"), selection: $textFontName) {
                    ForEach(UIFont.familyNames.sorted(by: <)) { name in
                        Text(name)
                            .tag(name)
                    }
                }
                ShowOptionValueField(localized("Font Size"), value: $subtitleFontSize.option, format: .number)
                Toggle(localized("Bold"), isOn: $textBold)
                Toggle(localized("Italic"), isOn: $textItalic)
                ColorPicker(localized("Text Color"), selection: $textColor)
                ColorPicker(localized("Shadow Color"), selection: $textShadowColor)
                ColorPicker(localized("Background Color"), selection: $textBackgroundColor)
            }
            Section("Position") {
                Picker(localized("Align X"), selection: $horizontalAlign) {
                    ForEach([HorizontalAlignment.leading, .center, .trailing]) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                Picker(localized("Align Y"), selection: $verticalAlign) {
                    ForEach([VerticalAlignment.top, .center, .bottom]) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                ShowOptionValueField(localized("Margin Left"), value: $leftMargin.option, format: .number)
                ShowOptionValueField(localized("Margin Right"), value: $rightMargin.option, format: .number)
                ShowOptionValueField(localized("Margin Vertical"), value: $verticalMargin.option, format: .number)
            }
        }
        .formStyle(.grouped)
    }
}

struct SettingAdvancedView: View {
    @Default(\.preferredForwardBufferDuration)
    private var preferredForwardBufferDuration
    @Default(\.maxBufferDuration)
    private var maxBufferDuration
    @Default(\.isLoopPlay)
    private var isLoopPlay
    @Default(\.canBackgroundPlay)
    private var canBackgroundPlay
    @Default(\.isSecondOpen)
    private var isSecondOpen
    @UnsafeDefault(\.isLowDelay)
    private var isLowDelay
    @UnsafeDefault(\.isQuickOpen)
    private var isQuickOpen
    @Default(\.isAccurateSeek)
    private var isAccurateSeek
    @UnsafeDefault(\.isKeepAlive)
    private var isKeepAlive
    @UnsafeDefault(\.seekUsePacketCache)
    private var seekUsePacketCache
    @Default(\.pictureInPictureType)
    private var pictureInPictureType
    @Default(\.canStartPictureInPictureAutomaticallyFromInline)
    private var canStartPictureInPictureAutomaticallyFromInline
    @Default(\.httpUserAgent)
    private var httpUserAgent
    @Default(\.hudLog)
    private var hudLog
    var body: some View {
        Form {
            ShowValueField(localized("Preferred Forward Buffer Duration"), value: $preferredForwardBufferDuration, format: .number)
            ShowValueField(localized("Max Buffer Second"), value: $maxBufferDuration, format: .number)
            Toggle(localized("Loop Play"), isOn: $isLoopPlay)
            Toggle(localized("Can Background Play"), isOn: $canBackgroundPlay)
            Toggle(localized("Fast Open Video"), isOn: $isSecondOpen)
            Toggle(localized("Fastest Open Video"), isOn: $isQuickOpen)
            Toggle(localized("Is Accurate Seek"), isOn: $isAccurateSeek)
            Toggle(localized("Is Low Delay"), isOn: $isLowDelay)
            Toggle(localized("Connection Keep Alive"), isOn: $isKeepAlive)
            Toggle(localized("Seek Use Packet Cache"), isOn: $seekUsePacketCache)
            Toggle(localized("Show Developer HUD Log"), isOn: $hudLog)
            Toggle(localized("Picture In Picture Inline"), isOn: $canStartPictureInPictureAutomaticallyFromInline)
            Picker(localized("Picture In Picture Type"), selection: $pictureInPictureType) {
                Text(localized("Default")).tag(NSStringFromClass(KSPictureInPictureController.self))
            }
            TextField(localized("Http User Agent"), text: $httpUserAgent)
            Section(localized("Schema demo")) {
                List {
                    ForEach([
                        "ksplayer://x-callback-url?url=https://raw.githubusercontent.com/kingslay/TestVideo/main/h264.mp4&x-success=iina://open&x-error=iina://open&x-success=iina://open&x-complete=iina%3A%2F%2Fopen%3Fxxx%26currentTime%3D120%26totalTime%3D3600",
                        "ksplayer://open?url=https://raw.githubusercontent.com/kingslay/TestVideo/main/h264.mp4",
                        "ksp://weblink?url=https://raw.githubusercontent.com/kingslay/TestVideo/main/h264.mp4",
                        "tracy://open?url=https://raw.githubusercontent.com/kingslay/TestVideo/main/h264.mp4",
                    ]) { url in
                        Link(destination: URL(string: url)!) {
                            Text(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShowOptionValueField<F: ParseableFormatStyle>: View where F.FormatOutput == String {
    private let titleKey: String
    private let value: Binding<F.FormatInput?>
    private let prompt: Text?
    private let format: F
    init(_ titleKey: String, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) {
        self.titleKey = titleKey
        self.value = value
        self.format = format
        self.prompt = prompt
    }

    var body: some View {
        #if os(macOS)
        TextField(titleKey, value: value, format: format, prompt: prompt)
        #else
        HStack {
            Text(titleKey)
            Spacer()
            let title = ""
            TextField(title, value: value, format: format, prompt: prompt)
        }
        #endif
    }
}

struct ShowSecureField: View {
    private let titleKey: String
    private let text: Binding<String>
    private let prompt: Text?
    init(_ titleKey: String, text: Binding<String>, prompt: Text? = nil) {
        self.titleKey = titleKey
        self.text = text
        self.prompt = prompt
    }

    var body: some View {
        #if os(macOS)
        SecureField(titleKey, text: text, prompt: prompt)
        #else
        HStack {
            Text(titleKey)
            Spacer()
            let title = ""
            SecureField(title, text: text, prompt: prompt)
        }
        #endif
    }
}

struct LocalDirManagerView: View {
    private let urls: [URL]
    init(localDir: URL) {
        urls = (try? FileManager.default.contentsOfDirectory(at: localDir, includingPropertiesForKeys: nil))?.sorted { left, right in
            left.lastPathComponent > right.lastPathComponent
        } ?? []
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: MoiveView.width))]) {
                ForEach(urls) { url in
                    let value = MovieModel(url: url)
                    NavigationLink(value: value) {
                        MoiveView(model: value)
                    }
                    #if os(tvOS)
                    .buttonStyle(TVButtonStyle())
                    #else
                    .buttonStyle(.borderless)
                    #endif
                }
            }
        }
        .padding()
    }
}

/// 这个方法可以自动生成翻译文件，但是写法比较麻烦
/// @inlinable
@available(macOS 12, iOS 15, tvOS 15, *)
func localized(_ string: @autoclosure () -> String.LocalizationValue) -> String {
    // #bundle要xcode26才有
    String(localized: string())
}

#if os(tvOS)
struct ColorPicker: View {
    private let titleKey: String
    private let selection: Binding<Color>
    init(_ titleKey: String, selection: Binding<Color>) {
        self.titleKey = titleKey
        self.selection = selection
    }

    var body: some View {
        NavigationLink {
            ColorPickerView(selection: selection)
        } label: {
            HStack {
                Text(titleKey)
                Spacer()
                Circle()
                    .fill(selection.wrappedValue)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 4)
                    )
                    .frame(width: 40, height: 40)
            }
        }
    }
}

struct ColorPickerView: View {
    @Binding
    var selection: Color // 当前选择的颜色
    @State
    private var color = Color.black
    @FocusState
    private var focusedColor: Color?
    @State
    private var opacity: Double = 0.5
    @FocusState
    private var focusedOpacity: Double?
    // 预定义颜色选项
    private let colors: [Color] = [.red, .orange, .yellow, Color(uiColor: UIColor(rgb: 0xFEFD55)), .green, .blue, .purple, .pink, .white, .gray, .black]
    private let opacityLevels: [Double] = Array(0 ... 10).map { Double($0) / 10.0 }
    var body: some View {
        VStack(spacing: 20) {
            // 显示选中的颜色（支持透明度）
            Rectangle()
                .fill(selection) // 应用透明度
                //                .frame(width: 300, height: 200)
                .padding()
                .cornerRadius(10)
                .background(Color.white) // 背景色
                .cornerRadius(20)
            // 颜色选择按钮
            HStack(spacing: 20) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 60, height: 60)
                        .padding()
                        .overlay(
                            Circle()
                                .stroke(focusedColor == color ? Color.white : Color.clear, lineWidth: 4)
                        )
                        .focusable(true)
                        .focused($focusedColor, equals: color) // 控制焦点
                }
            }
            // 透明度调整按钮
            Text("Opacity: \(Int(opacity * 100))%")
                .foregroundColor(.white)
            HStack {
                ForEach(opacityLevels, id: \.self) { opacity in
                    Circle()
                        .fill(Color.white.opacity(opacity))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(focusedOpacity == opacity ? Color.blue : Color.clear, lineWidth: 4)
                        )
                        .focusable(true)
                        .focused($focusedOpacity, equals: opacity) // 控制焦点
                }
            }
        }
        .onChange(of: focusedColor) { newValue in
            if let newValue {
                color = newValue
            }
            selection = color.opacity(opacity)
        }
        .onChange(of: focusedOpacity) { newValue in
            if let newValue {
                opacity = newValue
            }
            selection = color.opacity(opacity)
        }
        .onAppear {
            focusedColor = color
        }
    }
}

#endif

#if os(tvOS)
struct TVButtonStyle: PrimitiveButtonStyle {
    @State
    private var isFocused: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .focusable(true) { focused in
                if focused {
                    isFocused = true
                } else {
                    isFocused = false
                }
            }
            .background(RoundedRectangle(cornerRadius: 20).fill(isFocused ? .red : .clear).opacity(0.7))
            .shadow(color: Color.black, radius: isFocused ? 10 : 5, x: 5, y: isFocused ? 20 : 5)
            .scaleEffect(isFocused ? 1.2 : 1.0)
            .onTapGesture(perform: configuration.trigger)
    }
}
#endif
