import KSPlayer
import SwiftUI
struct ContentView: View {
    #if !os(tvOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @EnvironmentObject private var appModel: APPModel
    var body: some View {
        Group {
            #if os(macOS)
            HomeView()
            #else
            TabView {
                NavigationStack(path: $appModel.path) {
                    HomeView()
                        .navigationDestination(for: URL.self) { url in
                            KSVideoPlayerView(url: url)
                            #if !os(macOS)
                                .toolbar(.hidden, for: .tabBar)
                            #endif
                        }
                }

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
        .background(Color.black)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $appModel.openURLImport) {
            URLImportView()
        }
        .onChange(of: appModel.openWindow) { url in
            if let url {
                #if !os(tvOS)
                openWindow(value: url)
                #endif
                appModel.openWindow = nil
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
            if url.isPlaylist {
                appModel.replaceM3U(url: url)
            } else {
                #if os(macOS)
                openWindow(value: url)
                #else
                appModel.path.append(MovieModel(url: url))
                #endif
            }
        }
    }
}
