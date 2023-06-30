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
    @State private var playURL: String = ""
    @State private var rememberURL = false
    @AppStorage("historyURLs") private var historyURLs = [URL]()
    var body: some View {
        Form {
            Section {
                TextField("URL:", text: $playURL)
                Toggle("Remember URL", isOn: $rememberURL)
                if historyURLs.count > 0 {
                    Picker("History URL", selection: $playURL) {
                        ForEach(historyURLs) {
                            Text($0.description).tag($0.description)
                        }
                    }
                }
                Picker("IPTV", selection: $playURL) {
                    ForEach(appModel.m3uModels) {
                        Text($0.name).tag($0.m3uURL)
                    }
                }
            }
            Section("HTTP Authentication") {
                TextField("Username:", text: $username)
                SecureField("Password:", text: $password)
            }
            Section {
                HStack {
                    Button("Cancel") {
                        appModel.openURLImport = false
                    }
                    Spacer()
                    Button("Done") {
                        if var components = URLComponents(string: playURL.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines)) {
                            if username.count > 0 {
                                components.user = username
                            }
                            if password.count > 0 {
                                components.password = password
                            }
                            if let url = components.url {
                                if rememberURL {
                                    if let index = historyURLs.firstIndex(of: url) {
                                        historyURLs.swapAt(index, historyURLs.startIndex)
                                    } else {
                                        historyURLs.insert(url, at: 0)
                                    }
                                    if historyURLs.count > 20 {
                                        historyURLs.removeLast()
                                    }
                                }
                                appModel.open(url: url)
                            }
                        }
                        appModel.openURLImport = false
                    }
                }
            }
        }
        .padding()
    }
}
