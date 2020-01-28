//
//  OpenGLVRPlayView.swift
//  KSPlayer-3f659213
//
//  Created by kintan on 2018/5/29.
//

import CoreMedia

#if !targetEnvironment(macCatalyst) && !os(macOS)
import GLKit

final class OpenGLVRPlayView: OpenGLPlayView {
    private var fingerRotationX: Float = 0
    private var fingerRotationY: Float = 0
    private var numIndices: Int = 6
    override func configureBuffer() {
        let sphereSliceNum = 200
        let sphereRadius: Float = 1.0
        var indices: [UInt16] = [0, 1, 2, 1, 3, 2]
        numIndices = genSphere(numSlices: sphereSliceNum, radius: sphereRadius, vertices: &vertices, texCoords: &textCoord, indices: &indices)
        // Indices
        var tempVertexIndicesBufferID: GLuint = 0
        glGenBuffers(1, &tempVertexIndicesBufferID)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), tempVertexIndicesBufferID)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), numIndices * MemoryLayout<Int16>.size, indices, GLenum(GL_STATIC_DRAW))
        super.configureBuffer()
    }

    override func matrixWithSize(size: CGSize) -> [Float] {
        var modelViewMatrix: GLKMatrix4 = GLKMatrix4Identity
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, -Float(fingerRotationX))
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, Float(fingerRotationY))

        let aspect: Float = abs(Float(size.width) / Float(size.height))
        var mvpMatrix: GLKMatrix4 = GLKMatrix4Identity
        let projectionMatrix: GLKMatrix4 = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60), aspect, 0.1, 400.0)
        let viewMatrix: GLKMatrix4 = GLKMatrix4MakeLookAt(0, 0, 0.0, 0, 0, -1000, 0, 1, 0)
        mvpMatrix = GLKMatrix4Multiply(projectionMatrix, viewMatrix)
        mvpMatrix = GLKMatrix4Multiply(mvpMatrix, modelViewMatrix)
        return mvpMatrix.array
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        let touch: UITouch = touches.first!
        var distX: Float = Float(touch.location(in: touch.view).x) - Float(touch.previousLocation(in: touch.view).x)
        var distY: Float = Float(touch.location(in: touch.view).y) - Float(touch.previousLocation(in: touch.view).y)
        distX *= 0.005
        distY *= 0.005
        fingerRotationX += distY * 60 / 100
        fingerRotationY -= distX * 60 / 100
        glUniformMatrix4fv(GLint(uniformModelViewProjectionMatrix), 1, GLboolean(GL_FALSE), matrixWithSize(size: bounds.size))
    }

    private func genSphere(numSlices: Int, radius: Float, vertices: inout [Float], texCoords: inout [Float], indices: inout [UInt16]) -> Int {
        let numParallels: Int = numSlices / 2
        let numVertices: Int = (numParallels + 1) * (numSlices + 1)
        let numIndices: Int = numParallels * numSlices * 6
        let angleStep = Float(2.0 * Double.pi) / Float(numSlices)
        vertices = [Float](repeating: 0, count: 3 * numVertices)
        texCoords = [Float](repeating: 0, count: 2 * numVertices)
        indices = [UInt16](repeating: 0, count: numIndices)
        for i in 0 ..< numParallels + 1 {
            for j in 0 ..< numSlices + 1 {
                let vertex = (i * (numSlices + 1) + j) * 3
                vertices[vertex + 0] = radius * sinf(angleStep * Float(i)) * cosf(angleStep * Float(j))
                vertices[vertex + 1] = radius * cosf(angleStep * Float(i))
                vertices[vertex + 2] = radius * sinf(angleStep * Float(i)) * sinf(angleStep * Float(j))
                let texIndex = (i * (numSlices + 1) + j) * 2
                texCoords[texIndex + 0] = Float(j) / Float(numSlices)
                texCoords[texIndex + 1] = Float(i) / Float(numParallels)
            }
        }

        var index = 0
        for i in 0 ..< numParallels {
            for j in 0 ..< numSlices {
                indices[index] = UInt16(i * (numSlices + 1) + j)
                index += 1
                indices[index] = UInt16((i + 1) * (numSlices + 1) + j)
                index += 1
                indices[index] = UInt16((i + 1) * (numSlices + 1) + (j + 1))
                index += 1
                indices[index] = UInt16(i * (numSlices + 1) + j)
                index += 1
                indices[index] = UInt16((i + 1) * (numSlices + 1) + (j + 1))
                index += 1
                indices[index] = UInt16(i * (numSlices + 1) + (j + 1))
                index += 1
            }
        }
        return numIndices
    }

    override func set(pixelBuffer: CVPixelBuffer, time _: CMTime) {
        autoreleasepool {
            texture?.refreshTextureWithPixelBuffer(pixelBuffer: pixelBuffer)
            glDrawElements(GLenum(GL_TRIANGLES), GLsizei(numIndices), GLenum(GL_UNSIGNED_SHORT), nil)
        }
        #if os(macOS)
        setNeedsDisplay = true
        #else
        setNeedsDisplay()
        #endif
    }
}

extension GLKMatrix4 {
    var array: [Float] {
        return (0 ..< 16).map { i in
            self[i]
        }
    }
}
#endif
