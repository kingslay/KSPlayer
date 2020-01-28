//
//  DisplayModel.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2020/1/11.
//

import Foundation
import Metal
import simd

extension DisplayEnum {
    private static var planeDisplay = PlaneDisplayModel()
    private static var vrDiaplay = VRDisplayModel()
    private static var vrBoxDiaplay = VRBoxDisplayModel()

    func set(encoder: MTLRenderCommandEncoder) {
        switch self {
        case .plane:
            DisplayEnum.planeDisplay.set(encoder: encoder)
        case .vr:
            DisplayEnum.vrDiaplay.set(encoder: encoder)
        case .vrBox:
            DisplayEnum.vrBoxDiaplay.set(encoder: encoder)
        }
    }

    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
    func touchesMoved(touch: UITouch) {
        switch self {
        case .vr:
            DisplayEnum.vrDiaplay.touchesMoved(touch: touch)
        case .vrBox:
            DisplayEnum.vrBoxDiaplay.touchesMoved(touch: touch)
        default:
            break
        }
    }
    #endif
}

private class PlaneDisplayModel {
    let indexCount: Int
    let indexType = MTLIndexType.uint16
    let primitiveType = MTLPrimitiveType.triangleStrip
    let indexBuffer: MTLBuffer
    let vertexBuffer: MTLBuffer?
    let matrixBuffer: MTLBuffer?

    fileprivate init() {
        let (indices, vertices) = PlaneDisplayModel.genSphere()
        let device = MetalRender.share.device
        indexCount = Int(indices.count)
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.size * indices.count, options: .storageModeShared)!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.size * vertices.count, options: .storageModeShared)
        var matrix = matrix_identity_float4x4
        matrixBuffer = device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size, options: .storageModeShared)
    }

    private static func genSphere() -> ([UInt16], [Vertex]) {
        let vertices = [
            Vertex(-1.0, -1.0, 0.0, 1.0, 0.0, 1.0),
            Vertex(-1.0, 1.0, 0.0, 1.0, 0.0, 0.0),
            Vertex(1.0, -1.0, 0.0, 1.0, 1.0, 1.0),
            Vertex(1.0, 1.0, 0.0, 1.0, 1.0, 0.0),
        ]
        let indices: [UInt16] = [0, 1, 2, 3]
        return (indices, vertices)
    }

    func set(encoder: MTLRenderCommandEncoder) {
        encoder.setFrontFacing(.clockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 1)
        encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

private class SphereDisplayModel {
    private var fingerRotationX = Float(0)
    private var fingerRotationY = Float(0)
    fileprivate var modelViewMatrix = matrix_identity_float4x4
    let indexCount: Int
    let indexType = MTLIndexType.uint16
    let primitiveType = MTLPrimitiveType.triangle
    let indexBuffer: MTLBuffer
    let vertexBuffer: MTLBuffer?

    fileprivate init() {
        let (indices, vertices) = SphereDisplayModel.genSphere()
        let device = MetalRender.share.device
        indexCount = Int(indices.count)
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.size * indices.count, options: .storageModeShared)!
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.size * vertices.count, options: .storageModeShared)
        #if os(iOS)
        if KSDefaultParameter.enableSensor {
            MotionSensor.shared.start()
        }
        #endif
    }

    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
    func touchesMoved(touch: UITouch) {
        var distX = Float(touch.location(in: touch.view).x - touch.previousLocation(in: touch.view).x)
        var distY = Float(touch.location(in: touch.view).y - touch.previousLocation(in: touch.view).y)
        distX *= 0.005
        distY *= 0.005
        fingerRotationX -= distY * 60 / 100
        fingerRotationY -= distX * 60 / 100
        modelViewMatrix = matrix_identity_float4x4.rotateX(radians: fingerRotationX).rotateY(radians: fingerRotationY)
    }
    #endif
    func reset() {
        fingerRotationX = 0
        fingerRotationY = 0
        modelViewMatrix = matrix_identity_float4x4
    }

    private static func genSphere() -> ([UInt16], [Vertex]) {
        let slicesCount = UInt16(200)
        let parallelsCount = slicesCount / 2
        let indicesCount = Int(slicesCount) * Int(parallelsCount) * 6
        let verticesCount = (slicesCount + 1) * (parallelsCount + 1)
        var indices = [UInt16](repeating: 0, count: indicesCount)
        var vertices = [Vertex](repeating: Vertex(), count: Int(verticesCount))
        var runCount = 0
        let radius = Float(1.0)
        let step = (2.0 * Float.pi) / Float(slicesCount)
        for i in 0 ... parallelsCount {
            for j in 0 ... slicesCount {
                let vertex0 = radius * sinf(step * Float(i)) * cosf(step * Float(j))
                let vertex1 = radius * cosf(step * Float(i))
                let vertex2 = radius * sinf(step * Float(i)) * sinf(step * Float(j))
                let vertex3 = Float(1.0)
                let vertex4 = Float(j) / Float(slicesCount)
                let vertex5 = Float(i) / Float(parallelsCount)
                vertices[Int(i * (slicesCount + 1) + j)] = Vertex(vertex0, vertex1, vertex2, vertex3, vertex4, vertex5)
                if i < parallelsCount, j < slicesCount {
                    indices[runCount] = i * (slicesCount + 1) + j
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount + 1) + j)
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount + 1) + (j + 1))
                    runCount += 1
                    indices[runCount] = UInt16(i * (slicesCount + 1) + j)
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount + 1) + (j + 1))
                    runCount += 1
                    indices[runCount] = UInt16(i * (slicesCount + 1) + (j + 1))
                    runCount += 1
                }
            }
        }
        return (indices, vertices)
    }
}

