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
    private weak var view: KSPlayerLayer?
    private weak var viewController: UIViewController?
    #if canImport(UIKit)
    private weak var navigationController: UINavigationController?
    #endif
    func stop() {
        stopPictureInPicture()
        delegate = nil
        KSPictureInPictureController.pipController = nil
        #if canImport(UIKit)
        if let navigationController, let viewController, let originalViewController {
            if let nav = viewController as? UINavigationController,
               nav.viewControllers.count == 0 || (nav.viewControllers.count == 1 && nav.viewControllers[0] != originalViewController)
            {
                nav.viewControllers = [originalViewController]
            }
            var viewControllers = navigationController.viewControllers
            if let last = viewControllers.last, type(of: last) == type(of: viewController) {
                viewControllers[viewControllers.count - 1] = viewController
                navigationController.viewControllers = viewControllers
            }
            if viewControllers.firstIndex(of: viewController) == nil {
                navigationController.pushViewController(viewController, animated: true)
            }
        }
        #endif
        view?.player.isMuted = false
        view?.play()
        originalViewController = nil
    }

    func start(view: KSPlayerLayer) {
        startPictureInPicture()
        delegate = view
        self.view = view
        #if canImport(UIKit)
        if let viewController = view.viewController, let navigationController = viewController.navigationController {
            originalViewController = viewController
            if navigationController.viewControllers.count == 1 {
                self.viewController = navigationController
            } else {
                self.viewController = viewController
            }
            self.navigationController = self.viewController?.navigationController
            if let pre = KSPictureInPictureController.pipController {
                view.player.isMuted = true
                pre.view?.isPipActive = false
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
        #endif
        KSPictureInPictureController.pipController = self
    }

    static func mute() {
        pipController?.view?.player.isMuted = true
    }
}
