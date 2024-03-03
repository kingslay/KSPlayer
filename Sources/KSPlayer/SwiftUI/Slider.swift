//
//  Slider.swift
//  KSPlayer
//
//  Created by kintan on 2023/5/4.
//

import SwiftUI

#if os(tvOS)
import Combine

@available(tvOS 15.0, *)
public struct Slider: View {
    private let process: Binding<Float>
    private let onEditingChanged: (Bool) -> Void
    @FocusState
    private var isFocused: Bool
    public init(value: Binding<Double>, in bounds: ClosedRange<Double> = 0 ... 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        process = Binding {
            Float((value.wrappedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
        } set: { newValue in
            value.wrappedValue = (bounds.upperBound - bounds.lowerBound) * Double(newValue) + bounds.lowerBound
        }
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        TVOSSlide(process: process, isFocused: _isFocused, onEditingChanged: onEditingChanged)
            .focused($isFocused)
    }
}

@available(tvOS 15.0, *)
public struct TVOSSlide: UIViewRepresentable {
    public let process: Binding<Float>
    @FocusState
    public var isFocused: Bool
    public let onEditingChanged: (Bool) -> Void
    public typealias UIViewType = TVSlide
    public func makeUIView(context _: Context) -> UIViewType {
        TVSlide(process: process, onEditingChanged: onEditingChanged)
    }

    public func updateUIView(_ view: UIViewType, context _: Context) {
        if isFocused {
            if view.processView.tintColor == .white {
                view.processView.tintColor = .red
            }
        } else {
            view.processView.tintColor = .white
        }
        view.process = process
    }
}

public class TVSlide: UIControl {
    fileprivate let processView = UIProgressView()
    private var beganProgress = Float(0.0)
    private let onEditingChanged: (Bool) -> Void
    fileprivate var process: Binding<Float> {
        willSet {
            if newValue.wrappedValue != processView.progress {
                processView.progress = newValue.wrappedValue
            }
        }
    }

    private var preMoveDirection: UISwipeGestureRecognizer.Direction?
    private var preMoveTime = CACurrentMediaTime()
    private lazy var timer: Timer = .scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        guard let self, let preMoveDirection = self.preMoveDirection, (preMoveDirection == .left && self.process.wrappedValue > 0.01) || (preMoveDirection == .right && self.process.wrappedValue < 0.99) else {
            return
        }
        self.onEditingChanged(true)
        self.process.wrappedValue += Float(preMoveDirection == .right ? 0.01 : -0.01)
    }

    public init(process: Binding<Float>, onEditingChanged: @escaping (Bool) -> Void) {
        self.process = process
        self.onEditingChanged = onEditingChanged
        super.init(frame: .zero)
        processView.translatesAutoresizingMaskIntoConstraints = false
        processView.tintColor = .white
        addSubview(processView)
        NSLayoutConstraint.activate([
            processView.topAnchor.constraint(equalTo: topAnchor),
            processView.leadingAnchor.constraint(equalTo: leadingAnchor),
            processView.trailingAnchor.constraint(equalTo: trailingAnchor),
            processView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureAction(_:)))
        swipeLeft.direction = .left
        addGestureRecognizer(swipeLeft)
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipeGestureAction(_:)))
        swipeRight.direction = .right
        addGestureRecognizer(swipeRight)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let presse = presses.first else {
            return
        }
        switch presse.type {
        case .leftArrow:
            preMoveDirection = .left
            timer.fireDate = Date.distantPast
        case .rightArrow:
            preMoveDirection = .right
            timer.fireDate = Date.distantPast
        case .select:
            timer.fireDate = Date.distantFuture
            onEditingChanged(false)
        default: super.pressesBegan(presses, with: event)
        }
    }

    override open func pressesEnded(_: Set<UIPress>, with _: UIPressesEvent?) {
        timer.fireDate = Date.distantFuture
    }

    @objc fileprivate func swipeGestureAction(_ recognizer: UISwipeGestureRecognizer) {
        switch recognizer.direction {
        case .left:
            onEditingChanged(true)
            if preMoveDirection == .left, CACurrentMediaTime() - preMoveTime < 0.5 {
                timer.fireDate = Date.distantPast
                break
            } else {
                timer.fireDate = Date.distantFuture
                process.wrappedValue -= Float(0.01)
            }
            preMoveDirection = .left
            preMoveTime = CACurrentMediaTime()
        case .right:
            onEditingChanged(true)
            if preMoveDirection == .right, CACurrentMediaTime() - preMoveTime < 0.5 {
                timer.fireDate = Date.distantPast
                break
            } else {
                timer.fireDate = Date.distantFuture
                process.wrappedValue += Float(0.01)
            }
            preMoveDirection = .right
            preMoveTime = CACurrentMediaTime()
        default:
            break
        }
    }
}
#endif
