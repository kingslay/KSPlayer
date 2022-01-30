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

extension UIView {
    var backingLayer: CALayer? {
        #if !canImport(UIKit)
        wantsLayer = true
        #endif
        return layer
    }

    var cornerRadius: CGFloat {
        get {
            backingLayer?.cornerRadius ?? 0
        }
        set {
            backingLayer?.cornerRadius = newValue
        }
    }
}

@objc public enum ControlEvents: Int {
    case touchDown
    case touchUpInside
    case touchCancel
    case valueChanged
    case primaryActionTriggered
    case mouseEntered
    case mouseExited
}

protocol KSSliderDelegate: AnyObject {
    /**
     call when slider action trigged
     - parameter value:      progress
     - parameter event:       action
     */
    func slider(value: Double, event: ControlEvents)
}
