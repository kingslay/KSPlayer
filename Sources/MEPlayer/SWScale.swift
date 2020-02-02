//
//  SWScale.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2020/1/27.
//

import CoreGraphics
import CoreMedia
import ffmpeg
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
class SWScale {
    private var imgConvertCtx: OpaquePointer?
    private let format: AVPixelFormat
    private let height: Int32
    var dstFrame: UnsafeMutablePointer<AVFrame>?
    init?(width: Int32, height: Int32, format: AVPixelFormat, dstFormat: AVPixelFormat) {
        self.format = format
        self.height = height
        imgConvertCtx = sws_getCachedContext(imgConvertCtx, width, height, format, width, height, dstFormat, SWS_BICUBIC, nil, nil, nil)
        guard imgConvertCtx != nil else {
            return nil
        }
        dstFrame = av_frame_alloc()
        guard let dstFrame = dstFrame else {
            sws_freeContext(imgConvertCtx)
            imgConvertCtx = nil
            return nil
        }
        dstFrame.pointee.width = width
        dstFrame.pointee.height = height
        dstFrame.pointee.format = dstFormat.rawValue
        av_image_alloc(&dstFrame.pointee.data.0, &dstFrame.pointee.linesize.0, width, height, AVPixelFormat(rawValue: dstFrame.pointee.format), 64)
    }

    func swsConvert(frame: UnsafeMutablePointer<AVFrame>) {
        guard format.rawValue == frame.pointee.format, let dstFrame = dstFrame, swsConvert(data: Array(tuple: frame.pointee.data), linesize: Array(tuple: frame.pointee.linesize)) else {
            return
        }
        frame.pointee.format = dstFrame.pointee.format
        frame.pointee.data = dstFrame.pointee.data
        frame.pointee.linesize = dstFrame.pointee.linesize
    }

    func swsConvert(data: [UnsafeMutablePointer<UInt8>?], linesize: [Int32]) -> Bool {
        guard let dstFrame = dstFrame else {
            return false
        }
        let result = sws_scale(imgConvertCtx, data.map { UnsafePointer($0) }, linesize, 0, height, &dstFrame.pointee.data.0, &dstFrame.pointee.linesize.0)
        return result > 0
    }

    func shutdown() {
        av_frame_free(&dstFrame)
        sws_freeContext(imgConvertCtx)
        imgConvertCtx = nil
    }
}

public final class PixelBufferConverter {
    public static let share = PixelBufferConverter()
    public var bufferCount = 24
    private var pool: CVPixelBufferPool?
    private var width = Int32(0)
    private var height = Int32(0)
    private var format = Int32(0)
    private init() {}

    public static func isSupported(format: AVPixelFormat) -> Bool {
        return format == AV_PIX_FMT_NV12 || format == AV_PIX_FMT_YUV420P || format == AV_PIX_FMT_BGRA
    }

    public func getPixelBuffer(fromFrame frame: AVFrame) -> CVPixelBuffer? {
        if pool == nil || frame.width != width || frame.height != height || frame.format != format {
            makePool(fromFrame: frame)
        }
        return pool?.getPixelBuffer(fromFrame: frame)
    }

    public func shutdown() {
        if let pool = pool {
            CVPixelBufferPoolFlush(pool, CVPixelBufferPoolFlushFlags(rawValue: 0))
        }
        pool = nil
    }

    private func makePool(fromFrame frame: AVFrame) {
        shutdown()
        width = frame.width
        height = frame.height
        format = frame.format
        let dic: NSMutableDictionary = [
            kCVImageBufferChromaLocationBottomFieldKey: "left",
            kCVImageBufferChromaLocationTopFieldKey: "left",
            kCVImageBufferFieldCountKey: 1,
        ]
        let sourcePixelBufferOptions: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: AVPixelFormat(rawValue: format).format,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            //            kCVPixelBufferBytesPerRowAlignmentKey: 64,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVBufferPropagatedAttachmentsKey: dic,
        ]
        let pixelBufferPoolOptions: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: bufferCount]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferPoolOptions, sourcePixelBufferOptions, &pool)
    }
}

