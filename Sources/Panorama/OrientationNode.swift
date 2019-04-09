import SceneKit

public final class OrientationNode: SCNNode {
    let userRotationNode = SCNNode()
    let referenceRotationNode = SCNNode()
    let deviceOrientationNode = SCNNode()
    let interfaceOrientationNode = SCNNode()

    public let pointOfView = SCNNode()

    public var fieldOfView: CGFloat = FFPanoramaParameter.fieldOfView {
        didSet {
            updateCamera()
        }
    }

    public var deviceOrientationProvider: DeviceOrientationProvider?

    public override init() {
        super.init()
        #if os(iOS)
        deviceOrientationProvider = DefaultDeviceOrientationProvider()
        #endif
        addChildNode(userRotationNode)
        userRotationNode.addChildNode(referenceRotationNode)
        referenceRotationNode.addChildNode(deviceOrientationNode)
        deviceOrientationNode.addChildNode(interfaceOrientationNode)
        interfaceOrientationNode.addChildNode(pointOfView)

        let camera = SCNCamera()
        camera.zNear = 0.3
        pointOfView.camera = camera
        updateCamera()
    }

    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateDeviceOrientation(atTime time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let rotation = deviceOrientationProvider?.deviceOrientation(atTime: time) else { return }

        deviceOrientationNode.orientation = rotation.scnQuaternion
    }

    #if os(iOS)
    public func updateInterfaceOrientation(atTime _: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let interfaceOrientation = UIApplication.shared.statusBarOrientation
        var rotation = Rotation()

        switch interfaceOrientation {
        case .portraitUpsideDown:
            rotation.rotate(byZ: .pi)
        case .landscapeLeft:
            rotation.rotate(byZ: .pi / 2)
        case .landscapeRight:
            rotation.rotate(byZ: .pi / -2)
        default:
            break
        }

        interfaceOrientationNode.orientation = rotation.scnQuaternion

        if #available(iOS 11, OSX 10.13, tvOS 11.0, *) {
            let cameraProjectionDirection: SCNCameraProjectionDirection
            switch interfaceOrientation {
            case .landscapeLeft, .landscapeRight:
                cameraProjectionDirection = .vertical
            default:
                cameraProjectionDirection = .horizontal
            }

            pointOfView.camera?.projectionDirection = cameraProjectionDirection
        }
    }
    #endif

    public func resetRotation() {
        let rotation1 = Rotation(pointOfView.presentation.worldTransform).inverted()
        let rotation2 = Rotation(referenceRotationNode.presentation.worldTransform)
        let rotation3 = rotation1 * rotation2
        referenceRotationNode.transform = rotation3.scnMatrix4
        userRotationNode.transform = SCNMatrix4Identity
    }

    public func resetRotation(animated: Bool, completionHanlder: (() -> Void)? = nil) {
        SCNTransaction.lock()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
        SCNTransaction.completionBlock = completionHanlder
        SCNTransaction.disableActions = !animated

        resetRotation()

        SCNTransaction.commit()
        SCNTransaction.unlock()
    }

    /// Requests reset of rotation in the next rendering frame.
    ///
    /// - Parameter animated: Pass true to animate the transition.
    public func setNeedsResetRotation(animated: Bool) {
        let action = SCNAction.run { node in
            if let node = node as? OrientationNode {
                node.resetRotation(animated: animated)
            }
        }
        runAction(action, forKey: "setNeedsResetRotation")
    }

    private func updateCamera() {
        guard let camera = self.pointOfView.camera else { return }

        if #available(iOS 11, tvOS 11.0, OSX 10.13, *) {
            camera.fieldOfView = fieldOfView
        } else {
            camera.xFov = Double(fieldOfView)
            camera.yFov = Double(fieldOfView)
        }
    }
}
