//
//  PipPlayerView.swift
//  KSPlayer
//
//  Created by kintan on 11/4/24.
//

import Foundation
import KSPlayer
import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct PipPlayerView: View {
    private let playerLayer: KSPlayerLayer
    @Binding
    private var alignment: Alignment
    private let block: (Bool) -> Void
    @FocusState
    private var focusableView: FocusableView?
    @State
    private var isMuted: Bool
    public init(playerLayer: KSPlayerLayer, alignment: Binding<Alignment>, focusableView: FocusState<FocusableView?>, block: @escaping (Bool) -> Void) {
        self.playerLayer = playerLayer
        _alignment = alignment
        _focusableView = focusableView
        self.block = block
        isMuted = playerLayer.player.isMuted
    }

    public var body: some View {
        KSVideoPlayer(playerLayer: playerLayer)
            .overlay {
                HStack {
                    Button {
                        block(true)
                    } label: {
                        Image(systemName: "pip.exit")
                    }
                    .focused($focusableView, equals: .pipFull)
                    Button {
                        block(false)
                    } label: {
                        Image(systemName: "x.circle.fill")
                    }
                    .focused($focusableView, equals: .pipClose)
                    Button {
                        if alignment == .topTrailing {
                            alignment = .topLeading
                        } else if alignment == .topLeading {
                            alignment = .bottomLeading
                        } else if alignment == .bottomLeading {
                            alignment = .bottomTrailing
                        } else {
                            alignment = .topTrailing
                        }
                    } label: {
                        switch alignment {
                        case .topTrailing:
                            return Image(systemName: "inset.filled.topleading.rectangle")
                        case .topLeading:
                            return Image(systemName: "inset.filled.bottomleading.rectangle")
                        case .bottomLeading:
                            return Image(systemName: "inset.filled.bottomtrailing.rectangle")
                        default:
                            return Image(systemName: "inset.filled.toptrailing.rectangle")
                        }
                    }
                    .focused($focusableView, equals: .pipMove)
                    Button {
                        playerLayer.player.isMuted.toggle()
                        isMuted = playerLayer.player.isMuted
                    } label: {
                        Image(systemName: isMuted ? KSVideoPlayerViewBuilder.speakerDisabledSystemName : KSVideoPlayerViewBuilder.speakerSystemName)
                    }
                    .focused($focusableView, equals: .mute)
                }
                .opacity(focusableView == nil ? 0 : 1)
            }
    }

    public enum FocusableView {
        case pipFull, pipClose, pipMove, mute
    }
}
