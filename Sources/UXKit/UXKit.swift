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

public extension NSObjectProtocol {
    func image(named: String, bundleName: String? = "KSResources") -> UIImage? {
        var bundle = Bundle(for: type(of: self))
        if let bundleName = bundleName, let resourceURL = bundle.resourceURL, let newBundle = Bundle(url: resourceURL.appendingPathComponent(bundleName + ".bundle")) {
            bundle = newBundle
        }
        #if os(macOS)
        let image = bundle.image(forResource: named)
        #else
        let image = UIImage(named: named, in: bundle, compatibleWith: nil)
        #endif
        return image
    }
}
