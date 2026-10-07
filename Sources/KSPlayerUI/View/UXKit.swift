//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif
import KSPlayer
import SwiftUI

open class LayerContainerView: UIView {
    #if canImport(UIKit)
    override open class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    #else
    override public init(frame: CGRect) {
        super.init(frame: frame)
        layer = CAGradientLayer()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    public var gradientLayer: CAGradientLayer {
        // swiftlint:disable force_cast
        layer as! CAGradientLayer
        // swiftlint:enable force_cast
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

@MainActor
protocol KSSliderDelegate: AnyObject {
    /**
     call when slider action trigged
     - parameter value:      progress
     - parameter event:       action
     */
    func slider(value: Double, event: ControlEvents)
}

class PaddedLabel: UILabel {
    var padding = EdgeInsets() {
        didSet {
            #if os(macOS)
            (cell as? PaddedTextFieldCell)?.padding = padding
            #endif
        }
    }

    #if os(macOS)
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        cell = PaddedTextFieldCell(textCell: "")
    }

    override func draw(_ dirtyRect: NSRect) {
        // 没有strokeWidth的才自动加上strokeWidth。一般是srt字幕没有strokeWidth
        guard attributedStringValue.attributes(at: 0, effectiveRange: nil)[.strokeWidth] == nil, let context = NSGraphicsContext.current?.cgContext else {
            super.draw(dirtyRect)
            return
        }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.drawStroke(for: attributedStringValue, rect: bounds)
        context.restoreGState()
        super.draw(dirtyRect)
    }
    #else
    override func drawText(in rect: CGRect) {
        let rect = rect.inset(by: padding)
        guard let context = UIGraphicsGetCurrentContext() else {
            super.drawText(in: rect)
            return
        }
        let textColor = textColor
        context.setLineWidth(KSOptions.textStrokeWidth * UIApplication.scale)
        context.setLineJoin(.round)
        context.setTextDrawingMode(.stroke)
        self.textColor = KSOptions.textStrokeColor
        super.drawText(in: rect)
        self.textColor = textColor
        context.setTextDrawingMode(.fill)
        let shadowOffset = shadowOffset
        self.shadowOffset = CGSize(width: 0, height: 0)
        super.drawText(in: rect)
        self.shadowOffset = shadowOffset
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.leading + padding.trailing,
                      height: size.height + padding.top + padding.bottom)
    }
    #endif
}
