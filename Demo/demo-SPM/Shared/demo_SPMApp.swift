//
//  demo_SPMApp.swift
//  Shared
//
//  Created by kintan on 2021/5/3.
//

import AVFoundation
import AVKit
import KSPlayer
import SwiftUI
@main
struct demo_SPMApp: App {
    init() {
        KSPlayerManager.canBackgroundPlay = true
        KSPlayerManager.logLevel = .debug
        KSPlayerManager.firstPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
        KSOptions.isLoopPlay = true
        KSOptions.hardwareDecodeH265 = true
        KSOptions.hardwareDecodeH264 = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct AVContentView: View {
    var body: some View {
        StructAVPlayerView().frame(width: UIScreen.main.bounds.width, height: 400, alignment: .center)
    }
}

struct StructAVPlayerView: UIViewRepresentable {
    let playerVC = AVPlayerViewController()
    typealias UIViewType = UIView
    func makeUIView(context _: Context) -> UIView {
        playerVC.view
    }

    func updateUIView(_: UIView, context _: Context) {
        playerVC.player = AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!)
    }
}
