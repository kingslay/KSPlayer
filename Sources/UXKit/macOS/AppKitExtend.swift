//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AppKit
import CoreMedia
import IOKit.pwr_mgt

public typealias UIView = NSView
public typealias UIWindow = NSWindow
public typealias UIViewController = NSViewController
public typealias UIColor = NSColor
public typealias UIImage = NSImage
public typealias UIScreen = NSScreen
public typealias UIStackView = NSStackView
public typealias UIPanGestureRecognizer = NSPanGestureRecognizer
public typealias UIGestureRecognizer = NSGestureRecognizer
public typealias UIGestureRecognizerDelegate = NSGestureRecognizerDelegate
public typealias UIViewContentMode = ContentMode
public typealias UIFont = NSFont
public typealias UIControl = NSControl
public typealias UITextField = NSTextField
public typealias UIImageView = NSImageView
public typealias UITapGestureRecognizer = NSClickGestureRecognizer
public typealias UXSlider = NSSlider
public typealias UIApplication = NSApplication
public typealias UITableView = NSTableView
public typealias UITableViewDelegate = NSTableViewDelegate
public typealias UITableViewDataSource = NSTableViewDataSource
public typealias UITouch = NSTouch
public typealias UIEvent = NSEvent

extension NSScreen {
    var scale: CGFloat {
        return backingScaleFactor
    }

    static var size: CGSize {
        return main?.frame.size ?? .zero
    }
}

extension NSClickGestureRecognizer {
    open var numberOfTapsRequired: Int {
        get {
            return numberOfClicksRequired
        }
        set {
            numberOfClicksRequired = newValue
        }
    }
}

extension NSView {
    @objc var contentMode: UIViewContentMode {
        get {
            if let contentsGravity = backingLayer?.contentsGravity {
                switch contentsGravity {
                case .resize:
                    return .scaleToFill
                case .resizeAspect:
                    return .scaleAspectFit
                case .resizeAspectFill:
                    return .scaleAspectFill
                default:
                    return .scaleAspectFit
                }
            } else {
                return .scaleAspectFit
            }
        }
        set {
            switch newValue {
            case .scaleToFill:
                backingLayer?.contentsGravity = .resize
            case .scaleAspectFit:
                backingLayer?.contentsGravity = .resizeAspect
            case .scaleAspectFill:
                backingLayer?.contentsGravity = .resizeAspectFill
            case .center:
                backingLayer?.contentsGravity = .center
            default:
                break
            }
        }
    }

    open var center: CGPoint {
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    public var alpha: CGFloat {
        get {
            return alphaValue
        }
        set {
            alphaValue = newValue
        }
    }

    public var backgroundColor: UIColor? {
        get {
            if let layer = layer, let cgColor = layer.backgroundColor {
                return UIColor(cgColor: cgColor)
            } else {
                return nil
            }
        }
        set {
            backingLayer?.backgroundColor = newValue?.cgColor
        }
    }

    public var clipsToBounds: Bool {
        get {
            if let layer = layer {
                return layer.masksToBounds
            } else {
                return false
            }
        }
        set {
            backingLayer?.masksToBounds = newValue
        }
    }

    open class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setCompletionBlock {
            completion?(true)
        }
        animations()
        CATransaction.commit()
    }

    open class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void) {
        animate(withDuration: duration, animations: animations, completion: nil)
    }

    open func layoutIfNeeded() {
        backingLayer?.layoutIfNeeded()
    }

    open var transform: CGAffineTransform {
        get {
            return backingLayer?.affineTransform() ?? CGAffineTransform.identity
        }
        set {
            backingLayer?.setAffineTransform(newValue)
        }
    }
}

extension NSImage {
    public convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize.zero)
    }
}

extension NSButton {
    open var titleFont: UIFont? {
        get {
            return font
        }
        set {
            font = newValue
        }
    }

    var tintColor: UIColor? {
        get {
            if #available(OSX 10.14, *) {
                return contentTintColor
            } else {
                return nil
            }
        }
        set {
            if #available(OSX 10.14, *) {
                contentTintColor = newValue
            } else {}
        }
    }
}

extension NSControl {
    public var textAlignment: NSTextAlignment {
        get {
            return alignment
        }
        set {
            alignment = newValue
        }
    }

    public var text: String {
        get {
            return stringValue
        }
        set {
            stringValue = newValue
        }
    }

    public var attributedText: NSAttributedString {
        get {
            return attributedStringValue
        }
        set {
            attributedStringValue = newValue
        }
    }

    public var numberOfLines: Int {
        get {
            return usesSingleLineMode ? 1 : 0
        }
        set {
            usesSingleLineMode = newValue == 1
        }
    }
}

