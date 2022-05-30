//
//  SWScale.swift
//  KSPlayer-iOS
//
//  Created by wangjinbian on 2020/1/27.
//

import AVFoundation
import CoreGraphics
import CoreMedia
import Libavcodec
import Libswresample
import Libswscale
import VideoToolbox

protocol Swresample {
    func transfer(avframe: UnsafeMutablePointer<AVFrame>) throws -> MEFrame
    func shutdown()
}

class VideoSwresample: Swresample {
    private var imgConvertCtx: OpaquePointer?
    private var format: AVPixelFormat = AV_PIX_FMT_NONE
    private var height: Int32 = 0
    private var width: Int32 = 0
    private var pool: CVPixelBufferPool?
    private let dstFormat: AVPixelFormat?
    init(dstFormat: AVPixelFormat? = nil) {
        self.dstFormat = dstFormat
    }

    func transfer(avframe: UnsafeMutablePointer<AVFrame>) throws -> MEFrame {
        let frame = VideoVTBFrame()
        if avframe.pointee.format == AV_PIX_FMT_VIDEOTOOLBOX.rawValue {
            frame.corePixelBuffer = unsafeBitCast(avframe.pointee.data.3, to: CVPixelBuffer.self)
        } else {
            frame.corePixelBuffer = transfer(frame: avframe.pointee)
        }
        return frame
    }

    private func setup(format: AVPixelFormat, width: Int32, height: Int32, linesize: Int32) {
        if self.format == format, self.width == width, self.height == height {
            return
        }
        self.format = format
        self.height = height
        self.width = width
        let pixelFormatType: OSType
        if let osType = format.osType(), osType.planeCount() == format.planeCount() {
            pixelFormatType = osType
            sws_freeContext(imgConvertCtx)
            imgConvertCtx = nil
        } else {
            let dstFormat = dstFormat ?? format.bestPixelFormat()
            pixelFormatType = dstFormat.osType()!
            imgConvertCtx = sws_getCachedContext(imgConvertCtx, width, height, self.format, width, height, dstFormat, SWS_BICUBIC, nil, nil, nil)
        }
        pool = CVPixelBufferPool.ceate(width: width, height: height, bytesPerRowAlignment: linesize, pixelFormatType: pixelFormatType)
    }

