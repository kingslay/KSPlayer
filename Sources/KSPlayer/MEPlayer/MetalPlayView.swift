//
//  MetalPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import CoreMedia
import MetalKit

final class MetalPlayView: UIView {
    private let render = MetalRender()
    private let view = MTKView(frame: .zero, device: MetalRender.device)
    private var videoInfo: CMVideoFormatDescription?
    private var pixelBuffer: CVPixelBuffer?
//    private lazy var displayLink: CADisplayLink = .init(target: self, selector: #selector(drawView))
    private let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    var options: KSOptions
    weak var renderSource: OutputRenderSourceDelegate?
    #if canImport(UIKit)
    override public class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    #endif
    // AVSampleBufferAudioRenderer AVSampleBufferRenderSynchronizer AVSampleBufferDisplayLayer
    var displayLayer: AVSampleBufferDisplayLayer {
        // swiftlint:disable force_cast
        layer as! AVSampleBufferDisplayLayer
        // swiftlint:enable force_cast
    }

    init(options: KSOptions) {
        self.options = options
        super.init(frame: .zero)
        _ = options.$preferredFramesPerSecond.sink { value in
            self.timer.schedule(deadline: .now(), repeating: .milliseconds(Int(ceil(1000.0 / value))))
        }
        timer.setEventHandler { [weak self] in
            self?.drawView()
        }
        timer.activate()
        #if !canImport(UIKit)
        layer = AVSampleBufferDisplayLayer()
        #endif
        #if os(macOS)
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
        #endif
        view.framebufferOnly = true
        addSubview(view)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        isPaused = true
        var controlTimebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase)
        if let controlTimebase = controlTimebase {
            displayLayer.controlTimebase = controlTimebase
            CMTimebaseSetTime(controlTimebase, time: .zero)
            CMTimebaseSetRate(controlTimebase, rate: 1.0)
        }
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var contentMode: UIViewContentMode {
        didSet {
            view.contentMode = contentMode
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

    func clear() {
        if view.isHidden {
            displayLayer.flushAndRemoveImage()
        } else {
            if let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor {
                render.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
            }
        }
    }

    deinit {
        if isPaused {
            timer.resume()
        }
        timer.cancel()
    }
}

extension MetalPlayView {
    private func set(pixelBuffer: CVPixelBuffer, time _: CMTime) {
        if videoInfo == nil || !CMVideoFormatDescriptionMatchesImageBuffer(videoInfo!, imageBuffer: pixelBuffer) {
            let err = CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
            if err != noErr {
                KSLog("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
            }
        }
        guard let videoInfo = videoInfo else { return }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid)
//        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        // swiftlint:disable line_length
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoInfo, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)
        // swiftlint:enable line_length
        if let sampleBuffer = sampleBuffer {
            if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [NSMutableDictionary], let dic = attachmentsArray.first {
                dic[kCMSampleAttachmentKey_DisplayImmediately] = true
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
//            if let controlTimebase = displayLayer.controlTimebase {
//                CMTimebaseSetTime(controlTimebase, time: time)
//            }
        }
    }

    @objc private func drawView() {
        guard let frame = renderSource?.getVideoOutputRender() else {
            return
        }
        pixelBuffer = frame.corePixelBuffer
        guard let pixelBuffer = pixelBuffer else {
            return
        }
        let cmtime = frame.cmtime
        renderSource?.setVideo(time: cmtime)
        let par = pixelBuffer.size
        let sar = pixelBuffer.aspectRatio
        if options.isUseDisplayLayer() {
            if !view.isHidden {
                view.isHidden = true
                if let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor {
                    render.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
                }
            }
            if let dar = options.customizeDar(sar: sar, par: par) {
                pixelBuffer.aspectRatio = CGSize(width: dar.width, height: dar.height * par.width / par.height)
            }
            set(pixelBuffer: pixelBuffer, time: cmtime)
        } else {
            if view.isHidden {
                view.isHidden = false
                displayLayer.flushAndRemoveImage()
            }
            autoreleasepool {
                if options.display == .plane {
                    if let dar = options.customizeDar(sar: sar, par: par) {
                        view.drawableSize = CGSize(width: par.width, height: par.width * dar.height / dar.width)
                    } else {
                        view.drawableSize = CGSize(width: par.width, height: par.height * sar.height / sar.width)
                    }
                } else {
                    view.drawableSize = UIScreen.size
                }
                view.colorPixelFormat = KSOptions.colorPixelFormat(bitDepth: pixelBuffer.bitDepth)
                (view.layer as? CAMetalLayer)?.colorspace = pixelBuffer.colorspace
                guard let drawable = view.currentDrawable else {
                    return
                }
                render.draw(pixelBuffer: pixelBuffer, display: options.display, drawable: drawable)
            }
        }
    }
}

extension MetalPlayView: FrameOutput {
    var isPaused: Bool {
        get {
            view.isPaused
        }
        set {
            if isPaused != newValue {
                view.isPaused = newValue
                newValue ? timer.suspend() : timer.resume()
            }
        }
    }

    var drawableSize: CGSize {
        get {
            view.drawableSize
        }
        set {
            view.drawableSize = newValue
        }
    }
}

#if os(macOS)
import CoreVideo
class CADisplayLink {
    private let displayLink: CVDisplayLink
    private let target: AnyObject
    private let selector: Selector
    private var runloop: RunLoop?
    private var mode = RunLoop.Mode.default
    public var timestamp: TimeInterval {
        var timeStamp = CVTimeStamp()
        if CVDisplayLinkGetCurrentTime(displayLink, &timeStamp) == kCVReturnSuccess, (timeStamp.flags & CVTimeStampFlags.hostTimeValid.rawValue) != 0 {
            return TimeInterval(timeStamp.hostTime / NSEC_PER_SEC)
        }
        return 0
    }

    public var duration: TimeInterval {
        CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLink)
    }

    public var targetTimestamp: TimeInterval {
        duration + timestamp
    }

    public var isPaused: Bool {
        get {
            !CVDisplayLinkIsRunning(displayLink)
        }
        set {
            if newValue {
                CVDisplayLinkStop(displayLink)
            } else {
                CVDisplayLinkStart(displayLink)
            }
        }
    }

    public init(target: NSObject, selector sel: Selector) {
        self.target = target
        selector = sel
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink)
        self.displayLink = displayLink!
        CVDisplayLinkSetOutputCallback(self.displayLink, { (_, _, _, _, _, userData: UnsafeMutableRawPointer?) -> CVReturn in
            guard let userData = userData else {
                return kCVReturnError
            }
            let `self` = Unmanaged<CADisplayLink>.fromOpaque(userData).takeUnretainedValue()
            self.runloop?.perform(self.selector, target: self.target, argument: self, order: 0, modes: [self.mode])
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(self.displayLink)
    }

    open func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        self.runloop = runloop
        self.mode = mode
    }

    public func invalidate() {
        isPaused = true
        runloop = nil
    }
}
#endif
