import KSPlayer
import SwiftUI
struct ContentView: View {
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
        .onOpenURL { url in
            appModel.open(url: url)
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
