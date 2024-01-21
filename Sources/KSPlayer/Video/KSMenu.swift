//
//  KSMenu.swift
//  KSPlayer
//
//  Created by Alanko5 on 15/12/2022.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension UIMenu {
    func updateActionState(actionTitle: String? = nil) -> UIMenu {
        for action in children {
            guard let action = action as? UIAction else {
                continue
            }
            action.state = action.title == actionTitle ? .on : .off
        }
        return self
    }

    @available(tvOS 15.0, *)
    convenience init?<U>(title: String, current: U?, list: [U], addDisabled: Bool = false, titleFunc: (U) -> String, completition: @escaping (String, U?) -> Void) {
        if list.count < (addDisabled ? 1 : 2) {
            return nil
        }
        var actions = list.map { value in
            let item = UIAction(title: titleFunc(value)) { item in
                completition(item.title, value)
            }

            if let current, titleFunc(value) == titleFunc(current) {
                item.state = .on
            }
            return item
        }
        if addDisabled {
            actions.insert(UIAction(title: "Disabled") { item in
                completition(item.title, nil)
            }, at: 0)
        }

        self.init(title: title, children: actions)
    }
}

#if !os(tvOS)
extension UIButton {
    @available(iOS 14.0, *)
    func setMenu<U>(title: String, current: U?, list: [U], addDisabled: Bool = false, titleFunc: (U) -> String, completition handler: @escaping (U?) -> Void) {
        menu = UIMenu(title: title, current: current, list: list, addDisabled: addDisabled, titleFunc: titleFunc) { [weak self] title, value in
            guard let self else { return }
            handler(value)
            self.menu = self.menu?.updateActionState(actionTitle: title)
        }
    }
}
#endif

#if canImport(UIKit)

#else
public typealias UIMenu = NSMenu

public final class UIAction: NSMenuItem {
    private let handler: (UIAction) -> Void
    init(title: String, handler: @escaping (UIAction) -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(menuPressed), keyEquivalent: "")
        state = .off
        target = self
    }

    @objc private func menuPressed() {
        handler(self)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIMenu {
    var children: [NSMenuItem] {
        items
    }

    convenience init(title: String, children: [UIAction]) {
        self.init(title: title)
        for item in children {
            addItem(item)
        }
    }
}
#endif
