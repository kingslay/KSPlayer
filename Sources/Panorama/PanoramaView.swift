import CoreMedia
import SceneKit
#if os(OSX)
import AppKit
#else
import UIKit
#endif
public final class PanoramaView: UIView {
    private var textureLoad: MetalTexture
    public let device: MTLDevice?
    public var scene: (SCNScene & TextureRenderView & ImageRenderView)? {
        get {
            return scnView.scene as? (SCNScene & TextureRenderView & ImageRenderView)
        }
        set(value) {
            orientationNode.removeFromParentNode()
            value?.rootNode.addChildNode(orientationNode)
            scnView.scene = value
        }
    }

    public weak var sceneRendererDelegate: SCNSceneRendererDelegate?

    public lazy var orientationNode: OrientationNode = {
        let node = OrientationNode()
        let mask = CategoryBitMask.all.subtracting(.rightEye)
        node.pointOfView.camera?.categoryBitMask = mask.rawValue
        return node
    }()

    lazy var scnView: SCNView = {
        #if (arch(arm) || arch(arm64)) && os(iOS)
        let view = SCNView(frame: self.bounds, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue,
            SCNView.Option.preferredDevice.rawValue: self.device!,
        ])
        #else
        let view = SCNView(frame: self.bounds)
        #endif
        view.backgroundColor = .black
        #if os(iOS)
        view.isUserInteractionEnabled = false
        #endif
        view.delegate = self
        view.pointOfView = self.orientationNode.pointOfView
        view.isPlaying = true
        self.addSubview(view)
        return view
    }()

    private lazy var panGestureManager: PanoramaPanGestureManager = {
        let manager = PanoramaPanGestureManager(rotationNode: self.orientationNode.userRotationNode)
        manager.minimumVerticalRotationAngle = -60 / 180 * .pi
        manager.maximumVerticalRotationAngle = 60 / 180 * .pi
        return manager
    }()

    public convenience init() {
        self.init(format: .mono)
    }

    public convenience init(format: MediaFormat) {
        #if os(OSX)
        let metalDevice = MTLCopyAllDevices().first
        #else
        let metalDevice = MTLCreateSystemDefaultDevice()
        #endif
        self.init(frame: .zero, format: format, device: metalDevice)
    }

    public convenience init(frame: CGRect, format: MediaFormat) {
        #if os(OSX)
        let metalDevice = MTLCopyAllDevices().first
        #else
        let metalDevice = MTLCreateSystemDefaultDevice()
        #endif
        self.init(frame: frame, format: format, device: metalDevice)
    }

    public init(frame: CGRect, format: MediaFormat, device: MTLDevice?) {
        self.device = device
        textureLoad = MetalTexture(device: device)
        super.init(frame: frame)
        switch format {
        case .mono:
            scene = MonoSphericalVideoScene()
        case .stereoOverUnder:
            scene = StereoSphericalVideoScene(commandQueue: textureLoad.commandQueue)
        }
        addGestureRecognizer(panGestureManager.gestureRecognizer)
    }

    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        orientationNode.removeFromParentNode()
    }

    #if os(OSX)
    public override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        scnView.frame = bounds
    }

    #else
    public override func layoutSubviews() {
        super.layoutSubviews()
        scnView.frame = bounds
    }
    #endif
    #if os(iOS)
    private var observer: NSObjectProtocol?
    public override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            guard let observer = observer else {
                return
            }
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        } else {
            guard observer == nil else {
                return
            }
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.orientationNode.updateInterfaceOrientation()
            }
            orientationNode.updateInterfaceOrientation()
        }
    }
    #endif
}

extension PanoramaView: PixelRenderView {
    public func set(pixelBuffer: CVPixelBuffer, time _: CMTime) {
        if let texture = textureLoad.texture(pixelBuffer: pixelBuffer)?.first {
            scene?.set(texture: texture)
        }
    }
}

extension PanoramaView: ImageRenderView {
    public func set(image: UIImage) {
        scene?.set(image: image)
    }
}

extension PanoramaView {
    public var sceneRenderer: SCNSceneRenderer {
        return scnView
    }

    public var isPlaying: Bool {
        get {
            return scnView.isPlaying
        }
        set(value) {
            scnView.isPlaying = value
        }
    }

    public var antialiasingMode: SCNAntialiasingMode {
        get {
            return scnView.antialiasingMode
        }
        set(value) {
            scnView.antialiasingMode = value
        }
    }

    public func snapshot() -> UIImage {
        return scnView.snapshot()
    }

    public var panGestureRecognizer: UIPanGestureRecognizer {
        return panGestureManager.gestureRecognizer
    }

    public func setNeedsResetRotation(animated: Bool = false) {
        panGestureManager.stopAnimations()
        orientationNode.setNeedsResetRotation(animated: animated)
    }

    public func setNeedsResetRotation(_: Any?) {
        setNeedsResetRotation(animated: true)
    }
}

extension PanoramaView: OrientationIndicatorDataSource {
    public var pointOfView: SCNNode? {
        return orientationNode.pointOfView
    }

    public var viewportSize: CGSize {
        return scnView.bounds.size
    }
}

extension PanoramaView: SCNSceneRendererDelegate {
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        var disableActions = false

        if let provider = orientationNode.deviceOrientationProvider, provider.shouldWaitDeviceOrientation(atTime: time) {
            provider.waitDeviceOrientation(atTime: time)
            disableActions = true
        }

        SCNTransaction.lock()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1 / 15
        SCNTransaction.disableActions = disableActions

        orientationNode.updateDeviceOrientation(atTime: time)

        SCNTransaction.commit()
        SCNTransaction.unlock()

        sceneRendererDelegate?.renderer?(renderer, updateAtTime: time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        sceneRendererDelegate?.renderer?(renderer, didApplyAnimationsAtTime: time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        sceneRendererDelegate?.renderer?(renderer, didSimulatePhysicsAtTime: time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        sceneRendererDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        sceneRendererDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}
