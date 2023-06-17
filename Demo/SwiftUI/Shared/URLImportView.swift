//
//  ContentView.swift
//  Demo
//
//  Created by kintan on 2020/3/22.
//  Copyright © 2020 kintan. All rights reserved.
//

import KSPlayer
import SwiftUI

struct URLImportView: View {
    @EnvironmentObject private var appModel: APPModel
    @State private var username = ""
    @State private var password = ""
    @State private var playURL: String = "https://iptv-org.github.io/iptv/index.nsfw.m3u"
    var body: some View {
        List {
            TextField("Please enter the URL here……", text: $playURL)
            Section("HTTP Authentication") {
                HStack {
                    Text("Username")
                    TextField("", text: $username).border(.gray)
                }
                HStack {
                    Text("Password")
                    TextField("", text: $password).border(.gray)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    appModel.openURLImport = false
                }
                Button("Done") {
                    if var components = URLComponents(string: playURL.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines)) {
                        if username.count > 0 {
                            components.user = username
                        }
                        if password.count > 0 {
                            components.password = password
                        }
                        if let url = components.url {
                            appModel.open(url: url)
                        }
                    }
                    appModel.openURLImport = false
                }
            }
        }
    }
}
