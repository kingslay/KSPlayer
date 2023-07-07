import KSPlayer
import SwiftUI
struct ContentView: View {
    #if !os(tvOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @EnvironmentObject private var appModel: APPModel
    private var initialView: some View {
        #if os(macOS)
        NavigationView {
            List(selection: $appModel.tabSelected) {
                NavigationLink {
                    HomeView()
                } label: {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(TabBarItem.Home)
                NavigationLink {
                    FavoriteView()
                } label: {
                    Label("Favorite", systemImage: "star.fill")
                }
                .tag(TabBarItem.Favorite)
                NavigationLink {
                    FilesView()
                } label: {
                    Label("Files", systemImage: "folder.fill.badge.gearshape")
                }
                .tag(TabBarItem.Files)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                } label: {
                    Image(systemName: "sidebar.leading")
                }
            }
        }
        #else
        TabView(selection: $appModel.tabSelected) {
            NavigationStack(path: $appModel.path) {
                HomeView()
                    .navigationDestination(for: URL.self) { url in
                        KSVideoPlayerView(url: url)
                        #if !os(macOS)
                            .toolbar(.hidden, for: .tabBar)
                        #endif
                    }
                    .navigationDestination(for: PlayModel.self) { model in
                        KSVideoPlayerView(model: model)
                        #if !os(macOS)
                            .toolbar(.hidden, for: .tabBar)
                        #endif
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(TabBarItem.Home)
            NavigationStack(path: $appModel.path) {
                FavoriteView()
            }
            .tabItem {
                Label("Favorite", systemImage: "star.fill")
            }
            .tag(TabBarItem.Favorite)
            NavigationStack {
                FilesView()
            }
            .tabItem {
                Label("Files", systemImage: "folder.fill.badge.gearshape")
            }
            .tag(TabBarItem.Files)
            SettingView()
                .tabItem {
                    Label("Setting", systemImage: "gear")
                }
                .tag(TabBarItem.Setting)
        }
        #endif
    }

    var body: some View {
        initialView
            .background(Color.black)
            .preferredColorScheme(.dark)
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
}

enum TabBarItem: Int {
    case Home
    case Favorite
    case Files
    case Setting
}
