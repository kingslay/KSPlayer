import GLKit
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

public protocol SceneLoadable: class {
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

public protocol OrientationIndicatorDataSource: class {
    var pointOfView: SCNNode? { get }
    var viewportSize: CGSize { get }
}

public struct Rotation {
    public var matrix: GLKMatrix3

    public init(matrix: GLKMatrix3 = GLKMatrix3Identity) {
        self.matrix = matrix
    }
}

extension Rotation {
    public static let identity = Rotation()
}

extension Rotation {
    public init(_ glkMatrix3: GLKMatrix3) {
        self.init(matrix: glkMatrix3)
    }

    public var glkMatrix3: GLKMatrix3 {
        get {
            return matrix
        }
        set(value) {
            matrix = value
        }
    }
}

extension Rotation {
    public init(_ glkQuaternion: GLKQuaternion) {
        self.init(GLKMatrix3MakeWithQuaternion(glkQuaternion))
    }

    public var glkQuartenion: GLKQuaternion {
        get {
            return GLKQuaternionMakeWithMatrix3(glkMatrix3)
        }
        set(value) {
            glkMatrix3 = GLKMatrix3MakeWithQuaternion(value)
        }
    }
}

extension Rotation {
    public init(radians: Float, aroundVector vector: GLKVector3) {
        self.init(GLKMatrix3MakeRotation(radians, vector.x, vector.y, vector.z))
    }

    public init(x: Float) {
        self.init(GLKMatrix3MakeXRotation(x))
    }

    public init(y: Float) {
        self.init(GLKMatrix3MakeYRotation(y))
    }

    public init(z: Float) {
        self.init(GLKMatrix3MakeZRotation(z))
    }
}

extension Rotation {
    public mutating func rotate(byRadians radians: Float, aroundAxis axis: GLKVector3) {
        glkMatrix3 = GLKMatrix3RotateWithVector3(glkMatrix3, radians, axis)
    }

    public mutating func rotate(byX radians: Float) {
        glkMatrix3 = GLKMatrix3RotateX(glkMatrix3, radians)
    }

    public mutating func rotate(byY radians: Float) {
        glkMatrix3 = GLKMatrix3RotateY(glkMatrix3, radians)
    }

    public mutating func rotate(byZ radians: Float) {
        glkMatrix3 = GLKMatrix3RotateZ(glkMatrix3, radians)
    }

    public mutating func invert() {
        glkQuartenion = GLKQuaternionInvert(glkQuartenion)
    }

    public mutating func normalize() {
        glkQuartenion = GLKQuaternionNormalize(glkQuartenion)
    }
}

extension Rotation {
    public func rotated(byRadians radians: Float, aroundAxis axis: GLKVector3) -> Rotation {
        var r = self
        r.rotate(byRadians: radians, aroundAxis: axis)
        return r
    }

    public func rotated(byX x: Float) -> Rotation {
        var r = self
        r.rotate(byX: x)
        return r
    }

    public func rotated(byY y: Float) -> Rotation {
        var r = self
        r.rotate(byY: y)
        return r
    }

    public func rotated(byZ z: Float) -> Rotation {
        var r = self
        r.rotate(byZ: z)
        return r
    }

    public func inverted() -> Rotation {
        var r = self
        r.invert()
        return r
    }

    public func normalized() -> Rotation {
        var r = self
        r.normalize()
        return r
    }
}

public func * (lhs: Rotation, rhs: Rotation) -> Rotation {
    return Rotation(GLKMatrix3Multiply(lhs.glkMatrix3, rhs.glkMatrix3))
}

public func * (lhs: Rotation, rhs: GLKVector3) -> GLKVector3 {
    return GLKMatrix3MultiplyVector3(lhs.glkMatrix3, rhs)
}

extension Rotation {
    public init(_ scnQuaternion: SCNQuaternion) {
        self.init(GLKQuaternionMake(Float(scnQuaternion.x), Float(scnQuaternion.y), Float(scnQuaternion.z), Float(scnQuaternion.w)))
    }

    public var scnQuaternion: SCNQuaternion {
        let quartenion = glkQuartenion
        #if os(macOS)
        return SCNQuaternion(x: CGFloat(quartenion.x), y: CGFloat(quartenion.y), z: CGFloat(quartenion.z), w: CGFloat(quartenion.w))
        #else
        return SCNQuaternion(x: quartenion.x, y: quartenion.y, z: quartenion.z, w: quartenion.w)
        #endif
    }
}

extension Rotation {
    public init(_ scnMatrix4: SCNMatrix4) {
        let glkMatrix4 = SCNMatrix4ToGLKMatrix4(scnMatrix4)
        let glkMatrix3 = GLKMatrix4GetMatrix3(glkMatrix4)
        self.init(glkMatrix3)
    }

    public var scnMatrix4: SCNMatrix4 {
        let glkMatrix4 = GLKMatrix4MakeWithQuaternion(glkQuartenion)
        let scnMatrix4 = SCNMatrix4FromGLKMatrix4(glkMatrix4)
        return scnMatrix4
    }
}

#if os(iOS)
import CoreMotion
extension Rotation {
    public init(_ cmQuaternion: CMQuaternion) {
        self.init(GLKQuaternionMake(
            Float(cmQuaternion.x),
            Float(cmQuaternion.y),
            Float(cmQuaternion.z),
            Float(cmQuaternion.w)
        ))
    }

    public init(_ cmAttitude: CMAttitude) {
        self.init(cmAttitude.quaternion)
    }

    public init(_ cmDeviceMotion: CMDeviceMotion) {
        self.init(cmDeviceMotion.attitude)
    }
}
#endif