extension NSTextContainer {
    public var numberOfLines: Int {
        get {
            return maximumNumberOfLines
        }
        set {
            maximumNumberOfLines = newValue
        }
    }
}

extension NSResponder {
    public var next: NSResponder? {
        return nextResponder
    }
}

extension NSSlider {
    open var minimumTrackTintColor: UIColor? {
        get {
            if #available(OSX 10.12.2, *) {
                return trackFillColor
            } else {
                return nil
            }
        }
        set {
            if #available(OSX 10.12.2, *) {
                trackFillColor = newValue
            }
        }
    }

    open var maximumTrackTintColor: UIColor? {
        get {
            return nil
        }
        set {}
    }

    @IBInspectable public var maximumValue: Float {
        get {
            return Float(maxValue)
        }
        set {
            maxValue = Double(newValue)
        }
    }

    @IBInspectable public var minimumValue: Float {
        get {
            return Float(minValue)
        }
        set {
            minValue = Double(newValue)
        }
    }

    @IBInspectable public var value: Float {
        get {
            return floatValue
        }
        set {
            floatValue = newValue
        }
    }
}

extension NSStackView {
    open var axis: NSUserInterfaceLayoutOrientation {
        get {
            return orientation
        }
        set {
            orientation = newValue
        }
    }
}

extension NSWindow {
    open var rootViewController: NSViewController? {
        get {
            return contentViewController
        }
        set {
            contentViewController = newValue
        }
    }
}

extension NSGestureRecognizer {
    open func addTarget(_ target: AnyObject, action: Selector) {
        self.target = target
        self.action = action
    }
}

extension UIApplication {
    private static var assertionID = IOPMAssertionID()
    public static var isIdleTimerDisabled = false {
        didSet {
            if isIdleTimerDisabled != oldValue {
                if isIdleTimerDisabled {
                    _ = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                    "KSPlayer is playing video" as CFString,
                                                    &assertionID)
                } else {
                    _ = IOPMAssertionRelease(assertionID)
                }
            }
        }
    }

    public var isIdleTimerDisabled: Bool {
        get {
            return UIApplication.isIdleTimerDisabled
        }
        set {
            UIApplication.isIdleTimerDisabled = newValue
        }
    }
}

//    @available(*, unavailable, renamed: "UIView.ContentMode")
@objc public enum ContentMode: Int {
    case scaleToFill

    case scaleAspectFit // contents scaled to fit with fixed aspect. remainder is transparent

    case scaleAspectFill // contents scaled to fill with fixed aspect. some portion of content may be clipped.

    case redraw // redraw on bounds change (calls -setNeedsDisplay)

    case center // contents remain same size. positioned adjusted.

    case top

    case bottom

    case left

    case right

    case topLeft

    case topRight

    case bottomLeft

    case bottomRight
}

public struct State: OptionSet {
    public var rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var normal = State(rawValue: 1 << 0)
    public static var highlighted = State(rawValue: 1 << 1)
    public static var disabled = State(rawValue: 1 << 2)
    public static var selected = State(rawValue: 1 << 3)
    public static var focused = State(rawValue: 1 << 4)
    public static var application = State(rawValue: 1 << 5)
    public static var reserved = State(rawValue: 1 << 6)
}

