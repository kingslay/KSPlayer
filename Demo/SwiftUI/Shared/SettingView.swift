//
//  SettingView.swift
//  TracyPlayer
//
//  Created by kintan on 2023/6/21.
//

import KSPlayer
import SwiftUI

struct SettingView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: SettingGeneralView()) {
                    Label("General", systemImage: "switch.2")
                }
                NavigationLink(destination: SettingAudioView()) {
                    Label("Audio", systemImage: "waveform")
                }
                NavigationLink(destination: SettingVideoView()) {
                    Label("Video", systemImage: "play.rectangle.fill")
                }
                NavigationLink(destination: SettingSubtitleView()) {
                    Label("Subtitle", systemImage: "captions.bubble")
                }
                NavigationLink(destination: SettingAdvancedView()) {
                    Label("Advanced", systemImage: "gearshape.2.fill")
                }
            }
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
    }
}

struct SettingGeneralView: View {
    @Default(\.showRecentPlayList)
    private var showRecentPlayList
    var body: some View {
        Form {
            Toggle("Show Recent Play List", isOn: $showRecentPlayList)
        }
    }
}

struct SettingAudioView: View {
    @Default(\.isUseAudioRenderer)
    private var isUseAudioRenderer
    init() {}
    var body: some View {
        Form {
            Toggle("Use Audio Renderer", isOn: $isUseAudioRenderer)
        }
    }
}

struct SettingVideoView: View {
    @Default(\.hardwareDecode)
    private var hardwareDecode
    @Default(\.isUseDisplayLayer)
    private var isUseDisplayLayer

    var body: some View {
        Form {
            Toggle("Hardware decoder", isOn: $hardwareDecode)
            Toggle("Use DisplayLayer", isOn: $isUseDisplayLayer)
        }
    }
}

struct SettingSubtitleView: View {
    @Default(\.textFontSize)
    private var textFontSize
    @Default(\.textItalic)
    private var textBold
    @Default(\.textItalic)
    private var textItalic
    @Default(\.textColor)
    private var textColor
    @Default(\.textBackgroundColor)
    private var textBackgroundColor
    @Default(\.textXAlign)
    private var textXAlign
    @Default(\.textYAlign)
    private var textYAlign
    @Default(\.textXMargin)
    private var textXMargin
    @Default(\.textYMargin)
    private var textYMargin

    var body: some View {
        Form {
            Section("Position") {
                HStack {
                    #if os(iOS)
                    Text("Fone Size:")
                    #endif
                    TextField("Fone Size:", value: $textFontSize, format: .number)
                }
                Toggle("Bold", isOn: $textBold)
                Toggle("Italic", isOn: $textItalic)
                #if !os(tvOS)
                ColorPicker("Color:", selection: $textColor)
                ColorPicker("Background:", selection: $textBackgroundColor)
                #endif
            }
            Section("Position") {
                Picker("Align X:", selection: $textXAlign) {
                    ForEach([TextAlignment.leading, .center, .trailing]) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                Picker("Align Y:", selection: $textYAlign) {
                    ForEach([VerticalAlignment.top, .center, .bottom]) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                HStack {
                    #if os(iOS)
                    Text("Margin X:")
                    #endif
                    TextField("Margin X:", value: $textXMargin, format: .number)
                }
                HStack {
                    #if os(iOS)
                    Text("Margin Y:")
                    #endif
                    TextField("Margin Y:", value: $textYMargin, format: .number)
                }
            }
        }
        .padding()
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
    @Default(\.isAutoPlay)
    private var isAutoPlay
    @Default(\.isSecondOpen)
    private var isSecondOpen
    @Default(\.isAccurateSeek)
    private var isAccurateSeek
    @Default(\.isPipPopViewController)
    private var isPipPopViewController
//    @Default(\.isLoopPlay)
//    private var isLoopPlay
    var body: some View {
        Form {
            HStack {
                #if os(iOS)
                Text("Preferred Forward Buffer Duration:")
                #endif
                TextField("Preferred Forward Buffer Duration:", value: $preferredForwardBufferDuration, format: .number)
            }
            HStack {
                #if os(iOS)
                Text("Max Buffer Second:")
                #endif
                TextField("Max Buffer Second:", value: $maxBufferDuration, format: .number)
            }
            Toggle("Loop Play", isOn: $isLoopPlay)
            Toggle("Can Background Play", isOn: $canBackgroundPlay)
            Toggle("Auto Play", isOn: $isAutoPlay)
            Toggle("Fast Open Video", isOn: $isSecondOpen)
            Toggle("Fast Seek Video", isOn: $isAccurateSeek)
            Toggle("Picture In Picture Inline", isOn: $isPipPopViewController)
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
