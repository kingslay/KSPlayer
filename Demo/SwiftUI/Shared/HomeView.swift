import KSPlayer
import SwiftUI
struct HomeView: View {
    @EnvironmentObject private var appModel: APPModel
    @State var nameFilter: String = ""
    @State var groupFilter: String = ""
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: MoiveView.width))]) {
                Section {
                    ForEach(recentDocumentURLs) { url in
                        appModel.content(model: MovieModel(url: url))
                    }
                } header: {
                    HStack {
                        Text("Recent Document").font(.title)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                let playlist = appModel.playlist.filter { model in
                    var isIncluded = true
                    if nameFilter.count > 0 {
                        isIncluded = model.name.contains(nameFilter)
                    }
                    if groupFilter.count > 0 {
                        isIncluded = isIncluded && model.group == groupFilter
                    }
                    return isIncluded
                }
                Section {
                    ForEach(playlist) { model in
                        appModel.content(model: model)
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
        .searchable(text: $nameFilter)
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
            Picker("group filter", selection: $groupFilter) {
                Text("All ").tag("")
                ForEach(appModel.groups) { group in
                    Text(group).tag(group)
                }
            }
        }
    }
}

struct MoiveView: View {
    #if os(iOS)
    static let width = min(KSOptions.sceneSize.width, KSOptions.sceneSize.height) / 2 - 20
    #elseif os(tvOS)
    static let width = KSOptions.sceneSize.width / 4 - 30
    #else
    static let width = CGFloat(192)
    #endif
    @State var model: MovieModel
    
    var body: some View {
        VStack(alignment: .leading) {
            image
            Text(model.name).lineLimit(1)
        }
        .frame(width: MoiveView.width)
        .contextMenu {
            Button {
                model.isFavorite.toggle()
            } label: {
                Label(model.isFavorite ? "Cancel favorite" : "Favorite", systemImage: model.isFavorite ? "star" : "star.fill")
            }
            Button {
                #if os(macOS)
                UIPasteboard.general.setString(model.url.path, forType: .URL)
                #else
                UIPasteboard.general.setValue(model.url, forPasteboardType: "public.url")
                #endif
            } label: {
                Label("Copy url", systemImage: "doc.on.doc.fill")
            }
        }
    }
    var image: some View {
        AsyncImage(url: model.logo) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Color.gray
        }.frame(width: MoiveView.width, height: MoiveView.width / 16 * 9)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
