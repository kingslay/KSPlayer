//
//  MediaPlayerProtocol.swift
//  KSPlayer-tvOS
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Foundation
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
    func shutdown()
    func seek(time: TimeInterval, completion: @escaping ((Bool) -> Void))
}

public protocol MediaPlayerProtocol: MediaPlayback {
    var delegate: MediaPlayerDelegate? { get set }
    var view: UIView? { get }
    var playableTime: TimeInterval { get }
    var isReadyToPlay: Bool { get }
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
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
    var playbackCoordinator: AVPlaybackCoordinator { get }
    @available(tvOS 14.0, *)
    var pipController: KSPictureInPictureController? { get }
    init(url: URL, options: KSOptions)
    func replace(url: URL, options: KSOptions)
    func play()
    func pause()
    func enterBackground()
    func enterForeground()
    func thumbnailImageAtCurrentTime() async -> CGImage?
    func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack]
    func select(track: MediaPlayerTrack)
}

public extension MediaPlayerProtocol {
    var nominalFrameRate: Float {
        tracks(mediaType: .video).first { $0.isEnabled }?.nominalFrameRate ?? 0
    }
}

public protocol MediaPlayerDelegate: AnyObject {
    func readyToPlay(player: some MediaPlayerProtocol)
    func changeLoadState(player: some MediaPlayerProtocol)
    // 缓冲加载进度，0-100
    func changeBuffering(player: some MediaPlayerProtocol, progress: Int)
    func playBack(player: some MediaPlayerProtocol, loopCount: Int)
    func finish(player: some MediaPlayerProtocol, error: Error?)
}

public protocol MediaPlayerTrack: AnyObject, CustomStringConvertible {
    var trackID: Int32 { get }
    var name: String { get }
    var language: String? { get }
    var mediaType: AVFoundation.AVMediaType { get }
    var mediaSubType: CMFormatDescription.MediaSubType { get }
    var nominalFrameRate: Float { get }
    var rotation: Int16 { get }
    var bitRate: Int64 { get }
    var naturalSize: CGSize { get }
    var isEnabled: Bool { get set }
    var depth: Int32 { get }
    var fullRangeVideo: Bool { get }
    var colorPrimaries: String? { get }
    var transferFunction: String? { get }
    var yCbCrMatrix: String? { get }
    var isImageSubtitle: Bool { get }
    var audioStreamBasicDescription: AudioStreamBasicDescription? { get }
    var dovi: DOVIDecoderConfigurationRecord? { get }
    var fieldOrder: FFmpegFieldOrder { get }
}

// public extension MediaPlayerTrack: Identifiable {
//    var id: Int32 { trackID }
// }

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

// swiftlint:disable identifier_name
public struct DOVIDecoderConfigurationRecord {
    let dv_version_major: UInt8
    let dv_version_minor: UInt8
    let dv_profile: UInt8
    let dv_level: UInt8
    let rpu_present_flag: UInt8
    let el_present_flag: UInt8
    let bl_present_flag: UInt8
    let dv_bl_signal_compatibility_id: UInt8
}

public enum FFmpegFieldOrder: UInt8 {
    case unknown = 0
    case progressive
    case tt // < Top coded_first, top displayed first
    case bb // < Bottom coded first, bottom displayed first
    case tb // < Top coded first, bottom displayed first
    case bt // < Bottom coded first, top displayed first
}

// swiftlint:enable identifier_name
