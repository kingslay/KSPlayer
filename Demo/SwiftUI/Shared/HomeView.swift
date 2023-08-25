import KSPlayer
import SwiftUI
struct HomeView: View {
    @EnvironmentObject
    private var appModel: APPModel
    @State
    private var nameFilter: String = ""
    @State
    private var groupFilter: String?
    @Default(\.showRecentPlayList)
    private var showRecentPlayList
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @FetchRequest(fetchRequest: PlayModel.playTimeRequest)
    private var historyModels: FetchedResults<PlayModel>

    var body: some View {
        ScrollView {
            #if os(tvOS)
            HStack {
                toolbarView
            }
            #endif
            if showRecentPlayList {
                Section {
                    ScrollView(.horizontal) {
                        LazyHStack {
                            ForEach(historyModels) { model in
                                appModel.content(model: model)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Play").font(.title)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: MoiveView.width))]) {
                    let playlist = appModel.playlist.filter { model in
                        var isIncluded = true
                        if !nameFilter.isEmpty {
                            isIncluded = model.name!.contains(nameFilter)
                        }
                        if let groupFilter {
                            isIncluded = isIncluded && model.group == groupFilter
                        }
                        return isIncluded
                    }
                    ForEach(playlist) { model in
                        appModel.content(model: model)
                    }
                }

            } header: {
                HStack {
                    Text("Channels").font(.title)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .searchable(text: $nameFilter)
        #if !os(tvOS)
            .toolbar {
                toolbarView
            }
        #endif
    }

    private var toolbarView: some View {
        Group {
            Button {
                appModel.openFileImport = true
            } label: {
                Label("Open File", systemImage: "plus.rectangle.on.folder.fill")
            }
            #if !os(tvOS)
            .keyboardShortcut("o")
            #endif
            Button {
                appModel.openURLImport = true
            } label: {
                Label("Open URL", systemImage: "plus.app.fill")
            }
            #if !os(tvOS)
            .keyboardShortcut("o", modifiers: [.command, .shift])
            #endif

            Picker("group filter", selection: $groupFilter) {
                Text("All").tag(nil as String?)
                ForEach(appModel.groups) { group in
                    Text(group).tag(group as String?)
                }
            }
            #if os(tvOS)
            .pickerStyle(.navigationLink)
            #endif
        }
        .labelStyle(.titleAndIcon)
    }
}

struct MoiveView: View {
    static let width: CGFloat = {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return min(KSOptions.sceneSize.width, KSOptions.sceneSize.height) / 3 - 20
        } else {
            return min(KSOptions.sceneSize.width, KSOptions.sceneSize.height) / 2 - 20
        }
        #elseif os(tvOS)
        return KSOptions.sceneSize.width / 4 - 150
        #else
        return CGFloat(192)
        #endif
    }()

    @ObservedObject var model: PlayModel
    var body: some View {
        VStack {
            image
            Text(model.name!).lineLimit(1)
        }
        .frame(width: MoiveView.width)
        .contextMenu {
            Button {
                model.isFavorite.toggle()
                try? model.managedObjectContext?.save()
            } label: {
                Label(model.isFavorite ? "Cancel favorite" : "Favorite", systemImage: model.isFavorite ? "star" : "star.fill")
            }
            #if !os(tvOS)
            Button {
                #if os(macOS)
                UIPasteboard.general.clearContents()
                UIPasteboard.general.setString(model.url!.description, forType: .string)
                #else
                UIPasteboard.general.setValue(model.url!, forPasteboardType: "public.url")
                #endif
            } label: {
                Label("Copy url", systemImage: "doc.on.doc.fill")
            }
            #endif
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
