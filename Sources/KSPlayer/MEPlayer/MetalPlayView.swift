//
//  MetalPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import Combine
import CoreMedia
import MetalKit
public final class MetalPlayView: UIView {
    private let render = MetalRender()
    private let view = MTKView(frame: .zero, device: MetalRender.device)
    private var videoInfo: CMVideoFormatDescription?
    private var cancellable: AnyCancellable?
    public private(set) var pixelBuffer: CVPixelBuffer?
    /// 用displayLink会导致锁屏无法draw，
    /// 用DispatchSourceTimer的话，在播放4k视频的时候repeat的时间会变长,
    /// 用MTKView的draw(in:)也是不行，会卡顿
    private lazy var displayLink: CADisplayLink = .init(target: self, selector: #selector(draw(in:)))
//    private let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
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

    var isPaused: Bool = true {
        willSet {
            if isPaused != newValue {
                view.isPaused = newValue
                displayLink.isPaused = newValue
            }
        }
    }

    init(options: KSOptions) {
        self.options = options
        super.init(frame: .zero)
        cancellable = options.$preferredFramesPerSecond.sink { [weak self] value in
            self?.displayLink.preferredFramesPerSecond = Int(ceil(value * 1.5))
        }
        #if !canImport(UIKit)
        layer = AVSampleBufferDisplayLayer()
        #endif
        #if os(macOS)
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
        #endif
        view.framebufferOnly = true
        view.isPaused = true
        addSubview(view)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        displayLink.add(to: RunLoop.main, forMode: .common)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        var controlTimebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase)
        if let controlTimebase {
            displayLayer.controlTimebase = controlTimebase
            CMTimebaseSetTime(controlTimebase, time: .zero)
            CMTimebaseSetRate(controlTimebase, rate: 1.0)
        }
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var contentMode: UIViewContentMode {
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
    override public func touchesMoved(_ touches: Set<UITouch>, with: UIEvent?) {
        if options.display == .plane {
            super.touchesMoved(touches, with: with)
        } else {
            options.display.touchesMoved(touch: touches.first!)
        }
    }
    #endif

    func clear() {
        if view.isHidden {
            displayLayer.flushAndRemoveImage()
        } else {
            if let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor {
                render.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
            }
        }
    }

    func invalidate() {
        displayLink.invalidate()
    }

    public func readNextFrame() {
        draw(force: true)
    }
}

extension MetalPlayView {
    @objc private func draw(in _: Any) {
        draw(force: false)
    }

    private func draw(force: Bool) {
        autoreleasepool {
            guard let frame = renderSource?.getVideoOutputRender(force: force) else {
                return
            }
            pixelBuffer = frame.corePixelBuffer
            guard let pixelBuffer else {
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
                if options.display == .plane {
                    if let dar = options.customizeDar(sar: sar, par: par) {
                        view.drawableSize = CGSize(width: par.width, height: par.width * dar.height / dar.width)
                    } else {
                        view.drawableSize = CGSize(width: par.width, height: par.height * sar.height / sar.width)
                    }
                } else {
                    view.drawableSize = UIScreen.size
                }
                (view.layer as? CAMetalLayer)?.pixelFormat = KSOptions.colorPixelFormat(bitDepth: pixelBuffer.bitDepth)
                (view.layer as? CAMetalLayer)?.colorspace = pixelBuffer.colorspace
                guard let drawable = view.currentDrawable else {
                    return
                }
                render.draw(pixelBuffer: pixelBuffer, display: options.display, drawable: drawable)
            }
        }
    }

    private func set(pixelBuffer: CVPixelBuffer, time _: CMTime) {
        if videoInfo == nil || !CMVideoFormatDescriptionMatchesImageBuffer(videoInfo!, imageBuffer: pixelBuffer) {
            let err = CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
            if err != noErr {
                KSLog("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
            }
        }
        guard let videoInfo else { return }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid)
//        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        // swiftlint:disable line_length
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoInfo, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)
        // swiftlint:enable line_length
        if let sampleBuffer {
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
}

extension MetalPlayView: FrameOutput {
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
    private var target: AnyObject?
    private let selector: Selector
    private var runloop: RunLoop?
    private var mode = RunLoop.Mode.default
    public var preferredFramesPerSecond = 60
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
            guard let userData else {
                return kCVReturnError
            }
            let `self` = Unmanaged<CADisplayLink>.fromOpaque(userData).takeUnretainedValue()
            guard let runloop = self.runloop, let target = self.target else {
                return kCVReturnSuccess
            }
            runloop.perform(self.selector, target: target, argument: self, order: 0, modes: [self.mode])
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
        target = nil
    }
}
#endif
