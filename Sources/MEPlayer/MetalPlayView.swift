//
//  MetalPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import CoreMedia
import MetalKit

final class MetalPlayView: MTKView, MTKViewDelegate, FrameOutput {
    private let textureCache = MetalTextureCache()
    var display: DisplayEnum = .plane
    weak var renderSource: OutputRenderSourceDelegate?
    var isOutput = true
    init() {
        let device = MetalRender.share.device
        super.init(frame: .zero, device: device)
        framebufferOnly = true
        autoResizeDrawable = false
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        delegate = self
        preferredFramesPerSecond = KSPlayerManager.preferredFramesPerSecond
    }

    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play() {
        isPaused = false
    }

    func pause() {
        isPaused = true
    }

    func flush() {}

    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in _: MTKView) {
        if let frame = renderSource?.getOutputRender(type: .video, isDependent: true) {
            draw(frame: frame)
        }
    }

    func draw(frame: MEFrame) {
        if let frame = frame as? VideoVTBFrame {
            renderSource?.setVideo(time: frame.cmtime)
            let textures = frame.textures
            let size = display == .plane ? frame.drawableSize : UIScreen.size
            if drawableSize != size {
                drawableSize = size
            }
            guard isOutput, textures.count > 0, let drawable = currentDrawable, let renderPassDescriptor = currentRenderPassDescriptor else {
                return
            }
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            guard let commandBuffer = MetalRender.share.draw(pixelBuffer: frame, display: display, inputTextures: textures, renderPassDescriptor: renderPassDescriptor) else {
                return
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }

    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
    override func touchesMoved(_ touches: Set<UITouch>, with: UIEvent?) {
        if display == .plane {
            super.touchesMoved(touches, with: with)
        } else {
            display.touchesMoved(touch: touches.first!)
        }
    }
    #endif
}
