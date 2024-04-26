//
//  KSPictureInPictureController.swift
//  KSPlayer
//
//  Created by kintan on 2023/1/28.
//

import AVKit

@available(tvOS 14.0, *)
public class KSPictureInPictureController: AVPictureInPictureController {
    private static var pipController: KSPictureInPictureController?
    private var layer: KSPlayerLayer?
    private weak var originalViewController: UIViewController?
    private weak var viewController: UIViewController?
    private weak var presentingViewController: UIViewController?
    #if canImport(UIKit)
    private weak var navigationController: UINavigationController?
    #endif
    @MainActor
    func start(layer: KSPlayerLayer) {
        startPictureInPicture()
        self.layer = layer
        guard KSOptions.isPipPopViewController else {
            return
        }
        #if canImport(UIKit)
        guard let viewController = layer.player.view?.viewController else { return }
        originalViewController = viewController
        if let navigationController = viewController.navigationController, navigationController.viewControllers.count == 1 {
            self.viewController = navigationController
        } else {
            self.viewController = viewController
        }
        navigationController = self.viewController?.navigationController
        if let pre = KSPictureInPictureController.pipController {
            layer.player.isMuted = true
            pre.layer?.isPipActive = false
        } else {
            if let navigationController {
                navigationController.popViewController(animated: true)
                navigationController.pushViewController(viewController, animated: true)
//                #if os(iOS)
//                if navigationController.tabBarController != nil, navigationController.viewControllers.count == 1 {
//                    navigationController.setToolbarHidden(false, animated: true)
//                }
//                #endif
            } else {
                presentingViewController = originalViewController?.presentingViewController
                originalViewController?.dismiss(animated: true)
            }
        }
        #endif
        KSPictureInPictureController.pipController = self
    }

    @MainActor
    func stop(restoreUserInterface: Bool) {
        stopPictureInPicture()
        guard KSOptions.isPipPopViewController else {
            layer = nil
            return
        }
        KSPictureInPictureController.pipController = nil
        if restoreUserInterface {
            #if canImport(UIKit)
            guard let viewController, let originalViewController else { return }
            if let nav = viewController as? UINavigationController,
               nav.viewControllers.isEmpty || (nav.viewControllers.count == 1 && nav.viewControllers[0] != originalViewController)
            {
                nav.viewControllers = [originalViewController]
            }
            if let navigationController {
                var viewControllers = navigationController.viewControllers
                if viewControllers.count > 1, let last = viewControllers.last, type(of: last) == type(of: viewController) {
                    viewControllers[viewControllers.count - 1] = viewController
                    navigationController.viewControllers = viewControllers
                }
                if viewControllers.firstIndex(of: viewController) == nil {
                    // 新的swiftUI push之后。view会变成是emptyView。所以页面就空白了。
                    navigationController.pushViewController(viewController, animated: true)
                }
            } else {
                presentingViewController?.present(originalViewController, animated: true)
            }

            #endif
            layer?.player.isMuted = false
            layer?.play()
        }

        originalViewController = nil
        layer = nil
    }

    static func mute() {
        pipController?.layer?.player.isMuted = true
    }
}
