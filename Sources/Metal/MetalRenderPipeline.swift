//
//  MetalRenderPipeline.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2019/12/31.
//

import CoreImage
import CoreVideo
import Foundation
import Metal
import simd
import VideoToolbox
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
protocol MetalRenderPipeline {
    var device: MTLDevice { get }
    var library: MTLLibrary { get }
    var state: MTLRenderPipelineState { get }
    var descriptor: MTLRenderPipelineDescriptor { get }
    init(device: MTLDevice, library: MTLLibrary)
}

struct NV12MetalRenderPipeline: MetalRenderPipeline {
    let device: MTLDevice
    let library: MTLLibrary
    let state: MTLRenderPipelineState
    let descriptor: MTLRenderPipelineDescriptor
    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.library = library
        descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.fragmentFunction = library.makeFunction(name: "displayNV12Texture")
        // swiftlint:disable force_try
        try! state = device.makeRenderPipelineState(descriptor: descriptor)
        // swftlint:enable force_try
    }
}

struct BGRAMetalRenderPipeline: MetalRenderPipeline {
    let device: MTLDevice
    let library: MTLLibrary
    let state: MTLRenderPipelineState
    let descriptor: MTLRenderPipelineDescriptor
    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.library = library
        descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        // swiftlint:disable force_try
        try! state = device.makeRenderPipelineState(descriptor: descriptor)
        // swftlint:enable force_try
    }
}

struct YUVMetalRenderPipeline: MetalRenderPipeline {
    let device: MTLDevice
    let library: MTLLibrary
    let state: MTLRenderPipelineState
    let descriptor: MTLRenderPipelineDescriptor
    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.library = library
        descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.fragmentFunction = library.makeFunction(name: "displayYUVTexture")
        // swiftlint:disable force_try
        try! state = device.makeRenderPipelineState(descriptor: descriptor)
        // swftlint:enable force_try
    }
}

public protocol BufferProtocol: AnyObject {
    var drawableSize: CGSize { get }
    var format: OSType { get }
    var planeCount: Int { get }
    var isFullRangeVideo: Bool { get }
    var colorAttachments: NSString { get }
    func widthOfPlane(at planeIndex: Int) -> Int
    func heightOfPlane(at planeIndex: Int) -> Int
}

extension CVPixelBuffer: BufferProtocol {
    public var width: Int { CVPixelBufferGetWidth(self) }

    public var height: Int { CVPixelBufferGetHeight(self) }

    public var size: CGSize { CGSize(width: width, height: height) }

    public var isPlanar: Bool { CVPixelBufferIsPlanar(self) }

    public var planeCount: Int { isPlanar ? CVPixelBufferGetPlaneCount(self) : 1 }

    public var format: OSType { CVPixelBufferGetPixelFormatType(self) }

    public var drawableSize: CGSize {
        // Check if the pixel buffer exists
        if let ratio = CVBufferGetAttachment(self, kCVImageBufferPixelAspectRatioKey, nil)?.takeUnretainedValue() as? NSDictionary,
            let horizontal = (ratio[kCVImageBufferPixelAspectRatioHorizontalSpacingKey] as? NSNumber)?.intValue,
            let vertical = (ratio[kCVImageBufferPixelAspectRatioVerticalSpacingKey] as? NSNumber)?.intValue,
            horizontal > 0, vertical > 0, horizontal != vertical {
            return CGSize(width: width, height: height * vertical / horizontal)
        } else {
            return size
        }
    }

    public var isFullRangeVideo: Bool {
        CVBufferGetAttachment(self, kCMFormatDescriptionExtension_FullRangeVideo, nil)?.takeUnretainedValue() as? Bool ?? true
    }

    public var colorAttachments: NSString {
        CVBufferGetAttachment(self, kCVImageBufferYCbCrMatrixKey, nil)?.takeUnretainedValue() as? NSString ?? kCVImageBufferYCbCrMatrix_ITU_R_709_2
    }

    public func image() -> UIImage? {
        let ciImage = CIImage(cvImageBuffer: self)
        let context = CIContext(options: nil)
        if let videoImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: size)) {
            return UIImage(cgImage: videoImage)
        } else {
            return nil
        }
    }

    public func widthOfPlane(at planeIndex: Int) -> Int {
        CVPixelBufferGetWidthOfPlane(self, planeIndex)
    }

    public func heightOfPlane(at planeIndex: Int) -> Int {
        CVPixelBufferGetHeightOfPlane(self, planeIndex)
    }

    func baseAddressOfPlane(at planeIndex: Int) -> UnsafeMutableRawPointer? {
        CVPixelBufferGetBaseAddressOfPlane(self, planeIndex)
    }

    public func textures(frome cache: MetalTextureCache) -> [MTLTexture] {
        cache.texture(pixelBuffer: self)
    }
}
