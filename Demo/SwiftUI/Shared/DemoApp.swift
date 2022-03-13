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
struct DemoApp: App {
    init() {
        KSPlayerManager.canBackgroundPlay = true
        KSPlayerManager.logLevel = .debug
        KSPlayerManager.firstPlayerType = KSMEPlayer.self
        KSPlayerManager.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
        KSOptions.isLoopPlay = true
    }

    #if os(macOS)
    @State var playerView: KSVideoPlayerView?
    #endif
    var body: some Scene {
        let content = ContentView()
        WindowGroup {
            content
//            VideoPlayer(player: AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!))
//            AVContentView()
        }
        #if !os(tvOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add") {
                    content.showAddActionSheet = true
                }
            }
            #if os(macOS)
            CommandGroup(before: .newItem) {
                Button("Open") {
                    let panel = NSOpenPanel()
                    panel.title = NSLocalizedString("alert.choose_media_file.title", comment: "Choose Media File")
                    panel.canCreateDirectories = false
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK {
                        for url in panel.urls {
                            NSDocumentController.shared.noteNewRecentDocumentURL(url)
                        }
                        guard let url = panel.urls.first else {
                            return
                        }
                        if url.isAudio || url.isMovie {
                            let view = KSVideoPlayerView(url: url, options: KSOptions())
                            playerView = view
                            let controller = NSHostingController(rootView: view)
                            let win = NSWindow(contentViewController: controller)
                            win.contentViewController = controller
                            win.makeKeyAndOrderFront(nil)
                            if let frame = win.screen?.frame {
                                win.setFrame(frame, display: true)
                            }
                        } else {
                            if let playerView = playerView {
                                let info = URLSubtitleInfo(subtitleID: url.path, name: url.lastPathComponent)
                                info.downloadURL = url
                                info.enableSubtitle {
                                    playerView.subtitleModel.selectedSubtitle = try? $0.get()
                                }
                            }
                        }
                    }
                }.keyboardShortcut("o")
            }
            #endif
        }
        #endif
    }
}

// struct AVContentView: View {
//    var body: some View {
//        StructAVPlayerView().frame(width: UIScreen.main.bounds.width, height: 400, alignment: .center)
//    }
// }
//
// struct StructAVPlayerView: UIViewRepresentable {
//    let playerVC = AVPlayerViewController()
//    typealias UIViewType = UIView
//    func makeUIView(context _: Context) -> UIView {
//        playerVC.view
//    }
//
//    func updateUIView(_: UIView, context _: Context) {
//        playerVC.player = AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!)
//    }
// }