    private func transfer(frame: AVFrame) -> CVPixelBuffer? {
        let format = AVPixelFormat(rawValue: frame.format)
        let width = frame.width
        let height = frame.height
        let pbuf = transfer(format: format, width: width, height: height, data: Array(tuple: frame.data), linesize: Array(tuple: frame.linesize))
        if let pbuf = pbuf {
            if let aspectRatio = frame.sample_aspect_ratio.size.aspectRatio {
                CVBufferSetAttachment(pbuf, kCVImageBufferPixelAspectRatioKey, aspectRatio, .shouldPropagate)
            }
            if let ycbcrMatrix = frame.colorspace.ycbcrMatrix {
                CVBufferSetAttachment(pbuf, kCVImageBufferYCbCrMatrixKey, ycbcrMatrix, .shouldPropagate)
            }
            if let colorPrimaries = frame.color_primaries.colorPrimaries {
                CVBufferSetAttachment(pbuf, kCVImageBufferColorPrimariesKey, colorPrimaries, .shouldPropagate)
            }
            if let transferFunction = frame.color_trc.transferFunction {
                CVBufferSetAttachment(pbuf, kCVImageBufferTransferFunctionKey, transferFunction, .shouldPropagate)
            }
            if let colorSpace = frame.colorspace.colorSpace {
                CVBufferSetAttachment(pbuf, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
            }
        }
        return pbuf
    }

    func transfer(format: AVPixelFormat, width: Int32, height: Int32, data: [UnsafeMutablePointer<UInt8>?], linesize: [Int32]) -> CVPixelBuffer? {
        setup(format: format, width: width, height: height, linesize: linesize[0])
        guard let pool = pool else {
            return nil
        }
        var pbuf: CVPixelBuffer?
        let ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbuf)
        guard let pbuf = pbuf, ret == kCVReturnSuccess else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
        let bufferPlaneCount = pbuf.planeCount
        if let imgConvertCtx = imgConvertCtx {
            let bytesPerRow = (0 ..< bufferPlaneCount).map { i in
                Int32(CVPixelBufferGetBytesPerRowOfPlane(pbuf, i))
            }
            let contents = (0 ..< bufferPlaneCount).map { i in
                pbuf.baseAddressOfPlane(at: i)?.assumingMemoryBound(to: UInt8.self)
            }
            _ = sws_scale(imgConvertCtx, data.map { UnsafePointer($0) }, linesize, 0, height, contents, bytesPerRow)
        } else {
            let planeCount = format.planeCount()
            for i in 0 ..< bufferPlaneCount {
                let height = pbuf.heightOfPlane(at: i)
                let size = Int(linesize[i])
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pbuf, i)
                var contents = pbuf.baseAddressOfPlane(at: i)
                var source = data[i]!
                if bufferPlaneCount < planeCount, i + 2 == planeCount {
                    var sourceU = data[i]!
                    var sourceV = data[i + 1]!
                    for _ in 0 ..< height {
                        var j = 0
                        while j < size {
                            contents?.advanced(by: 2 * j).copyMemory(from: sourceU.advanced(by: j), byteCount: 1)
                            contents?.advanced(by: 2 * j + 1).copyMemory(from: sourceV.advanced(by: j), byteCount: 1)
                            j += 1
                        }
                        contents = contents?.advanced(by: bytesPerRow)
                        sourceU = sourceU.advanced(by: size)
                        sourceV = sourceV.advanced(by: size)
                    }
                } else if bytesPerRow == size {
                    contents?.copyMemory(from: source, byteCount: height * size)
                } else {
                    for _ in 0 ..< height {
                        contents?.copyMemory(from: source, byteCount: size)
                        contents = contents?.advanced(by: bytesPerRow)
                        source = source.advanced(by: size)
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
        return pbuf
    }

    func shutdown() {
        sws_freeContext(imgConvertCtx)
        imgConvertCtx = nil
    }
}

/**
 Clients who specify AVVideoColorPropertiesKey must specify a color primary, transfer function, and Y'CbCr matrix.
 Most clients will want to specify HD, which consists of:

 AVVideoColorPrimaries_ITU_R_709_2
 AVVideoTransferFunction_ITU_R_709_2
 AVVideoYCbCrMatrix_ITU_R_709_2

 If you require SD colorimetry use:

 AVVideoColorPrimaries_SMPTE_C
 AVVideoTransferFunction_ITU_R_709_2
 AVVideoYCbCrMatrix_ITU_R_601_4

 If you require wide gamut HD colorimetry, you can use:

 AVVideoColorPrimaries_P3_D65
 AVVideoTransferFunction_ITU_R_709_2
 AVVideoYCbCrMatrix_ITU_R_709_2

 If you require 10-bit wide gamut HD colorimetry, you can use:

 AVVideoColorPrimaries_P3_D65
 AVVideoTransferFunction_ITU_R_2100_HLG
 AVVideoYCbCrMatrix_ITU_R_709_2
 */
extension AVColorPrimaries {
    var colorPrimaries: CFString? {
        switch self {
        case AVCOL_PRI_BT470BG:
            return kCVImageBufferColorPrimaries_EBU_3213
        case AVCOL_PRI_SMPTE170M:
            return kCVImageBufferColorPrimaries_SMPTE_C
        case AVCOL_PRI_BT709:
            return kCVImageBufferColorPrimaries_ITU_R_709_2
        case AVCOL_PRI_BT2020:
            return kCVImageBufferColorPrimaries_ITU_R_2020
        default:
            return CVColorPrimariesGetStringForIntegerCodePoint(Int32(rawValue))?.takeUnretainedValue()
        }
    }
}

extension AVColorTransferCharacteristic {
    var transferFunction: CFString? {
        switch self {
        case AVCOL_TRC_SMPTE2084:
            return kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ
        case AVCOL_TRC_BT2020_10, AVCOL_TRC_BT2020_12:
            return kCVImageBufferTransferFunction_ITU_R_2020
        case AVCOL_TRC_BT709:
            return kCVImageBufferTransferFunction_ITU_R_709_2
        case AVCOL_TRC_SMPTE240M:
            return kCVImageBufferTransferFunction_SMPTE_240M_1995
        case AVCOL_TRC_LINEAR:
            return kCVImageBufferTransferFunction_Linear
        case AVCOL_TRC_SMPTE428:
            return kCVImageBufferTransferFunction_SMPTE_ST_428_1
        case AVCOL_TRC_ARIB_STD_B67:
            return kCVImageBufferTransferFunction_ITU_R_2100_HLG
        case AVCOL_TRC_GAMMA22, AVCOL_TRC_GAMMA28:
            return kCVImageBufferTransferFunction_UseGamma
        default:
            return CVTransferFunctionGetStringForIntegerCodePoint(Int32(rawValue))?.takeUnretainedValue()
        }
    }
}

extension AVColorSpace {
    var ycbcrMatrix: CFString? {
        switch self {
        case AVCOL_SPC_BT709:
            return kCVImageBufferYCbCrMatrix_ITU_R_709_2
        case AVCOL_SPC_BT470BG, AVCOL_SPC_SMPTE170M:
            return kCVImageBufferYCbCrMatrix_ITU_R_601_4
        case AVCOL_SPC_SMPTE240M:
            return kCVImageBufferYCbCrMatrix_SMPTE_240M_1995
        case AVCOL_SPC_BT2020_CL, AVCOL_SPC_BT2020_NCL:
            return kCVImageBufferYCbCrMatrix_ITU_R_2020
        default:
            return CVYCbCrMatrixGetStringForIntegerCodePoint(Int32(rawValue))?.takeUnretainedValue()
        }
    }

    var colorSpace: CGColorSpace? {
        switch self {
        case AVCOL_SPC_BT709:
            return CGColorSpace(name: CGColorSpace.itur_709)
        case AVCOL_SPC_BT470BG, AVCOL_SPC_SMPTE170M:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case AVCOL_SPC_BT2020_CL, AVCOL_SPC_BT2020_NCL:
            return CGColorSpace(name: CGColorSpace.itur_2020)
        default:
            return nil
        }
    }
}

extension BinaryInteger {
    func alignment(value: Self) -> Self {
        let remainder = self % value
        return remainder == 0 ? self : self + value - remainder
    }
}

extension AVPixelFormat {
    func bitDepth() -> Int32 {
        let descriptor = av_pix_fmt_desc_get(self)
        return descriptor?.pointee.comp.0.depth ?? 8
    }

    func planeCount() -> UInt8 {
        if let desc = av_pix_fmt_desc_get(self) {
            switch desc.pointee.nb_components {
            case 3:
                return UInt8(desc.pointee.comp.2.plane + 1)
            case 2:
                return UInt8(desc.pointee.comp.1.plane + 1)
            default:
                return UInt8(desc.pointee.comp.0.plane + 1)
            }
        } else {
            return 1
        }
    }

    func bestPixelFormat() -> AVPixelFormat {
        bitDepth() > 8 ? AV_PIX_FMT_P010LE : AV_PIX_FMT_NV12
    }

    // swiftlint:disable cyclomatic_complexity
    // avfoundation.m
    func osType() -> OSType? {
        switch self {
        case AV_PIX_FMT_MONOBLACK: return kCVPixelFormatType_1Monochrome
        case AV_PIX_FMT_GRAY8: return kCVPixelFormatType_OneComponent8
        case AV_PIX_FMT_RGB555BE: return kCVPixelFormatType_16BE555
        case AV_PIX_FMT_RGB555LE: return kCVPixelFormatType_16LE555
        case AV_PIX_FMT_RGB565BE: return kCVPixelFormatType_16BE565
        case AV_PIX_FMT_RGB565LE: return kCVPixelFormatType_16LE565
        case AV_PIX_FMT_BGR24: return kCVPixelFormatType_24BGR
        case AV_PIX_FMT_RGB24: return kCVPixelFormatType_24RGB
        case AV_PIX_FMT_0RGB: return kCVPixelFormatType_32ARGB
        case AV_PIX_FMT_BGR0: return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_0BGR: return kCVPixelFormatType_32ABGR
        case AV_PIX_FMT_RGB0: return kCVPixelFormatType_32RGBA
        case AV_PIX_FMT_BGR48BE: return kCVPixelFormatType_48RGB
        case AV_PIX_FMT_NV12: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_P010LE: return kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
        case AV_PIX_FMT_YUV420P10LE: return kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
        case AV_PIX_FMT_YUV420P: return kCVPixelFormatType_420YpCbCr8Planar
        case AV_PIX_FMT_UYVY422: return kCVPixelFormatType_422YpCbCr8
        case AV_PIX_FMT_YUYV422: return kCVPixelFormatType_422YpCbCr8_yuvs
        case AV_PIX_FMT_YUVJ420P: return kCVPixelFormatType_420YpCbCr8PlanarFullRange
        case AV_PIX_FMT_YUV422P10LE: return kCVPixelFormatType_422YpCbCr10
        case AV_PIX_FMT_YUV422P16LE: return kCVPixelFormatType_422YpCbCr16
        case AV_PIX_FMT_YUV444P: return kCVPixelFormatType_444YpCbCr8
        case AV_PIX_FMT_YUV444P10LE: return kCVPixelFormatType_444YpCbCr10
        case AV_PIX_FMT_YUVA444P: return kCVPixelFormatType_4444YpCbCrA8R
        case AV_PIX_FMT_YUVA444P16LE: return kCVPixelFormatType_4444AYpCbCr16
        default:
            return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

extension OSType {
    func planeCount() -> UInt8 {
        switch self {
        case
            kCVPixelFormatType_48RGB,
            kCVPixelFormatType_32ABGR,
            kCVPixelFormatType_32ARGB,
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_32RGBA,
            kCVPixelFormatType_24BGR,
            kCVPixelFormatType_24RGB,
            kCVPixelFormatType_16BE555,
            kCVPixelFormatType_16LE555,
            kCVPixelFormatType_16BE565,
            kCVPixelFormatType_16LE565,
            kCVPixelFormatType_16BE555,
            kCVPixelFormatType_OneComponent8,
            kCVPixelFormatType_1Monochrome:
            return 1
        case
            kCVPixelFormatType_444YpCbCr8,
            kCVPixelFormatType_4444YpCbCrA8R,
            kCVPixelFormatType_444YpCbCr10,
            kCVPixelFormatType_4444AYpCbCr16,
            kCVPixelFormatType_422YpCbCr8,
            kCVPixelFormatType_422YpCbCr8_yuvs,
            kCVPixelFormatType_422YpCbCr10,
            kCVPixelFormatType_422YpCbCr16,
            kCVPixelFormatType_420YpCbCr8Planar,
            kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            return 3
        default: return 2
        }
    }
}

extension CVPixelBufferPool {
    static func ceate(width: Int32, height: Int32, bytesPerRowAlignment: Int32, pixelFormatType: OSType, bufferCount: Int = 24) -> CVPixelBufferPool? {
        let sourcePixelBufferOptions: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferBytesPerRowAlignmentKey: bytesPerRowAlignment.alignment(value: 64),
            kCVPixelBufferMetalCompatibilityKey: true,
//            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()
        ]
        var outputPool: CVPixelBufferPool?
        let pixelBufferPoolOptions: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: bufferCount]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferPoolOptions, sourcePixelBufferOptions, &outputPool)
        return outputPool
    }
}

extension CGImage {
    static func make(rgbData: UnsafePointer<UInt8>, linesize: Int, width: Int, height: Int, isAlpha: Bool = false) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = isAlpha ? CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue) : CGBitmapInfo.byteOrderMask
        guard let data = CFDataCreate(kCFAllocatorDefault, rgbData, linesize * height), let provider = CGDataProvider(data: data) else {
            return nil
        }
        // swiftlint:disable line_length
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: isAlpha ? 32 : 24, bytesPerRow: linesize, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        // swiftlint:enable line_length
    }
}

typealias SwrContext = OpaquePointer

class AudioSwresample: Swresample {
    private var swrContext: SwrContext?
    private var descriptor: AudioDescriptor
    private let channels: Int32
    init(codecpar: AVCodecParameters) {
        descriptor = AudioDescriptor(codecpar: codecpar)
        channels = Int32(max(min(KSPlayerManager.channelLayout.channelCount, descriptor.inputNumberOfChannels), 2))
        _ = setup(descriptor: descriptor)
    }

