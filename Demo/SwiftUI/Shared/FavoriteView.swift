//
//  FavoriteView.swift
//  TracyPlayer
//
//  Created by kintan on 2023/7/2.
//

import SwiftUI

struct FavoriteView: View {
    @EnvironmentObject
    private var appModel: APPModel
    @State
    private var nameFilter: String = ""
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MovieModel.name, ascending: true)],
        predicate: NSPredicate(format: "playmodel.isFavorite == YES")
    )
    private var favoritelist: FetchedResults<MovieModel>
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: MoiveView.width))]) {
                let playlist = favoritelist.filter { model in
                    var isIncluded = true
                    if !nameFilter.isEmpty {
                        isIncluded = model.name!.contains(nameFilter)
                    }
                    return isIncluded
                }
                ForEach(playlist) { model in
                    appModel.content(model: model)
                }
            }
        }
        .padding()
        .searchable(text: $nameFilter)
    }
}
