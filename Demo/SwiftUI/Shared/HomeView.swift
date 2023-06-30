import KSPlayer
import SwiftUI
struct HomeView: View {
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
                        ForEach(recentDocumentURLs) { url in
                            content(model: MovieModel(url: url))
                        }
                    } header: {
                        HStack {
                            Text("Recent Document").font(.title)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                let playlist = appModel.playlist.filter { model in
                    var isIncluded = true
                    if appModel.nameFilter.count > 0 {
                        isIncluded = model.name.contains(appModel.nameFilter)
                    }
                    if appModel.groupFilter.count > 0 {
                        isIncluded = isIncluded && model.group == appModel.groupFilter
                    }
                    return isIncluded
                }
                Section {
                    ForEach(playlist) { model in
                        content(model: model)
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
                ForEach(appModel.groups) { group in
                    Text(group).tag(group)
                }
            }
        }
    }

    private func content(model: MovieModel) -> some View {
        #if os(macOS)
        MoiveView(model: model)
            .onTapGesture {
                appModel.open(url: model.url)
            }
        #else
        NavigationLink(value: model.url) {
            MoiveView(model: model)
        }
        .buttonStyle(.plain)
        #endif
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
