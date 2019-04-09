//
//  VideoOutput.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import CoreImage
import QuartzCore
#if os(OSX)
import AppKit
#else
import UIKit
#endif
final class VideoOutput: NSObject, FrameOutput {
    private var currentRender: MEFrame?
    weak var renderSource: OutputRenderSourceDelegate?
    var renderView: PixelRenderView & UIView
    private lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        displayLink.add(to: .main, forMode: RunLoop.Mode.default)
        displayLink.isPaused = true
        return displayLink
    }()

    init(renderView: PixelRenderView & UIView) {
        self.renderView = renderView
    }

    func play() {
        displayLink.isPaused = false
    }

    func pause() {
        displayLink.isPaused = true
    }

    @objc private func readBuffer(_: CADisplayLink) {
        if let render = renderSource?.getOutputRender(type: .video, isDependent: true) {
            renderSource?.setVideo(time: render.cmtime)
            renderView.set(render: render)
            currentRender = render
        }
    }

    func invalidate() {
        displayLink.invalidate()
    }

    deinit {
        invalidate()
    }

    func flush() {}

    func shutdown() {}

    public func thumbnailImageAtCurrentTime() -> UIImage? {
        if let frame = currentRender as? VideoVTBFrame, let pixelBuffer = frame.corePixelBuffer {
            let ciImage = CIImage(cvImageBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            if let videoImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: pixelBuffer.size)) {
                return UIImage(cgImage: videoImage)
            }
        }
        return nil
    }
}
