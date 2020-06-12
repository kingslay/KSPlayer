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
    private var needsClear = false
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    var display: DisplayEnum = .plane
    weak var renderSource: OutputRenderSourceDelegate?
    var isOutput = true
    init() {
        let device = MetalRender.share.device
        super.init(frame: .zero, device: device)
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        framebufferOnly = true
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        delegate = self
        preferredFramesPerSecond = KSPlayerManager.preferredFramesPerSecond
    }

    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        needsClear = true
        draw()
    }

    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in _: MTKView) {
        if needsClear {
            guard let currentRenderPassDescriptor = currentRenderPassDescriptor, let commandBuffer = MetalRender.share.clear(renderPassDescriptor: currentRenderPassDescriptor) else {
                return
            }
            guard let drawable = currentDrawable else {
                return
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            needsClear = false
        } else {
            if let frame = renderSource?.getOutputRender(type: .video, isDependent: true) {
                draw(frame: frame)
            }
        }
    }

    func draw(frame: MEFrame) {
        if let frame = frame as? VideoVTBFrame, let pixelBuffer = frame.corePixelBuffer {
            renderSource?.setVideo(time: frame.cmtime)
            let size = display == .plane ? pixelBuffer.drawableSize : UIScreen.size
            if drawableSize != size {
                drawableSize = size
            }
            guard let drawable = currentDrawable else {
                return
            }
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            let textures = pixelBuffer.textures(frome: textureCache)
            guard let commandBuffer = MetalRender.share.draw(pixelBuffer: pixelBuffer, display: display, inputTextures: textures, renderPassDescriptor: renderPassDescriptor) else {
                return
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            frame.corePixelBuffer = nil
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
