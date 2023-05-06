//
//  File.swift
//  KSSubtitle
//
//  Created by kintan on 2018/8/3.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import Combine

public class KSSRTOptions {
    public enum Size {
        case smaller
        case standard
        case large

        var font: UIFont {
            switch self {
            case .smaller:
                #if os(tvOS)
                return .systemFont(ofSize: 30)
                #elseif os(macOS)
                return .systemFont(ofSize: 20)
                #else
                return .systemFont(ofSize: 12)
                #endif
            case .standard:
                #if os(tvOS)
                return .systemFont(ofSize: 36)
                #elseif os(macOS)
                return .systemFont(ofSize: 26)
                #else
                return .systemFont(ofSize: 16)
                #endif
            case .large:
                #if os(tvOS)
                return .systemFont(ofSize: 42)
                #elseif os(macOS)
                return .systemFont(ofSize: 32)
                #else
                return .systemFont(ofSize: 20)
                #endif
            }
        }
    }

    var size: Size
    var bacgroundColor: UIColor
    var textColor: UIColor

    init(size: Size = .standard, bacgroundColor: UIColor = .clear, textColor: UIColor = .white) {
        self.size = size
        self.bacgroundColor = bacgroundColor
        self.textColor = textColor
    }
}

public class KSSubtitleController: SubtitleModel {
    private let cacheDataSouce = CacheDataSouce()
    public var view: KSSubtitleView
    public init(customControlView: KSSubtitleView? = nil) {
        if let customView = customControlView {
            view = customView
        } else {
            view = KSSubtitleView()
        }
        super.init()
        view.isHidden = true
        view.selectWithFilePath = { [weak self] result in
            guard let self else { return }
            self.selectedSubtitleInfo = result
        }
    }
}
