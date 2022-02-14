//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import AVKit
import CoreMedia
import CoreServices
#if canImport(UIKit)
import UIKit
extension UIScreen {
    static var size: CGSize {
        main.bounds.size
    }
}
#else
import AppKit
public typealias UIView = NSView
public typealias UIScreen = NSScreen
extension NSScreen {
    static var size: CGSize {
        main?.frame.size ?? .zero
    }
}
#endif

public protocol MediaPlayback: AnyObject {
    var duration: TimeInterval { get }
    var naturalSize: CGSize { get }
    var currentPlaybackTime: TimeInterval { get }
    func prepareToPlay()
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
    var seekable: Bool { get }
    //    var numberOfBytesTransferred: Int64 { get }
    var isMuted: Bool { get set }
    var allowsExternalPlayback: Bool { get set }
    var usesExternalPlaybackWhileExternalScreenIsActive: Bool { get set }
    var isExternalPlaybackActive: Bool { get }
    var playbackRate: Float { get set }
    var playbackVolume: Float { get set }
    var contentMode: UIViewContentMode { get set }
    var subtitleDataSouce: SubtitleDataSouce? { get }
    @available(tvOS 14.0, macOS 10.15, *)
    var pipController: AVPictureInPictureController? { get }
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
    var playbackCoordinator: AVPlaybackCoordinator { get }
    init(url: URL, options: KSOptions)
    func replace(url: URL, options: KSOptions)
    func play()
    func pause()
    func enterBackground()
    func enterForeground()
    func thumbnailImageAtCurrentTime(handler: @escaping (UIImage?) -> Void)
    func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack]
    func select(track: MediaPlayerTrack)
}

public extension MediaPlayerProtocol {
    var nominalFrameRate: Float {
        tracks(mediaType: .video).first { $0.isEnabled }?.nominalFrameRate ?? 0
    }
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
    var mediaType: AVFoundation.AVMediaType { get }
    var codecType: FourCharCode { get }
    var nominalFrameRate: Float { get }
    var rotation: Double { get }
    var bitRate: Int64 { get }
    var naturalSize: CGSize { get }
    var isEnabled: Bool { get }
    var bitDepth: Int32 { get }
    var colorPrimaries: String? { get }
    var transferFunction: String? { get }
    var yCbCrMatrix: String? { get }
}

public extension FourCharCode {
    var string: String {
        let cString: [CChar] = [
            CChar(self >> 24 & 0xFF),
            CChar(self >> 16 & 0xFF),
            CChar(self >> 8 & 0xFF),
            CChar(self & 0xFF),
            0,
        ]
        return String(cString: cString)
    }
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
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
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
    public internal(set) var fps: Float
    public internal(set) var bitRateStates: [BitRateState]
    public internal(set) var currentPlaybackTime: TimeInterval = 0
    public internal(set) var isPlayable: Bool = false
    public internal(set) var loadedCount: Int = 0
}

open class KSOptions {
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
    /// Applies to short videos only
    public static var isLoopPlay = false
    /// 是否自动播放，默认false
    public static var isAutoPlay = false
    /// seek完是否自动播放
    public static var isSeekedAutoPlay = true

    //    public static let shared = KSOptions()
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
    /// Applies to short videos only
    public var isLoopPlay = KSOptions.isLoopPlay
    /// 是否自动播放，默认false
    public var isAutoPlay = KSOptions.isAutoPlay
    /// seek完是否自动播放
    public var isSeekedAutoPlay = KSOptions.isSeekedAutoPlay
    /*
     AVSEEK_FLAG_BACKWARD: 1
     AVSEEK_FLAG_BYTE: 2
     AVSEEK_FLAG_ANY: 4
     AVSEEK_FLAG_FRAME: 8
     */
    public var seekFlags = Int32(1)
//    ffmpeg only cache http
    public var cache = false
    public var display = DisplayEnum.plane
    public var audioDelay = 0.0 // s
    public var subtitleDelay = 0.0 // s
    public var videoDisable = false
    public var audioDisable = false
    public var audioFilters: String?
    public var videoFilters: String?
    public var subtitleDisable = false
    public var videoAdaptable = true
    public var syncDecodeAudio = false
    public var syncDecodeVideo = false
    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var decoderOptions = [String: Any]()
    public var probesize: Int64?
    public var maxAnalyzeDuration: Int64?
    public var lowres = UInt8(0)
    public internal(set) var formatName = ""
    public internal(set) var starTime = 0.0
    public internal(set) var openTime = 0.0
    public internal(set) var findTime = 0.0
    public internal(set) var readAudioTime = 0.0
    public internal(set) var readVideoTime = 0.0
    public internal(set) var decodeAudioTime = 0.0
    public internal(set) var decodeVideoTime = 0.0
    public init() {
        formatContextOptions["auto_convert"] = 0
        formatContextOptions["fps_probe_size"] = 3
        formatContextOptions["reconnect"] = 1
        // There is total different meaning for 'listen_timeout' option in rtmp
        // set 'listen_timeout' = -1 for rtmp、rtsp
//        formatContextOptions["listen_timeout"] = 3
        formatContextOptions["rw_timeout"] = 3_000_000
        formatContextOptions["user_agent"] = "ksplayer"
        decoderOptions["threads"] = "auto"
        decoderOptions["refcounted_frames"] = "1"
    }

