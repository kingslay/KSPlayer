//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public protocol MediaPlayback: AnyObject {
    var duration: TimeInterval { get }
    var naturalSize: CGSize { get }
    var currentPlaybackTime: TimeInterval { get }
    func prepareToPlay()
    func play()
    func shutdown()
    func seek(time: TimeInterval, completion handler: ((Bool) -> Void)?)
}

public protocol MediaPlayerProtocol: MediaPlayback {
    var delegate: MediaPlayerDelegate? { get set }
    var view: UIView { get }
    var playableTime: TimeInterval { get }
    var isPreparedToPlay: Bool { get }
    var playbackState: MediaPlaybackState { get }
    var loadState: MediaLoadState { get }
    var isPlaying: Bool { get }
    //    var numberOfBytesTransferred: Int64 { get }
    var isMuted: Bool { get set }
    var allowsExternalPlayback: Bool { get set }
    var usesExternalPlaybackWhileExternalScreenIsActive: Bool { get set }
    var isExternalPlaybackActive: Bool { get }
    var playbackRate: Float { get set }
    var playbackVolume: Float { get set }
    var contentMode: UIViewContentMode { get set }
    var subtitleDataSouce: SubtitleDataSouce? { get }
    init(url: URL, options: KSOptions)
    func replace(url: URL, options: KSOptions)
    func pause()
    func enterBackground()
    func enterForeground()
    func thumbnailImageAtCurrentTime(handler: @escaping (UIImage?) -> Void)
    func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack]
    func select(track: MediaPlayerTrack)
}

public protocol MediaPlayerDelegate: AnyObject {
    func preparedToPlay(player: MediaPlayerProtocol)
    func changeLoadState(player: MediaPlayerProtocol)
    // 缓冲加载进度，0-100
    func changeBuffering(player: MediaPlayerProtocol, progress: Int)
    func playBack(player: MediaPlayerProtocol, loopCount: Int)
    func finish(player: MediaPlayerProtocol, error: Error?)
}

public protocol MediaPlayerTrack {
    var name: String { get }
    var language: String? { get }
}

