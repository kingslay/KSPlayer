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
#if !canImport(UIKit)
typealias UIHostingController = NSHostingController
typealias UIWindow = NSWindow

#endif
@main
struct DemoApp: App {
    @State private var playerView: KSVideoPlayerView? {
        didSet {
            if let view = playerView {
                let controller = UIHostingController(rootView: view)
                let win = UIWindow(contentViewController: controller)
                win.contentViewController = controller
                win.makeKeyAndOrderFront(nil)
                if let frame = win.screen?.frame {
                    win.setFrame(frame, display: true)
                }
            }
        }
    }
    @State private var isImporting: Bool = false
    init() {
        KSPlayerManager.canBackgroundPlay = true
        KSPlayerManager.logLevel = .debug
        KSPlayerManager.firstPlayerType = KSMEPlayer.self
        KSPlayerManager.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
        KSOptions.isLoopPlay = true
        let arguments = ProcessInfo.processInfo.arguments.dropFirst()
        var dropNextArg = false
        var playerArgs = [String]()
        var filenames = [String]()
        for argument in arguments {
            if dropNextArg {
                dropNextArg = false
                continue
            }
            if argument.starts(with: "--") {
                playerArgs.append(argument)
            } else if argument.starts(with: "-") {
                dropNextArg = true
            } else {
                filenames.append(argument)
            }
        }
        if let urlString = filenames.first {
            _playerView = .init(initialValue: KSVideoPlayerView(url: URL(fileURLWithPath: urlString), options: KSOptions()))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    playerView = KSVideoPlayerView(url: url, options: KSOptions())
                }
            #if !os(tvOS)
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.movie, .audio, .data]) { result in
                    guard let url = try? result.get() else {
                        return
                    }
                    #if os(macOS)
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                    #endif
                    if url.isAudio || url.isMovie {
                        playerView = KSVideoPlayerView(url: url, options: KSOptions())
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
            #endif
//
//            VideoPlayer(player: AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!))
//            AVContentView()
        }
        #if !os(tvOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add") {
//                    content.showAddActionSheet = true
                }
            }
            #if os(macOS)
            CommandGroup(before: .newItem) {
                Button("Open") {
                    isImporting = true
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