    public func setCookie(_ cookies: [HTTPCookie]) {
        if #available(OSX 10.15, *) {
            avOptions[AVURLAssetHTTPCookiesKey] = cookies
        }
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
        let packetCount = capacitys.map(\.packetCount).min() ?? 0
        let frameCount = capacitys.map(\.frameCount).min() ?? 0
        let isEndOfFile = capacitys.allSatisfy(\.isEndOfFile)
        let loadedTime = capacitys.map { TimeInterval($0.packetCount + $0.frameCount) / TimeInterval($0.fps) }.min() ?? 0
        let progress = loadedTime * 100.0 / preferredForwardBufferDuration
        let isPlayable = capacitys.allSatisfy { capacity in
            if capacity.isEndOfFile && capacity.packetCount == 0 {
                return true
            }
            guard capacity.frameCount >= capacity.frameMaxCount >> 2 else {
                return false
            }
            if (syncDecodeVideo && capacity.mediaType == .video) || (syncDecodeAudio && capacity.mediaType == .audio) {
                return true
            }
            if isFirst || isSeek {
                // 让音频能更快的打开
                if capacity.mediaType == .audio || isSecondOpen {
                    if isFirst {
                        return true
                    } else if isSeek, capacity.packetCount >= Int(capacity.fps) {
                        return true
                    }
                }
            }
            return capacity.packetCount + capacity.frameCount >= Int(capacity.fps * Float(preferredForwardBufferDuration))
        }
        return LoadingState(loadedTime: loadedTime, progress: progress, packetCount: packetCount,
                            frameCount: frameCount, isEndOfFile: isEndOfFile, isPlayable: isPlayable,
                            isFirst: isFirst, isSeek: isSeek)
    }

    open func adaptable(state: VideoAdaptationState) -> (Int64, Int64)? {
        guard let last = state.bitRateStates.last, CACurrentMediaTime() - last.time > maxBufferDuration / 2, let index = state.bitRates.firstIndex(of: last.bitRate) else {
            return nil
        }
        let isUp = state.loadedCount > Int(Double(state.fps) * maxBufferDuration / 2)
        if isUp != state.isPlayable {
            return nil
        }
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

    ///  wanted video stream index, or nil for automatic selection
    /// - Parameter : video bitRate
    /// - Returns: The index of the bitRates
    open func wantedVideo(bitRates _: [Int64]) -> Int? {
        nil
    }

    /// wanted audio stream index, or nil for automatic selection
    /// - Parameter :  audio bitRate and language
    /// - Returns: The index of the infos
    open func wantedAudio(infos _: [(bitRate: Int64, language: String?)]) -> Int? {
        nil
    }

    open func videoFrameMaxCount(fps _: Float) -> Int {
        8
    }

    open func audioFrameMaxCount(fps _: Float, channels: Int) -> Int {
        (16 * max(channels, 1)) >> 1
    }

    /// customize dar
    /// - Parameters:
    ///   - sar: SAR(Sample Aspect Ratio)
    ///   - dar: PAR(Pixel Aspect Ratio)
    /// - Returns: DAR(Display Aspect Ratio)
    open func customizeDar(sar _: CGSize, par _: CGSize) -> CGSize? {
        nil
    }

    private class func deviceCpuCount() -> Int {
        var ncpu = UInt(0)
        var len: size_t = MemoryLayout.size(ofValue: ncpu)
        sysctlbyname("hw.ncpu", &ncpu, &len, nil, 0)
        return Int(ncpu)
    }

    open func isUseDisplayLayer() -> Bool {
        display == .plane
    }
}

// 缓冲情况
public protocol CapacityProtocol {
    var fps: Float { get }
    var packetCount: Int { get }
    var frameCount: Int { get }
    var frameMaxCount: Int { get }
    var isEndOfFile: Bool { get }
    var mediaType: AVFoundation.AVMediaType { get }
}

public struct LoadingState {
    public let loadedTime: TimeInterval
    public let progress: TimeInterval
    public let packetCount: Int
    public let frameCount: Int
    public let isEndOfFile: Bool
    public let isPlayable: Bool
    public let isFirst: Bool
    public let isSeek: Bool
}

