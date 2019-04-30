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

@objc public protocol MediaPlayback: AnyObject {
    var duration: TimeInterval { get }
    var naturalSize: CGSize { get }
    var currentPlaybackTime: TimeInterval { get }
    /// 开启无缝循环播放
    var isLoopPlay: Bool { get set }
    func prepareToPlay()
    func play()
    func shutdown()
    func seek(time: TimeInterval, completion handler: ((Bool) -> Void)?)
}

@objc public protocol MediaPlayerProtocol: MediaPlayback {
    var delegate: MediaPlayerDelegate? { get set }
    var view: UIView { get }
    var playableTime: TimeInterval { get }
    var isPreparedToPlay: Bool { get }
    var playbackState: MediaPlaybackState { get }
    var loadState: MediaLoadState { get }
    var isPlaying: Bool { get }
    //    var numberOfBytesTransferred: Int64 { get }
    var isAutoPlay: Bool { get set }
    var isMuted: Bool { get set }
    var allowsExternalPlayback: Bool { get set }
    var usesExternalPlaybackWhileExternalScreenIsActive: Bool { get set }
    var isExternalPlaybackActive: Bool { get }
    var playbackRate: Float { get set }
    var playbackVolume: Float { get set }
    var contentMode: UIViewContentMode { get set }
    var preferredForwardBufferDuration: TimeInterval { get set }
    var subtitleDataSouce: SubtitleDataSouce? { get }
    init(url: URL, options: [String: Any]?)
    func replace(url: URL, options: [String: Any]?)
    func pause()
    func enterBackground()
    func enterForeground()
    func thumbnailImageAtCurrentTime() -> UIImage?
}

@objc public protocol MediaPlayerDelegate: AnyObject {
    func preparedToPlay(player: MediaPlayerProtocol)
    func changeLoadState(player: MediaPlayerProtocol)
    // 缓冲加载进度，0-100
    func changeBuffering(player: MediaPlayerProtocol, progress: Int)
    func playBack(player: MediaPlayerProtocol, loopCount: Int)
    func finish(player: MediaPlayerProtocol, error: Error?)
}

extension MediaPlayerProtocol {
    func setAudioSession() {
        #if !os(macOS)
        if #available(iOS 11.0, tvOS 11.0, *) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longForm)
        } else if #available(iOS 10.0, *) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

public enum KSPlayerTopBarShowCase {
    /// 始终显示
    case always
    /// 只在横屏界面显示
    case horizantalOnly
    /// 不显示
    case none
}

public struct KSPlayerManager {
    /// 是否自动播放，默认false
    public static var isAutoPlay = false
    /// seek完是否自动播放
    public static var isSeekedAutoPlay = true
    /// 顶部返回、标题、AirPlay按钮 显示选项，默认.Always，可选.HorizantalOnly、.None
    public static var topBarShowInCase = KSPlayerTopBarShowCase.always
    /// 自动隐藏操作栏的时间间隔 默认5秒
    public static var animateDelayTimeInterval = TimeInterval(5)
    /// 开启亮度手势 默认true
    public static var enableBrightnessGestures = true
    /// 开启音量手势 默认true
    public static var enableVolumeGestures = true
    /// 开启进度滑动手势 默认true
    public static var enablePlaytimeGestures = true
    /// 竖屏是否开启手势控制 默认false
    public static var enablePortraitGestures = false
    /// 最低缓存视频时间
    public static var preferredForwardBufferDuration = 3.0
    /// 最大缓存视频时间
    public static var maxBufferDuration = 30.0
    /// 播放内核选择策略 先使用firstPlayer，失败了自动切换到secondPlayer，播放内核有KSAVPlayer、KSMEPlayer两个选项
    public static var firstPlayerType: MediaPlayerProtocol.Type = KSAVPlayer.self
    public static var secondPlayerType: MediaPlayerProtocol.Type?
    /// 是否开启秒开
    public static var isSecondOpen = false
    /// 开启精确seek
    public static var isAccurateSeek = true
    /// 开启无缝循环播放
    public static var isLoopPlay = false
    /// 是否能后台播放视频
    public static var canBackgroundPlay = false
    /// 日志输出方式
    public static var logFunctionPoint: (String) -> Void = {
        print($0)
    }
}

@objc public enum MediaPlaybackState: Int {
    case idle
    case stopped
    case playing
    case paused
    case seeking
    case finished
}

@objc public enum MediaLoadState: Int {
    case idle
    case paused
    case loading
    case playable
}

func KSLog(_ message: CustomStringConvertible, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    KSPlayerManager.logFunctionPoint("KSPlayer: \(fileName):\(line) \(function) | \(message)")
}

public protocol PixelRenderView {
    func set(pixelBuffer: CVPixelBuffer, time: CMTime)
}
