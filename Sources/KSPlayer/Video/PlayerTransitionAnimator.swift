//
//  PlayerTransitionAnimator.swift
//  KSPlayer
//
//  Created by kintan on 2021/8/20.
//

#if canImport(UIKit)
import UIKit
class PlayerTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isDismiss: Bool
    private let containerView: UIView
    private let animationView: UIView
    private let fromCenter: CGPoint
    init(containerView: UIView, animationView: UIView, isDismiss: Bool = false) {
        self.containerView = containerView
        self.animationView = animationView
        self.isDismiss = isDismiss
        fromCenter = containerView.superview?.convert(containerView.center, to: nil) ?? .zero
        super.init()
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animationSuperView = animationView.superview
        let initSize = animationView.frame.size
        guard let presentedView = transitionContext.view(forKey: isDismiss ? .from : .to) else {
            return
        }
        if isDismiss {
            containerView.layoutIfNeeded()
            presentedView.bounds = containerView.bounds
            presentedView.removeFromSuperview()
        } else {
            if let viewController = transitionContext.viewController(forKey: .to) {
                presentedView.frame = transitionContext.finalFrame(for: viewController)
            }
        }
        presentedView.layoutIfNeeded()
        transitionContext.containerView.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = true
        guard let transform = transitionContext.viewController(forKey: .from)?.view.transform else {
            return
        }
        animationView.transform = CGAffineTransform(scaleX: initSize.width / animationView.frame.size.width, y: initSize.height / animationView.frame.size.height).concatenating(transform)
        let toCenter = transitionContext.containerView.center
        let fromCenter = transform == .identity ? fromCenter : fromCenter.reverse
        animationView.center = isDismiss ? toCenter : fromCenter
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: .curveEaseInOut) {
            self.animationView.transform = .identity
            self.animationView.center = self.isDismiss ? fromCenter : toCenter
        } completion: { _ in
            animationSuperView?.addSubview(self.animationView)
            if !self.isDismiss {
                transitionContext.containerView.addSubview(presentedView)
            }
            transitionContext.completeTransition(true)
        }
    }
}
#endif