    private func setup(descriptor: AudioDescriptor) -> Bool {
        let outChannel = av_get_default_channel_layout(channels)
        let inChannel = av_get_default_channel_layout(Int32(descriptor.inputNumberOfChannels))
        swrContext = swr_alloc_set_opts(nil, outChannel, AV_SAMPLE_FMT_FLTP, KSPlayerManager.audioPlayerSampleRate, inChannel, descriptor.inputFormat, descriptor.inputSampleRate, 0, nil)
        let result = swr_init(swrContext)
        if result < 0 {
            shutdown()
            return false
        } else {
            return true
        }
    }

    func transfer(avframe: UnsafeMutablePointer<AVFrame>) throws -> MEFrame {
        if !(descriptor == avframe.pointee) {
            let descriptor = AudioDescriptor(frame: avframe)
            if setup(descriptor: descriptor) {
                self.descriptor = descriptor
            } else {
                throw NSError(errorCode: .auidoSwrInit, userInfo: ["outChannel": channels, "inChannel": descriptor.inputNumberOfChannels])
            }
        }
        var numberOfSamples = avframe.pointee.nb_samples
        let nbSamples = swr_get_out_samples(swrContext, numberOfSamples)
        var frameBuffer = Array(tuple: avframe.pointee.data).map { UnsafePointer<UInt8>($0) }
        var bufferSize = Int32(0)
        _ = av_samples_get_buffer_size(&bufferSize, channels, nbSamples, AV_SAMPLE_FMT_FLTP, 1)
        let frame = AudioFrame(bufferSize: bufferSize, channels: channels)
        numberOfSamples = swr_convert(swrContext, &frame.dataWrap.data, nbSamples, &frameBuffer, numberOfSamples)
        frame.numberOfSamples = Int(numberOfSamples)
        return frame
    }

