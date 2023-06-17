import KSPlayer
import SwiftUI
struct InitialView: View {
    @EnvironmentObject private var appModel: APPModel
    @Environment(\.openWindow) var openWindow
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private let columns = [GridItem(.adaptive(minimum: MoiveView.width))]
    init() {}

    var body: some View {
        HStack {
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
        }
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(appModel.playlist, id: \.self) { resource in
                    NavigationLink(value: resource) {
                        MoiveView(model: resource)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct MoiveView: View {
    #if os(iOS)
    static let width = CGFloat(320)
    #else
    static let width = CGFloat(320)
    #endif
    let model: MovieModel
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: model.logo) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray
            }.frame(width: MoiveView.width, height: MoiveView.width / 16 * 9)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(model.name)
        }
        .frame(width: MoiveView.width)
    }
}
