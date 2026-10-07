//
//  ImmersiveView.swift
//  Player
//
//  Created by BM on 2024/7/16.
//

import Combine
import KSPlayer
import SwiftUI

#if os(visionOS)
import RealityKit

struct ImmersiveView: View {
    @Binding var url: String?

    @State var view: KSMEPlayer?
    @AppStorage("is360Play")
    private var is360Play = false

    var body: some View {
        RealityView { content in
            if let url = URL(string: url ?? "") {
                let options = KSOptions()
                let player = KSMEPlayer(url: url, options: options)
                view = player
                let displayLayer = player.videoOutput.displayLayer
                if is360Play {
                    let videoEntity = Entity()
                    let material = VideoMaterial(videoRenderer: displayLayer.sampleBufferRenderer)
                    let geometry = MeshResource.generateSphere(radius: 1e3)
                    videoEntity.components.set(ModelComponent(mesh: geometry, materials: [material]))
                    videoEntity.scale *= SIMD3(1, 1, -1)
                    videoEntity.orientation *= simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
                    content.add(videoEntity)
                } else {
                    let videoEntity = Entity()
                    let material = VideoMaterial(videoRenderer: displayLayer.sampleBufferRenderer)
                    let boxMesh = MeshResource.generatePlane(width: 16, height: 9)
                    videoEntity.components.set(ModelComponent(mesh: boxMesh, materials: [material]))

                    videoEntity.transform.translation = [0, 2.5, -5]
                    content.add(videoEntity)
                }

                player.prepareToPlay()
                player.play()
            }
        }
        .onDisappear {
            view = nil
        }
    }
}
#endif