    func shutdown() {
        swr_free(&swrContext)
    }
}

private class AudioDescriptor: Equatable {
    fileprivate let inputNumberOfChannels: AVAudioChannelCount
    fileprivate let inputSampleRate: Int32
    fileprivate let inputFormat: AVSampleFormat
    init(codecpar: AVCodecParameters) {
        inputNumberOfChannels = max(UInt32(codecpar.channels), 1)
        let sampleRate = codecpar.sample_rate
        inputSampleRate = sampleRate == 0 ? KSPlayerManager.audioPlayerSampleRate : sampleRate
        inputFormat = AVSampleFormat(rawValue: codecpar.format)
    }

    init(frame: UnsafeMutablePointer<AVFrame>) {
        inputNumberOfChannels = max(UInt32(frame.pointee.channels), 1)
        let sampleRate = frame.pointee.sample_rate
        inputSampleRate = sampleRate == 0 ? KSPlayerManager.audioPlayerSampleRate : sampleRate
        inputFormat = AVSampleFormat(rawValue: frame.pointee.format)
    }

    static func == (lhs: AudioDescriptor, rhs: AudioDescriptor) -> Bool {
        lhs.inputFormat == rhs.inputFormat && lhs.inputSampleRate == rhs.inputSampleRate && lhs.inputNumberOfChannels == rhs.inputNumberOfChannels
    }

    static func == (lhs: AudioDescriptor, rhs: AVFrame) -> Bool {
        lhs.inputFormat.rawValue == rhs.format && lhs.inputSampleRate == rhs.sample_rate && lhs.inputNumberOfChannels == rhs.channels
    }
}
