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
    @Environment(\.dismiss) private var dismiss
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
            }
            Section("HTTP Authentication") {
                TextField("Username:", text: $username)
                SecureField("Password:", text: $password)
            }
            Section {
                Button("Done") {
                    dismiss()
                    let urlString = playURL.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines)
                    if urlString.count > 0, var components = URLComponents(string: urlString) {
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
                }
                #if os(macOS)
                Button("Cancel") {
                    dismiss()
                }
                #endif
            }
        }
        .padding()
    }
}
