//
//  MetalTexture.swift
//  Pods
//
//  Created by kintan on 2018/6/14.
//

import MetalKit
final class MetalTexture {
    #if !targetEnvironment(simulator)
    private var textureCache: CVMetalTextureCache?
    #endif
    public var commandQueue: MTLCommandQueue?
    init(device: MTLDevice?) {
        #if !targetEnvironment(simulator)
        if let device = device {
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        }
        #endif
        commandQueue = device?.makeCommandQueue()
    }

    public func makeCommandBuffer() -> MTLCommandBuffer? {
        return commandQueue?.makeCommandBuffer()
    }

    public func texture(pixelBuffer: CVPixelBuffer) -> [MTLTexture]? {
        if pixelBuffer.isPlanar {
            var textures = [MTLTexture]()
            for index in 0 ..< pixelBuffer.planeCount {
                let width = pixelBuffer.widthOfPlane(at: index)
                let height = pixelBuffer.heightOfPlane(at: index)
                if let texture = texture(pixelBuffer: pixelBuffer, planeIndex: index, pixelFormat: index == 0 ? .r8Unorm : .rg8Unorm, width: width, height: height) {
                    textures.append(texture)
                }
            }
            return textures
        } else {
            if let texture = texture(pixelBuffer: pixelBuffer, planeIndex: 0, pixelFormat: .bgra8Unorm, width: pixelBuffer.width, height: pixelBuffer.height) {
                return [texture]
            }
        }
        return nil
    }

    private func texture(pixelBuffer: CVPixelBuffer, planeIndex: Int, pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        #if targetEnvironment(simulator)
        return nil
        #else
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }
        return inputTexture
        #endif
    }
}
