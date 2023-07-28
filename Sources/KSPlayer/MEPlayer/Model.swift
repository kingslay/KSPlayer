//
//  Packet.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
import Libavcodec

// MARK: enum

enum MESourceState {
    case idle
    case opening
    case opened
    case reading
    case seeking
    case paused
    case finished
    case closed
    case failed
}

// MARK: delegate

protocol OutputRenderSourceDelegate: AnyObject {
    func getVideoOutputRender(force: Bool) -> VideoVTBFrame?
    func getAudioOutputRender() -> AudioFrame?
    func setAudio(time: CMTime)
    func setVideo(time: CMTime, duration: CMTime)
}

protocol CodecCapacityDelegate: AnyObject {
    func codecDidFinished(track: some CapacityProtocol)
}

protocol MEPlayerDelegate: AnyObject {
    func sourceDidChange(loadingState: LoadingState)
    func sourceDidOpened()
    func sourceDidFailed(error: NSError?)
    func sourceDidFinished()
    func sourceDidChange(oldBitRate: Int64, newBitrate: Int64)
}

// MARK: protocol

public protocol ObjectQueueItem {
    var duration: Int64 { get set }
    var position: Int64 { get set }
    var size: Int32 { get set }
}

protocol FrameOutput: AnyObject {
    var renderSource: OutputRenderSourceDelegate? { get set }
}

protocol MEFrame: ObjectQueueItem {
    var timebase: Timebase { get set }
}

extension MEFrame {
    public var seconds: TimeInterval { cmtime.seconds }
    public var cmtime: CMTime { timebase.cmtime(for: position) }
}

// MARK: model

// for MEPlayer
public extension KSOptions {
    /// 开启VR模式的陀飞轮
    static var enableSensor = true
    static var stackSize = 65536
    static var isClearVideoWhereReplace = true
    /// true: AVSampleBufferAudioRenderer false: AVAudioEngine
    static var isUseAudioRenderer = false
    static func colorSpace(ycbcrMatrix: CFString?, transferFunction: CFString?) -> CGColorSpace? {
        switch ycbcrMatrix {
        case kCVImageBufferYCbCrMatrix_ITU_R_709_2:
            return CGColorSpace(name: CGColorSpace.itur_709)
        case kCVImageBufferYCbCrMatrix_ITU_R_601_4:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case kCVImageBufferYCbCrMatrix_ITU_R_2020:
            if transferFunction == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ {
                if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
                    return CGColorSpace(name: CGColorSpace.itur_2100_PQ)
                } else if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                    return CGColorSpace(name: CGColorSpace.itur_2020_PQ)
                } else {
                    return CGColorSpace(name: CGColorSpace.itur_2020_PQ_EOTF)
                }
            } else if transferFunction == kCVImageBufferTransferFunction_ITU_R_2100_HLG {
                if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
                    return CGColorSpace(name: CGColorSpace.itur_2100_HLG)
                } else {
                    return CGColorSpace(name: CGColorSpace.itur_2020)
                }
            } else {
                return CGColorSpace(name: CGColorSpace.itur_2020)
            }

        default:
            return CGColorSpace(name: CGColorSpace.sRGB)
        }
    }

    static func colorSpace(colorPrimaries: CFString?) -> CGColorSpace? {
        switch colorPrimaries {
        case kCVImageBufferColorPrimaries_ITU_R_709_2:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case kCVImageBufferColorPrimaries_DCI_P3:
            if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                return CGColorSpace(name: CGColorSpace.displayP3_PQ)
            } else {
                return CGColorSpace(name: CGColorSpace.displayP3_PQ_EOTF)
            }
        case kCVImageBufferColorPrimaries_ITU_R_2020:
            if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
                return CGColorSpace(name: CGColorSpace.itur_2100_PQ)
            } else if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                return CGColorSpace(name: CGColorSpace.itur_2020_PQ)
            } else {
                return CGColorSpace(name: CGColorSpace.itur_2020_PQ_EOTF)
            }
        default:
            return CGColorSpace(name: CGColorSpace.sRGB)
        }
    }

    static func colorPixelFormat(bitDepth: Int32) -> MTLPixelFormat {
        if bitDepth == 10 {
            return .bgr10a2Unorm
        } else {
            return .bgra8Unorm
        }
    }
}

enum MECodecState {
    case idle
    case decoding
    case flush
    case closed
    case failed
    case finished
}

struct Timebase {
    static let defaultValue = Timebase(num: 1, den: 1)
    public let num: Int32
    public let den: Int32
    func getPosition(from seconds: TimeInterval) -> Int64 { Int64(seconds * TimeInterval(den) / TimeInterval(num)) }

    func cmtime(for timestamp: Int64) -> CMTime { CMTime(value: timestamp * Int64(num), timescale: den) }
}

extension Timebase {
    public var rational: AVRational { AVRational(num: num, den: den) }

    init(_ rational: AVRational) {
        num = rational.num
        den = rational.den
    }
}

final class Packet: ObjectQueueItem {
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    var assetTrack: FFmpegAssetTrack!
    private(set) var corePacket = av_packet_alloc()
    func fill() {
        guard let corePacket else {
            return
        }
        position = corePacket.pointee.pts == Int64.min ? corePacket.pointee.dts : corePacket.pointee.pts
        duration = corePacket.pointee.duration
        size = corePacket.pointee.size
    }

    deinit {
        av_packet_unref(corePacket)
        av_packet_free(&corePacket)
    }
}

final class SubtitleFrame: MEFrame {
    var timebase: Timebase
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    let part: SubtitlePart
    init(part: SubtitlePart, timebase: Timebase) {
        self.part = part
        self.timebase = timebase
    }
}

final class AudioFrame: MEFrame {
    var timebase = Timebase.defaultValue
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    var numberOfSamples: UInt32 = 0
    let channels: UInt32
    let dataSize: Int
    var data: [UnsafeMutablePointer<UInt8>?]
    public init(bufferSize: Int32, channels: UInt32, count: Int) {
        self.channels = channels
        dataSize = Int(bufferSize)
        data = (0 ..< count).map { _ in
            UnsafeMutablePointer<UInt8>.allocate(capacity: Int(bufferSize))
        }
    }

    deinit {
        for i in 0 ..< data.count {
            data[i]?.deinitialize(count: dataSize)
            data[i]?.deallocate()
        }
        data.removeAll()
    }
}

final class VideoVTBFrame: MEFrame {
    var timebase = Timebase.defaultValue
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    var corePixelBuffer: CVPixelBuffer?
}

extension Array {
    init(tuple: (Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7])
    }

    init(tuple: (Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3])
    }

    var tuple8: (Element, Element, Element, Element, Element, Element, Element, Element) {
        (self[0], self[1], self[2], self[3], self[4], self[5], self[6], self[7])
    }

    var tuple4: (Element, Element, Element, Element) {
        (self[0], self[1], self[2], self[3])
    }
}
