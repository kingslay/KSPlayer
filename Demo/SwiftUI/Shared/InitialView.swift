import KSPlayer
import SwiftUI
struct InitialView: View {
    @EnvironmentObject private var appModel: APPModel
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private let columns = [GridItem(.adaptive(minimum: MoiveView.width))]
    init() {}

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(appModel.filterParsePlaylist(), id: \.self) { resource in
                    NavigationLink(value: resource) {
                        MoiveView(model: resource)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $appModel.nameFilter)
        .toolbar {
            Button {
                appModel.openFileImport = true
            } label: {
                Text("打开文件")
            }
            Button {
                appModel.openURLImport = true
            } label: {
                Text("打开URL")
            }
            Picker("group filter", selection: $appModel.groupFilter) {
                Text("All ").tag("")
                ForEach(appModel.groups, id: \.self) { group in
                    Text(group).tag(group)
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
