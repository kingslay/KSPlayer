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

public protocol BufferProtocol: AnyObject {
    var aspectRatio: CGSize { get }
    var planeCount: Int { get }
    var width: Int { get }
    var height: Int { get }
    var bitDepth: Int32 { get }
    var isFullRangeVideo: Bool { get }
//    var colorPrimaries: CFString? { get }
//    var transferFunction: CFString? { get }
    var yCbCrMatrix: CFString? { get }
    var attachmentsDic: CFDictionary? { get }
    var colorspace: CGColorSpace? { get }
    func widthOfPlane(at planeIndex: Int) -> Int
    func heightOfPlane(at planeIndex: Int) -> Int
    func textures(frome cache: MetalTextureCache) -> [MTLTexture]
    func image() -> CGImage?
}

extension BufferProtocol {
    var size: CGSize { CGSize(width: width, height: height) }
}

extension CVPixelBuffer: BufferProtocol {
    public var width: Int { CVPixelBufferGetWidth(self) }

    public var height: Int { CVPixelBufferGetHeight(self) }

    public var aspectRatio: CGSize {
        get {
            if let ratio = CVBufferGetAttachment(self, kCVImageBufferPixelAspectRatioKey, nil)?.takeUnretainedValue() as? NSDictionary,
               let horizontal = (ratio[kCVImageBufferPixelAspectRatioHorizontalSpacingKey] as? NSNumber)?.intValue,
               let vertical = (ratio[kCVImageBufferPixelAspectRatioVerticalSpacingKey] as? NSNumber)?.intValue,
               horizontal > 0, vertical > 0 {
                return CGSize(width: horizontal, height: vertical)
            } else {
                return CGSize(width: 1, height: 1)
            }
        }
        set {
            if let aspectRatio = newValue.aspectRatio {
                CVBufferSetAttachment(self, kCVImageBufferPixelAspectRatioKey, aspectRatio, .shouldPropagate)
            }
        }
    }

    public var isPlanar: Bool { CVPixelBufferIsPlanar(self) }

    public var planeCount: Int { isPlanar ? CVPixelBufferGetPlaneCount(self) : 1 }

    public var isFullRangeVideo: Bool {
        CVBufferGetAttachment(self, kCMFormatDescriptionExtension_FullRangeVideo, nil)?.takeUnretainedValue() as? Bool ?? true
    }

    public var attachmentsDic: CFDictionary? {
        CVBufferGetAttachments(self, .shouldPropagate)
    }

    public var yCbCrMatrix: CFString? {
        CVBufferGetAttachment(self, kCVImageBufferYCbCrMatrixKey, nil)?.takeUnretainedValue() as? NSString
    }

    public var colorPrimaries: CFString? {
        CVBufferGetAttachment(self, kCVImageBufferColorPrimariesKey, nil)?.takeUnretainedValue() as? NSString
    }

    public var transferFunction: CFString? {
        CVBufferGetAttachment(self, kCVImageBufferTransferFunctionKey, nil)?.takeUnretainedValue() as? NSString
    }

    public var colorspace: CGColorSpace? {
        #if os(macOS)
        return CVImageBufferGetColorSpace(self)?.takeUnretainedValue() ?? attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
        #else
        return attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
        #endif
    }

    public var bitDepth: Int32 {
        switch CVPixelBufferGetPixelFormatType(self) {
        case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            return 10
        default:
            return 8
        }
    }

    public func image() -> CGImage? {
        let ciImage = CIImage(cvImageBuffer: self)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: CGRect(origin: .zero, size: size))
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

extension KSOptions {
    static func colorPixelFormat(bitDepth: Int32) -> MTLPixelFormat {
        if bitDepth == 10 {
            #if os(macOS) || targetEnvironment(macCatalyst)
            return .bgr10a2Unorm
            #elseif targetEnvironment(simulator)
            return .bgra8Unorm
            #else
            return .bgr10_xr_srgb
            #endif
        } else {
            return .bgra8Unorm
        }
    }
}
