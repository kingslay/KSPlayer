//
//  PixelBufferProtocol.swift
//  KSPlayer-iOS
//
//  Created by kintan on 2019/12/31.
//

import AVFoundation
import CoreVideo
import Foundation
import Libavutil
import simd
import VideoToolbox
#if canImport(UIKit)
import UIKit
#endif

public protocol PixelBufferProtocol: AnyObject {
    var aspectRatio: CGSize { get set }
    var planeCount: Int { get }
    var width: Int { get }
    var height: Int { get }
    var bitDepth: Int32 { get }
    var leftShift: UInt8 { get }
//    var colorPrimaries: CFString? { get }
//    var transferFunction: CFString? { get }
    var yCbCrMatrix: CFString? { get }
    var colorspace: CGColorSpace? { get }
    var attachmentsDic: CFDictionary? { get }
    var cvPixelBuffer: CVPixelBuffer? { get }
    var isFullRangeVideo: Bool { get }
    func cgImage() -> CGImage?
    func textures() -> [MTLTexture]
    func widthOfPlane(at planeIndex: Int) -> Int
    func heightOfPlane(at planeIndex: Int) -> Int
}

extension PixelBufferProtocol {
    var size: CGSize { CGSize(width: width, height: height) }
}

extension CVPixelBuffer: PixelBufferProtocol {
    public var leftShift: UInt8 { 0 }
    public var cvPixelBuffer: CVPixelBuffer? { self }
    public var width: Int { CVPixelBufferGetWidth(self) }
    public var height: Int { CVPixelBufferGetHeight(self) }
    public var aspectRatio: CGSize {
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

    public var planeCount: Int { isPlanar ? CVPixelBufferGetPlaneCount(self) : 1 }

    public var isFullRangeVideo: Bool {
        CVBufferGetAttachment(self, kCMFormatDescriptionExtension_FullRangeVideo, nil)?.takeUnretainedValue() as? Bool ?? false
    }

    public var attachmentsDic: CFDictionary? {
        CVBufferGetAttachments(self, .shouldPropagate)
    }

    public var yCbCrMatrix: CFString? {
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

    public var colorspace: CGColorSpace? {
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

    public var bitDepth: Int32 {
        CVPixelBufferGetPixelFormatType(self).bitDepth
    }

    public func cgImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        return cgImage
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

    public func textures() -> [MTLTexture] {
        MetalRender.texture(pixelBuffer: self)
    }
}

class PixelBuffer: PixelBufferProtocol {
    let bitDepth: Int32
    let width: Int
    let height: Int
    let planeCount: Int
    var aspectRatio: CGSize
    let leftShift: UInt8
    let isFullRangeVideo: Bool
    var cvPixelBuffer: CVPixelBuffer? { nil }
    var attachmentsDic: CFDictionary?
    let colorPrimaries: CFString?
    let transferFunction: CFString?
    let yCbCrMatrix: CFString?
    private let format: AVPixelFormat
    private let formats: [MTLPixelFormat]
    private let widths: [Int]
    private let heights: [Int]
    private let buffers: [MTLBuffer?]
    private let lineSize: [Int]
    public var colorspace: CGColorSpace? {
        attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
    }

    init(frame: AVFrame) {
        yCbCrMatrix = frame.colorspace.ycbcrMatrix
        colorPrimaries = frame.color_primaries.colorPrimaries
        transferFunction = frame.color_trc.transferFunction
        var attachments = [CFString: CFString]()
        attachments[kCVImageBufferColorPrimariesKey] = colorPrimaries
        attachments[kCVImageBufferTransferFunctionKey] = transferFunction
        attachments[kCVImageBufferYCbCrMatrixKey] = yCbCrMatrix
        attachmentsDic = attachments as CFDictionary
        width = Int(frame.width)
        height = Int(frame.height)
        isFullRangeVideo = frame.color_range == AVCOL_RANGE_JPEG
        aspectRatio = frame.sample_aspect_ratio.size
        format = AVPixelFormat(rawValue: frame.format)
        leftShift = format.leftShift
        bitDepth = format.bitDepth
        planeCount = Int(format.planeCount)
        let desc = av_pix_fmt_desc_get(format)?.pointee
        let chromaW = desc?.log2_chroma_w == 1 ? 2 : 1
        let chromaH = desc?.log2_chroma_h == 1 ? 2 : 1
        switch planeCount {
        case 3:
            widths = [width, width / chromaW, width / chromaW]
            heights = [height, height / chromaH, height / chromaH]
        case 2:
            widths = [width, width / chromaW]
            heights = [height, height / chromaH]
        default:
            widths = [width]
            heights = [height]
        }
        formats = KSOptions.pixelFormat(planeCount: planeCount, bitDepth: bitDepth)
        var buffers = [MTLBuffer?]()
        var lineSize = [Int]()
        let bytes = Array(tuple: frame.data)
        let bytesPerRow = Array(tuple: frame.linesize).compactMap { Int($0) }
        for i in 0 ..< planeCount {
            lineSize.append(bytesPerRow[i].alignment(value: MetalRender.device.minimumLinearTextureAlignment(for: formats[i])))
            buffers.append(MetalRender.device.makeBuffer(length: lineSize[i] * heights[i]))
            if bytesPerRow[i] == lineSize[i] {
                buffers[i]?.contents().copyMemory(from: bytes[i]!, byteCount: heights[i] * lineSize[i])
            } else {
                let contents = buffers[i]?.contents()
                let source = bytes[i]!
                for j in 0 ..< heights[i] {
                    contents?.advanced(by: j * lineSize[i]).copyMemory(from: source.advanced(by: j * bytesPerRow[i]), byteCount: bytesPerRow[i])
                }
            }
        }
        self.lineSize = lineSize
        self.buffers = buffers
    }

    func textures() -> [MTLTexture] {
        MetalRender.textures(formats: formats, widths: widths, heights: heights, buffers: buffers, lineSizes: lineSize)
    }

    func widthOfPlane(at planeIndex: Int) -> Int {
        widths[planeIndex]
    }

    func heightOfPlane(at planeIndex: Int) -> Int {
        heights[planeIndex]
    }

    func cgImage() -> CGImage? {
        let image: CGImage?
        if format == AV_PIX_FMT_RGB24 {
            image = CGImage.make(rgbData: buffers[0]!.contents().assumingMemoryBound(to: UInt8.self), linesize: Int(lineSize[0]), width: width, height: height)
        } else {
            let scale = VideoSwresample(dstFormat: AV_PIX_FMT_RGB24, isDovi: false)
            image = scale.transfer(format: format, width: Int32(width), height: Int32(height), data: buffers.map { $0?.contents().assumingMemoryBound(to: UInt8.self) }, linesize: lineSize.map { Int32($0) })?.cgImage()
            scale.shutdown()
        }
        return image
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
