//
//  MetalPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import CoreMedia
import MetalKit

final class MetalPlayView: MTKView, MTKViewDelegate, FrameOutput {
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

    override var drawableSize: CGSize {
        didSet {
            #if targetEnvironment(simulator)
            if #available(iOS 13.0, tvOS 13.0, *) {
                (layer as? CAMetalLayer)?.drawableSize = drawableSize
            }
            #else
            (layer as? CAMetalLayer)?.drawableSize = drawableSize
            #endif
        }
    }

    func play() {
        isPaused = false
    }

    func pause() {
        isPaused = true
    }

    func flush() {}

    func shutdown() {
        MetalTexture.share.flush()
    }

    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in _: MTKView) {
        if let render = renderSource?.getOutputRender(type: .video, isDependent: true) {
            set(render: render)
        }
    }

    func set(render: MEFrame) {
        if let render = render as? VideoVTBFrame, let pixelBuffer = render.corePixelBuffer {
            renderSource?.setVideo(time: render.cmtime)
            guard isOutput, let drawable = currentDrawable else {
                return
            }
            drawableSize = display == .plane ? pixelBuffer.drawableSize : UIScreen.size
            guard let commandBuffer = MetalRender.share.draw(pixelBuffer: pixelBuffer, display: display, outputTexture: drawable.texture) else {
                return
            }
            //        commandBuffer.present(drawable)
            commandBuffer.addScheduledHandler { _ in
                drawable.present()
                render.corePixelBuffer = nil
            }
            commandBuffer.commit()
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
    deinit {
        MetalTexture.share.flush()
    }
}
