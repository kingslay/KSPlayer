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
        framebufferOnly = false
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
        if let frame = frame as? VideoVTBFrame, let pixelBuffer = frame.corePixelBuffer {
            renderSource?.setVideo(time: frame.cmtime)
            drawableSize = display == .plane ? pixelBuffer.drawableSize : UIScreen.size
            guard isOutput, let drawable = currentDrawable, let renderPassDescriptor = currentRenderPassDescriptor else {
                return
            }
            let textures = pixelBuffer.textures(frome: textureCache)
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            guard let commandBuffer = MetalRender.share.draw(pixelBuffer: pixelBuffer, display: display, inputTextures: textures, renderPassDescriptor: renderPassDescriptor) else {
                return
            }
            //        commandBuffer.present(drawable)
            commandBuffer.addScheduledHandler { _ in
                drawable.present()
                frame.corePixelBuffer = nil
            }
            commandBuffer.commit()
//            commandBuffer.waitUntilCompleted()
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
