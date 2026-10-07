//
//  SwiftUIView.swift
//  Player2
//
//  Created by kintan on 7/19/25.
//
import KSPlayer
import KSPlayerUI
import Libavformat
import SwiftUI

@main
struct TestcameraApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            CameraView()
        }
    }
}

struct CameraView: View {
    let options = MEOptions()

    var body: some View {
        VStack {
            let url = "https://raw.githubusercontent.com/kingslay/TestVideo/main/subrip.mkv"
//            let url = "rtsp://localhost:8554/mystream"
            KSVideoPlayerView(url: URL(string: url)!, options: options)
        }
    }
}

class MEOptions: KSOptions, @unchecked Sendable {
    override nonisolated func resolveIO(for url: URL, interrupt _: AVIOInterruptCB) async -> Either<URL, AbstractAVIOContext> {
        formatContextOptions["rtsp_transport"] = "tcp"
        return .left(url)
    }
}
