//
//  Defaults.swift
//  TracyPlayer
//
//  Created by kintan on 2023/7/21.
//

import Foundation
import KSPlayer
import SwiftUI

@MainActor
public class Defaults: ObservableObject {
    @AppStorage("preferredForwardBufferDuration")
    public var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration {
        didSet {
            KSOptions.preferredForwardBufferDuration = preferredForwardBufferDuration
        }
    }

    @AppStorage("maxBufferDuration")
    public var maxBufferDuration = KSOptions.maxBufferDuration {
        didSet {
            KSOptions.maxBufferDuration = maxBufferDuration
        }
    }

    @AppStorage("isLoopPlay")
    public var isLoopPlay = KSOptions.isLoopPlay {
        didSet {
            KSOptions.isLoopPlay = isLoopPlay
        }
    }

    @AppStorage("canBackgroundPlay")
    public var canBackgroundPlay = KSOptions.canBackgroundPlay {
        didSet {
            KSOptions.canBackgroundPlay = canBackgroundPlay
        }
    }

    @AppStorage("isAutoPlay")
    public var isAutoPlay = KSOptions.isAutoPlay {
        didSet {
            KSOptions.isAutoPlay = isAutoPlay
        }
    }

    @AppStorage("isSecondOpen")
    public var isSecondOpen = KSOptions.isSecondOpen {
        didSet {
            KSOptions.isSecondOpen = isSecondOpen
        }
    }

    @AppStorage("isAccurateSeek")
    public var isAccurateSeek = KSOptions.isAccurateSeek {
        didSet {
            KSOptions.isAccurateSeek = isAccurateSeek
        }
    }

    @AppStorage("canStartPictureInPictureAutomaticallyFromInline")
    public var canStartPictureInPictureAutomaticallyFromInline = KSOptions.canStartPictureInPictureAutomaticallyFromInline {
        didSet {
            KSOptions.canStartPictureInPictureAutomaticallyFromInline = canStartPictureInPictureAutomaticallyFromInline
        }
    }

    @AppStorage("stripSutitleStyle")
    public var stripSubtitleStyle = KSOptions.stripSubtitleStyle {
        didSet {
            KSOptions.stripSubtitleStyle = stripSubtitleStyle
        }
    }

    @AppStorage("subtitleFontSize")
    public var subtitleFontSize = KSOptions.subtitleFontSize {
        didSet {
            KSOptions.subtitleFontSize = subtitleFontSize
        }
    }

    @AppStorage("textBold")
    public var textBold = KSOptions.textBold {
        didSet {
            KSOptions.textBold = textBold
        }
    }

    @AppStorage("textItalic")
    public var textItalic = KSOptions.textItalic {
        didSet {
            KSOptions.textItalic = textItalic
        }
    }

    @AppStorage("textColor")
    public var textColor = Color(KSOptions.textColor) {
        didSet {
            KSOptions.textColor = UIColor(textColor)
        }
    }

    @AppStorage("textShadowColor")
    public var textShadowColor = Color(KSOptions.textShadowColor) {
        didSet {
            KSOptions.textShadowColor = UIColor(textShadowColor)
        }
    }

    @AppStorage("textBackgroundColor")
    public var textBackgroundColor = Color(KSOptions.textBackgroundColor) {
        didSet {
            KSOptions.textBackgroundColor = UIColor(textBackgroundColor)
        }
    }

    @AppStorage("horizontalAlign")
    public var horizontalAlign = KSOptions.textPosition.horizontalAlign {
        didSet {
            KSOptions.textPosition.horizontalAlign = horizontalAlign
        }
    }

    @AppStorage("verticalAlign")
    public var verticalAlign = KSOptions.textPosition.verticalAlign {
        didSet {
            KSOptions.textPosition.verticalAlign = verticalAlign
        }
    }

    @AppStorage("leftMargin")
    public var leftMargin = KSOptions.textPosition.leftMargin {
        didSet {
            KSOptions.textPosition.leftMargin = leftMargin
        }
    }

    @AppStorage("rightMargin")
    public var rightMargin = KSOptions.textPosition.rightMargin {
        didSet {
            KSOptions.textPosition.rightMargin = rightMargin
        }
    }

    @AppStorage("verticalMargin")
    public var verticalMargin = KSOptions.textPosition.verticalMargin {
        didSet {
            KSOptions.textPosition.verticalMargin = verticalMargin
        }
    }

    @AppStorage("yadifMode")
    public var yadifMode = KSOptions.yadifMode {
        didSet {
            KSOptions.yadifMode = yadifMode
        }
    }

    @AppStorage("deInterlaceAddIdet")
    public var deInterlaceAddIdet = KSOptions.deInterlaceAddIdet {
        didSet {
            KSOptions.deInterlaceAddIdet = deInterlaceAddIdet
        }
    }

