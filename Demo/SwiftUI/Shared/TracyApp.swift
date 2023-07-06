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
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            #if !os(tvOS)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "pause"), allowing: Set(arrayLiteral: "*"))
            #endif
        }
        #if !os(tvOS)
//        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            SidebarCommands()

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
        .defaultSize(width: 1120, height: 630)
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
        WindowGroup("player", for: PlayModel.self) { $model in
            if let model {
                KSVideoPlayerView(model: model)
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
    @Published var openURL: URL?
    @Published var openPlayModel: PlayModel?
    @Published private(set) var playlist = [PlayModel]() {
        didSet {
            var groupSet = Set<String>()
            playlist.forEach { model in
                if let group = model.group {
                    groupSet.insert(group)
                }
            }
            groups = Array(groupSet)
        }
    }

    @Published var path = NavigationPath()
    @Published var openFileImport = false
    @Published var openURLImport = false
    @Published var hiddenTitleBar = false
    @AppStorage("activeM3UURL") private var activeM3UURL: URL?
    @Published var activeM3UModel: M3UModel? = nil {
        didSet {
            if let activeM3UModel, activeM3UModel != oldValue {
                activeM3UURL = activeM3UModel.m3uURL
                Task { @MainActor in
                    playlist = await activeM3UModel.parsePlaylist()
                }
            }
        }
    }

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
        KSOptions.isPipPopViewController = true
        KSOptions.subtitleDataSouces = [DirectorySubtitleDataSouce(), ShooterSubtitleDataSouce(), AssrtSubtitleDataSouce(token: "5IzWrb2J099vmA96ECQXwdRSe9xdoBUv")]
//        KSOptions.isUseAudioRenderer = true
//        KSOptions.isLoopPlay = true
        if let activeM3UURL {
            let request = M3UModel.fetchRequest()
            request.predicate = NSPredicate(format: "m3uURL == %@", activeM3UURL.description)
            if let model = try? PersistenceController.shared.container.viewContext.fetch(request).first {
                activeM3UModel = model
            }
        }
    }

    func addM3U(url: URL, name: String? = nil) {
        let request = M3UModel.fetchRequest()
        request.predicate = NSPredicate(format: "m3uURL == %@", url.description)
        activeM3UModel = try? PersistenceController.shared.container.viewContext.fetch(request).first ?? M3UModel(url: url, name: name)
    }

    func open(url: URL) {
        if url.isPlaylist {
            addM3U(url: url)
        } else {
            #if os(macOS)
            openURL = url
            #else
            path.append(url)
            #endif
        }
    }

    func content(model: PlayModel) -> some View {
        #if os(macOS)
        MoiveView(model: model)
            .onTapGesture {
                self.openPlayModel = model
            }
        #else
        NavigationLink(value: model) {
            MoiveView(model: model)
        }
        .buttonStyle(.plain)
        #endif
    }

//    private(set) var m3uModels: [M3UModel] = [
//        M3UModel(name: "YanG", m3uURL: "https://raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u"),
//        M3UModel(name: "Iptv-org", m3uURL: "https://iptv-org.github.io/iptv/index.m3u"),
//        M3UModel(name: "China", m3uURL: "https://iptv-org.github.io/iptv/countries/cn.m3u"),
//        M3UModel(name: "Hong Kong", m3uURL: "https://iptv-org.github.io/iptv/countries/hk.m3u"),
//        M3UModel(name: "Taiwan", m3uURL: "https://iptv-org.github.io/iptv/countries/tw.m3u"),
//        M3UModel(name: "Americas", m3uURL: "https://iptv-org.github.io/iptv/regions/amer.m3u"),
//        M3UModel(name: "Asia", m3uURL: "https://iptv-org.github.io/iptv/regions/asia.m3u"),
//        M3UModel(name: "Europe", m3uURL: "https://iptv-org.github.io/iptv/regions/eur.m3u"),
//        M3UModel(name: "Education", m3uURL: "https://iptv-org.github.io/iptv/categories/education.m3u"),
//        M3UModel(name: "Movies", m3uURL: "https://iptv-org.github.io/iptv/categories/movies.m3u"),
//        M3UModel(name: "Chinese", m3uURL: "https://iptv-org.github.io/iptv/languages/zho.m3u"),
//        M3UModel(name: "English", m3uURL: "https://iptv-org.github.io/iptv/languages/eng.m3u"),
//    "https://raw.githubusercontent.com/kingslay/KSPlayer/develop/Tests/KSPlayerTests/test.m3u"
//    ]
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
