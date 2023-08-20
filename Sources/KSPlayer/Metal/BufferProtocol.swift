//
//  BufferProtocol.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2019/12/31.
//

import AVFoundation
import CoreVideo
import Foundation
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
               horizontal > 0, vertical > 0
            {
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
        CVBufferGetAttachment(self, kCMFormatDescriptionExtension_FullRangeVideo, nil)?.takeUnretainedValue() as? Bool ?? false
    }

    var attachmentsDic: CFDictionary? {
        CVBufferGetAttachments(self, .shouldPropagate)
    }

    var yCbCrMatrix: CFString? {
        get {
            CVBufferGetAttachment(self, kCVImageBufferYCbCrMatrixKey, nil)?.takeUnretainedValue() as? NSString
        }
        set {
            if let newValue {
                CVBufferSetAttachment(self, kCVImageBufferYCbCrMatrixKey, newValue, .shouldPropagate)
            }
        }
    }

    var colorPrimaries: CFString? {
        get {
            CVBufferGetAttachment(self, kCVImageBufferColorPrimariesKey, nil)?.takeUnretainedValue() as? NSString
        }
        set {
            if let newValue {
                CVBufferSetAttachment(self, kCVImageBufferColorPrimariesKey, newValue, .shouldPropagate)
            }
        }
    }

    var transferFunction: CFString? {
        get {
            CVBufferGetAttachment(self, kCVImageBufferTransferFunctionKey, nil)?.takeUnretainedValue() as? NSString
        }
        set {
            if let newValue {
                CVBufferSetAttachment(self, kCVImageBufferTransferFunctionKey, newValue, .shouldPropagate)
            }
        }
    }

    var colorspace: CGColorSpace? {
        get {
            #if os(macOS)
            return CVImageBufferGetColorSpace(self)?.takeUnretainedValue() ?? attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
            #else
            return attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
            #endif
        }
        set {
            if let newValue {
                CVBufferSetAttachment(self, kCVImageBufferCGColorSpaceKey, newValue, .shouldPropagate)
            }
        }
    }

    var bitDepth: Int32 {
        switch CVPixelBufferGetPixelFormatType(self) {
        case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            return 10
        default:
            return 8
        }
    }

    func cgImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        return cgImage
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
