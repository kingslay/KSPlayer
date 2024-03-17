//
//  KSVideoPlayerViewBuilder.swift
//
//
//  Created by Ian Magallan Bosch on 17.03.24.
//

import SwiftUI

enum KSVideoPlayerViewBuilder {
    
    @MainActor
    static func playbackControlView(config: KSVideoPlayer.Coordinator) -> some View {
        HStack {
            Spacer()
            if config.playerLayer?.player.seekable ?? false {
                Button {
                    config.skip(interval: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.largeTitle)
                }
                #if !os(tvOS)
                .keyboardShortcut(.leftArrow, modifiers: .none)
                #endif
            }
            Spacer()
            Button {
                if config.state.isPlaying {
                    config.playerLayer?.pause()
                } else {
                    config.playerLayer?.play()
                }
            } label: {
                Image(systemName: config.state == .error ? playSlashSystemName : (config.state.isPlaying ? pauseSystemName : playSystemName))
                    .font(.largeTitle)
            }
            #if !os(tvOS)
            .keyboardShortcut(.space, modifiers: .none)
            #endif
            Spacer()
            if config.playerLayer?.player.seekable ?? false {
                Button {
                    config.skip(interval: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.largeTitle)
                }
                #if !os(tvOS)
                .keyboardShortcut(.rightArrow, modifiers: .none)
                #endif
            }
            Spacer()
        }
    }
}

private extension KSVideoPlayerViewBuilder {
    
    private static var playSlashSystemName: String {
        #if os(xrOS)
        "play.slash"
        #else
        "play.slash.fill"
        #endif
    }

    private static var playSystemName: String {
        #if os(xrOS)
        "play"
        #else
        "play.circle.fill"
        #endif
    }

    private static var pauseSystemName: String {
        #if os(xrOS)
        "pause"
        #else
        "pause.circle.fill"
        #endif
    }
}
