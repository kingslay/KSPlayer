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
    func getVideoOutputRender(force: Bool) -> VideoVTBFrame?
    func getAudioOutputRender() -> AudioFrame?
    func setVideo(time: CMTime)
    func setAudio(time: CMTime)
}

protocol CodecCapacityDelegate: AnyObject {
    func codecDidFinished(track: some CapacityProtocol)
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
    var duration: Int64 { get set }
    var size: Int64 { get set }
    var position: Int64 { get set }
}

protocol FrameOutput: AnyObject {
    var renderSource: OutputRenderSourceDelegate? { get set }
    var isPaused: Bool { get set }
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

public extension KSOptions {
    /// 开启VR模式的陀飞轮
    static var enableSensor = true
    /// 日志级别
    static var logLevel = LogLevel.warning
    static var stackSize = 32768
    static var channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
    #if os(macOS)
    internal static var audioPlayerSampleRate = Int32(44100)
    #else
    internal static var audioPlayerSampleRate = Int32(AVAudioSession.sharedInstance().sampleRate)
    #endif
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
    var size: Int64 = 0
    var position: Int64 = 0
    var assetTrack: FFmpegAssetTrack!
    private(set) var corePacket = av_packet_alloc()
    func fill() {
        guard let corePacket else {
            return
        }
        position = corePacket.pointee.pts == Int64.min ? corePacket.pointee.dts : corePacket.pointee.pts
        duration = corePacket.pointee.duration
        size = Int64(corePacket.pointee.size)
    }

    deinit {
        av_packet_unref(corePacket)
        av_packet_free(&corePacket)
    }
}

final class SubtitleFrame: MEFrame {
    var timebase: Timebase
    var duration: Int64 = 0
    var size: Int64 = 0
    var position: Int64 = 0
    let part: SubtitlePart
    init(part: SubtitlePart, timebase: Timebase) {
        self.part = part
        self.timebase = timebase
    }
}

final class AudioFrame: MEFrame {
    var timebase = Timebase.defaultValue
    var duration: Int64 = 0
    var size: Int64 = 0
    var position: Int64 = 0
    var numberOfSamples = 0
    var data: [UnsafeMutablePointer<UInt8>?]
    let dataSize: [Int]
    public init(bufferSize: Int32, channels: Int32) {
        dataSize = Array(repeating: Int(bufferSize), count: Int(channels))
        data = (0 ..< channels).map { _ in
            UnsafeMutablePointer<UInt8>.allocate(capacity: Int(bufferSize))
        }
    }

    deinit {
        for i in 0 ..< data.count {
            data[i]?.deinitialize(count: dataSize[i])
            data[i]?.deallocate()
        }
        data.removeAll()
    }
}

final class VideoVTBFrame: MEFrame {
    var timebase = Timebase.defaultValue
    var duration: Int64 = 0
    var size: Int64 = 0
    var position: Int64 = 0
    var corePixelBuffer: CVPixelBuffer?
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
            } else if let dic = value as? Dictionary {
                let string = dic.map { "\($0.0)=\($0.1)" }.joined(separator: "\r\n")
                av_dict_set(&avOptions, key, string, 0)
            }
        }
        return avOptions
    }
}

public struct AVError: Error, Equatable {
    public var code: Int32
    public var message: String

    init(code: Int32) {
        self.code = code
        message = String(avErrorCode: code)
    }
}

extension String {
    init(avErrorCode code: Int32) {
        let buf = UnsafeMutablePointer<Int8>.allocate(capacity: Int(AV_ERROR_MAX_STRING_SIZE))
        buf.initialize(repeating: 0, count: Int(AV_ERROR_MAX_STRING_SIZE))
        defer { buf.deallocate() }
        self = String(cString: av_make_error_string(buf, Int(AV_ERROR_MAX_STRING_SIZE), code))
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