extension State: Hashable {}
public class UILabel: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        alignment = .left
        isBordered = false
        isEditable = false
        isSelectable = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        textColor = NSColor.white
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class UIButton: NSButton {
    private var images = [State: UIImage]()
    private var titles = [State: String]()
    private var titleColors = [State: UIColor]()
    private var targetActions = [ControlEvents: (AnyObject?, Selector)]()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var isSelected: Bool = false {
        didSet {
            update(state: isSelected ? .selected : .normal)
        }
    }

    public override var isEnabled: Bool {
        didSet {
            update(state: isEnabled ? .normal : .disabled)
        }
    }

    open func setImage(_ image: UIImage?, for state: State) {
        images[state] = image
        if state == .normal, isEnabled, !isSelected {
            self.image = image
        }
    }

    open func setTitle(_ title: String, for state: State) {
        titles[state] = title
        if state == .normal, isEnabled, !isSelected {
            self.title = title
        }
    }

    open func setTitleColor(_ titleColor: UIColor?, for state: State) {
        titleColors[state] = titleColor
        if state == .normal, isEnabled, !isSelected {
//            self.titleColor = titleColor
        }
    }

    private func update(state: State) {
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

    open override func updateTrackingAreas() {
        trackingAreas.forEach {
            removeTrackingArea($0)
        }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let (target, action) = targetActions[.touchUpInside] {
            _ = target?.perform(action, with: self)
        }
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let (target, action) = targetActions[.mouseExited] {
            _ = target?.perform(action, with: self)
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let (target, action) = targetActions[.mouseExited] {
            _ = target?.perform(action, with: self)
        }
    }
}

public class KSSlider: NSSlider {
    weak var delegate: KSSliderDelegate?
    public var trackHeigt = CGFloat(2)
    public var isPlayable = false
    public convenience init() {
        self.init(frame: .zero)
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(progressSliderTouchEnded(_:))
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func progressSliderTouchEnded(_ sender: KSSlider) {
        delegate?.slider(value: Double(sender.value), event: .touchUpInside)
    }

    open func setThumbImage(_: UIImage?, for _: State) {}
}

class UIActivityIndicatorView: UIView {
    private var loadingView = NSView()
    private var progressLabel = UILabel()
    public var progress: Double = 0 {
        didSet {
            print("new progress: \(progress)")
            progressLabel.stringValue = "\(Int(progress * 100))%"
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backingLayer?.backgroundColor = UIColor(white: 0, alpha: 0.2).cgColor
        setupLoadingView()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLoadingView() {
        loadingView.wantsLayer = true
        addSubview(loadingView)
        let imageView = NSImageView()
        imageView.image = image(named: "loading")
        loadingView.addSubview(imageView)
        imageView.imageScaling = .scaleAxesIndependently
        imageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 110),
            heightAnchor.constraint(equalToConstant: 110),
            loadingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingView.widthAnchor.constraint(equalTo: widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: heightAnchor),
            imageView.bottomAnchor.constraint(equalTo: loadingView.bottomAnchor),
            imageView.leftAnchor.constraint(equalTo: loadingView.leftAnchor),
            imageView.heightAnchor.constraint(equalTo: widthAnchor),
            imageView.widthAnchor.constraint(equalTo: heightAnchor),
        ])
        progressLabel.alignment = .center
        progressLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        addSubview(progressLabel)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: loadingView.bottomAnchor, constant: 20),
            progressLabel.widthAnchor.constraint(equalToConstant: 100),
            progressLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
        startAnimating()
    }
}

extension UIActivityIndicatorView: LoadingIndector {
    func startAnimating() {
        loadingView.backingLayer?.position = CGPoint(x: loadingView.layer!.frame.midX, y: loadingView.layer!.frame.midY)
        loadingView.backingLayer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.duration = 1.0
        rotationAnimation.repeatCount = MAXFLOAT
        rotationAnimation.fromValue = 0.0
        rotationAnimation.toValue = Float.pi * -2
        loadingView.backingLayer?.add(rotationAnimation, forKey: "loading")
    }

    func stopAnimating() {
        loadingView.backingLayer?.removeAnimation(forKey: "loading")
    }
}

import CoreVideo
class CADisplayLink: NSObject {
    private var displayLink: CVDisplayLink?
    private var target: AnyObject
    private var selector: Selector
    private var runloop: RunLoop?
    private var mode = RunLoop.Mode.default
    public var frameInterval = 1
    public var timestamp: TimeInterval {
        var timeStamp = CVTimeStamp()
        if CVDisplayLinkGetCurrentTime(displayLink!, &timeStamp) == kCVReturnSuccess, (timeStamp.flags & CVTimeStampFlags.hostTimeValid.rawValue) != 0 {
            return TimeInterval(timeStamp.hostTime / NSEC_PER_SEC)
        }
        return 0
    }

    public var duration: TimeInterval {
        return CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLink!)
    }

    public var targetTimestamp: TimeInterval {
        return duration + timestamp
    }

    public var isPaused: Bool {
        get {
            return !CVDisplayLinkIsRunning(displayLink!)
        }
        set {
            if newValue {
                CVDisplayLinkStop(displayLink!)
            } else {
                CVDisplayLinkStart(displayLink!)
            }
        }
    }

    public init(target: NSObject, selector sel: Selector) {
        self.target = target
        selector = sel
        super.init()
        CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, { (_, _, _, _, _, userData: UnsafeMutableRawPointer?) -> CVReturn in
            let `self` = Unmanaged<CADisplayLink>.fromOpaque(userData!).takeUnretainedValue()
            self.target.performSelector(onMainThread: self.selector, with: self, waitUntilDone: false, modes: [String(self.mode.rawValue)])
            // 用runloop会卡顿
//            self.runloop?.perform(self.selector, target: self.target, argument: self, order: 0, modes: [self.mode])
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink!)
    }

    open func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        self.runloop = runloop
        self.mode = mode
    }

    public func invalidate() {
        isPaused = true
        runloop = nil
    }

    deinit {
        invalidate()
    }
}
