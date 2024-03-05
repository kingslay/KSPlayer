//
//  Defaults.swift
//  TracyPlayer
//
//  Created by kintan on 2023/7/21.
//

import Foundation
import KSPlayer
import SwiftUI

public class Defaults: ObservableObject {
    @AppStorage("showRecentPlayList") public var showRecentPlayList = false

    @AppStorage("hardwareDecode")
    public var hardwareDecode = KSOptions.hardwareDecode {
        didSet {
            KSOptions.hardwareDecode = hardwareDecode
        }
    }

    @AppStorage("asynchronousDecompression")
    public var asynchronousDecompression = KSOptions.asynchronousDecompression {
        didSet {
            KSOptions.asynchronousDecompression = asynchronousDecompression
        }
    }

    @AppStorage("isUseDisplayLayer")
    public var isUseDisplayLayer = MEOptions.isUseDisplayLayer {
        didSet {
            MEOptions.isUseDisplayLayer = isUseDisplayLayer
        }
    }

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
    public var canBackgroundPlay = true {
        didSet {
            KSOptions.canBackgroundPlay = canBackgroundPlay
        }
    }

    @AppStorage("isAutoPlay")
    public var isAutoPlay = true {
        didSet {
            KSOptions.isAutoPlay = isAutoPlay
        }
    }

    @AppStorage("isSecondOpen")
    public var isSecondOpen = true {
        didSet {
            KSOptions.isSecondOpen = isSecondOpen
        }
    }

    @AppStorage("isAccurateSeek")
    public var isAccurateSeek = true {
        didSet {
            KSOptions.isAccurateSeek = isAccurateSeek
        }
    }

    @AppStorage("isPipPopViewController")
    public var isPipPopViewController = true {
        didSet {
            KSOptions.isPipPopViewController = isPipPopViewController
        }
    }

    @AppStorage("textFontSize")
    public var textFontSize = SubtitleModel.textFontSize {
        didSet {
            SubtitleModel.textFontSize = textFontSize
        }
    }

    @AppStorage("textBold")
    public var textBold = SubtitleModel.textBold {
        didSet {
            SubtitleModel.textBold = textBold
        }
    }

    @AppStorage("textItalic")
    public var textItalic = SubtitleModel.textItalic {
        didSet {
            SubtitleModel.textItalic = textItalic
        }
    }

    @AppStorage("textColor")
    public var textColor = SubtitleModel.textColor {
        didSet {
            SubtitleModel.textColor = textColor
        }
    }

    @AppStorage("textBackgroundColor")
    public var textBackgroundColor = SubtitleModel.textBackgroundColor {
        didSet {
            SubtitleModel.textBackgroundColor = textBackgroundColor
        }
    }

    @AppStorage("horizontalAlign")
    public var horizontalAlign = SubtitleModel.textPosition.horizontalAlign {
        didSet {
            SubtitleModel.textPosition.horizontalAlign = horizontalAlign
        }
    }

    @AppStorage("verticalAlign")
    public var verticalAlign = SubtitleModel.textPosition.verticalAlign {
        didSet {
            SubtitleModel.textPosition.verticalAlign = verticalAlign
        }
    }

    @AppStorage("leftMargin")
    public var leftMargin = SubtitleModel.textPosition.leftMargin {
        didSet {
            SubtitleModel.textPosition.leftMargin = leftMargin
        }
    }

    @AppStorage("rightMargin")
    public var rightMargin = SubtitleModel.textPosition.rightMargin {
        didSet {
            SubtitleModel.textPosition.rightMargin = rightMargin
        }
    }

    @AppStorage("verticalMargin")
    public var verticalMargin = SubtitleModel.textPosition.verticalMargin {
        didSet {
            SubtitleModel.textPosition.verticalMargin = verticalMargin
        }
    }

    @AppStorage("yadifMode")
    public var yadifMode = MEOptions.yadifMode {
        didSet {
            MEOptions.yadifMode = yadifMode
        }
    }

    @AppStorage("audioPlayerType")
    public var audioPlayerType = NSStringFromClass(KSOptions.audioPlayerType) {
        didSet {
            KSOptions.audioPlayerType = NSClassFromString(audioPlayerType) as! any AudioOutput.Type
        }
    }

    public static let shared = Defaults()
    private init() {
        KSOptions.hardwareDecode = hardwareDecode
        MEOptions.isUseDisplayLayer = isUseDisplayLayer
        SubtitleModel.textFontSize = textFontSize
        SubtitleModel.textBold = textBold
        SubtitleModel.textItalic = textItalic
        SubtitleModel.textColor = textColor
        SubtitleModel.textBackgroundColor = textBackgroundColor
        SubtitleModel.textPosition.horizontalAlign = horizontalAlign
        SubtitleModel.textPosition.verticalAlign = verticalAlign
        SubtitleModel.textPosition.leftMargin = leftMargin
        SubtitleModel.textPosition.rightMargin = rightMargin
        SubtitleModel.textPosition.verticalMargin = verticalMargin
        KSOptions.preferredForwardBufferDuration = preferredForwardBufferDuration
        KSOptions.maxBufferDuration = maxBufferDuration
        KSOptions.isLoopPlay = isLoopPlay
        KSOptions.canBackgroundPlay = canBackgroundPlay
        KSOptions.isAutoPlay = isAutoPlay
        KSOptions.isSecondOpen = isSecondOpen
        KSOptions.isAccurateSeek = isAccurateSeek
        KSOptions.isPipPopViewController = isPipPopViewController
        MEOptions.yadifMode = yadifMode
        KSOptions.audioPlayerType = NSClassFromString(audioPlayerType) as! any AudioOutput.Type
    }
}

@propertyWrapper
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
