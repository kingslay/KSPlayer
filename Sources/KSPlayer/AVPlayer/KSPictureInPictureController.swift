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
    private var originalViewController: UIViewController?
    private var view: KSPlayerLayer?
    private weak var viewController: UIViewController?
    private weak var presentingViewController: UIViewController?
    #if canImport(UIKit)
    private weak var navigationController: UINavigationController?
    #endif
    @MainActor
    func start(view: KSPlayerLayer) {
        startPictureInPicture()
        delegate = view
        guard KSOptions.isPipPopViewController else {
            #if canImport(UIKit)
            // 直接退到后台
            runOnMainThread {
                UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            }
            #endif
            return
        }
        self.view = view
        #if canImport(UIKit)
        guard let viewController = view.player.view?.viewController else { return }
        originalViewController = viewController
        if let navigationController = viewController.navigationController, navigationController.viewControllers.count == 1 {
            self.viewController = navigationController
        } else {
            self.viewController = viewController
        }
        navigationController = self.viewController?.navigationController
        if let pre = KSPictureInPictureController.pipController {
            view.player.isMuted = true
            pre.view?.isPipActive = false
        } else {
            if let navigationController {
                navigationController.popViewController(animated: true)
                #if os(iOS)
                if navigationController.tabBarController != nil, navigationController.viewControllers.count == 1 {
                    DispatchQueue.main.async { [weak self] in
                        self?.navigationController?.setToolbarHidden(false, animated: true)
                    }
                }
                #endif
            } else {
                presentingViewController = originalViewController?.presentingViewController
                originalViewController?.dismiss(animated: true)
            }
        }
        navigationController?.topViewController?.addChild(viewController)
        #endif
        KSPictureInPictureController.pipController = self
    }

    @MainActor
    func stop(restoreUserInterface: Bool) {
        stopPictureInPicture()
        delegate = nil
        guard KSOptions.isPipPopViewController else {
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
            view?.player.isMuted = false
            view?.play()
        }

        originalViewController = nil
        view = nil
    }

    static func mute() {
        pipController?.view?.player.isMuted = true
    }
}