public enum KSPlayerManager {
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
        case .auidoSwrInit:
            return "swr_init swrContext fail"
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

@propertyWrapper public final class KSObservable<T> {
    public var observer: ((_ oldValue: T, _ newValue: T) -> Void)? {
        didSet {
            observer?(wrappedValue, wrappedValue)
        }
    }

    public var wrappedValue: T {
        didSet {
            observer?(oldValue, wrappedValue)
        }
    }

    public var projectedValue: KSObservable { self }

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

extension CMTime {
    init(seconds: TimeInterval) {
        self.init(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC))
    }
}

extension CMTimeRange {
    init(start: TimeInterval, end: TimeInterval) {
        self.init(start: CMTime(seconds: start), end: CMTime(seconds: end))
    }
}

extension CGPoint {
    var reverse: CGPoint {
        CGPoint(x: y, y: x)
    }
}

extension CGSize {
    var reverse: CGSize {
        CGSize(width: height, height: width)
    }

    var toPoint: CGPoint {
        CGPoint(x: width, y: height)
    }

    var isHorizonal: Bool {
        width > height
    }
}

func * (left: CGSize, right: CGFloat) -> CGSize {
    CGSize(width: left.width * right, height: left.height * right)
}

func * (left: CGPoint, right: CGFloat) -> CGPoint {
    CGPoint(x: left.x * right, y: left.y * right)
}

func * (left: CGRect, right: CGFloat) -> CGRect {
    CGRect(origin: left.origin * right, size: left.size * right)
}

func - (left: CGSize, right: CGSize) -> CGSize {
    CGSize(width: left.width - right.width, height: left.height - right.height)
}

public func runInMainqueue(block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

extension UIView {
    var widthConstraint: NSLayoutConstraint? {
        // 防止返回NSContentSizeLayoutConstraint
        constraints.first { $0.isMember(of: NSLayoutConstraint.self) && $0.firstAttribute == .width }
    }

    var heightConstraint: NSLayoutConstraint? {
        // 防止返回NSContentSizeLayoutConstraint
        constraints.first { $0.isMember(of: NSLayoutConstraint.self) && $0.firstAttribute == .height }
    }

    var trailingConstraint: NSLayoutConstraint? {
        superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .trailing }
    }

    var leadingConstraint: NSLayoutConstraint? {
        superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .leading }
    }

    var topConstraint: NSLayoutConstraint? {
        superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .top }
    }

    var bottomConstraint: NSLayoutConstraint? {
        superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .bottom }
    }

    var centerXConstraint: NSLayoutConstraint? {
        superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .centerX }
    }

    var centerYConstraint: NSLayoutConstraint? {
        superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .centerY }
    }

    var frameConstraints: [NSLayoutConstraint] {
        var frameConstraint = superview?.constraints.filter { constraint in
            constraint.firstItem === self
        } ?? [NSLayoutConstraint]()
        for constraint in constraints where
            constraint.isMember(of: NSLayoutConstraint.self) && constraint.firstItem === self && (constraint.firstAttribute == .width || constraint.firstAttribute == .height) {
            frameConstraint.append(constraint)
        }
        return frameConstraint
    }

    var safeTopAnchor: NSLayoutYAxisAnchor {
        if #available(macOS 11.0, *) {
            return self.safeAreaLayoutGuide.topAnchor
        } else {
            return topAnchor
        }
    }

    var readableTopAnchor: NSLayoutYAxisAnchor {
        #if os(macOS)
        topAnchor
        #else
        readableContentGuide.topAnchor
        #endif
    }

    var safeLeadingAnchor: NSLayoutXAxisAnchor {
        if #available(macOS 11.0, *) {
            return self.safeAreaLayoutGuide.leadingAnchor
        } else {
            return leadingAnchor
        }
    }

    var safeTrailingAnchor: NSLayoutXAxisAnchor {
        if #available(macOS 11.0, *) {
            return self.safeAreaLayoutGuide.trailingAnchor
        } else {
            return trailingAnchor
        }
    }

    var safeBottomAnchor: NSLayoutYAxisAnchor {
        if #available(macOS 11.0, *) {
            return self.safeAreaLayoutGuide.bottomAnchor
        } else {
            return bottomAnchor
        }
    }
}

extension URL {
    var isMovie: Bool {
        if let typeID = try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier as CFString? {
            return UTTypeConformsTo(typeID, kUTTypeMovie)
        }
        return false
    }

    var isAudio: Bool {
        if let typeID = try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier as CFString? {
            return UTTypeConformsTo(typeID, kUTTypeAudio)
        }
        return false
    }
}
