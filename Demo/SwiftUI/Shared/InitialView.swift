import KSPlayer
import SwiftUI
struct InitialView: View {
    @EnvironmentObject private var appModel: APPModel
    init() {}

    var body: some View {
        List {
            Button {
                appModel.openFileImport = true
            } label: {
                HStack {
                    Text("打开...")
                    Spacer()
                    Text("⌘O")
                }
            }
            Button {
                appModel.openURLImport = true
            } label: {
                HStack {
                    Text("打开URL...")
                    Spacer()
                    Text("⇧⌘O")
                }
            }
            ForEach(appModel.playlist, id: \.self) { resource in
                #if os(macOS)
                Button {
                    appModel.url = resource.definitions[0].url
                } label: {
                    Text(resource.name)
                    Spacer()
                }
                #else
                NavigationLink(resource.name, destination: KSVideoPlayerView(resource: resource))
                #endif
            }
        }
        .onOpenURL { url in
            appModel.url = url
        }
    }
}

extension KSVideoPlayerView {
    init(resource: KSPlayerResource) {
        let definition = resource.definitions.first!
        self.init(url: definition.url, options: definition.options)
    }
}
