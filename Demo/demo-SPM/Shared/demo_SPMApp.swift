//
//  demo_SPMApp.swift
//  Shared
//
//  Created by kintan on 2021/5/3.
//

import KSPlayer
import SwiftUI
@main
struct demo_SPMApp: App {
    init() {
        KSPlayerManager.firstPlayerType = KSMEPlayer.self
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
