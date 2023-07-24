import KSPlayer
import SwiftUI
struct ContentView: View {
    #if !os(tvOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @EnvironmentObject private var appModel: APPModel
    private var initialView: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $appModel.tabSelected) {
                link(to: .Home)
                link(to: .Favorite)
                link(to: .Files)
            }
        } detail: {
            appModel.tabSelected.destination
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
            .background(Color.black)
            .preferredColorScheme(.dark)
            .accentColor(.white)
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
                        DispatchQueue.main.async {
                            appModel.open(url: url)
                        }
                    }
                }
                return true
            }
            .fileImporter(isPresented: $appModel.openFileImport, allowedContentTypes: [.movie, .audio, .data]) { result in
                guard let url = try? result.get() else {
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
        NavigationLink(value: item) {
            item.lable
        }
        .tag(item)
    }

    func tab(to item: TabBarItem) -> some View {
        NavigationStack(path: $appModel.path) {
            item.destination
                .navigationPlay()
        }
        .tabItem {
            item.lable
        }
        .tag(item)
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
            return Label("Home", systemImage: "house.fill")
        case .Favorite:
            return Label("Favorite", systemImage: "star.fill")
        case .Files:
            return Label("Files", systemImage: "folder.fill.badge.gearshape")
        case .Setting:
            return Label("Setting", systemImage: "gear")
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .Home:
            HomeView()
        case .Favorite:
            FavoriteView()
        case .Files:
            FilesView()
        case .Setting:
            SettingView()
        }
    }
}

public extension View {
    @ViewBuilder
    func navigationPlay() -> some View {
        navigationDestination(for: URL.self) { url in
            KSVideoPlayerView(url: url)
            #if !os(macOS)
                .toolbar(.hidden, for: .tabBar)
            #endif
        }
        .navigationDestination(for: PlayModel.self) { model in
            KSVideoPlayerView(model: model)
            #if !os(tvOS)
                .navigationTitle(model.name!)
            #endif
            #if !os(macOS)
            .toolbar(.hidden, for: .tabBar)
            #endif
        }
    }
}
