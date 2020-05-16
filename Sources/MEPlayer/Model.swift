//
//  Packet.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
import ffmpeg
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
func canUseMetal() -> Bool {
    #if arch(arm)
    return false
    #else
    #if targetEnvironment(simulator)
    if #available(iOS 13.0, tvOS 13.0, *) {
        return true
    } else {
        return false
    }
    #else
    return true
    #endif
    #endif
}

// MARK: enum

extension NSError {
    convenience init(errorCode: KSPlayerErrorCode, ffmpegErrnum: Int32) {
        var errorStringBuffer = [Int8](repeating: 0, count: 512)
        av_strerror(ffmpegErrnum, &errorStringBuffer, 512)
        let underlyingError = NSError(domain: "FFmpegDomain", code: Int(ffmpegErrnum), userInfo: [NSLocalizedDescriptionKey: String(cString: errorStringBuffer)])
        self.init(errorCode: errorCode, userInfo: [NSUnderlyingErrorKey: underlyingError])
    }
}

extension Int32: Error {}

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
    var currentPlaybackTime: TimeInterval { get }
    func getOutputRender(type: AVFoundation.AVMediaType, isDependent: Bool) -> MEFrame?
    func setVideo(time: CMTime)
    func setAudio(time: CMTime)
}

extension OutputRenderSourceDelegate {
    func getOutputRender(type: AVFoundation.AVMediaType) -> MEFrame? {
        getOutputRender(type: type, isDependent: false)
    }
}

protocol CodecCapacityDelegate: AnyObject {
    func codecDidChangeCapacity(track: PlayerItemTrackProtocol)
    func codecDidFinished(track: PlayerItemTrackProtocol)
}

protocol MEPlayerDelegate: AnyObject {
    func sourceDidChange(loadingState: LoadingState)
    func sourceDidOpened()
    func sourceDidFailed(error: NSError?)
    func sourceDidFinished(type: AVFoundation.AVMediaType, allSatisfy: Bool)
    func sourceDidChange(oldBitRate: Int64, newBitrate: Int64)
}

// MARK: protocol

public protocol ObjectQueueItem {
    var duration: Int64 { get }
    var size: Int64 { get }
    var position: Int64 { get }
}

protocol FrameOutput {
    var renderSource: OutputRenderSourceDelegate? { get set }
    func play()
    func pause()
    func flush()
}

protocol MEFrame: ObjectQueueItem {
    var timebase: Timebase { get set }
}

extension MEFrame {
    public var seconds: TimeInterval { cmtime.seconds }
    public var cmtime: CMTime { timebase.cmtime(for: position) }
}

// MARK: model

public enum LogLevel: Int32 {
    case panic = 0
    case fatal = 8
    case error = 16
    case warning = 24
    case info = 32
    case verbose = 40
    case debug = 48
    case trace = 56
}

extension KSPlayerManager {
    /// 开启VR模式的陀飞轮
    public static var enableSensor = true
    /// 日志级别
    public static var logLevel = LogLevel.warning
    public static var stackSize = 16384
    public static var audioPlayerMaximumFramesPerSlice = AVAudioFrameCount(4096)
    public static var preferredFramesPerSecond = 60
    #if os(macOS)
    public static var audioPlayerSampleRate = Int32(44100)
    public static var audioPlayerMaximumChannels = AVAudioChannelCount(2)
    #else
    public static var audioPlayerSampleRate = Int32(AVAudioSession.sharedInstance().sampleRate)
    public static var audioPlayerMaximumChannels = AVAudioChannelCount(AVAudioSession.sharedInstance().outputNumberOfChannels)
    #endif
    static func outputFormat() -> AudioStreamBasicDescription {
        var audioStreamBasicDescription = AudioStreamBasicDescription()
        let floatByteSize = UInt32(MemoryLayout<Float>.size)
        audioStreamBasicDescription.mBitsPerChannel = 8 * floatByteSize
        audioStreamBasicDescription.mBytesPerFrame = floatByteSize
        audioStreamBasicDescription.mChannelsPerFrame = audioPlayerMaximumChannels
        audioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        audioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM
        audioStreamBasicDescription.mFramesPerPacket = 1
        audioStreamBasicDescription.mBytesPerPacket = audioStreamBasicDescription.mFramesPerPacket * audioStreamBasicDescription.mBytesPerFrame
        audioStreamBasicDescription.mSampleRate = Float64(audioPlayerSampleRate)
        return audioStreamBasicDescription
    }

