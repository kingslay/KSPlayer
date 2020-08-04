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
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    var display: DisplayEnum = .plane
    weak var renderSource: OutputRenderSourceDelegate?
    var pixelBuffer: BufferProtocol? {
        didSet {
            if let pixelBuffer = pixelBuffer {
                autoreleasepool {
                    let size = display == .plane ? pixelBuffer.drawableSize : UIScreen.size
                    if drawableSize != size {
                        drawableSize = size
                    }
                    let textures = pixelBuffer.textures(frome: textureCache)
                    guard let drawable = currentDrawable else {
                        return
                    }
                    MetalRender.share.draw(pixelBuffer: pixelBuffer, display: display, inputTextures: textures, drawable: drawable, renderPassDescriptor: renderPassDescriptor)
                }
            } else {
                guard let drawable = currentDrawable else {
                    return
                }
                MetalRender.share.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
            }
        }
    }

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
//        no use the way to clear texture
//        pixelBuffer = nil
    }

    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in _: MTKView) {
        if let frame = renderSource?.getOutputRender(type: .video, isDependent: true) as? VideoVTBFrame, let corePixelBuffer = frame.corePixelBuffer {
            renderSource?.setVideo(time: frame.cmtime)
            pixelBuffer = corePixelBuffer
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
    func toImage() -> UIImage? {
        pixelBuffer?.image()
    }
}