    @AppStorage("firstPlayerType")
    public var firstPlayerType = NSStringFromClass(KSOptions.firstPlayerType) {
        didSet {
            KSOptions.firstPlayerType = NSClassFromString(firstPlayerType) as! any MediaPlayerProtocol.Type
            KSOptions.secondPlayerType = KSMEPlayer.self
        }
    }

    public var videoSoftDecodeThreadCount = KSOptions.videoSoftDecodeThreadCount {
        didSet {
            KSOptions.videoSoftDecodeThreadCount = videoSoftDecodeThreadCount
        }
    }

    @AppStorage("isSRTUseImageRender")
    public var isSRTUseImageRender = KSOptions.isSRTUseImageRender {
        didSet {
            KSOptions.isSRTUseImageRender = isSRTUseImageRender
        }
    }

    @AppStorage("audioPlayerType")
    public var audioPlayerType = NSStringFromClass(KSOptions.audioPlayerType) {
        didSet {
            KSOptions.audioPlayerType = NSClassFromString(audioPlayerType) as! any AudioOutput.Type
        }
    }

    @AppStorage("audioVideoClockSync")
    public var audioVideoClockSync = KSOptions.audioVideoClockSync {
        didSet {
            KSOptions.audioVideoClockSync = audioVideoClockSync
        }
    }

    @AppStorage("pictureInPictureType")
    public var pictureInPictureType = NSStringFromClass(KSOptions.pictureInPictureType) {
        didSet {
            KSOptions.pictureInPictureType = NSClassFromString(pictureInPictureType) as! any KSPictureInPictureProtocol.Type
        }
    }

    @AppStorage("showTranslateSourceText")
    public var showTranslateSourceText = KSOptions.showTranslateSourceText {
        didSet {
            KSOptions.showTranslateSourceText = showTranslateSourceText
        }
    }

    @AppStorage("textFontName")
    public var textFontName = KSOptions.textFontName {
        didSet {
            KSOptions.textFontName = textFontName
        }
    }

    @AppStorage("hudLog")
    public var hudLog = KSOptions.hudLog {
        didSet {
            KSOptions.hudLog = hudLog
        }
    }

    /// 不用KSOptions的默认值。
    @AppStorage("preferredFrame")
    public var preferredFrame = false {
        didSet {
            KSOptions.preferredFrame = preferredFrame
        }
    }

    @AppStorage("isASSUseImageRender")
    public var isASSUseImageRender = true {
        didSet {
            KSOptions.isASSUseImageRender = isASSUseImageRender
        }
    }

    @AppStorage("useMACaptionAppearance")
    public var useMACaptionAppearance = true {
        didSet {
            KSOptions.useMACaptionAppearance = useMACaptionAppearance
        }
    }

    @AppStorage("isUseDisplayLayer")
    public var isUseDisplayLayer = true

    @AppStorage("isImmersiveSpace")
    public var isImmersiveSpace = false
    @AppStorage("httpUserAgent")
    public var httpUserAgent: String = ""

    #if os(tvOS)
    /// tvos的审核不让打开任意的url。所以先屏蔽了
    @AppStorage("isShowURLImport")
    public var isShowURLImport = false
    #else
    @AppStorage("isShowURLImport")
    public var isShowURLImport = true
    #endif
    @AppStorage("isSavePlaybackHistory")
    public var isSavePlaybackHistory = true
    @AppStorage("isVideoUpscaling")
    public var isVideoUpscaling = true