    static let audioDefaultFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(audioPlayerSampleRate), channels: audioPlayerMaximumChannels, interleaved: false)!
}

struct MECodecState: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    static let idle = MECodecState(rawValue: 1 << 0)
    static let decoding = MECodecState(rawValue: 1 << 1)
    static let flush = MECodecState(rawValue: 1 << 2)
    static let closed = MECodecState(rawValue: 1 << 3)
    static let finished = MECodecState(rawValue: 1 << 4)
    static let failed = MECodecState(rawValue: 1 << 5)
}

struct Timebase {
    static let defaultValue = Timebase(num: 1, den: 1)
    public var num: Int32
    public var den: Int32
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

struct METime {
    public var timestamp: Int64
    public var timebase: Timebase
}

extension METime {
    public var seconds: TimeInterval { cmtime.seconds }

    public var cmtime: CMTime { timebase.cmtime(for: timestamp) }
}

final class Packet: ObjectQueueItem {
    final class AVPacketWrap {
        fileprivate var corePacket = av_packet_alloc()
        deinit {
            av_packet_free(&corePacket)
        }
    }

    public var duration: Int64 = 0
    public var size: Int64 = 0
    public var position: Int64 = 0
    var assetTrack: TrackProtocol!
    var corePacket: UnsafeMutablePointer<AVPacket> { packetWrap.corePacket! }
    private let packetWrap = ObjectPool.share.object(class: AVPacketWrap.self, key: "AVPacketWrap") { AVPacketWrap() }
    func fill() {
        position = corePacket.pointee.pts == Int64.min ? corePacket.pointee.dts : corePacket.pointee.pts
        duration = corePacket.pointee.duration
        size = Int64(corePacket.pointee.size)
    }

    deinit {
        av_packet_unref(corePacket)
        ObjectPool.share.comeback(item: packetWrap, key: "AVPacketWrap")
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

final class ByteDataWrap {
    var data: [UnsafeMutablePointer<UInt8>?]
    var size: [Int] = [0] {
        didSet {
            if size.description != oldValue.description {
                (0 ..< data.count).forEach { i in
                    if oldValue[i] > 0 {
                        data[i]?.deinitialize(count: oldValue[i])
                        data[i]?.deallocate()
                    }
                }
                data.removeAll()
                (0 ..< size.count).forEach { i in
                    data.append(UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size[i])))
                }
            }
        }
    }

    public init() {
        data = Array(repeating: nil, count: 1)
    }

    deinit {
        (0 ..< data.count).forEach { i in
            data[i]?.deinitialize(count: size[i])
            data[i]?.deallocate()
        }
        data.removeAll()
    }
}

final class AudioFrame: Frame {
    public var numberOfSamples = 0
    let dataWrap: ByteDataWrap
    public init(bufferSize: Int32) {
        dataWrap = ObjectPool.share.object(class: ByteDataWrap.self, key: "AudioData") { ByteDataWrap() }
        dataWrap.size = Array(repeating: Int(bufferSize), count: Int(KSPlayerManager.audioPlayerMaximumChannels))
    }

    deinit {
        ObjectPool.share.comeback(item: dataWrap, key: "AudioData")
    }
}

final class VideoVTBFrame: Frame {
    public var corePixelBuffer: BufferProtocol?
}

extension Dictionary where Key == String {
    var avOptions: OpaquePointer? {
        var avOptions: OpaquePointer?
        forEach { key, value in
            if let i = value as? Int64 {
                av_dict_set_int(&avOptions, key, i, 0)
            } else if let i = value as? Int {
                av_dict_set_int(&avOptions, key, Int64(i), 0)
            } else if let string = value as? String {
                av_dict_set(&avOptions, key, string, 0)
            }
        }
        return avOptions
    }
}
