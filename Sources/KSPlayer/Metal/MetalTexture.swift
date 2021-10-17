//
//  MetalTexture.swift
//  Pods
//
//  Created by kintan on 2018/6/14.
//

import MetalKit
public final class MetalTextureCache {
    private var textureCache: CVMetalTextureCache?
    public init() {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalRender.device, nil, &textureCache)
    }

    public func texture(pixelBuffer: CVPixelBuffer) -> [MTLTexture] {
        let formats: [MTLPixelFormat]
        if pixelBuffer.planeCount == 3 {
            formats = [.r8Unorm, .r8Unorm, .r8Unorm]
        } else if pixelBuffer.planeCount == 2 {
            if pixelBuffer.bitDepth > 8 {
                formats = [.r16Unorm, .rg16Unorm]
            } else {
                formats = [.r8Unorm, .rg8Unorm]
            }
        } else {
            formats = [.bgra8Unorm]
        }
        return (0 ..< pixelBuffer.planeCount).compactMap { index in
            let width = pixelBuffer.widthOfPlane(at: index)
            let height = pixelBuffer.heightOfPlane(at: index)
            return texture(pixelBuffer: pixelBuffer, planeIndex: index, pixelFormat: formats[index], width: width, height: height)
        }
    }

    private func texture(pixelBuffer: CVPixelBuffer, planeIndex: Int, pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }
        return inputTexture
    }

    func textures(formats: [MTLPixelFormat], widths: [Int], heights: [Int], buffers: [MTLBuffer?], lineSizes: [Int]) -> [MTLTexture] {
        (0 ..< formats.count).compactMap { i in
            guard let buffer = buffers[i] else {
                return nil
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: formats[i], width: widths[i], height: heights[i], mipmapped: false)
            descriptor.storageMode = buffer.storageMode
            return buffer.makeTexture(descriptor: descriptor, offset: 0, bytesPerRow: lineSizes[i])
        }
    }

    deinit {
        if let textureCache = textureCache {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
    }
}
