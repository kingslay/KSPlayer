//
//  GestureView.swift
//
//  Created by WangJun on 2024/10/05.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

public typealias Action = (UISwipeGestureRecognizer.Direction) -> Void

public struct GestureView: UIViewRepresentable {
    private let swipeAction: Action
    private let pressAction: Action
    private let toucheAction: () -> Void
    public init(swipeAction: @escaping Action, pressAction: @escaping Action, toucheAction: @escaping () -> Void) {
        self.swipeAction = swipeAction
        self.pressAction = pressAction
        self.toucheAction = toucheAction
    }

    public func makeUIView(context _: Context) -> UIView {
        TVGestureHelpView(swipeAction: swipeAction, pressAction: pressAction, toucheAction: toucheAction)
    }

    public func updateUIView(_: UIView, context _: Context) {}
}

public class TVGestureHelpView: UIControl {
    private let swipeAction: Action
    private let pressAction: Action
    private let toucheAction: () -> Void

    public init(swipeAction: @escaping Action, pressAction: @escaping Action, toucheAction: @escaping () -> Void) {
        self.swipeAction = swipeAction
        self.pressAction = pressAction
        self.toucheAction = toucheAction
        super.init(frame: .zero)
        let upSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture))
        upSwipeRecognizer.direction = .up

        let downSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture))
        downSwipeRecognizer.direction = .down

        let leftSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture))
        leftSwipeRecognizer.direction = .left

        let rightSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture))
        rightSwipeRecognizer.direction = .right

        addGestureRecognizer(upSwipeRecognizer)
        addGestureRecognizer(downSwipeRecognizer)
        addGestureRecognizer(leftSwipeRecognizer)
        addGestureRecognizer(rightSwipeRecognizer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func handleSwipeGesture(gesture: UIGestureRecognizer) {
        guard let swipeGesture = gesture as? UISwipeGestureRecognizer else { return }
        swipeAction(swipeGesture.direction)
    }

    override public func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            return
        }
        switch press.type {
        case .upArrow:
            pressAction(.up)
        case .downArrow:
            pressAction(.down)
        case .leftArrow:
            pressAction(.left)
        case .rightArrow:
            pressAction(.right)
        default:
            super.pressesEnded(presses, with: event)
        }
    }

    override public func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        toucheAction()
    }
}
#endif
