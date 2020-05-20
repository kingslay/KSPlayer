import SceneKit

public final class MediaSphereNode: SCNNode {
    public var mediaContents: Any? {
        get {
            geometry?.firstMaterial?.diffuse.contents
        }
        set(value) {
            geometry?.firstMaterial?.diffuse.contents = value
        }
    }

    public init(radius: CGFloat = 10, segmentCount: Int = 300) {
        super.init()

        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = segmentCount
        sphere.firstMaterial?.isDoubleSided = true
        geometry = sphere

        scale = SCNVector3(x: 1, y: 1, z: -1)
        renderingOrder = .max
    }

    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class MonoSphericalMediaScene: SCNScene {
    public lazy var mediaSphereNode: MediaSphereNode = {
        let node = MediaSphereNode()
        self.rootNode.addChildNode(node)
        return node
    }()
}

public class StereoSphericalMediaScene: SCNScene {
    public lazy var leftMediaSphereNode: MediaSphereNode = {
        let node = MediaSphereNode()
        node.categoryBitMask = CategoryBitMask.leftEye.rawValue
        self.rootNode.addChildNode(node)
        return node
    }()

    public lazy var rightMediaSphereNode: MediaSphereNode = {
        let node = MediaSphereNode()
        node.categoryBitMask = CategoryBitMask.rightEye.rawValue
        self.rootNode.addChildNode(node)
        return node
    }()
}

class MonoSphericalVideoScene: MonoSphericalMediaScene, TextureRenderView, ImageRenderView {
    func set(texture: MTLTexture) {
        mediaSphereNode.mediaContents = texture
    }

    func set(image: UIImage) {
        mediaSphereNode.mediaContents = image
    }
}

class StereoSphericalVideoScene: StereoSphericalMediaScene, TextureRenderView {
    private let zeroOrigin = MTLOrigin(x: 0, y: 0, z: 0)
    private let commandQueue: MTLCommandQueue?
    init(commandQueue: MTLCommandQueue?) {
        self.commandQueue = commandQueue
        super.init()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(texture: MTLTexture) {
        if let commandBuffer = commandQueue?.makeCommandBuffer() {
            let halfHeight = texture.height / 2
            let device = texture.device
            let sphereTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: halfHeight, mipmapped: true)
            leftSphereTexture = device.makeTexture(descriptor: sphereTextureDescriptor)
            rightSphereTexture = device.makeTexture(descriptor: sphereTextureDescriptor)
            let size = MTLSize(width: texture.width, height: halfHeight, depth: 0)
            if let leftTexture = leftSphereTexture {
                if let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() {
                    blitCommandEncoder.copy(
                        from: texture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: zeroOrigin,
                        sourceSize: size,
                        to: leftTexture,
                        destinationSlice: 0,
                        destinationLevel: 0,
                        destinationOrigin: zeroOrigin
                    )
                    blitCommandEncoder.endEncoding()
                }
            }
            if let rightTexture = rightSphereTexture {
                if let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() {
                    blitCommandEncoder.copy(
                        from: texture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: halfHeight, z: 0),
                        sourceSize: size,
                        to: rightTexture,
                        destinationSlice: 0,
                        destinationLevel: 0,
                        destinationOrigin: zeroOrigin
                    )
                    blitCommandEncoder.endEncoding()
                }
            }
            commandBuffer.commit()
        }
    }

    private var leftSphereTexture: MTLTexture? {
        didSet {
            leftMediaSphereNode.mediaContents = leftSphereTexture
        }
    }

    private var rightSphereTexture: MTLTexture? {
        didSet {
            rightMediaSphereNode.mediaContents = rightSphereTexture
        }
    }

    func copyPlayerTexture(region _: MTLRegion, to _: MTLTexture, commandBuffer _: MTLCommandBuffer) {}
}

extension StereoSphericalVideoScene: ImageRenderView {
    func set(image: UIImage) {
        #if os(iOS)
        var leftImage: UIImage?
        var rightImage: UIImage?
        let imageSize = CGSize(width: image.size.width, height: image.size.height / 2)
        UIGraphicsBeginImageContextWithOptions(imageSize, true, image.scale)
        image.draw(at: .zero)
        leftImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        UIGraphicsBeginImageContextWithOptions(imageSize, true, image.scale)
        image.draw(at: CGPoint(x: 0, y: -imageSize.height))
        rightImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        leftMediaSphereNode.mediaContents = leftImage?.cgImage
        rightMediaSphereNode.mediaContents = rightImage?.cgImage
        #endif
    }
}