private class VRDisplayModel: SphereDisplayModel {
    private let modelViewProjectionMatrix: simd_float4x4
    required override init() {
        let size = UIScreen.size
        let aspect = Float(size.width / size.height)
        let projectionMatrix = simd_float4x4(perspective: Float.pi / 3, aspect: aspect, nearZ: 0.1, farZ: 400.0)
        let viewMatrix = simd_float4x4(lookAt: SIMD3<Float>.zero, center: [0, 0, -1000], up: [0, 1, 0])
        modelViewProjectionMatrix = projectionMatrix * viewMatrix
        super.init()
    }

    func set(encoder: MTLRenderCommandEncoder) {
        encoder.setFrontFacing(.clockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        #if os(iOS)
        if KSDefaultParameter.enableSensor, let matrix = MotionSensor.shared.matrix() {
            modelViewMatrix = matrix
        }
        #endif
        var matrix = modelViewProjectionMatrix * modelViewMatrix
        let matrixBuffer = MetalRender.share.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size, options: .storageModeShared)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 1)
        encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

private class VRBoxDisplayModel: SphereDisplayModel {
    private let modelViewProjectionMatrixLeft: simd_float4x4
    private let modelViewProjectionMatrixRight: simd_float4x4
    required override init() {
        let size = UIScreen.size
        let aspect = Float(size.width / size.height) / 2
        let viewMatrixLeft = simd_float4x4(lookAt: [-0.012, 0, 0], center: [0, 0, -1000], up: [0, 1, 0])
        let viewMatrixRight = simd_float4x4(lookAt: [0.012, 0, 0], center: [0, 0, -1000], up: [0, 1, 0])
        let projectionMatrix = simd_float4x4(perspective: Float.pi / 3, aspect: aspect, nearZ: 0.1, farZ: 400.0)
        modelViewProjectionMatrixLeft = projectionMatrix * viewMatrixLeft
        modelViewProjectionMatrixRight = projectionMatrix * viewMatrixRight
        super.init()
    }

    func set(encoder: MTLRenderCommandEncoder) {
        encoder.setFrontFacing(.clockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        #if os(iOS)
        if KSDefaultParameter.enableSensor, let matrix = MotionSensor.shared.matrix() {
            modelViewMatrix = matrix
        }
        #endif
        let layerSize = UIScreen.size
        let width = Double(layerSize.width / 2)
        [(modelViewProjectionMatrixLeft, MTLViewport(originX: 0, originY: 0, width: width, height: Double(layerSize.height), znear: 0, zfar: 0)),
         (modelViewProjectionMatrixRight, MTLViewport(originX: width, originY: 0, width: width, height: Double(layerSize.height), znear: 0, zfar: 0))].forEach { modelViewProjectionMatrix, viewport in
            encoder.setViewport(viewport)
            var matrix = modelViewProjectionMatrix * modelViewMatrix
            let matrixBuffer = MetalRender.share.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size, options: .storageModeShared)
            encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 1)
            encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
    }
}
