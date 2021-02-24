//
//  MetalRenderer.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2020/1/11.
//
import CoreVideo
import Foundation
import Metal
import QuartzCore
import simd
import VideoToolbox
import Accelerate
// swiftlint:disable identifier_name
private let kvImage_YpCbCrToARGBMatrix_ITU_R_2020 = vImage_YpCbCrToARGBMatrix(Yp: 1, Cr_R: 1.4746, Cr_G: -0.57135, Cb_G: -0.16455, Cb_B: 1.8814)
// swiftlint:enable identifier_name
class MetalRender {
    static let share = MetalRender()
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue?
    private let library: MTLLibrary
    private lazy var yuv = YUVMetalRenderPipeline(device: device, library: library)
    private lazy var yuvp010LE = YUVMetalRenderPipeline(device: device, library: library, bitDepth: 10)
    private lazy var nv12 = NV12MetalRenderPipeline(device: device, library: library)
    private lazy var p010LE = NV12MetalRenderPipeline(device: device, library: library, bitDepth: 10)
    private lazy var bgra = BGRAMetalRenderPipeline(device: device, library: library)
    private lazy var samplerState: MTLSamplerState? = {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.mipFilter = .nearest
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.rAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        return device.makeSamplerState(descriptor: samplerDescriptor)
    }()

    private lazy var colorConversion601VideoRangeMatrixBuffer: MTLBuffer? = {
        kvImage_YpCbCrToARGBMatrix_ITU_R_601_4.pointee.videoRange.buffer(device: device)
    }()

    private lazy var colorConversion601FullRangeMatrixBuffer: MTLBuffer? = {
        kvImage_YpCbCrToARGBMatrix_ITU_R_601_4.pointee.buffer(device: device)
    }()

    private lazy var colorConversion709VideoRangeMatrixBuffer: MTLBuffer? = {
        kvImage_YpCbCrToARGBMatrix_ITU_R_709_2.pointee.videoRange.buffer(device: device)
    }()

    private lazy var colorConversion709FullRangeMatrixBuffer: MTLBuffer? = {
        kvImage_YpCbCrToARGBMatrix_ITU_R_709_2.pointee.buffer(device: device)
    }()

    private lazy var colorConversion2020MatrixBuffer: MTLBuffer? = {
        kvImage_YpCbCrToARGBMatrix_ITU_R_2020.videoRange.buffer(device: device)
    }()

    private lazy var colorConversion2020FullRangeMatrixBuffer: MTLBuffer? = {
        kvImage_YpCbCrToARGBMatrix_ITU_R_2020.buffer(device: device)
    }()

    private lazy var colorOffsetVideoRangeMatrixBuffer: MTLBuffer? = {
        var firstColumn = SIMD3<Float>(-16.0 / 255.0, -128.0/255.0, -128.0/255.0)
        let buffer = device.makeBuffer(bytes: &firstColumn, length: MemoryLayout<SIMD3<Float>>.size, options: .storageModeShared)
        buffer?.label = "colorOffset"
        return buffer
    }()

    private lazy var colorOffsetFullRangeMatrixBuffer: MTLBuffer? = {
        var firstColumn = SIMD3<Float>(0, -128.0/255.0, -128.0/255.0)
        let buffer = device.makeBuffer(bytes: &firstColumn, length: MemoryLayout<SIMD3<Float>>.size, options: .storageModeShared)
        buffer?.label = "colorOffset"
        return buffer
    }()

    private init() {
        device = MTLCreateSystemDefaultDevice()!
        var library: MTLLibrary!
        library = device.makeDefaultLibrary()
        if library == nil, let path = Bundle(for: type(of: self)).path(forResource: "Metal", ofType: "bundle"), let bundle = Bundle(path: path) {
            library = try? device.makeDefaultLibrary(bundle: bundle)
        }
        self.library = library
        commandQueue = device.makeCommandQueue()
    }

    func clear(drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func draw(pixelBuffer: BufferProtocol, display: DisplayEnum = .plane, inputTextures: [MTLTexture], drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        guard inputTextures.count > 0, let commandBuffer = commandQueue?.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(pipeline(pixelBuffer: pixelBuffer).state)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        for (index, texture) in inputTextures.enumerated() {
            texture.label = "texture\(index)"
            encoder.setFragmentTexture(texture, index: index)
        }
        setFragmentBuffer(pixelBuffer: pixelBuffer, encoder: encoder)
        display.set(encoder: encoder)
        encoder.popDebugGroup()
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func pipeline(pixelBuffer: BufferProtocol) -> MetalRenderPipeline {
        switch pixelBuffer.planeCount {
        case 3:
            if pixelBuffer.bitDepth == 10 {
                return yuvp010LE
            } else {
                return yuv
            }
        case 2:
            if pixelBuffer.bitDepth == 10 {
                return p010LE
            } else {
                return nv12
            }
        case 1:
            return bgra
        default:
            return bgra
        }
    }

    private func setFragmentBuffer(pixelBuffer: BufferProtocol, encoder: MTLRenderCommandEncoder) {
        if pixelBuffer.planeCount > 1 {
            let buffer: MTLBuffer?
            let yCbCrMatrix = pixelBuffer.yCbCrMatrix
            let isFullRangeVideo = pixelBuffer.isFullRangeVideo
            if yCbCrMatrix == kCVImageBufferYCbCrMatrix_ITU_R_709_2 {
                buffer = isFullRangeVideo ? colorConversion709FullRangeMatrixBuffer : colorConversion709VideoRangeMatrixBuffer
            } else if yCbCrMatrix == kCVImageBufferYCbCrMatrix_ITU_R_2020 {
                buffer = isFullRangeVideo ? colorConversion2020FullRangeMatrixBuffer : colorConversion2020MatrixBuffer
            } else {
                buffer = isFullRangeVideo ? colorConversion601FullRangeMatrixBuffer : colorConversion601VideoRangeMatrixBuffer
            }
            encoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            let colorOffset = isFullRangeVideo ? colorOffsetFullRangeMatrixBuffer : colorOffsetVideoRangeMatrixBuffer
            encoder.setFragmentBuffer(colorOffset, offset: 0, index: 1)
        }
    }
}
extension vImage_YpCbCrToARGBMatrix {
    var videoRange: vImage_YpCbCrToARGBMatrix {
        vImage_YpCbCrToARGBMatrix(Yp: 255/219*Yp, Cr_R: 255/224*Cr_R, Cr_G: 255/224*Cr_G, Cb_G: 255/224*Cb_G, Cb_B: 255/224*Cb_B)
    }

    func buffer(device: MTLDevice) -> MTLBuffer? {
        var matrix = simd_float3x3([Yp, Yp, Yp], [0.0, Cb_G, Cb_B], [Cr_R, Cr_G, 0.0])
        let buffer = device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float3x3>.size, options: .storageModeShared)
        buffer?.label = "colorConversionMatrix"
        return buffer
    }
}
