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
    var body: some View {
        Form {
            Section {
                TextField("URL:", text: $playURL)
                Picker("iptv", selection: $playURL) {
                    ForEach(appModel.iptv, id: \.self) {
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
        .padding()
    }
}
