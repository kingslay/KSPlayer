//
//  Packet.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
import ffmpeg
#if os(OSX)
import AppKit
#else
import UIKit
#endif

// MARK: enum

@objc public enum MEErrorCode: Int {
    case unknown
    case formatCreate
    case formatOpenInput
    case formatFindStreamInfo
    case streamNotFound
    case readFrame
    case codecContextCreate
    case codecContextSetParam
    case codecFindDecoder
    case codecVideoSendPacket
    case codecAudioSendPacket
    case codecVideoReceiveFrame
    case codecAudioReceiveFrame
    case codecOpen2
    case auidoSwrInit
    case codecSubtitleSendPacket
}

extension NSError {
    convenience init(result: Int32, errorCode: MEErrorCode) {
        var errorStringBuffer = [Int8](repeating: 0, count: 512)
        av_strerror(result, &errorStringBuffer, 512)
        self.init(domain: "FFmpeg", code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: "FFmpeg code : \(result), FFmpeg msg : \(String(cString: errorStringBuffer))"])
    }
}

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

protocol OutputRenderSourceDelegate: class {
    var currentPlaybackTime: TimeInterval { get }
    func getOutputRender(type: AVFoundation.AVMediaType, isDependent: Bool) -> MEFrame?
    func setVideo(time: CMTime)
    func setAudio(time: CMTime)
}

extension OutputRenderSourceDelegate {
    func getOutputRender(type: AVFoundation.AVMediaType) -> MEFrame? {
        return getOutputRender(type: type, isDependent: false)
    }
}

protocol CodecCapacityDelegate: class {
    func codecDidChangeCapacity(track: PlayerItemTrackProtocol)
    func codecFailed(error: NSError, track: PlayerItemTrackProtocol)
    func codecDidFinished(track: PlayerItemTrackProtocol)
}

protocol MEPlayerDelegate: class {
    func sourceDidChange(capacity: Capacity)
    func sourceDidOpened()
    func sourceDidFailed(error: NSError?)
    func sourceDidFinished(type: AVFoundation.AVMediaType, allSatisfy: Bool)
}

// MARK: protocol

// 缓冲情况
protocol Capacity: class {
    var loadedTime: TimeInterval { get }
    var loadedCount: Int { get }
    var bufferingProgress: Int { get }
    var isPlayable: Bool { get }
    var isFinished: Bool { get }
}

public protocol ObjectQueueItem: class {
    var duration: Int64 { get }
    var size: Int64 { get }
    var position: Int64 { get }
}

protocol PixelFormat {
    var pixelFormatType: OSType { get set }
}

protocol FrameOutput: class {
    var renderSource: OutputRenderSourceDelegate? { get set }
    func play()
    func pause()
    func flush()
    func shutdown()
}

protocol MEFrame: ObjectQueueItem {
    var timebase: Timebase { get set }
}

extension MEFrame {
    public var seconds: TimeInterval {
        return cmtime.seconds
    }

    public var cmtime: CMTime {
        return timebase.cmtime(for: position)
    }
}

// MARK: model

public struct KSDefaultParameter {
    /// 视频颜色编码方式 支持kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange kCVPixelFormatType_420YpCbCr8BiPlanarFullRange kCVPixelFormatType_32BGRA 默认是kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    public static var bufferPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    /// 开启 硬解 默认true
    public static var enableVideotoolbox = true
    /// 日志级别
    public static var logLevel = AV_LOG_WARNING
    public static var audioPlayerMaximumFramesPerSlice = Int32(4096)
    public static var audioPlayerMaximumChannels = Int32(2)
    public static var audioPlayerSampleRate = Int32(44100)
    // 视频缓冲算法函数
    public static var playable: (LoadingStatus) -> Bool = { status in
        guard status.frameCount > 0 else { return false }
        if status.isSecondOpen, status.isFirst || status.isSeek, status.frameCount == status.frameMaxCount {
            if status.isFirst {
                return true
            } else if status.isSeek {
                return status.packetCount >= status.fps
            }
        }
        return status.packetCount > status.fps * Int(KSPlayerManager.preferredForwardBufferDuration)
    }

