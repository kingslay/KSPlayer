//
//  MetalPlayView.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import Combine
import CoreMedia
#if canImport(MetalKit)
import MetalKit
#endif
public final class MetalPlayView: UIView {
    private let render = MetalRender()
    private let metalView = MTKView(frame: .zero, device: MetalRender.device)
    private var videoInfo: CMVideoFormatDescription?
    public private(set) var pixelBuffer: CVPixelBuffer?
    /// 用displayLink会导致锁屏无法draw，
    /// 用DispatchSourceTimer的话，在播放4k视频的时候repeat的时间会变长,
    /// 用MTKView的draw(in:)也是不行，会卡顿
    private lazy var displayLink: CADisplayLink = .init(target: self, selector: #selector(draw(in:)))
//    private let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    var options: KSOptions
    weak var renderSource: OutputRenderSourceDelegate?
    // AVSampleBufferAudioRenderer AVSampleBufferRenderSynchronizer AVSampleBufferDisplayLayer
    var displayView = AVSampleBufferDisplayView()

    init(options: KSOptions) {
        self.options = options
        super.init(frame: .zero)
        #if os(macOS)
        (metalView.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
        #endif
        metalView.framebufferOnly = true
        metalView.isPaused = true
        metalView.isHidden = true
        addSubview(metalView)
        addSubview(displayView)
        displayLink.add(to: .main, forMode: .common)
        pause()
    }

    func prepare(fps: Float) {
        displayLink.preferredFramesPerSecond = Int(ceil(fps)) << 1
    }

    func play() {
        displayLink.isPaused = false
        metalView.isPaused = false
    }

    func pause() {
        displayLink.isPaused = true
        metalView.isPaused = true
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview == displayView || subview == metalView {
            subview.frame = frame
            subview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                subview.leftAnchor.constraint(equalTo: leftAnchor),
                subview.topAnchor.constraint(equalTo: topAnchor),
                subview.centerXAnchor.constraint(equalTo: centerXAnchor),
                subview.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }

    override public var contentMode: UIViewContentMode {
        didSet {
            metalView.contentMode = contentMode
            switch contentMode {
            case .scaleToFill:
                displayView.displayLayer.videoGravity = .resize
            case .scaleAspectFit, .center:
                displayView.displayLayer.videoGravity = .resizeAspect
            case .scaleAspectFill:
                displayView.displayLayer.videoGravity = .resizeAspectFill
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
    #else
    override public func touchesMoved(with event: NSEvent) {
        if options.display == .plane {
            super.touchesMoved(with: event)
        } else {
            options.display.touchesMoved(touch: event.allTouches().first!)
        }
    }
    #endif

    func clear() {
        if displayView.isHidden {
            if let drawable = metalView.currentDrawable, let renderPassDescriptor = metalView.currentRenderPassDescriptor {
                render.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
            }
        } else {
            displayView.displayLayer.flushAndRemoveImage()
        }
    }

    func invalidate() {
        displayLink.invalidate()
    }

    public func readNextFrame() {
        draw(force: true)
    }
}

class AVSampleBufferDisplayView: UIView {
    #if canImport(UIKit)
    override public class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    #endif
    var displayLayer: AVSampleBufferDisplayLayer {
        // swiftlint:disable force_cast
        layer as! AVSampleBufferDisplayLayer
        // swiftlint:enable force_cast
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        #if !canImport(UIKit)
        layer = AVSampleBufferDisplayLayer()
        #endif
        var controlTimebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase)
        if let controlTimebase {
            displayLayer.controlTimebase = controlTimebase
            CMTimebaseSetTime(controlTimebase, time: .zero)
            CMTimebaseSetRate(controlTimebase, rate: 1.0)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func enqueue(imageBuffer: CVPixelBuffer, formatDescription: CMVideoFormatDescription) {
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        //        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: imageBuffer, formatDescription: formatDescription, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)
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
                if displayView.isHidden {
                    displayView.isHidden = false
                    metalView.isHidden = true
                    if let drawable = metalView.currentDrawable, let renderPassDescriptor = metalView.currentRenderPassDescriptor {
                        render.clear(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
                    }
                }
                if let dar = options.customizeDar(sar: sar, par: par) {
                    pixelBuffer.aspectRatio = CGSize(width: dar.width, height: dar.height * par.width / par.height)
                }
                set(pixelBuffer: pixelBuffer, time: cmtime)
            } else {
                if !displayView.isHidden {
                    displayView.isHidden = true
                    metalView.isHidden = false
                    displayView.displayLayer.flushAndRemoveImage()
                }
                if options.display == .plane {
                    if let dar = options.customizeDar(sar: sar, par: par) {
                        metalView.drawableSize = CGSize(width: par.width, height: par.width * dar.height / dar.width)
                    } else {
                        metalView.drawableSize = CGSize(width: par.width, height: par.height * sar.height / sar.width)
                    }
                } else {
                    metalView.drawableSize = UIScreen.size
                }
                (metalView.layer as? CAMetalLayer)?.pixelFormat = KSOptions.colorPixelFormat(bitDepth: pixelBuffer.bitDepth)
                (metalView.layer as? CAMetalLayer)?.colorspace = pixelBuffer.colorspace
                guard let drawable = metalView.currentDrawable else {
                    return
                }
                render.draw(pixelBuffer: pixelBuffer, display: options.display, drawable: drawable)
            }
        }
    }

    private func set(pixelBuffer: CVPixelBuffer, time _: CMTime) {
        if videoInfo == nil || !CMVideoFormatDescriptionMatchesImageBuffer(videoInfo!, imageBuffer: pixelBuffer) {
            if videoInfo != nil {
                displayView.removeFromSuperview()
                displayView = AVSampleBufferDisplayView()
                addSubview(displayView)
            }
            let err = CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
            if err != noErr {
                KSLog("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
            }
        }
        guard let videoInfo else { return }
        displayView.enqueue(imageBuffer: pixelBuffer, formatDescription: videoInfo)
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