    public static let shared = Defaults()
    private init() {
        KSOptions.stripSubtitleStyle = stripSubtitleStyle
        KSOptions.subtitleFontSize = subtitleFontSize
        KSOptions.textBold = textBold
        KSOptions.textItalic = textItalic
        KSOptions.textColor = UIColor(textColor)
        KSOptions.textShadowColor = UIColor(textShadowColor)
        KSOptions.textBackgroundColor = UIColor(textBackgroundColor)
        KSOptions.textPosition.horizontalAlign = horizontalAlign
        KSOptions.textPosition.verticalAlign = verticalAlign
        KSOptions.textPosition.leftMargin = leftMargin
        KSOptions.textPosition.rightMargin = rightMargin
        KSOptions.textPosition.verticalMargin = verticalMargin
        KSOptions.preferredForwardBufferDuration = preferredForwardBufferDuration
        KSOptions.maxBufferDuration = maxBufferDuration
        KSOptions.isLoopPlay = isLoopPlay
        KSOptions.canBackgroundPlay = canBackgroundPlay
        KSOptions.isAutoPlay = isAutoPlay
        KSOptions.isSecondOpen = isSecondOpen
        KSOptions.isAccurateSeek = isAccurateSeek
        if let type = NSClassFromString(pictureInPictureType) as? any KSPictureInPictureProtocol.Type {
            KSOptions.pictureInPictureType = type
        }
        KSOptions.canStartPictureInPictureAutomaticallyFromInline = canStartPictureInPictureAutomaticallyFromInline
        KSOptions.yadifMode = yadifMode
        KSOptions.preferredFrame = preferredFrame
        KSOptions.audioPlayerType = NSClassFromString(audioPlayerType) as! any AudioOutput.Type
        KSOptions.firstPlayerType = NSClassFromString(firstPlayerType) as! any MediaPlayerProtocol.Type
        KSOptions.deInterlaceAddIdet = deInterlaceAddIdet
        KSOptions.isASSUseImageRender = isASSUseImageRender
        KSOptions.videoSoftDecodeThreadCount = videoSoftDecodeThreadCount
        KSOptions.isSRTUseImageRender = isSRTUseImageRender
        KSOptions.audioVideoClockSync = audioVideoClockSync
        KSOptions.showTranslateSourceText = showTranslateSourceText
        KSOptions.textFontName = textFontName
        KSOptions.hudLog = hudLog
        KSOptions.useMACaptionAppearance = useMACaptionAppearance
    }
}

public class UnsafeDefaults: ObservableObject {
    public nonisolated(unsafe) static let shared = UnsafeDefaults()
    @AppStorage("videoDecodeType")
    public var videoDecodeType = VideoDecodeType.hardware
    @AppStorage("isEnablePublicStore")
    public var isEnablePublicStore = false
    public var videoFilters = ""
    public var audioFilters = ""
    @AppStorage("isDoubleRefreshRate")
    public var isDoubleRefreshRate = true
    #if os(tvOS)
    /// tvOS使用硬盘缓存的话，那4k 50fps会出现丢帧的情况。所以默认关掉
    @AppStorage("fileIOContextType")
    public var fileIOContextType = ""
    @AppStorage("preLoadMaxFileSize")
    public var preLoadMaxFileSize = Int(512)
    #else
    @AppStorage("fileIOContextType")
    public var fileIOContextType = ""
    @AppStorage("preLoadMaxFileSize")
    public var preLoadMaxFileSize = Int(1024)
    #endif
    @AppStorage("saveCacheVideo")
    public var saveCacheVideo = false
    @AppStorage("isSelectMaxBitRateTrack")
    public var isSelectMaxBitRateTrack = false
    @AppStorage("isLowDelay")
    public var isLowDelay = false
    @AppStorage("isQuickOpen")
    public var isQuickOpen = false
    @AppStorage("isForceISO")
    public var isForceISO = false
    @AppStorage("isRecordVideo")
    public var isRecordVideo = false
    @AppStorage("playbackTimeInterval")
    public var playbackTimeInterval = 0.1
    @AppStorage("isKeepAlive")
    public var isKeepAlive = false
    @AppStorage("renderUseDispatchSourceTimer")
    public var renderUseDispatchSourceTimer = false
    @AppStorage("isSeekImageSubtitle")
    public var isSeekImageSubtitle = true
    @AppStorage("seekUsePacketCache")
    public var seekUsePacketCache = true
    private init() {}
}

@propertyWrapper
@MainActor
public struct Default<T>: DynamicProperty {
    @ObservedObject private var defaults: Defaults
    private let keyPath: ReferenceWritableKeyPath<Defaults, T>
    public init(_ keyPath: ReferenceWritableKeyPath<Defaults, T>, defaults: Defaults = .shared) {
        self.keyPath = keyPath
        self.defaults = defaults
    }

    public var wrappedValue: T {
        get { defaults[keyPath: keyPath] }
        nonmutating set { defaults[keyPath: keyPath] = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { defaults[keyPath: keyPath] },
            set: { value in
                defaults[keyPath: keyPath] = value
            }
        )
    }
}

@propertyWrapper
@MainActor
public struct UnsafeDefault<T>: DynamicProperty {
    @ObservedObject
    private var defaults: UnsafeDefaults
    private let keyPath: ReferenceWritableKeyPath<UnsafeDefaults, T>
    public init(_ keyPath: ReferenceWritableKeyPath<UnsafeDefaults, T>, defaults: UnsafeDefaults = .shared) {
        self.keyPath = keyPath
        self.defaults = defaults
    }

    public var wrappedValue: T {
        get { defaults[keyPath: keyPath] }
        nonmutating set { defaults[keyPath: keyPath] = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { defaults[keyPath: keyPath] },
            set: { value in
                defaults[keyPath: keyPath] = value
            }
        )
    }
}
