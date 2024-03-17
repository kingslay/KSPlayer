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
                Image(systemName: config.state == .error ? "play.slash.fill" : (config.state.isPlaying ? pauseSystemName : playSystemName))
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
    
    @MainActor
    static func contentModeButton(config: KSVideoPlayer.Coordinator) -> some View {
        Button {
            config.isScaleAspectFill.toggle()
        } label: {
            Image(systemName: config.isScaleAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
        }
    }
}

private extension KSVideoPlayerViewBuilder {

    static var playSystemName: String {
        #if os(xrOS)
        "play.fill"
        #else
        "play.circle.fill"
        #endif
    }

    static var pauseSystemName: String {
        #if os(xrOS)
        "pause"
        #else
        "pause.circle.fill"
        #endif
    }
}
