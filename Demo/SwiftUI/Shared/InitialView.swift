import KSPlayer
import SwiftUI
struct InitialView: View {
    @EnvironmentObject private var appModel: APPModel
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private let columns = [GridItem(.adaptive(minimum: MoiveView.width))]
    private var recentDocumentURLs = [URL]()
    init() {
        #if os(macOS)
        for url in NSDocumentController.shared.recentDocumentURLs {
            recentDocumentURLs.append(url)
        }
        #endif
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                if recentDocumentURLs.count > 0 {
                    Section {
                        ForEach(recentDocumentURLs, id: \.self) { url in
                            let mode = MovieModel(url: url)
                            NavigationLink(value: mode) {
                                MoiveView(model: mode)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("Recent Document").font(.title)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                let playlist = appModel.filterParsePlaylist()
                Section {
                    ForEach(playlist, id: \.self) { resource in
                        NavigationLink(value: resource) {
                            MoiveView(model: resource)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Channels").font(.title)
                        Spacer()
                    }
                    .padding()
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
    static let width = KSOptions.sceneSize.width - 30
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
