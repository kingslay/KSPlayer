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
    @State private var isImporting: Bool = false
    @State private var url: URL? = nil
    init() {
        KSOptions.canBackgroundPlay = true
        #if DEBUG
//        KSOptions.logLevel = .warning
        #endif
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
//        KSOptions.isUseAudioRenderer = true
//        KSOptions.isLoopPlay = true
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
            url = URL(fileURLWithPath: urlString)
        }
    }

    @ViewBuilder
    var contentView: some View {
        if let url {
            KSVideoPlayerView(url: url, options: MEOptions())
                .onDisappear {
                    self.url = nil
                }
        } else {
            //            HStack {
            //                KSVideoPlayerView(resource: testObjects[0])
            //                KSVideoPlayerView(resource: testObjects[1])
            //            }
            //
            //            VideoPlayer(player: AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!))
            //            AVContentView()
            ContentView()
                .onOpenURL { url in
                    self.url = url
                }
        }
    }

    var body: some Scene {
        WindowGroup {
            contentView
                .background(Color.black)
            #if !os(tvOS)
                .onDrop(of: ["public.url", "public.file-url"], isTargeted: nil) { items -> Bool in
                    guard let item = items.first, let identifier = item.registeredTypeIdentifiers.first else {
                        return false
                    }
                    item.loadItem(forTypeIdentifier: identifier, options: nil) { urlData, _ in
                        if let urlData = urlData as? Data {
                            let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                            DispatchQueue.main.async {
                                self.url = url
                            }
                        }
                    }
                    return true
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.movie, .audio, .data]) { result in
                    guard let url = try? result.get() else {
                        return
                    }
                    self.url = url
                }
            #endif
        }
        #if !os(tvOS)
        .commands {
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
