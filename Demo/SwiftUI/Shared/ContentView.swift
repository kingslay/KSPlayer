import KSPlayer
import SwiftUI
struct ContentView: View {
    var body: some View {
        #if os(macOS)
        HomeView()
        #else
        TabView {
            HomeView()
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
}

struct HomeView: View {
    @EnvironmentObject private var appModel: APPModel
    var body: some View {
        NavigationStack(path: $appModel.path) {
            InitialView()
                .navigationDestination(for: MovieModel.self) { model in
                    KSVideoPlayerView(model: model)
                    #if !os(macOS)
                        .toolbar(.hidden, for: .tabBar)
                    #endif
                }
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
        .sheet(isPresented: $appModel.openURLImport) {
            URLImportView()
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
    }
}

extension KSVideoPlayerView {
    init(model: MovieModel) {
        let key = "playtime_\(model.url)"
        model.options.startPlayTime = UserDefaults.standard.double(forKey: key)
        self.init(url: model.url, options: model.options) { layer in
            if let layer {
                if layer.player.duration > 0, layer.player.currentPlaybackTime > 0, layer.state != .playedToTheEnd, layer.player.duration > layer.player.currentPlaybackTime + 120 {
                    UserDefaults.standard.set(layer.player.currentPlaybackTime, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }
}
