import SceneKit

public struct FFPanoramaParameter {
    static var fieldOfView: CGFloat = 100
}

public enum MediaFormat {
    case mono
    case stereoOverUnder
}

public enum Eye {
    case left
    case right
}

public protocol ImageRenderView {
    func set(image: UIImage)
}

public protocol TextureRenderView {
    func set(texture: MTLTexture)
}

public protocol SceneLoadable: AnyObject {
    var scene: SCNScene? { get set }
}

public struct CategoryBitMask: OptionSet {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension CategoryBitMask {
    public static let all = CategoryBitMask(rawValue: .max)
    public static let leftEye = CategoryBitMask(rawValue: 1 << 21)
    public static let rightEye = CategoryBitMask(rawValue: 1 << 22)
}

public protocol OrientationIndicatorDataSource: AnyObject {
    var pointOfView: SCNNode? { get }
    var viewportSize: CGSize { get }
}

extension simd_quatf {
    public static let identity = simd_quatf(angle: 1, axis: .zero)
    public init() {
        self.init(angle: 1, axis: .zero)
    }

    public init(x angle: Float) {
        self.init(angle: angle, axis: SIMD3(1, 0, 0))
    }

    public init(y angle: Float) {
        self.init(angle: angle, axis: SIMD3(0, 1, 0))
    }

    public init(z angle: Float) {
        self.init(angle: angle, axis: SIMD3(0, 0, 1))
    }

    public init(_ scnMatrix4: SCNMatrix4) {
        self.init(simd_float4x4(scnMatrix4))
    }

    public mutating func rotate(byX angle: Float) {
        self = self * simd_quatf(x: angle)
    }

    public mutating func rotate(byY angle: Float) {
        self = self * simd_quatf(y: angle)
    }

    public mutating func rotate(byZ angle: Float) {
        self = self * simd_quatf(z: angle)
    }

    public var scnMatrix4: SCNMatrix4 {
        SCNMatrix4(simd_float4x4(self))
    }

    public var scnQuaternion: SCNQuaternion {
        #if os(macOS)
        return SCNQuaternion(x: CGFloat(vector.x), y: CGFloat(vector.y), z: CGFloat(vector.z), w: CGFloat(vector.w))
        #else
        return SCNQuaternion(x: vector.x, y: vector.y, z: vector.z, w: vector.w)
        #endif
    }
}

#if os(iOS)
import CoreMotion
extension simd_quatf {
    public init(_ cmAttitude: CMAttitude) {
        self.init(cmAttitude.quaternion)
    }

    public init(_ cmDeviceMotion: CMDeviceMotion) {
        self.init(cmDeviceMotion.attitude)
        self = normalized
    }

    public init(_ cmQuaternion: CMQuaternion) {
        self.init(ix: Float(cmQuaternion.x),
                  iy: Float(cmQuaternion.y),
                  iz: Float(cmQuaternion.z),
                  r: Float(cmQuaternion.w))
    }
}
#endif
