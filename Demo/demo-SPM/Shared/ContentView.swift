//
//  ContentView.swift
//  Shared
//
//  Created by kintan on 2021/5/3.
//

import KSPlayer
import SwiftUI
struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct StructPlayerView: UIViewRepresentable {
    typealias UIViewType = VideoPlayerView
    var resource: KSPlayerResource?
    func makeUIView(context _: UIViewRepresentableContext<StructPlayerView>) -> VideoPlayerView {
        IOSVideoPlayerView()
    }

    func updateUIView(_ uiView: VideoPlayerView, context _: UIViewRepresentableContext<StructPlayerView>) {
        if let resource = resource {
            uiView.set(resource: resource)
        }
    }
}
