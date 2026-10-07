//
//  Extensions.swift
//  KSPlayer
//
//  Created by kintan on 23.06.26.
//

import KSPlayer
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public extension UIColor {
    func createImage(size: CGSize = .one) -> UIImage {
        #if canImport(UIKit)
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
        #else
        let image = UIImage(size: size)
        image.lockFocus()
        drawSwatch(in: CGRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
        #endif
    }
}

extension UIImageView {
    func image(url: URL?) {
        guard let url else { return }
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let data = try? Data(contentsOf: url)
            let image = data.flatMap { UIImage(data: $0) }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.image = image
            }
        }
    }
}

extension UIView {
    var cornerRadius: CGFloat {
        get {
            backingLayer?.cornerRadius ?? 0
        }
        set {
            backingLayer?.cornerRadius = newValue
        }
    }

    public var viewController: UIViewController? {
        var next = next
        while next != nil {
            if let viewController = next as? UIViewController {
                return viewController
            }
            next = next?.next
        }
        return nil
    }
}