extension MediaPlayerProtocol {
    func setAudioSession() {
        #if os(macOS)
//        try? AVAudioSession.sharedInstance().setRouteSharingPolicy(.longFormAudio)
        #else
        let category = AVAudioSession.sharedInstance().category
        if category == .playback || category == .playAndRecord {
            return
        }
        if #available(iOS 11.0, tvOS 11.0, *) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

public enum DisplayEnum {
    case plane
    // swiftlint:disable identifier_name
    case vr
    // swiftlint:enable identifier_name
    case vrBox
}

public struct VideoAdaptationState {
    public struct BitRateState {
        let bitRate: Int64
        let time: TimeInterval
    }

    public let bitRates: [Int64]
    public let duration: TimeInterval
    public var currentPlaybackTime: TimeInterval
    public var fps: Int
    public internal(set) var bitRateStates: [BitRateState]
    public internal(set) var loadedCount: Int = 0
}

public class KSOptions {
    /// 视频颜色编码方式 支持kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange kCVPixelFormatType_420YpCbCr8BiPlanarFullRange kCVPixelFormatType_32BGRA kCVPixelFormatType_420YpCbCr8Planar
    public static var bufferPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    public static var hardwareDecodeH264 = true
    public static var hardwareDecodeH265 = true
    /// 最低缓存视频时间
    public static var preferredForwardBufferDuration = 3.0
    /// 最大缓存视频时间
    public static var maxBufferDuration = 30.0
    /// 是否开启秒开
    public static var isSecondOpen = false
    /// 开启精确seek
    public static var isAccurateSeek = true
    /// 开启无缝循环播放
    public static var isLoopPlay = false
    /// 是否自动播放，默认false
    public static var isAutoPlay = false
    /// seek完是否自动播放
    public static var isSeekedAutoPlay = true

    //    public static let shared = KSOptions()
    public var bufferPixelFormatType = KSOptions.bufferPixelFormatType
    public var hardwareDecodeH264 = KSOptions.hardwareDecodeH264
    public var hardwareDecodeH265 = KSOptions.hardwareDecodeH265
    /// 最低缓存视频时间
    @KSObservable
    public var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration
    /// 最大缓存视频时间
    public var maxBufferDuration = KSOptions.maxBufferDuration
    /// 是否开启秒开
    public var isSecondOpen = KSOptions.isSecondOpen
    /// 开启精确seek
    public var isAccurateSeek = KSOptions.isAccurateSeek
    /// 开启无缝循环播放
    public var isLoopPlay = KSOptions.isLoopPlay
    /// 是否自动播放，默认false
    public var isAutoPlay = KSOptions.isAutoPlay
    /// seek完是否自动播放
    public var isSeekedAutoPlay = KSOptions.isSeekedAutoPlay
    public var display = DisplayEnum.plane
    public var videoDisable = false
    public var audioDisable = false
    public var subtitleDisable = false
    public var asynchronousDecompression = false
    public var videoAdaptable = true
    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var decoderOptions = [String: Any]()
    public internal(set) var formatName = ""
    // 加个节流器，防止频繁的更新加载状态
    private var throttle = CACurrentMediaTime()
    public init() {
        formatContextOptions["analyzeduration"] = 2_000_000
        formatContextOptions["probesize"] = 2_000_000
        formatContextOptions["auto_convert"] = 0
        formatContextOptions["reconnect"] = 1
        // There is total different meaning for 'timeout' option in rtmp
        // remove 'timeout' option for rtmp
        formatContextOptions["timeout"] = 30_000_000
        formatContextOptions["rw_timeout"] = 30_000_000
        formatContextOptions["user_agent"] = "ksplayer"
        decoderOptions["threads"] = "auto"
        decoderOptions["refcounted_frames"] = "1"
    }

    public func setCookie(_ cookies: [HTTPCookie]) {
        #if !os(macOS)
        avOptions[AVURLAssetHTTPCookiesKey] = cookies
        #endif
        var cookieStr = "Cookie: "
        for cookie in cookies {
            cookieStr.append("\(cookie.name)=\(cookie.value); ")
        }
        cookieStr = String(cookieStr.dropLast(2))
        cookieStr.append("\r\n")
        formatContextOptions["headers"] = cookieStr
    }

    // 缓冲算法函数
    open func playable(capacitys: [CapacityProtocol], isFirst: Bool, isSeek: Bool) -> LoadingState? {
        guard isFirst || isSeek ||  CACurrentMediaTime() - throttle > 0.5 else {
            return nil
        }
        let packetCount = capacitys.map { $0.packetCount }.min() ?? 0
        let frameCount = capacitys.map { $0.frameCount }.min() ?? 0
        let isFinished = capacitys.allSatisfy { $0.isFinished }
        let loadedTime = capacitys.map { TimeInterval($0.loadedCount) / TimeInterval($0.fps) }.min() ?? 0
        let progress = loadedTime * 100.0 / preferredForwardBufferDuration
        let isPlayable = capacitys.allSatisfy { capacity in
            guard capacity.frameCount > 0 else { return false }
            // 让音频能更快的打开
            if capacity.mediaType == .audio || isSecondOpen, isFirst || isSeek, capacity.frameCount == capacity.frameMaxCount {
                if isFirst {
                    return true
                } else if isSeek {
                    return capacity.packetCount >= capacity.fps
                }
            }
            return capacity.loadedCount >= capacity.fps * Int(preferredForwardBufferDuration)
        }
        throttle = CACurrentMediaTime()
        return LoadingState(loadedTime: loadedTime, progress: progress, packetCount: packetCount, frameCount: frameCount, isFinished: isFinished, isPlayable: isPlayable, isFirst: isFirst, isSeek: isSeek)
    }

    open func adaptable(state: VideoAdaptationState) -> (Int64, Int64)? {
        guard let last = state.bitRateStates.last, CACurrentMediaTime() - last.time > maxBufferDuration / 2, let index = state.bitRates.firstIndex(of: last.bitRate) else {
            return nil
        }
        let isUp = state.loadedCount > (state.fps * Int(maxBufferDuration)) / 2
        if isUp {
            if index < state.bitRates.endIndex - 1 {
                return (last.bitRate, state.bitRates[index + 1])
            }
        } else {
            if index > state.bitRates.startIndex {
                return (last.bitRate, state.bitRates[index - 1])
            }
        }
        return nil
    }
}

// 缓冲情况
public protocol CapacityProtocol {
    var fps: Int { get }
    var packetCount: Int { get }
    var frameCount: Int { get }
    var frameMaxCount: Int { get }
    var isFinished: Bool { get }
    var mediaType: AVFoundation.AVMediaType { get }
}

public struct LoadingState {
    public let loadedTime: TimeInterval
    public let progress: TimeInterval
    public let packetCount: Int
    public let frameCount: Int
    public let isFinished: Bool
    public let isPlayable: Bool
    public let isFirst: Bool
    public let isSeek: Bool
}

public struct KSPlayerManager {
    public static var firstPlayerType: MediaPlayerProtocol.Type = KSAVPlayer.self
    public static var secondPlayerType: MediaPlayerProtocol.Type?
    /// 日志输出方式
    public static var logFunctionPoint: (String) -> Void = {
        print($0)
    }
}

public enum MediaPlaybackState: Int {
    case idle
    case playing
    case paused
    case seeking
    case finished
    case stopped
}

public enum MediaLoadState: Int {
    case idle
    case loading
    case playable
}

func KSLog(_ message: CustomStringConvertible, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    KSPlayerManager.logFunctionPoint("KSPlayer: \(fileName):\(line) \(function) | \(message)")
}

public let KSPlayerErrorDomain = "KSPlayerErrorDomain"

public enum KSPlayerErrorCode: Int {
    case unknown
    case formatCreate
    case formatOpenInput
    case formatFindStreamInfo
    case readFrame
    case codecContextCreate
    case codecContextSetParam
    case codecContextFindDecoder
    case codesContextOpen
    case codecVideoSendPacket
    case codecAudioSendPacket
    case codecVideoReceiveFrame
    case codecAudioReceiveFrame
    case auidoSwrInit
    case codecSubtitleSendPacket
    case videoTracksUnplayable
    case subtitleUnEncoding
    case subtitleUnParse
    case subtitleFormatUnSupport
}

extension KSPlayerErrorCode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .formatCreate:
            return "avformat_alloc_context return nil"
        case .formatOpenInput:
            return "avformat can't open input"
        case .formatFindStreamInfo:
            return "avformat_find_stream_info return nil"
        case .codecContextCreate:
            return "avcodec_alloc_context3 return nil"
        case .codecContextSetParam:
            return "avcodec can't set parameters to context"
        case .codesContextOpen:
            return "codesContext can't Open"
        case .codecVideoReceiveFrame:
            return "avcodec can't receive video frame"
        case .codecAudioReceiveFrame:
            return "avcodec can't receive audio frame"
        case .videoTracksUnplayable:
            return "VideoTracks are not even playable."
        case .codecSubtitleSendPacket:
            return "avcodec can't decode subtitle"
        case .subtitleUnEncoding:
            return "Subtitle encoding format is not supported."
        case .subtitleUnParse:
            return "Subtitle parsing error"
        case .subtitleFormatUnSupport:
            return "Current subtitle format is not supported"
        default:
            return "unknown"
        }
    }
}

extension NSError {
    convenience init(errorCode: KSPlayerErrorCode, userInfo: [String: Any] = [:]) {
        var userInfo = userInfo
        userInfo[NSLocalizedDescriptionKey] = errorCode.description
        self.init(domain: KSPlayerErrorDomain, code: errorCode.rawValue, userInfo: userInfo)
    }
}
