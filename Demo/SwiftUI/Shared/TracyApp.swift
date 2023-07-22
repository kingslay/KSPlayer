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
            CommandGroup(before: .newItem) {
                Button("Open") {
                    appModel.openFileImport = true
                }
                .keyboardShortcut("o")
            }
            CommandGroup(before: .newItem) {
                Button("Open URL") {
                    appModel.openURLImport = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
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
                    .navigationTitle(model.name!)
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

    @Published var tabSelected: TabBarItem = .Files
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
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        _ = Defaults.shared
        KSOptions.subtitleDataSouces = [DirectorySubtitleDataSouce(), ShooterSubtitleDataSouce(), AssrtSubtitleDataSouce(token: "5IzWrb2J099vmA96ECQXwdRSe9xdoBUv")]
        if let activeM3UURL {
            addM3U(url: activeM3UURL)
            tabSelected = .Home
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
        .buttonStyle(.automatic)
        #endif
    }
}

struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(APPModel())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
