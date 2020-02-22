//
//  ContentView.swift
//  demo-SwiftUI
//
//  Created by wangjinbian on 2020/2/21.
//  Copyright © 2020 wangjinbian. All rights reserved.
//

import KSPlayer
import SwiftUI
struct ContentView: View {
    var body: some View {
        StructPlayerView()
    }
}

struct StructPlayerView: UIViewRepresentable {
    typealias UIViewType = PlayerView

    func makeUIView(context _: UIViewRepresentableContext<StructPlayerView>) -> PlayerView {
        IOSVideoPlayerView()
    }

    func updateUIView(_ uiView: PlayerView, context _: UIViewRepresentableContext<StructPlayerView>) {
        uiView.set(url: URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!, options: KSOptions())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
