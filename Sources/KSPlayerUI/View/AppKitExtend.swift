//
//  AppKitExtend.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

// 'NSWindow' is unavailable in Mac Catalyst

#if !canImport(UIKit)
import AppKit
import CoreMedia
import CoreVideo
import KSPlayer
import RealityKit
import SwiftUI

public typealias UIApplicationDelegate = NSApplicationDelegate
public typealias UIStackView = NSStackView
public typealias UIPanGestureRecognizer = NSPanGestureRecognizer
public typealias UIGestureRecognizer = NSGestureRecognizer
public typealias UIGestureRecognizerDelegate = NSGestureRecognizerDelegate
public typealias UIControl = NSControl
public typealias UITextField = NSTextField
public typealias UIImageView = NSImageView
public typealias UITapGestureRecognizer = NSClickGestureRecognizer
public typealias UXSlider = NSSlider
public typealias UITableView = NSTableView
public typealias UITableViewDelegate = NSTableViewDelegate
public typealias UITableViewDataSource = NSTableViewDataSource
public typealias UIEvent = NSEvent
public typealias UIButton = KSButton
public typealias UIEdgeInsets = NSEdgeInsets
public typealias UIPasteboard = NSPasteboard
public typealias UIScreen = NSScreen

public class UILabel: NSTextField {
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        alignment = .left
        isBezeled = false
        isBordered = false
        isEditable = false
        isSelectable = true
        drawsBackground = false
        focusRingType = .none
        textColor = NSColor.white
        lineBreakMode = .byWordWrapping
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var textAlignment: NSTextAlignment {
        get {
            alignment
        }
        set {
            alignment = newValue
        }
    }

    var text: String {
        get {
            stringValue
        }
        set {
            stringValue = newValue
        }
    }

    var attributedText: NSAttributedString? {
        get {
            attributedStringValue
        }
        set {
            attributedStringValue = newValue ?? NSAttributedString()
        }
    }

    var numberOfLines: Int {
        get {
            maximumNumberOfLines
        }
        set {
            maximumNumberOfLines = newValue
        }
    }
}

public class KSButton: NSButton {
    private var images = [UIControl.State: UIImage]()
    private var titles = [UIControl.State: String]()
    private var titleColors = [State: UIColor]()
    private var targetActions = [ControlEvents: (AnyObject?, Selector)]()

    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        isBordered = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var isSelected: Bool = false {
        didSet {
            update(state: isSelected ? .selected : .normal)
        }
    }

    override public var isEnabled: Bool {
        didSet {
            update(state: isEnabled ? .normal : .disabled)
        }
    }

    open func setImage(_ image: UIImage?, for state: UIControl.State) {
        images[state] = image
        if state == .normal, isEnabled, !isSelected {
            self.image = image
        }
    }

    open func setTitle(_ title: String, for state: UIControl.State) {
        titles[state] = title
        if state == .normal, isEnabled, !isSelected {
            self.title = title
        }
    }

    open func setTitleColor(_ titleColor: UIColor?, for state: UIControl.State) {
        titleColors[state] = titleColor
        if state == .normal, isEnabled, !isSelected {
            //            self.titleColor = titleColor
        }
    }

    private func update(state: UIControl.State) {
        if let stateImage = images[state] {
            image = stateImage
        }
        if let stateTitle = titles[state] {
            title = stateTitle
        }
    }

    open func addTarget(_ target: AnyObject?, action: Selector, for controlEvents: ControlEvents) {
        targetActions[controlEvents] = (target, action)
    }

    open func removeTarget(_: AnyObject?, action _: Selector?, for controlEvents: ControlEvents) {
        targetActions.removeValue(forKey: controlEvents)
    }

    override open func updateTrackingAreas() {
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override public func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let (target, action) = targetActions[.touchUpInside] ?? targetActions[.primaryActionTriggered] {
            _ = target?.perform(action, with: self)
        }
    }

    override public func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let (target, action) = targetActions[.mouseExited] {
            _ = target?.perform(action, with: self)
        }
    }

    override public func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let (target, action) = targetActions[.mouseExited] {
            _ = target?.perform(action, with: self)
        }
    }

    open func sendActions(for controlEvents: ControlEvents) {
        if let (target, action) = targetActions[controlEvents] {
            _ = target?.perform(action, with: self)
        }
    }
}

public class KSSlider: NSSlider {
    weak var delegate: KSSliderDelegate?
    public var trackHeigt = CGFloat(2)
    public var isPlayable = false
    public var isUserInteractionEnabled: Bool = true
    var tintColor: UIColor?
    public convenience init() {
        self.init(frame: .zero)
    }

    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(progressSliderTouchEnded(_:))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func progressSliderTouchEnded(_ sender: KSSlider) {
        if isUserInteractionEnabled {
            delegate?.slider(value: Double(sender.floatValue), event: .touchUpInside)
        }
    }

