import KSPlayer
import SwiftUI
struct HomeView: View {
    @EnvironmentObject
    private var appModel: APPModel
    @State
    private var nameFilter: String = ""
    @State
    private var groupFilter: String = ""
    @Default(\.showRecentPlayList)
    private var showRecentPlayList
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @FetchRequest(fetchRequest: PlayModel.playTimeRequest)
    private var historyModels: FetchedResults<PlayModel>

    var body: some View {
        ScrollView {
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
            }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: MoiveView.width))]) {
                    let playlist = appModel.playlist.filter { model in
                        var isIncluded = true
                        if nameFilter.count > 0 {
                            isIncluded = model.name!.contains(nameFilter)
                        }
                        if groupFilter.count > 0 {
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
        }
        .padding()
        .toolbar {
            Button {
                appModel.openFileImport = true
            } label: {
                Text("Open File")
            }
            #if !os(tvOS)
            .keyboardShortcut("o")
            #endif
            Button {
                appModel.openURLImport = true
            } label: {
                Text("Open URL")
            }
            #if !os(tvOS)
            .keyboardShortcut("o", modifiers: [.command, .shift])
            #endif
            Picker("group filter", selection: $groupFilter) {
                Text("All ").tag("")
                ForEach(appModel.groups) { group in
                    Text(group).tag(group)
                }
            }
            #if os(tvOS)
//                    .pickerStyle(.menu)
            #endif
        }
        #if !os(tvOS)
        .searchable(text: $nameFilter)
        #endif
    }
}

struct MoiveView: View {
    #if os(iOS)
    static let width = min(KSOptions.sceneSize.width, KSOptions.sceneSize.height) / 2 - 20
    #elseif os(tvOS)
    static let width = KSOptions.sceneSize.width / 4 - 150
    #else
    static let width = CGFloat(192)
    #endif
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
