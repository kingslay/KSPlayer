//
//  KSPlayerItem.swift
//  Pods
//
//  Created by kintan on 16/5/21.
//
//

import AVFoundation
import Foundation

public enum DisplayEnum {
    case plane
    // swiftlint:disable identifier_name
    case vr
    // swiftlint:enable identifier_name
    case vrBox
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

    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var decoderOptions = [String: Any]()
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

    // 视频缓冲算法函数
    open func playable(status: LoadingStatus) -> Bool {
        guard status.frameCount > 0 else { return false }
        if status.isSecondOpen, status.isFirst || status.isSeek, status.frameCount == status.frameMaxCount {
            if status.isFirst {
                return true
            } else if status.isSeek {
                return status.packetCount >= status.fps
            }
        }
        return status.packetCount > status.fps * Int(preferredForwardBufferDuration)
    }
}

public class KSPlayerResource: Hashable {
    public static func == (lhs: KSPlayerResource, rhs: KSPlayerResource) -> Bool {
        lhs.definitions == rhs.definitions
    }

    public let name: String
    public let cover: URL?
    public let definitions: [KSPlayerResourceDefinition]
    public var subtitle: KSSubtitleProtocol?
    /**
     Player recource item with url, used to play single difinition video

     - parameter name:      video name
     - parameter url:       video url
     - parameter cover:     video cover, will show before playing, and hide when play
     - parameter subtitleURL: video subtitle
     */
    public convenience init(url: URL, options: KSOptions = KSOptions(), name: String = "", cover: URL? = nil, subtitleURL: URL? = nil) {
        let definition = KSPlayerResourceDefinition(url: url, definition: "", options: options)
        var subtitle: KSSubtitleProtocol?
        if let subtitleURL = subtitleURL {
            subtitle = KSURLSubtitle(url: subtitleURL)
        }
        self.init(name: name, definitions: [definition], cover: cover, subtitle: subtitle)
    }

    /**
     Play resouce with multi definitions

     - parameter name:        video name
     - parameter definitions: video definitions
     - parameter cover:       video cover
     - parameter subtitle:   video subtitle
     */
    public init(name: String = "", definitions: [KSPlayerResourceDefinition], cover: URL? = nil, subtitle: KSSubtitleProtocol? = nil) {
        self.name = name
        self.cover = cover
        self.subtitle = subtitle
        self.definitions = definitions
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(definitions)
    }
}

public class KSPlayerResourceDefinition: Hashable {
    public static func == (lhs: KSPlayerResourceDefinition, rhs: KSPlayerResourceDefinition) -> Bool {
        lhs.url == rhs.url
    }

    public let url: URL
    public let definition: String
    public let options: KSOptions
    /// 代理地址
    public var proxyUrl: URL?

    /**
     Video recource item with defination name and specifying options

     - parameter url:        video url
     - parameter definition: url deifination
     - parameter options:    specifying options for the initialization of the AVURLAsset

     you can add http-header or other options which mentions in https://developer.apple.com/reference/avfoundation/avurlasset/initialization_options

     to add http-header init options like this
     ```
     let header = ["user_agent":"KSPlayer"]
     let options = KSOptions()
     options.avOptions = ["AVURLAssetHTTPHeaderFieldsKey":header]
     ```
     */
    public init(url: URL, definition: String, options: KSOptions = KSOptions()) {
        self.url = url
        self.definition = definition
        self.options = options
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
