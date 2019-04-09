import SceneKit
#if os(OSX)
import AppKit
#else
import UIKit
#endif

final class PanoramaPanGestureManager {
    let rotationNode: SCNNode

    var allowsVerticalRotation = true
    var minimumVerticalRotationAngle: Float?
    var maximumVerticalRotationAngle: Float?

    var allowsHorizontalRotation = true
    var minimumHorizontalRotationAngle: Float?
    var maximumHorizontalRotationAngle: Float?

    lazy var gestureRecognizer: UIPanGestureRecognizer = {
        let recognizer = AdvancedPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        recognizer.earlyTouchEventHandler = { [weak self] in
            self?.stopAnimations()
            self?.resetReferenceAngles()
        }
        return recognizer
    }()

    private var referenceAngles: SCNVector3?

    init(rotationNode: SCNNode) {
        self.rotationNode = rotationNode
    }

    #if os(OSX)
    private func limit(angle: Float) -> CGFloat {
        var angle = angle
        if let minimum = minimumVerticalRotationAngle {
            angle = max(angle, minimum)
        }
        if let maximum = maximumVerticalRotationAngle {
            angle = min(angle, maximum)
        }
        return CGFloat(angle)
    }

    #else
    private func limit(angle: Float) -> Float {
        var angle = angle
        if let minimum = minimumVerticalRotationAngle {
            angle = max(angle, minimum)
        }
        if let maximum = maximumVerticalRotationAngle {
            angle = min(angle, maximum)
        }
        return angle
    }
    #endif

    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        guard let view = sender.view else { return }

        switch sender.state {
        case .changed:
            guard let referenceAngles = referenceAngles else {
                break
            }

            var angles = SCNVector3Zero
            let viewSize = max(view.bounds.width, view.bounds.height)
            let translation = sender.translation(in: view)

            if allowsVerticalRotation {
                let angle = Float(referenceAngles.x) + Float(translation.y / viewSize) * (.pi / 2)
                angles.x = limit(angle: angle)
            }

            if allowsHorizontalRotation {
                let angle = Float(referenceAngles.y) + Float(translation.x / viewSize) * (.pi / 2)
                angles.y = limit(angle: angle)
            }

            SCNTransaction.lock()
            SCNTransaction.begin()
            SCNTransaction.disableActions = true

            rotationNode.eulerAngles = angles.normalized

            SCNTransaction.commit()
            SCNTransaction.unlock()

        case .ended:
            var angles = rotationNode.eulerAngles
            let velocity = sender.velocity(in: view)
            let viewSize = max(view.bounds.width, view.bounds.height)

            if allowsVerticalRotation {
                var angle = Float(angles.x)
                angle += Float(velocity.y / viewSize) / .pi
                angles.x = limit(angle: angle)
            }

            if allowsHorizontalRotation {
                var angle = Float(angles.y)
                angle += Float(velocity.x / viewSize) / .pi
                angles.y = limit(angle: angle)
            }

            SCNTransaction.lock()
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.165, 0.84, 0.44, 1)

            rotationNode.eulerAngles = angles

            SCNTransaction.commit()
            SCNTransaction.unlock()

        default:
            break
        }
    }

    func stopAnimations() {
        SCNTransaction.lock()
        SCNTransaction.begin()
        SCNTransaction.disableActions = true

        rotationNode.eulerAngles = rotationNode.presentation.eulerAngles.normalized
        rotationNode.removeAllAnimations()

        SCNTransaction.commit()
        SCNTransaction.unlock()
    }

    private func resetReferenceAngles() {
        referenceAngles = rotationNode.presentation.eulerAngles
    }
}

private final class AdvancedPanGestureRecognizer: UIPanGestureRecognizer {
    var earlyTouchEventHandler: (() -> Void)?
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        if state == .possible {
            earlyTouchEventHandler?()
        }
    }
    #endif
}

private extension Float {
    var normalized: Float {
        let angle: Float = self
        if angle > .pi {
            return angle - .pi * 2 * ceil(abs(angle) / .pi * 2)
        } else if angle < -.pi {
            return angle + .pi * 2 * ceil(abs(angle) / .pi * 2)
        } else {
            return angle
        }
    }
}

private extension CGFloat {
    var normalized: CGFloat {
        let angle: CGFloat = self
        if angle > .pi {
            return angle - .pi * 2 * ceil(abs(angle) / .pi * 2)
        } else if angle < -.pi {
            return angle + .pi * 2 * ceil(abs(angle) / .pi * 2)
        } else {
            return angle
        }
    }
}

private extension SCNVector3 {
    var normalized: SCNVector3 {
        let angles: SCNVector3 = self

        return SCNVector3(
            x: angles.x.normalized,
            y: angles.y.normalized,
            z: angles.z.normalized
        )
    }
}
