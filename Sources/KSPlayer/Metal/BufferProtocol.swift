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
#endif

public extension CVPixelBuffer {
    var width: Int { CVPixelBufferGetWidth(self) }
    var height: Int { CVPixelBufferGetHeight(self) }
    var size: CGSize { CGSize(width: width, height: height) }
    var aspectRatio: CGSize {
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

    var isPlanar: Bool { CVPixelBufferIsPlanar(self) }

    var planeCount: Int { isPlanar ? CVPixelBufferGetPlaneCount(self) : 1 }

    var isFullRangeVideo: Bool {
        CVBufferGetAttachment(self, kCMFormatDescriptionExtension_FullRangeVideo, nil)?.takeUnretainedValue() as? Bool ?? true
    }

    var attachmentsDic: CFDictionary? {
        CVBufferGetAttachments(self, .shouldPropagate)
    }

    var yCbCrMatrix: CFString? {
        CVBufferGetAttachment(self, kCVImageBufferYCbCrMatrixKey, nil)?.takeUnretainedValue() as? NSString
    }

    var colorPrimaries: CFString? {
        CVBufferGetAttachment(self, kCVImageBufferColorPrimariesKey, nil)?.takeUnretainedValue() as? NSString
    }

    var transferFunction: CFString? {
        CVBufferGetAttachment(self, kCVImageBufferTransferFunctionKey, nil)?.takeUnretainedValue() as? NSString
    }

    var colorspace: CGColorSpace? {
        #if os(macOS)
        return CVImageBufferGetColorSpace(self)?.takeUnretainedValue() ?? attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
        #else
        return attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
        #endif
    }

    var bitDepth: Int32 {
        switch CVPixelBufferGetPixelFormatType(self) {
        case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            return 10
        default:
            return 8
        }
    }

    func image() -> UIImage? {
        var cgImage: CGImage?
        cgImage = CIContext(options: nil).createCGImage(CIImage(cvImageBuffer: self), from: CGRect(origin: .zero, size: size))
//        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        guard let cgImage = cgImage else {
            return nil
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        return UIImage(cgImage: cgImage)
        #else
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return UIImage(cgImage: cgImage)
        }
        let rect = CGRect(origin: .zero, size: size)
        ctx.setFillColor(UIColor.clear.cgColor)
        ctx.fill(rect)
        ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height))
        ctx.draw(cgImage, in: rect)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage(cgImage: cgImage)
        #endif
    }

    func widthOfPlane(at planeIndex: Int) -> Int {
        CVPixelBufferGetWidthOfPlane(self, planeIndex)
    }

    func heightOfPlane(at planeIndex: Int) -> Int {
        CVPixelBufferGetHeightOfPlane(self, planeIndex)
    }

    internal func baseAddressOfPlane(at planeIndex: Int) -> UnsafeMutableRawPointer? {
        CVPixelBufferGetBaseAddressOfPlane(self, planeIndex)
    }

    func textures() -> [MTLTexture] {
        MetalRender.texture(pixelBuffer: self)
    }
}

extension CGSize {
    var aspectRatio: NSDictionary? {
        if width != 0, height != 0, width != height {
            return [kCVImageBufferPixelAspectRatioHorizontalSpacingKey: width,
                    kCVImageBufferPixelAspectRatioVerticalSpacingKey: height]
        } else {
            return nil
        }
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
