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
struct TracyApp: App {
    @StateObject var appModel = APPModel()
    init() {
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
            appModel.open(url: URL(fileURLWithPath: urlString))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }

        #if !os(tvOS)
        .commands {
            #if os(macOS)
            CommandGroup(before: .newItem) {
                Button("Open") {
                    appModel.openFileImport = true
                }.keyboardShortcut("o")
            }
            CommandGroup(before: .newItem) {
                Button("Open URL") {
                    appModel.openURLImport = true
                }.keyboardShortcut("o", modifiers: [.command, .shift])
            }
            #endif
        }
        #endif
        #if os(macOS)
        .defaultSize(width: 1600, height: 900)
        .defaultPosition(.center)
        #endif
        #if os(macOS)

        Settings {
//            SettingContainer()
        }

        MenuBarExtra {
//            MenuBar()
        } label: {
            Image(systemName: "film.fill")
        }
        .menuBarExtraStyle(.menu)

        #endif
    }
}

class APPModel: ObservableObject {
    @Published private(set) var playlist = [MovieModel]()
    @Published var path = NavigationPath()
    @Published var openFileImport: Bool = false
    @Published var openURLImport: Bool = false
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
        #if os(macOS)
        for url in NSDocumentController.shared.recentDocumentURLs {
            playlist.append(MovieModel(url: url))
        }
        #else

        #endif
        #if DEBUG
        playlist.append(contentsOf: testObjects)
        #endif
    }

    func open(url: URL) {
        if url.isPlaylist {
            url.parsePlaylist { result in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let array = result.compactMap { name, url, extinf in
                        MovieModel(url: url, name: name, extinf: extinf)
                    }
                    self.playlist.insert(contentsOf: array, at: 0)
                }
            }
        } else {
            path.append(MovieModel(url: url))
        }
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
