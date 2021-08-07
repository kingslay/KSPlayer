//
//  MotionSensor.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2020/1/13.
//

#if canImport(UIKit) && canImport(CoreMotion)
import CoreMotion
import Foundation
import simd
import UIKit
final class MotionSensor {
    static let shared = MotionSensor()
    private let manager = CMMotionManager()
    private let worldToInertialReferenceFrame = simd_float4x4(euler: -90, y: 0, z: 90)
    private var deviceToDisplay = simd_float4x4.identity
    private let defalutRadiansY: Float
    private var orientation = UIInterfaceOrientation.unknown {
        didSet {
            if oldValue != orientation {
                switch orientation {
                case .portraitUpsideDown:
                    deviceToDisplay = simd_float4x4(euler: 0, y: 0, z: 180)
                case .landscapeRight:
                    deviceToDisplay = simd_float4x4(euler: 0, y: 0, z: -90)
                case .landscapeLeft:
                    deviceToDisplay = simd_float4x4(euler: 0, y: 0, z: 90)
                default:
                    deviceToDisplay = simd_float4x4.identity
                }
            }
        }
    }

    private init() {
        switch UIApplication.shared.statusBarOrientation {
        case .landscapeRight:
            defalutRadiansY = -.pi / 2
        case .landscapeLeft:
            defalutRadiansY = .pi / 2
        default:
            defalutRadiansY = 0
        }
    }

    func ready() -> Bool {
        manager.isDeviceMotionAvailable ? manager.isDeviceMotionActive : false
    }

    func start() {
        if manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive {
            manager.deviceMotionUpdateInterval = 1 / 60
            manager.startDeviceMotionUpdates()
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    func matrix() -> simd_float4x4? {
        if var matrix = manager.deviceMotion.flatMap(simd_float4x4.init(motion:)) {
            matrix = matrix.transpose
            matrix *= worldToInertialReferenceFrame
            orientation = UIApplication.shared.statusBarOrientation
            matrix = deviceToDisplay * matrix
            matrix = matrix.rotateY(radians: defalutRadiansY)
            return matrix
        }
        return nil
    }
}

public extension simd_float4x4 {
    init(motion: CMDeviceMotion) {
        self.init(rotation: motion.attitude.rotationMatrix)
    }

    init(rotation: CMRotationMatrix) {
        self.init(SIMD4<Float>(Float(rotation.m11), Float(rotation.m12), Float(rotation.m13), 0.0),
                  SIMD4<Float>(Float(rotation.m21), Float(rotation.m22), Float(rotation.m23), 0.0),
                  SIMD4<Float>(Float(rotation.m31), Float(rotation.m32), Float(rotation.m33), -1),
                  SIMD4<Float>(0, 0, 0, 1))
    }
}
#endif
