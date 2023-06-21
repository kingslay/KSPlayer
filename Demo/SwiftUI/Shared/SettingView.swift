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
                NavigationLink(destination: Text("Audio")) {
                    Label("Audio", systemImage: "waveform")
                }
                NavigationLink(destination: SettingSubtitleView()) {
                    Label("Subtitle", systemImage: "captions.bubble")
                }
                NavigationLink(destination: Text("Video")) {
                    Label("Video", systemImage: "play.rectangle.fill")
                }
                NavigationLink(destination: Text("Advanced")) {
                    Label("Advanced", systemImage: "gearshape.2.fill")
                }
                NavigationLink(destination: Text("Utilities")) {
                    Label("Utilities", systemImage: "wrench.adjustable.fill")
                }
            }
        }
    }
}

struct SettingSubtitleView: View {
    var body: some View {
        HStack {
            Text("Fone Size:")
            TextField("", value: Binding {
                SubtitleModel.textFont.pointSize
            } set: { text in
                if let value = text {
                    SubtitleModel.textFont = .systemFont(ofSize: CGFloat(value))
                }
            }, format: .number)
        }.fixedSize()
        ColorPicker("Color:", selection: Binding {
            Color(SubtitleModel.textColor)
        } set: { value in
            SubtitleModel.textColor = UIColor(value)
        })
        ColorPicker("Background:", selection: Binding {
            Color(SubtitleModel.textBackgroundColor)
        } set: { value in
            SubtitleModel.textBackgroundColor = UIColor(value)
        })

        Picker("Align X:", selection: Binding {
            SubtitleModel.textXAlign
        } set: {
            SubtitleModel.textXAlign = $0
        }) {
            ForEach([TextAlignment.leading, .center, .trailing], id: \.self) { value in
                Text(value.description).tag(value)
            }
        }
        Picker("Align Y:", selection: Binding {
            SubtitleModel.textYAlign
        } set: {
            SubtitleModel.textYAlign = $0
        }) {
            ForEach([VerticalAlignment.top, .center, .bottom], id: \.self) { value in
                Text(value.description).tag(value)
            }
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