    open func setThumbImage(_: UIImage?, for _: State) {}

    @IBInspectable var maximumValue: Float {
        get {
            Float(maxValue)
        }
        set {
            maxValue = Double(newValue)
        }
    }

    @IBInspectable var minimumValue: Float {
        get {
            Float(minValue)
        }
        set {
            minValue = Double(newValue)
        }
    }

    @IBInspectable var value: Float {
        get {
            floatValue
        }
        set {
            floatValue = newValue
        }
    }
}

open class UIAlertController: UIViewController {
    public enum Style: Int {
        case actionSheet
        case alert
    }

    public convenience init(title _: String?, message _: String?, preferredStyle _: UIAlertController.Style) {
        self.init()
    }

    var preferredAction: UIAlertAction?

    open func addAction(_: UIAlertAction) {}
}

open class UIAlertAction: NSObject {
    public enum Style: Int {
        case `default`
        case cancel
        case destructive
    }

    public let title: String?
    public let style: UIAlertAction.Style
    public private(set) var isEnabled: Bool = false
    public init(title: String?, style: UIAlertAction.Style, handler _: ((UIAlertAction) -> Void)? = nil) {
        self.title = title
        self.style = style
    }
}

class PaddedTextFieldCell: NSTextFieldCell {
    /// 内边距设置（可修改）
    var padding = EdgeInsets()

    /// 调整文本绘制区域
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let insetRect = rect.inset(by: padding)
        return super.drawingRect(forBounds: insetRect)
    }

    /// 调整编辑区域
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.inset(by: padding)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    /// 调整选中区域
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.inset(by: padding)
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    /// 修正内容尺寸计算（重要！）
    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.width += padding.leading + padding.trailing
        size.height += padding.top + padding.bottom
        return size
    }
}

public extension UIFont {
    var lineHeight: CGFloat {
        ascender - descender + leading
    }
}

public extension NSClickGestureRecognizer {
    var numberOfTapsRequired: Int {
        get {
            numberOfClicksRequired
        }
        set {
            numberOfClicksRequired = newValue
        }
    }

    func require(toFail otherGestureRecognizer: NSClickGestureRecognizer) {
        buttonMask = otherGestureRecognizer.buttonMask << 1
    }
}

public extension NSView {
    var alpha: CGFloat {
        get {
            alphaValue
        }
        set {
            alphaValue = newValue
        }
    }

    var clipsToBounds: Bool {
        get {
            if let layer {
                return layer.masksToBounds
            } else {
                return false
            }
        }
        set {
            backingLayer?.masksToBounds = newValue
        }
    }

    class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setCompletionBlock {
            completion?(true)
        }
        animations()
        CATransaction.commit()
    }

    class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void) {
        animate(withDuration: duration, animations: animations, completion: nil)
    }

    func layoutIfNeeded() {
        layer?.layoutIfNeeded()
    }
}

public extension NSImage {
    @available(macOS 11.0, *)
    convenience init?(systemName: String) {
        self.init(systemSymbolName: systemName, accessibilityDescription: nil)
    }
}

extension NSButton {
    var titleFont: UIFont? {
        get {
            font
        }
        set {
            font = newValue
        }
    }

    var tintColor: UIColor? {
        get {
            contentTintColor
        }
        set {
            contentTintColor = newValue
        }
    }
}

public extension NSControl {}

public extension NSTextContainer {
    var numberOfLines: Int {
        get {
            maximumNumberOfLines
        }
        set {
            maximumNumberOfLines = newValue
        }
    }
}

public extension NSSlider {
    var minimumTrackTintColor: UIColor? {
        get {
            trackFillColor
        }
        set {
            trackFillColor = newValue
        }
    }

    var maximumTrackTintColor: UIColor? {
        get {
            nil
        }
        set {}
    }
}

public extension NSStackView {
    var axis: NSUserInterfaceLayoutOrientation {
        get {
            orientation
        }
        set {
            orientation = newValue
        }
    }
}

public extension NSGestureRecognizer {
    func addTarget(_ target: AnyObject, action: Selector) {
        self.target = target
        self.action = action
    }
}

public extension UIControl {
    @MainActor
    struct State: @preconcurrency OptionSet {
        public var rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let normal = State(rawValue: 1 << 0)
        public static let highlighted = State(rawValue: 1 << 1)
        public static let disabled = State(rawValue: 1 << 2)
        public static let selected = State(rawValue: 1 << 3)
        public static let focused = State(rawValue: 1 << 4)
        public static let application = State(rawValue: 1 << 5)
        public static let reserved = State(rawValue: 1 << 6)
    }
}

extension UIControl.State: Hashable {}

extension UIView {
    func image() -> UIImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }
}

public extension UIViewController {
    func present(_: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {}
}

public extension NSFont {
    static var familyNames: [String] {
        NSFontManager.shared.availableFontFamilies
    }
}

public extension UIApplication {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

#endif
