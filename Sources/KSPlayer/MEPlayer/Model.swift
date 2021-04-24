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

extension NSError {
    convenience init(errorCode: KSPlayerErrorCode, ffmpegErrnum: Int32) {
        var errorStringBuffer = [Int8](repeating: 0, count: 512)
        av_strerror(ffmpegErrnum, &errorStringBuffer, 512)
        let underlyingError = NSError(domain: "FFmpegDomain", code: Int(ffmpegErrnum), userInfo: [NSLocalizedDescriptionKey: String(cString: errorStringBuffer)])
        self.init(errorCode: errorCode, userInfo: [NSUnderlyingErrorKey: underlyingError])
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

protocol OutputRenderSourceDelegate: AnyObject {
    var currentPlaybackTime: TimeInterval { get }
    func getOutputRender(type: AVFoundation.AVMediaType) -> MEFrame?
    func setVideo(time: CMTime)
    func setAudio(time: CMTime)
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

protocol FrameOutput: AnyObject {
    var renderSource: OutputRenderSourceDelegate? { get set }
    var isPaused: Bool { get set }
}

protocol MEFrame: ObjectQueueItem {
    var timebase: Timebase { get set }
    var position: Int64 { get set}
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
    public static var stackSize = 32768
    public static var audioPlayerMaximumFramesPerSlice = AVAudioFrameCount(4096)
    public static var preferredFramesPerSecond = 60
    #if os(macOS)
    public static var audioPlayerSampleRate = Int32(44100)
    public static var audioPlayerMaximumChannels = AVAudioChannelCount(2)
    #else
    public static var audioPlayerSampleRate = Int32(AVAudioSession.sharedInstance().sampleRate)
    public static var audioPlayerMaximumChannels = AVAudioChannelCount(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels)
    #endif
    static func outputFormat() -> AudioStreamBasicDescription {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(audioPlayerMaximumChannels))
        #endif
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

extension AVRational {
    var size: CGSize {
        num > 0 && den > 0 ? CGSize(width: Int(den), height: Int(num)) : CGSize(width: 1, height: 1)
    }
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

final class SubtitleFrame: MEFrame {
    public var timebase = Timebase.defaultValue
    public var duration: Int64 = 0
    public var size: Int64 = 0
    public var position: Int64 = 0
    public let part: SubtitlePart
    init(part: SubtitlePart) {
        self.part = part
    }
}

final class ByteDataWrap {
    var data: [UnsafeMutablePointer<UInt8>?]
    var size: [Int] = [0] {
        didSet {
            if size.description != oldValue.description {
                for i in (0 ..< data.count) where oldValue[i] > 0 {
                    data[i]?.deinitialize(count: oldValue[i])
                    data[i]?.deallocate()
                }
                data.removeAll()
                for i in (0 ..< size.count) {
                    data.append(UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size[i])))
                }
            }
        }
    }

    public init() {
        data = Array(repeating: nil, count: 1)
    }

    deinit {
        for i in (0 ..< data.count) {
            data[i]?.deinitialize(count: size[i])
            data[i]?.deallocate()
        }
        data.removeAll()
    }
}

final class MTLBufferWrap {
    var data: [MTLBuffer?]
    var size: [Int] {
        didSet {
            if size.description != oldValue.description {
                data = size.map { MetalRender.device.makeBuffer(length: $0) }
            }
        }
    }
    public init(size: [Int]) {
        self.size = size
        data = size.map { MetalRender.device.makeBuffer(length: $0) }
    }

    deinit {
        (0 ..< data.count).forEach { i in
            data[i] = nil
        }
        data.removeAll()
    }
}

final class AudioFrame: MEFrame {
    public var timebase = Timebase.defaultValue
    public var duration: Int64 = 0
    public var size: Int64 = 0
    public var position: Int64 = 0
    public var numberOfSamples = 0
    let dataWrap: ByteDataWrap

    public init(bufferSize: Int32, channels: Int32) {
        dataWrap = ObjectPool.share.object(class: ByteDataWrap.self, key: "AudioData_\(channels)") { ByteDataWrap() }
        if dataWrap.size[0] < bufferSize {
            dataWrap.size = Array(repeating: Int(bufferSize), count: Int(channels))
        }
    }

    deinit {
        ObjectPool.share.comeback(item: dataWrap, key: "AudioData_\(dataWrap.data.count)")
    }
}

final class VideoVTBFrame: MEFrame {
    public var timebase = Timebase.defaultValue
    public var duration: Int64 = 0
    public var size: Int64 = 0
    public var position: Int64 = 0
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
