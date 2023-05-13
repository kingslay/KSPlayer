import KSPlayer
import SwiftUI
struct InitialView: View {
    @EnvironmentObject private var appModel: APPModel
    init() {}

    var body: some View {
        VStack {
            Button {
                appModel.openFileImport = true
            } label: {
                Text("打开...")
                Spacer()
                Text("⌘O")
            }
            Button {
                appModel.openURLImport = true
            } label: {
                Text("打开URL...")
                Spacer()
                Text("⇧⌘O")
            }
            List {
                ForEach(appModel.playlist, id: \.self) { resource in
                    Button {
                        appModel.url = resource.definitions[0].url
                    } label: {
                        Text(resource.name)
                        Spacer()
                    }
                }
            }
        }
    }
}