class PixelBuffer: BufferProtocol {
    let format: OSType
    let planeCount: Int
    let width: Int
    let height: Int
    let isFullRangeVideo: Bool
    let colorAttachments: NSString
    let textures: [MTLTexture]?
    let drawableSize: CGSize
//    private let bytes: [UnsafeMutablePointer<UInt8>?]
//    private let bytesPerRow: [Int32]
    init(frame: UnsafeMutablePointer<AVFrame>, aspectRatio: NSDictionary?) {
        format = AVPixelFormat(rawValue: frame.pointee.format).format
        if frame.pointee.colorspace == AVCOL_SPC_BT709 {
            colorAttachments = kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2
        } else {
            //        else if frame.colorspace == AVCOL_SPC_SMPTE170M || frame.colorspace == AVCOL_SPC_BT470BG {
            colorAttachments = kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4
        }
        width = Int(frame.pointee.width)
        height = Int(frame.pointee.height)
        isFullRangeVideo = format != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        textures = MetalTexture.share.textures(pixelFormat: format, width: width, height: height, bytes: Array(tuple: frame.pointee.data), bytesPerRow: Array(tuple: frame.pointee.linesize))
        if let ratio = aspectRatio,
            let horizontal = (ratio[kCVImageBufferPixelAspectRatioHorizontalSpacingKey] as? NSNumber)?.intValue,
            let vertical = (ratio[kCVImageBufferPixelAspectRatioVerticalSpacingKey] as? NSNumber)?.intValue,
            horizontal > 0, vertical > 0, horizontal != vertical {
            drawableSize = CGSize(width: width, height: height * vertical / horizontal)
        } else {
            drawableSize = CGSize(width: width, height: height)
        }
        switch format {
        case kCVPixelFormatType_420YpCbCr8Planar:
            planeCount = 3
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            planeCount = 2
        default:
            planeCount = 1
        }
    }

    func widthOfPlane(at planeIndex: Int) -> Int {
        planeIndex == 0 ? width : width / 2
    }

    func heightOfPlane(at planeIndex: Int) -> Int {
        planeIndex == 0 ? height : height / 2
    }

    public static func isSupported(format: AVPixelFormat) -> Bool {
        return format == AV_PIX_FMT_NV12 || format == AV_PIX_FMT_YUV420P || format == AV_PIX_FMT_BGRA
    }

    private func image() -> UIImage? {
//        var image: UIImage?
//        if format.format == AV_PIX_FMT_RGB24 {
//            image = UIImage(rgbData: bytes[0]!, linesize: Int(bytesPerRow[0]), width: width, height: height)
//        }
//        if let scale = SWScale(width: Int32(width), height: Int32(height), format: AV_PIX_FMT_RGB24) {
//            if scale.swsConvert(data: bytes, linesize: bytesPerRow), let frame = scale.dstFrame?.pointee {
//                image = UIImage(rgbData: frame.data.0!, linesize: Int(frame.linesize.0), width: width, height: height)
//            }
//            scale.shutdown()
//        }
        return nil
    }

    deinit {
        if let textures = textures {
            MetalTexture.share.comeback(textures: textures)
        }
    }
}

extension UIImage {
    convenience init?(rgbData: UnsafeMutablePointer<UInt8>, linesize: Int, width: Int, height: Int) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let data = CFDataCreate(kCFAllocatorDefault, rgbData, linesize * height),
            let provider = CGDataProvider(data: data),
            // swiftlint:disable line_length
            let imageRef = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: linesize, space: colorSpace, bitmapInfo: [], provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            // swiftlint:enable line_length
            return nil
        }
        self.init(cgImage: imageRef)
    }
}
