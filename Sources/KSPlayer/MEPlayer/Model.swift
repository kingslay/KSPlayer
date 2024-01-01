//
//  Model.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
import Libavcodec
#if canImport(UIKit)
import UIKit
#endif

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

public protocol OutputRenderSourceDelegate: AnyObject {
    func getVideoOutputRender(force: Bool) -> VideoVTBFrame?
    func getAudioOutputRender() -> AudioFrame?
    func setAudio(time: CMTime, position: Int64)
    func setVideo(time: CMTime, position: Int64)
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
    var timebase: Timebase { get }
    var timestamp: Int64 { get set }
    var duration: Int64 { get set }
    // byte position
    var position: Int64 { get set }
    var size: Int32 { get set }
}

extension ObjectQueueItem {
    var seconds: TimeInterval { cmtime.seconds }
    var cmtime: CMTime { timebase.cmtime(for: timestamp) }
}

public protocol FrameOutput: AnyObject {
    var renderSource: OutputRenderSourceDelegate? { get set }
    func pause()
    func flush()
}

protocol MEFrame: ObjectQueueItem {
    var timebase: Timebase { get set }
}

// MARK: model

// for MEPlayer
public extension KSOptions {
    /// 开启VR模式的陀飞轮
    static var enableSensor = true
    static var stackSize = 65536
    static var isClearVideoWhereReplace = true
    /// true: AVSampleBufferAudioRenderer false: AVAudioEngine
    static var audioPlayerType: AudioOutput.Type = AudioEnginePlayer.self
    static var videoPlayerType: (VideoOutput & UIView).Type = MetalPlayView.self
    static var yadifMode = 1
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

