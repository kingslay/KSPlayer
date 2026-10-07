import KSPlayer
import KSPlayerUI
import SwiftUI

struct ContentView: View {
    #if !os(tvOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @EnvironmentObject
    private var appModel: APPModel
    private var initialView: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $appModel.tabSelected) {
                link(to: .Home)
                link(to: .Favorite)
                link(to: .Files)
            }
        } detail: {
            NavigationStack(path: $appModel.path) {
                appModel.tabSelected.destination(appModel: appModel)
            }
        }
        #else
        TabView(selection: $appModel.tabSelected) {
            tab(to: .Home)
            tab(to: .Favorite)
            tab(to: .Files)
            tab(to: .Setting)
        }
        #endif
    }

    var body: some View {
        initialView
            .preferredColorScheme(.dark)
            .background(Color.black)
            .sheet(isPresented: $appModel.openURLImport) {
                URLImportView()
            }
            .onChange(of: appModel.openURL) { url in
                if let url {
                    #if !os(tvOS)
                    openWindow(value: url)
                    #endif
                    appModel.openURL = nil
                }
            }
            .onChange(of: appModel.openPlayModel) { model in
                if let model {
                    #if !os(tvOS)
                    openWindow(value: model)
                    #endif
                    appModel.openPlayModel = nil
                }
            }
        #if !os(tvOS)
            .onDrop(of: ["public.url", "public.file-url"], isTargeted: nil) { items -> Bool in
                guard let item = items.first, let identifier = item.registeredTypeIdentifiers.first else {
                    return false
                }
                item.loadItem(forTypeIdentifier: identifier, options: nil) { urlData, _ in
                    if let urlData = urlData as? Data {
                        let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                        Task { @MainActor in
                            appModel.open(url: url)
                        }
                    }
                }
                return true
        }
        .fileImporter(isPresented: $appModel.openFileImport, allowedContentTypes: [.movie, .audio, .data]) { result in
            guard let url = try? result.get(), url.startAccessingSecurityScopedResource() else {
                return
            }
            appModel.open(url: url)
        }
        #endif
        .onOpenURL { url in
            KSLog("onOpenURL")
            appModel.open(url: url)
        }
    }

    func link(to item: TabBarItem) -> some View {
        item.lable.tag(item)
    }

    func tab(to item: TabBarItem) -> some View {
        Group {
            if item == .Home {
                NavigationStack(path: $appModel.path) {
                    item.destination(appModel: appModel)
                }

            } else {
                NavigationStack {
                    item.destination(appModel: appModel)
                }
            }
        }
        .tabItem {
            item.lable.tag(item)
        }.tag(item)
    }
}

enum TabBarItem: Int {
    case Home
    case Favorite
    case Files
    case Setting
    var lable: Label<Text, Image> {
        switch self {
        case .Home:
            Label("Home", systemImage: "house.fill")
        case .Favorite:
            Label("Favorite", systemImage: "star.fill")
        case .Files:
            Label("Files", systemImage: "folder.fill.badge.gearshape")
        case .Setting:
            Label("Setting", systemImage: "gear")
        }
    }

    @MainActor
    @ViewBuilder
    func destination(appModel: APPModel) -> some View {
        switch self {
        case .Home:
            HomeView(m3uURL: appModel.activeM3UModel?.m3uURL)
                .navigationPlay()
        case .Favorite:
            FavoriteView()
                .navigationPlay()
        case .Files:
            FilesView()
        case .Setting:
            SettingView()
                .navigationPlay()
        }
    }
}

public extension View {
    @MainActor
    func navigationPlay() -> some View {
        navigationDestination(for: URL.self) { url in
            KSVideoPlayerView(url: url)
            #if !os(macOS)
            .toolbar(.hidden, for: .tabBar)
            #endif
        }
        .navigationDestination(for: MovieModel.self) { model in
            model.view
        }
    }
}

extension MovieModel {
    @MainActor
    var view: some View {
//        KSAudioPlayerView(url: url!, options: MEOptions())
//        #if os(iOS)
//        KSIOSVideoPlayerView(url: url!, options: MEOptions())
//        #endif
        KSVideoPlayerView(model: self)
        #if !os(macOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }
}

#if os(iOS)
struct KSIOSVideoPlayerView: View, UIViewRepresentable {
    let url: URL
    let options: KSOptions
    typealias UIViewType = IOSVideoPlayerView
    init(url: URL, options: KSOptions) {
        self.url = url
        self.options = options
    }

    func makeUIView(context _: Context) -> UIViewType {
        IOSVideoPlayerView()
    }

    func updateUIView(_ view: UIViewType, context _: Context) {
        view.set(url: url, options: options)
    }

    /// iOS tvOS真机先调用onDisappear在调用dismantleUIView，但是模拟器就反过来了。
    static func dismantleUIView(_: UIViewType, coordinator _: Coordinator) {}
}
#endif
struct KSAudioPlayerView: View, UIViewRepresentable {
    let url: URL
    let options: KSOptions
    #if canImport(UIKit)
    typealias UIViewType = AudioPlayerView
    func makeUIView(context _: Context) -> UIViewType {
        let view = AudioPlayerView()
        view.set(url: url, options: options)
        return view
    }

    func updateUIView(_: UIViewType, context _: Context) {}

    /// iOS tvOS真机先调用onDisappear在调用dismantleUIView，但是模拟器就反过来了。
    static func dismantleUIView(_ view: UIViewType, coordinator _: Coordinator) {
        view.resetPlayer()
    }

    #else
    typealias NSViewType = AudioPlayerView
    func makeNSView(context _: Context) -> NSViewType {
        let view = AudioPlayerView()
        view.set(url: url, options: options)
        return view
    }

    func updateNSView(_: NSViewType, context _: Context) {}

    /// macOS先调用onDisappear在调用dismantleNSView
    static func dismantleNSView(_ view: NSViewType, coordinator _: Coordinator) {
        view.resetPlayer()
    }
    #endif
}
