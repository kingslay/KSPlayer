//
//  FavoriteView.swift
//  TracyPlayer
//
//  Created by kintan on 2023/7/2.
//

import SwiftUI

struct FavoriteView: View {
    @EnvironmentObject private var appModel: APPModel
    @State var nameFilter: String = ""
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: MoiveView.width))]) {
                let playlist = appModel.favoritelist.filter { model in
                    var isIncluded = true
                    if nameFilter.count > 0 {
                        isIncluded = model.name.contains(nameFilter)
                    }
                    return isIncluded
                }
                ForEach(playlist) { model in
                    appModel.content(model: model)
                }
            }
        }
        .searchable(text: $nameFilter)
    }
}
