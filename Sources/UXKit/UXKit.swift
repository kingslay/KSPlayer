//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension UIView {
    var backingLayer: CALayer? {
        #if os(macOS)
        wantsLayer = true
        #endif
        return layer
    }

    var cornerRadius: CGFloat {
        get {
            return backingLayer?.cornerRadius ?? 0
        }
        set {
            backingLayer?.cornerRadius = newValue
        }
    }
}

public protocol LoadingIndector {
    func startAnimating()
    func stopAnimating()
}

@objc public enum ControlEvents: Int {
    case touchDown
    case touchUpInside
    case valueChanged
    case touchCancel
    case mouseEntered
    case mouseExited
}

protocol KSSliderDelegate: class {
    /**
     call when slider action trigged
     - parameter value:      progress
     - parameter event:       action
     */
    func slider(value: Double, event: ControlEvents)
}