    // 画面绘制类
    public static var renderViewType: (PixelRenderView & UIView).Type = {
        #if arch(arm)
        return OpenGLPlayView.self
        #else
        #if targetEnvironment(simulator)
        return SampleBufferPlayerView.self
        #else
        return MetalPlayView.self
        #endif
        #endif
    }()
}

// 加载情况
public struct LoadingStatus {
    let fps: Int
    let packetCount: Int
    let frameCount: Int
    let frameMaxCount: Int
    let isFirst: Bool
    let isSeek: Bool
    let isSecondOpen: Bool
}

struct MECodecState: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    static let idle = MECodecState(rawValue: 1 << 0)
    static let opening = MECodecState(rawValue: 1 << 1)
    static let decoding = MECodecState(rawValue: 1 << 2)
    static let flush = MECodecState(rawValue: 1 << 3)
    static let closed = MECodecState(rawValue: 1 << 4)
    static let finished = MECodecState(rawValue: 1 << 5)
    static let failed = MECodecState(rawValue: 1 << 6)
}

struct Timebase {
    static let defaultValue = Timebase(num: 1, den: 1)
    public var num: Int32
    public var den: Int32
    func getPosition(from seconds: TimeInterval) -> Int64 {
        return Int64(seconds * TimeInterval(den) / TimeInterval(num))
    }

    func cmtime(for timestamp: Int64) -> CMTime {
        return CMTime(value: timestamp * Int64(num), timescale: den)
    }
}

extension Timebase {
    public var rational: AVRational {
        return AVRational(num: num, den: den)
    }

    init(_ rational: AVRational) {
        num = rational.num
        den = rational.den
    }
}

struct METime {
    public var timestamp: Int64
    public var timebase: Timebase
}

extension METime {
    public var seconds: TimeInterval {
        return cmtime.seconds
    }

    public var cmtime: CMTime {
        return timebase.cmtime(for: timestamp)
    }
}

final class Packet: ObjectQueueItem {
    public var duration: Int64 = 0
    public var size: Int64 = 0
    public var position: Int64 = 0
    public var corePacket = av_packet_alloc()

    public func fill() {
        if let corePacket = corePacket {
            position = corePacket.pointee.pts
            duration = corePacket.pointee.duration
            size = Int64(corePacket.pointee.size)
        }
    }

    deinit {
        av_packet_free(&corePacket)
        corePacket = nil
    }
}

class Frame: MEFrame {
    public var timebase = Timebase.defaultValue
    public var duration: Int64 = 0
    public var size: Int64 = 0
    public var position: Int64 = 0
}

final class SubtitleFrame: Frame {
    public var part: SubtitlePart?
}

final class AudioFrame: Frame {
    public var data: [UnsafeMutablePointer<UInt8>?]
    public var linesize: [Int32]
    public var bufferSize: Int32 = 0 {
        didSet {
            if bufferSize != oldValue {
                (0 ..< Int(KSDefaultParameter.audioPlayerMaximumChannels)).forEach { index in
                    if oldValue > 0 {
                        data[index]?.deinitialize(count: Int(oldValue))
                        data[index]?.deallocate()
                    }
                    if bufferSize > 0 {
                        data[index] = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(bufferSize))
                    }
                }
            }
        }
    }

    public required override init() {
        data = Array(repeating: nil, count: Int(KSDefaultParameter.audioPlayerMaximumChannels))
        linesize = Array(repeating: bufferSize, count: Int(KSDefaultParameter.audioPlayerMaximumChannels))
    }

    deinit {
        if bufferSize > 0 {
            (0 ..< Int(KSDefaultParameter.audioPlayerMaximumChannels)).forEach { index in
                data[index]?.deinitialize(count: Int(bufferSize))
                data[index]?.deallocate()
            }
        }
    }
}

final class VideoVTBFrame: Frame {
    public var corePixelBuffer: CVPixelBuffer?
    deinit {
        corePixelBuffer = nil
    }
}

final class VideoSampleBufferFrame: Frame {
    public var sampleBuffer: CMSampleBuffer?
}

extension PixelRenderView {
    func set(render: MEFrame) {
        if let render = render as? VideoVTBFrame, let corePixelBuffer = render.corePixelBuffer {
            set(pixelBuffer: corePixelBuffer, time: render.cmtime)
        }
    }
}
