//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//
#if canImport(UIKit)
import UIKit
extension UIScreen {
    static var size: CGSize {
        main.bounds.size
    }
}

public class KSSlider: UXSlider {
    private var tapGesture: UITapGestureRecognizer!
    private var panGesture: UIPanGestureRecognizer!
    weak var delegate: KSSliderDelegate?
    public var trackHeigt = CGFloat(2)
    public var isPlayable = false
    override public init(frame: CGRect) {
        super.init(frame: frame)
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionTapGesture(sender:)))
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(actionPanGesture(sender:)))
        addGestureRecognizer(tapGesture)
        addGestureRecognizer(panGesture)
        addTarget(self, action: #selector(progressSliderTouchBegan(_:)), for: .touchDown)
        addTarget(self, action: #selector(progressSliderValueChanged(_:)), for: .valueChanged)
        addTarget(self, action: #selector(progressSliderTouchEnded(_:)), for: [.touchUpInside, .touchCancel, .touchUpOutside])
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func trackRect(forBounds bounds: CGRect) -> CGRect {
        var customBounds = super.trackRect(forBounds: bounds)
        customBounds.origin.y -= trackHeigt / 2
        customBounds.size.height = trackHeigt
        return customBounds
    }

    override open func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let rect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        return rect.insetBy(dx: -20, dy: -20)
    }

    // MARK: - handle UI slider actions

    @objc private func progressSliderTouchBegan(_ sender: KSSlider) {
        guard isPlayable else { return }
        tapGesture.isEnabled = false
        panGesture.isEnabled = false
        value = value
        delegate?.slider(value: Double(sender.value), event: .touchDown)
    }

    @objc private func progressSliderValueChanged(_ sender: KSSlider) {
        guard isPlayable else { return }
        delegate?.slider(value: Double(sender.value), event: .valueChanged)
    }

    @objc private func progressSliderTouchEnded(_ sender: KSSlider) {
        guard isPlayable else { return }
        tapGesture.isEnabled = true
        panGesture.isEnabled = true
        delegate?.slider(value: Double(sender.value), event: .touchUpInside)
    }

    @objc private func actionTapGesture(sender: UITapGestureRecognizer) {
        //        guard isPlayable else {
        //            return
        //        }
        let touchPoint = sender.location(in: self)
        let value = (maximumValue - minimumValue) * Float(touchPoint.x / frame.size.width)
        self.value = value
        delegate?.slider(value: Double(value), event: .valueChanged)
        delegate?.slider(value: Double(value), event: .touchUpInside)
    }

    @objc private func actionPanGesture(sender: UIPanGestureRecognizer) {
        //        guard isPlayable else {
        //            return
        //        }
        let touchPoint = sender.location(in: self)
        let value = (maximumValue - minimumValue) * Float(touchPoint.x / frame.size.width)
        self.value = value
        if sender.state == .began {
            delegate?.slider(value: Double(value), event: .touchDown)
        } else if sender.state == .ended {
            delegate?.slider(value: Double(value), event: .touchUpInside)
        } else {
            delegate?.slider(value: Double(value), event: .valueChanged)
        }
    }
}

#if !os(tvOS)
public typealias UXSlider = UISlider
#else
public class UXSlider: UIProgressView {
    @IBInspectable public var value: Float {
        get {
            progress * maximumValue
        }
        set {
            progress = newValue / maximumValue
        }
    }

    @IBInspectable public var maximumValue: Float = 1 {
        didSet {
            refresh()
        }
    }

    @IBInspectable public var minimumValue: Float = 0 {
        didSet {
            refresh()
        }
    }

    open var minimumTrackTintColor: UIColor? {
        get {
            progressTintColor
        }
        set {
            progressTintColor = newValue
        }
    }

    open var maximumTrackTintColor: UIColor? {
        get {
            trackTintColor
        }
        set {
            trackTintColor = newValue
        }
    }

    open func setThumbImage(_: UIImage?, for _: UIControl.State) {}
    open func addTarget(_: Any?, action _: Selector, for _: UIControl.Event) {}

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    // MARK: - private functions

    private func setup() {
        refresh()
    }

    private func refresh() {}
    open func trackRect(forBounds bounds: CGRect) -> CGRect {
        bounds
    }

    open func thumbRect(forBounds bounds: CGRect, trackRect _: CGRect, value _: Float) -> CGRect {
        bounds
    }
}
#endif
public typealias UIViewContentMode = UIView.ContentMode
internal extension UIButton {
    var titleFont: UIFont? {
        get {
            titleLabel?.font
        }
        set {
            titleLabel?.font = newValue
        }
    }

    var title: String? {
        get {
            titleLabel?.text
        }
        set {
            titleLabel?.text = newValue
        }
    }
}

extension UIView {
    func image() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            return image
        }
        return nil
    }

    public func centerRotate(byDegrees: Double) {
        transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi * byDegrees / 180.0))
    }
}
#endif
