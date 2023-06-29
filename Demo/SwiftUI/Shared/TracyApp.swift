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
    private let appModel = APPModel()
    init() {
        let arguments = ProcessInfo.processInfo.arguments.dropFirst()
        var dropNextArg = false
        var playerArgs = [String]()
        var filenames = [String]()
        KSLog("launch arguments \(arguments)")
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
            #if !os(tvOS)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "pause"), allowing: Set(arrayLiteral: "*"))
            #endif
        }
        #if !os(tvOS)
//        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
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
        }
        #endif
        #if os(macOS)
        .defaultSize(width: 1600, height: 900)
        .defaultPosition(.center)
        #endif
        #if os(macOS)
        WindowGroup("player", for: URL.self) { $url in
            if let url {
                KSVideoPlayerView(url: url)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        Settings {
            SettingView()
        }
//        MenuBarExtra {
//            MenuBar()
//        } label: {
//            Image(systemName: "film.fill")
//        }
//        .menuBarExtraStyle(.menu)
        #endif
    }
}

class APPModel: ObservableObject {
    private(set) var groups = [String]()
    @Published var openWindow: URL?
    @Published private(set) var playlist = [MovieModel]()
    @Published var nameFilter: String = ""
    @Published var groupFilter: String = ""
    @Published var path = NavigationPath()
    @Published var openFileImport = false
    @Published var openURLImport = false
    @Published var hiddenTitleBar = false
    init() {
        #if !DEBUG
        var fileHandle = FileHandle.standardOutput
        if let logURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("log.txt") {
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: logURL) {
                fileHandle = handle
                _ = try? fileHandle.seekToEnd()
            }
        }
        KSOptions.logger = FileLog(fileHandle: fileHandle)
        #endif
        KSOptions.canBackgroundPlay = true
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
        KSOptions.subtitleDataSouces = [DirectorySubtitleDataSouce(), ShooterSubtitleDataSouce(), AssrtSubtitleDataSouce(token: "5IzWrb2J099vmA96ECQXwdRSe9xdoBUv")]
//        KSOptions.isUseAudioRenderer = true
//        KSOptions.isLoopPlay = true
        #if DEBUG
        let model = M3UModel(name: "Test", m3uURL: "https://raw.githubusercontent.com/kingslay/KSPlayer/develop/Tests/KSPlayerTests/test.m3u")
        m3uModels.append(model)
        if let url = URL(string: model.m3uURL) {
            replaceM3U(url: url)
        }
        #endif
    }

    func replaceM3U(url: URL) {
        Task { @MainActor in
            let result = try? await url.parsePlaylist()
            var groupSet = Set<String>()
            let array = result?.compactMap { name, url, extinf in
                let model = MovieModel(url: url, name: name, extinf: extinf)
                if let group = model.group {
                    groupSet.insert(group)
                }
                return model
            }
            self.playlist = array ?? []
            self.groups = Array(groupSet)
            self.groupFilter = ""
        }
    }

    func open(url: URL) {
        if url.isPlaylist {
            replaceM3U(url: url)
        } else {
            #if os(macOS)
            openWindow = url
            #else
            path.append(url)
            #endif
        }
    }

    @inline(__always) func filterParsePlaylist() -> [MovieModel] {
        playlist.filter { model in
            var isIncluded = true
            if nameFilter.count > 0 {
                isIncluded = model.name.contains(nameFilter)
            }
            if groupFilter.count > 0 {
                isIncluded = isIncluded && model.group == groupFilter
            }
            return isIncluded
        }
    }

    private(set) var m3uModels: [M3UModel] = [
        M3UModel(name: "YanG", m3uURL: "https://raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u"),
        M3UModel(name: "Iptv", m3uURL: "https://iptv-org.github.io/iptv/index.nsfw.m3u"),
        M3UModel(name: "China", m3uURL: "https://iptv-org.github.io/iptv/countries/cn.m3u"),
        M3UModel(name: "Hong Kong", m3uURL: "https://iptv-org.github.io/iptv/countries/hk.m3u"),
        M3UModel(name: "Taiwan", m3uURL: "https://iptv-org.github.io/iptv/countries/tw.m3u"),
        M3UModel(name: "Americas", m3uURL: "https://iptv-org.github.io/iptv/regions/amer.m3u"),
        M3UModel(name: "Asia", m3uURL: "https://iptv-org.github.io/iptv/regions/asia.m3u"),
        M3UModel(name: "Europe", m3uURL: "https://iptv-org.github.io/iptv/regions/eur.m3u"),
        M3UModel(name: "Education", m3uURL: "https://iptv-org.github.io/iptv/categories/education.m3u"),
        M3UModel(name: "Movies", m3uURL: "https://iptv-org.github.io/iptv/categories/movies.m3u"),
        M3UModel(name: "Chinese", m3uURL: "https://iptv-org.github.io/iptv/languages/zho.m3u"),
        M3UModel(name: "English", m3uURL: "https://iptv-org.github.io/iptv/languages/eng.m3u"),
    ]
}

// struct AVContentView: View {
//    var body: some View {
//        StructAVPlayerView().frame(width: UIScene.main.bounds.width, height: 400, alignment: .center)
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
struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
        KSVideoPlayerView(url: url, options: KSOptions())
    }
}
