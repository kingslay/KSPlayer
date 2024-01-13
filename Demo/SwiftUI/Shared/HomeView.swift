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
    @FetchRequest(fetchRequest: MovieModel.playTimeRequest)
    private var historyModels: FetchedResults<MovieModel>
    @FetchRequest
    private var movieModels: FetchedResults<MovieModel>
    init(m3uURL: URL?) {
        let request = MovieModel.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MovieModel.name, ascending: true)]
        request.predicate = NSPredicate(format: "m3uURL == %@  && name != nil ", m3uURL?.description ?? "nil")
        _movieModels = FetchRequest<MovieModel>(fetchRequest: request)
    }

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
                    let playlist = movieModels.filter { model in
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
        #if !os(tvOS)
        // tvos如果加searchable。那就会导致滚动错乱，所以只能去掉了
        .searchable(text: $nameFilter)
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
            let groups = movieModels.reduce(Set<String>()) { partialResult, model in
                if let group = model.group {
                    var set = partialResult
                    set.insert(group)
                    return set
                } else {
                    return partialResult
                }
            }.sorted()
            Picker("group filter", selection: $groupFilter) {
                Text("All").tag(nil as String?)
                ForEach(groups) { group in
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
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return min(KSOptions.sceneSize.width, KSOptions.sceneSize.height) / 2 - 20
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            return min(KSOptions.sceneSize.width, KSOptions.sceneSize.height) / 3 - 20
        } else if UIDevice.current.userInterfaceIdiom == .tv {
            return KSOptions.sceneSize.width / 4 - 150
        } else if UIDevice.current.userInterfaceIdiom == .mac {
            return CGFloat(192)
        } else {
            return CGFloat(192)
        }
        #else
        return CGFloat(192)
        #endif
    }()

    @ObservedObject var model: MovieModel
    var body: some View {
        VStack {
            image
            Text(model.name ?? "").lineLimit(1)
        }
        .frame(width: MoiveView.width)
        .contextMenu {
            Button {
                model.isFavorite.toggle()
                try? model.managedObjectContext?.save()
            } label: {
                let isFavorite = model.isFavorite
                Label(isFavorite ? "Cancel favorite" : "Favorite", systemImage: isFavorite ? "star" : "star.fill")
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
