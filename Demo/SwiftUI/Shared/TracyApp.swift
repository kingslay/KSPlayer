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
            #if os(macOS)
            ContentView()
                .environmentObject(appModel)
            #else
            TabView {
                ContentView()
                    .environmentObject(appModel)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                SettingView()
                    .tabItem {
                        Label("Setting", systemImage: "gear")
                    }
            }
            #endif
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
            SettingView()
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
    @Published var nameFilter: String = ""
    @Published var groupFilter: String = ""
    private(set) var groups = [String]()
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
            replaceM3U(url: url)
        } else {
            path.append(MovieModel(url: url))
        }
    }

    func replaceM3U(url: URL) {
        url.parsePlaylist { result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var groupSet = Set<String>()
                let array = result.compactMap { name, url, extinf in
                    let model = MovieModel(url: url, name: name, extinf: extinf)
                    if let group = model.group {
                        groupSet.insert(group)
                    }
                    return model
                }
                self.playlist = array
                self.groups = Array(groupSet)
                self.groupFilter = ""
            }
        }
    }

    func filterParsePlaylist() -> [MovieModel] {
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

    private(set) var iptv: [M3UModel] = [
        M3UModel(name: "All", m3uURL: "https://iptv-org.github.io/iptv/index.nsfw.m3u"),
        M3UModel(name: "China", m3uURL: "https://iptv-org.github.io/iptv/countries/cn.m3u"),
        M3UModel(name: "Hong Kong", m3uURL: "https://iptv-org.github.io/iptv/countries/hk.m3u"),
        M3UModel(name: "Taiwan", m3uURL: "https://iptv-org.github.io/iptv/countries/tw.m3u"),
        M3UModel(name: "Americas", m3uURL: "https://iptv-org.github.io/iptv/regions/amer.m3u"),
        M3UModel(name: "Asia", m3uURL: "https://iptv-org.github.io/iptv/regions/asia.m3u"),
        M3UModel(name: "Europe", m3uURL: "https://iptv-org.github.io/iptv/regions/eur.m3u"),
        M3UModel(name: "Education", m3uURL: "https://iptv-org.github.io/iptv/categories/education.m3u"),
        M3UModel(name: "Movies", m3uURL: "https://iptv-org.github.io/iptv/categories/movies.m3u"),
//        M3UModel(name: "XXX", m3uURL: "https://iptv-org.github.io/iptv/categories/xxx.m3u"),
        M3UModel(name: "Chinese", m3uURL: "https://iptv-org.github.io/iptv/languages/zho.m3u"),
        M3UModel(name: "English", m3uURL: "https://iptv-org.github.io/iptv/languages/eng.m3u"),
    ]
}

struct M3UModel: Hashable {
    let name: String
    let m3uURL: String
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
