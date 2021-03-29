//
//  MetalPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import CoreMedia
import MetalKit

final class MetalPlayView: MTKView, MTKViewDelegate, FrameOutput {
    private let render = MetalRender()
    private var videoInfo: CMVideoFormatDescription?
    // AVSampleBufferAudioRenderer AVSampleBufferRenderSynchronizer AVSampleBufferDisplayLayer
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pixelBuffer: BufferProtocol?
    var options: KSOptions
    weak var renderSource: OutputRenderSourceDelegate?
    init(options: KSOptions) {
        self.options = options
        super.init(frame: .zero, device: MetalRender.device)
        framebufferOnly = true
        preferredFramesPerSecond = KSPlayerManager.preferredFramesPerSecond
        isPaused = true
        backingLayer?.addSublayer(displayLayer)
        displayLayer.isHidden = true
        delegate = self
        var controlTimebase: CMTimebase?
        CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault, masterClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase)
        if let controlTimebase = controlTimebase {
            displayLayer.controlTimebase = controlTimebase
            CMTimebaseSetTime(controlTimebase, time: .zero)
            CMTimebaseSetRate(controlTimebase, rate: 1.0)
        }
    }

    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func draw(in view: MTKView) {
        guard let frame = renderSource?.getOutputRender(type: .video) as? VideoVTBFrame else {
            return
        }
        pixelBuffer = frame.corePixelBuffer
        guard let pixelBuffer = pixelBuffer else {
            return
        }
        let cmtime = frame.cmtime
        renderSource?.setVideo(time: cmtime)
        if pixelBuffer is PixelBuffer || !options.isUseDisplayLayer() {
            displayLayer.isHidden = true
            autoreleasepool {
                let size = options.drawableSize(par: pixelBuffer.size, sar: pixelBuffer.sar)
                if drawableSize != size {
                    drawableSize = size
                }
                colorPixelFormat = KSOptions.colorPixelFormat(bitDepth: pixelBuffer.bitDepth)
                #if targetEnvironment(simulator)
                if #available(iOS 13.0, tvOS 13.0, *) {
                    (layer as? CAMetalLayer)?.colorspace = pixelBuffer.colorspace
                }
                #else
                (layer as? CAMetalLayer)?.colorspace = pixelBuffer.colorspace
                #endif
                #if os(macOS) || targetEnvironment(macCatalyst)
                (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
                #endif
                guard let drawable = currentDrawable else {
                    return
                }
                render.draw(pixelBuffer: pixelBuffer, display: options.display, drawable: drawable)
            }
        } else {
            if displayLayer.isHidden {
                displayLayer.frame = bounds
                displayLayer.isHidden = false
                if let drawable = currentDrawable, let renderPassDescriptor = currentRenderPassDescriptor {
                    render.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
                }
            }
            // swiftlint:disable force_cast
            set(pixelBuffer: pixelBuffer as! CVPixelBuffer, time: cmtime)
            // swiftlint:enable force_cast
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        displayLayer.frame = bounds
    }

    public func set(pixelBuffer: CVPixelBuffer, time: CMTime) {
        if videoInfo == nil || !CMVideoFormatDescriptionMatchesImageBuffer(videoInfo!, imageBuffer: pixelBuffer) {
            let err = CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
            if err != noErr {
                KSLog("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
            }
        }
        guard let videoInfo = videoInfo else { return }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        // swiftlint:disable line_length
        CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoInfo, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)
        // swiftlint:enable line_length

        if let sampleBuffer = sampleBuffer {
            if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [Any] {
                if let dic = attachmentsArray.first as? NSMutableDictionary {
                    dic[kCMSampleAttachmentKey_DisplayImmediately] = true
                }
            }
            if displayLayer.isReadyForMoreMediaData {
                displayLayer.enqueue(sampleBuffer)
            }
            if displayLayer.status == .failed {
                displayLayer.flush()
                //                    if let error = displayLayer.error as NSError?, error.code == -11847 {
                //                        displayLayer.stopRequestingMediaData()
                //                    }
            }
            if let controlTimebase = displayLayer.controlTimebase {
                CMTimebaseSetTime(controlTimebase, time: time)
            }
        }
    }

    override var contentMode: UIViewContentMode {
        didSet {
            switch contentMode {
            case .scaleToFill:
                displayLayer.videoGravity = .resize
            case .scaleAspectFit, .center:
                displayLayer.videoGravity = .resizeAspect
            case .scaleAspectFill:
                displayLayer.videoGravity = .resizeAspectFill
            default:
                break
            }
        }
    }

    #if canImport(UIKit)
    override func touchesMoved(_ touches: Set<UITouch>, with: UIEvent?) {
        if options.display == .plane {
            super.touchesMoved(touches, with: with)
        } else {
            options.display.touchesMoved(touch: touches.first!)
        }
    }
    #endif
    func toImage() -> UIImage? {
        pixelBuffer?.image().flatMap { UIImage(cgImage: $0) }
    }
}
