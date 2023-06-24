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
                NavigationLink(destination: SettingSubtitleView()) {
                    Label("Subtitle", systemImage: "captions.bubble")
                }
                NavigationLink(destination: SettingAudioView()) {
                    Label("Audio", systemImage: "waveform")
                }
                NavigationLink(destination: SettingVideoView()) {
                    Label("Video", systemImage: "play.rectangle.fill")
                }
                NavigationLink(destination: SettingAdvancedView()) {
                    Label("Advanced", systemImage: "gearshape.2.fill")
                }
                NavigationLink(destination: Text("Utilities")) {
                    Label("Utilities", systemImage: "wrench.adjustable.fill")
                }
            }
        }
    }
}

struct SettingAudioView: View {
    @AppStorage("isUseAudioRenderer") private var isUseAudioRenderer = KSOptions.isUseAudioRenderer
    init() {}
    var body: some View {
        Form {
            Toggle(isOn: $isUseAudioRenderer) {
                Text("Use Audio Renderer")
            }
        }
        .onChange(of: isUseAudioRenderer) {
            KSOptions.isUseAudioRenderer = $0
        }
    }
}

struct SettingVideoView: View {
    @AppStorage("hardwareDecode") private var hardwareDecode = KSOptions.hardwareDecode
    var body: some View {
        Form {
            Toggle(isOn: $hardwareDecode) {
                Text("Hardware decoder")
            }
        }
        .onChange(of: hardwareDecode) {
            KSOptions.hardwareDecode = $0
        }
    }
}

struct SettingAdvancedView: View {
    @AppStorage("preferredForwardBufferDuration") private var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration
    @AppStorage("maxBufferDuration") private var maxBufferDuration = KSOptions.maxBufferDuration
    @AppStorage("isLoopPlay") private var isLoopPlay = KSOptions.isLoopPlay

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
            Toggle(isOn: $isLoopPlay) {
                Text("Loop Play")
            }
        }
        .onChange(of: preferredForwardBufferDuration) {
            KSOptions.preferredForwardBufferDuration = $0
        }
        .onChange(of: maxBufferDuration) {
            KSOptions.maxBufferDuration = $0
        }
        .onChange(of: isLoopPlay) {
            KSOptions.isLoopPlay = $0
        }
    }
}

struct SettingSubtitleView: View {
    @AppStorage("textFontSize") private var textFontSize = SubtitleModel.textFontSize
    @AppStorage("textBold") private var textBold = SubtitleModel.textBold
    @AppStorage("textItalic") private var textItalic = SubtitleModel.textItalic
    @AppStorage("textColor") private var textColor = SubtitleModel.textColor
    @AppStorage("textBackgroundColor") private var textBackgroundColor = SubtitleModel.textBackgroundColor
    @AppStorage("textXAlign") private var textXAlign = SubtitleModel.textXAlign
    @AppStorage("textYAlign") private var textYAlign = SubtitleModel.textYAlign
    @AppStorage("textXMargin") private var textXMargin = SubtitleModel.textXMargin
    @AppStorage("textYMargin") private var textYMargin = SubtitleModel.textYMargin

    var body: some View {
        Form {
            Section("Position") {
                HStack {
                    #if os(iOS)
                    Text("Fone Size:")
                    #endif
                    TextField("Fone Size:", value: $textFontSize, format: .number)
                }
                Toggle(isOn: $textBold) {
                    Text("Bold")
                }
                Toggle(isOn: $textItalic) {
                    Text("Italic")
                }
                #if !os(tvOS)
                ColorPicker("Color:", selection: $textColor)
                ColorPicker("Background:", selection: $textBackgroundColor)
                #endif
            }
            Section("Position") {
                Picker("Align X:", selection: $textXAlign) {
                    ForEach([TextAlignment.leading, .center, .trailing], id: \.self) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                Picker("Align Y:", selection: $textYAlign) {
                    ForEach([VerticalAlignment.top, .center, .bottom], id: \.self) { value in
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
        .onChange(of: textFontSize) {
            SubtitleModel.textFontSize = $0
        }
        .onChange(of: textBold) {
            SubtitleModel.textBold = $0
        }
        .onChange(of: textItalic) {
            SubtitleModel.textItalic = $0
        }
        .onChange(of: textColor) {
            SubtitleModel.textColor = $0
        }
        .onChange(of: textBackgroundColor) {
            SubtitleModel.textBackgroundColor = $0
        }
        .onChange(of: textXAlign) {
            SubtitleModel.textXAlign = $0
        }
        .onChange(of: textYAlign) {
            SubtitleModel.textYAlign = $0
        }
        .onChange(of: textXMargin) {
            SubtitleModel.textXMargin = $0
        }
        .onChange(of: textYMargin) {
            SubtitleModel.textYMargin = $0
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
