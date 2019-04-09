//
//  SampleBufferPlayerView.swift
//  KSPlayer
//
//  Created by kintan on 2018/4/12.
//
import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
// AVSampleBufferAudioRenderer AVSampleBufferRenderSynchronizer AVSampleBufferDisplayLayer
public final class SampleBufferPlayerView: UIView {
    private var videoInfo: CMVideoFormatDescription?
    private var displayLayer: AVSampleBufferDisplayLayer {
        // swiftlint:disable force_cast
        return layer as! AVSampleBufferDisplayLayer
        // swiftlint:enable force_cast
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        #if os(macOS)
        layer = AVSampleBufferDisplayLayer()
        #endif
        var controlTimebase: CMTimebase?
        CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault, masterClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase)
        if let controlTimebase = controlTimebase {
            displayLayer.controlTimebase = controlTimebase
            CMTimebaseSetTime(controlTimebase, time: .zero)
            CMTimebaseSetRate(controlTimebase, rate: 1.0)
        }
    }

    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if !os(macOS)
    public override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    public override var contentMode: UIViewContentMode {
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
    #endif
}

extension SampleBufferPlayerView: PixelRenderView {
    func set(render: MEFrame) {
        if let render = render as? VideoSampleBufferFrame, let sampleBuffer = render.sampleBuffer {
            if displayLayer.isReadyForMoreMediaData {
                displayLayer.enqueue(sampleBuffer)
            }
            if displayLayer.status == .failed {
                displayLayer.flush()
            }
            if let controlTimebase = displayLayer.controlTimebase {
                CMTimebaseSetTime(controlTimebase, time: render.cmtime)
            }
        } else if let render = render as? VideoVTBFrame, let pixelBuffer = render.corePixelBuffer {
            set(pixelBuffer: pixelBuffer, time: render.cmtime)
        }
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
}