    static func pixelFormat(planeCount: Int, bitDepth: Int32) -> [MTLPixelFormat] {
        if planeCount == 3 {
            if bitDepth > 8 {
                return [.r16Unorm, .r16Unorm, .r16Unorm]
            } else {
                return [.r8Unorm, .r8Unorm, .r8Unorm]
            }
        } else if planeCount == 2 {
            if bitDepth > 8 {
                return [.r16Unorm, .rg16Unorm]
            } else {
                return [.r8Unorm, .rg8Unorm]
            }
        } else {
            return [colorPixelFormat(bitDepth: bitDepth)]
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

public struct Timebase {
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
    var timestamp: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    private(set) var corePacket = av_packet_alloc()
    var timebase: Timebase {
        assetTrack.timebase
    }

    var isKeyFrame: Bool {
        if let corePacket {
            return corePacket.pointee.flags & AV_PKT_FLAG_KEY == AV_PKT_FLAG_KEY
        } else {
            return false
        }
    }

    var assetTrack: FFmpegAssetTrack! {
        didSet {
            guard let packet = corePacket?.pointee else {
                return
            }
            timestamp = packet.pts == Int64.min ? packet.dts : packet.pts
            position = packet.pos
            duration = packet.duration
            size = packet.size
        }
    }

    deinit {
        av_packet_unref(corePacket)
        av_packet_free(&corePacket)
    }
}

final class SubtitleFrame: MEFrame {
    var timestamp: Int64 = 0
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

public final class AudioFrame: MEFrame {
    let dataSize: Int
    let audioFormat: AVAudioFormat
    public var timebase = Timebase.defaultValue
    public var timestamp: Int64 = 0
    public var duration: Int64 = 0
    public var position: Int64 = 0
    public var size: Int32 = 0
    var numberOfSamples: UInt32 = 0
    var data: [UnsafeMutablePointer<UInt8>?]
    public init(dataSize: Int, audioFormat: AVAudioFormat) {
        self.dataSize = dataSize
        self.audioFormat = audioFormat
        let count = audioFormat.isInterleaved ? 1 : audioFormat.channelCount
        data = (0 ..< count).map { _ in
            UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
        }
    }

    init(array: [AudioFrame]) {
        audioFormat = array[0].audioFormat
        timebase = array[0].timebase
        timestamp = array[0].timestamp
        position = array[0].position
        var dataSize = 0
        for frame in array {
            duration += frame.duration
            dataSize += frame.dataSize
            size += frame.size
            numberOfSamples += frame.numberOfSamples
        }
        self.dataSize = dataSize
        let count = audioFormat.isInterleaved ? 1 : audioFormat.channelCount
        data = (0 ..< count).map { _ in
            UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
        }
        var offset = 0
        for frame in array {
            for i in 0 ..< data.count {
                data[i]?.advanced(by: offset).initialize(from: frame.data[i]!, count: frame.dataSize)
            }
            offset += frame.dataSize
        }
    }

    deinit {
        for i in 0 ..< data.count {
            data[i]?.deinitialize(count: dataSize)
            data[i]?.deallocate()
        }
        data.removeAll()
    }

    func toPCMBuffer() -> AVAudioPCMBuffer? {
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: numberOfSamples) else {
            return nil
        }
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let capacity = Int(pcmBuffer.frameCapacity)
        for i in 0 ..< min(Int(pcmBuffer.format.channelCount), data.count) {
            switch audioFormat.commonFormat {
            case .pcmFormatInt16:
                data[i]?.withMemoryRebound(to: Int16.self, capacity: capacity) { src in
                    pcmBuffer.int16ChannelData?[i].update(from: src, count: capacity)
                }
            case .pcmFormatInt32:
                data[i]?.withMemoryRebound(to: Int32.self, capacity: capacity) { src in
                    pcmBuffer.int32ChannelData?[i].update(from: src, count: capacity)
                }
            default:
                data[i]?.withMemoryRebound(to: Float.self, capacity: capacity) { src in
                    pcmBuffer.floatChannelData?[i].update(from: src, count: capacity)
                }
            }
        }
        return pcmBuffer
    }

    func toCMSampleBuffer() -> CMSampleBuffer? {
        var outBlockListBuffer: CMBlockBuffer?
        CMBlockBufferCreateEmpty(allocator: kCFAllocatorDefault, capacity: UInt32(data.count), flags: 0, blockBufferOut: &outBlockListBuffer)
        guard let outBlockListBuffer else {
            return nil
        }
        let sampleSize = Int(audioFormat.sampleSize)
        let sampleCount = CMItemCount(numberOfSamples)
        let dataByteSize = sampleCount * sampleSize
        if dataByteSize > dataSize {
            assertionFailure("dataByteSize: \(dataByteSize),render.dataSize: \(dataSize)")
        }
        for i in 0 ..< data.count {
            var outBlockBuffer: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: dataByteSize,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataByteSize,
                flags: kCMBlockBufferAssureMemoryNowFlag,
                blockBufferOut: &outBlockBuffer
            )
            if let outBlockBuffer {
                CMBlockBufferReplaceDataBytes(
                    with: data[i]!,
                    blockBuffer: outBlockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: dataByteSize
                )
                CMBlockBufferAppendBufferReference(
                    outBlockListBuffer,
                    targetBBuf: outBlockBuffer,
                    offsetToData: 0,
                    dataLength: CMBlockBufferGetDataLength(outBlockBuffer),
                    flags: 0
                )
            }
        }
        var sampleBuffer: CMSampleBuffer?
        // 因为sampleRate跟timescale没有对齐，所以导致杂音。所以要让duration为invalid
//        let duration = CMTime(value: CMTimeValue(sampleCount), timescale: CMTimeScale(audioFormat.sampleRate))
        let duration = CMTime.invalid
        let timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: cmtime, decodeTimeStamp: .invalid)
        let sampleSizeEntryCount: CMItemCount
        let sampleSizeArray: [Int]?
        if audioFormat.isInterleaved {
            sampleSizeEntryCount = 1
            sampleSizeArray = [sampleSize]
        } else {
            sampleSizeEntryCount = 0
            sampleSizeArray = nil
        }
        CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: outBlockListBuffer, formatDescription: audioFormat.formatDescription, sampleCount: sampleCount, sampleTimingEntryCount: 1, sampleTimingArray: [timing], sampleSizeEntryCount: sampleSizeEntryCount, sampleSizeArray: sampleSizeArray, sampleBufferOut: &sampleBuffer)
        return sampleBuffer
    }
}

public final class VideoVTBFrame: MEFrame {
    public var timebase = Timebase.defaultValue
    // 交叉视频的duration会不准，直接减半了
    public var duration: Int64 = 0
    public var position: Int64 = 0
    public var timestamp: Int64 = 0
    public var size: Int32 = 0
    public let fps: Float
    public let isDovi: Bool
    var corePixelBuffer: PixelBufferProtocol?
    init(fps: Float, isDovi: Bool) {
        self.fps = fps
        self.isDovi = isDovi
    }
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
