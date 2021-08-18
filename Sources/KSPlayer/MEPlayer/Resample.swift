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
    private var dstFormat: AVPixelFormat
    private var imgConvertCtx: OpaquePointer?
    private var format: AVPixelFormat = AV_PIX_FMT_NONE
    private var height: Int32 = 0
    private var width: Int32 = 0
    private var forceTransfer: Bool
    private var pool: CVPixelBufferPool?
    var dstFrame: UnsafeMutablePointer<AVFrame>?
    init(dstFormat: AVPixelFormat = AV_PIX_FMT_NV12, forceTransfer: Bool = false) {
        self.dstFormat = dstFormat
        self.forceTransfer = forceTransfer
    }

    private func setup(frame: UnsafeMutablePointer<AVFrame>) -> Bool {
        let format = AVPixelFormat(rawValue: frame.pointee.format)
        let width = frame.pointee.width
        let height = frame.pointee.height
        if self.format == format, self.width == width, self.height == height {
            return true
        }
        let result = setup(format: format, width: width, height: height)
        if result, let pixelFormatType = dstFormat.osType() {
            pool = CVPixelBufferPool.ceate(width: width, height: height, bytesPerRowAlignment: frame.pointee.linesize.0, pixelFormatType: pixelFormatType)
        }
        return result
    }

    private func setup(format: AVPixelFormat, width: Int32, height: Int32) -> Bool {
        shutdown()
        self.format = format
        self.height = height
        self.width = width
        if !forceTransfer {
            if self.format.osType() != nil {
                dstFormat = self.format
                return true
            } else {
                dstFormat = self.format.bestPixelFormat()
            }
        }
        imgConvertCtx = sws_getCachedContext(imgConvertCtx, width, height, self.format, width, height, dstFormat, SWS_BICUBIC, nil, nil, nil)
        guard imgConvertCtx != nil else {
            return false
        }
        dstFrame = av_frame_alloc()
        guard let dstFrame = dstFrame else {
            sws_freeContext(imgConvertCtx)
            imgConvertCtx = nil
            return false
        }
        dstFrame.pointee.width = width
        dstFrame.pointee.height = height
        dstFrame.pointee.format = dstFormat.rawValue
        av_image_alloc(&dstFrame.pointee.data.0, &dstFrame.pointee.linesize.0, width, height, AVPixelFormat(rawValue: dstFrame.pointee.format), 64)
        return true
    }

    func transfer(avframe: UnsafeMutablePointer<AVFrame>) throws -> MEFrame {
        let frame = VideoVTBFrame()
        if avframe.pointee.format == AV_PIX_FMT_VIDEOTOOLBOX.rawValue {
            // swiftlint:disable force_cast
            frame.corePixelBuffer = avframe.pointee.data.3 as! CVPixelBuffer
            // swiftlint:enable force_cast
        } else {
            _ = setup(frame: avframe)
            if let dstFrame = dstFrame, swsConvert(data: Array(tuple: avframe.pointee.data), linesize: Array(tuple: avframe.pointee.linesize)) {
                avframe.pointee.format = dstFrame.pointee.format
                avframe.pointee.data = dstFrame.pointee.data
                avframe.pointee.linesize = dstFrame.pointee.linesize
            }
            if let pool = pool {
                frame.corePixelBuffer = pool.getPixelBuffer(fromFrame: avframe.pointee)
            } else {
                frame.corePixelBuffer = PixelBuffer(frame: avframe)
            }
        }
        return frame
    }

    func transfer(format: AVPixelFormat, width: Int32, height: Int32, data: [UnsafeMutablePointer<UInt8>?], linesize: [Int]) -> CGImage? {
        if setup(format: format, width: width, height: height), swsConvert(data: data, linesize: linesize.compactMap { Int32($0) }), let frame = dstFrame?.pointee {
            return CGImage.make(rgbData: frame.data.0!, linesize: Int(frame.linesize.0), width: Int(width), height: Int(height), isAlpha: dstFormat == AV_PIX_FMT_RGBA)
        }
        return nil
    }

    private func swsConvert(data: [UnsafeMutablePointer<UInt8>?], linesize: [Int32]) -> Bool {
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

    static func == (lhs: VideoSwresample, rhs: AVFrame) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && lhs.format.rawValue == rhs.format
    }
}

class PixelBuffer: BufferProtocol {
    var attachmentsDic: CFDictionary?
    let bitDepth: Int32
    let format: AVPixelFormat
    let width: Int
    let height: Int
    let planeCount: Int
    let isFullRangeVideo: Bool
    let colorPrimaries: CFString?
    let transferFunction: CFString?
    let yCbCrMatrix: CFString?
    let aspectRatio: CGSize
    private let formats: [MTLPixelFormat]
    private let widths: [Int]
    private let heights: [Int]
    private let dataWrap: MTLBufferWrap
    private var lineSize = [Int]()
    public var colorspace: CGColorSpace? {
        attachmentsDic.flatMap { CVImageBufferCreateColorSpaceFromAttachments($0)?.takeUnretainedValue() }
    }

    init(frame: UnsafeMutablePointer<AVFrame>) {
        format = AVPixelFormat(rawValue: frame.pointee.format)
        yCbCrMatrix = frame.pointee.colorspace.ycbcrMatrix
        colorPrimaries = frame.pointee.color_primaries.colorPrimaries
        transferFunction = frame.pointee.color_trc.transferFunction
        var attachments = [CFString: CFString]()
        attachments[kCVImageBufferColorPrimariesKey] = colorPrimaries
        attachments[kCVImageBufferTransferFunctionKey] = transferFunction
        attachments[kCVImageBufferYCbCrMatrixKey] = yCbCrMatrix
        attachmentsDic = attachments as CFDictionary
        width = Int(frame.pointee.width)
        height = Int(frame.pointee.height)
        isFullRangeVideo = frame.pointee.color_range == AVCOL_RANGE_JPEG
        let bytesPerRow = Array(tuple: frame.pointee.linesize).compactMap { Int($0) }
        bitDepth = format.bitDepth()
        aspectRatio = frame.pointee.sample_aspect_ratio.size
        planeCount = Int(format.planeCount())
        switch planeCount {
        case 3:
            formats = bitDepth > 8 ? [.r16Unorm, .r16Unorm, .r16Unorm] : [.r8Unorm, .r8Unorm, .r8Unorm]
            widths = [width, width / 2, width / 2]
            heights = [height, height / 2, height / 2]
        case 2:
            formats = bitDepth > 8 ? [.r16Unorm, .rg16Unorm] : [.r8Unorm, .rg8Unorm]
            widths = [width, width / 2]
            heights = [height, height / 2]
        default:
            formats = [.bgra8Unorm]
            widths = [width]
            heights = [height]
        }
        var size = [Int]()
        for i in 0 ..< planeCount {
            lineSize.append(bytesPerRow[i].alignment(value: MetalRender.device.minimumLinearTextureAlignment(for: formats[i])))
            size.append(lineSize[i] * heights[i])
        }
        dataWrap = ObjectPool.share.object(class: MTLBufferWrap.self, key: "VideoData") { MTLBufferWrap(size: size) }
        dataWrap.size = size
        let bytes = Array(tuple: frame.pointee.data)
        for i in 0 ..< planeCount {
            if bytesPerRow[i] == lineSize[i] {
                dataWrap.data[i]?.contents().copyMemory(from: bytes[i]!, byteCount: heights[i] * lineSize[i])
            } else {
                let contents = dataWrap.data[i]?.contents()
                let source = bytes[i]!
                for j in 0 ..< heights[i] {
                    contents?.advanced(by: j * lineSize[i]).copyMemory(from: source.advanced(by: j * bytesPerRow[i]), byteCount: bytesPerRow[i])
                }
            }
        }
    }

    deinit {
        ObjectPool.share.comeback(item: dataWrap, key: "VideoData")
    }

    func textures(frome cache: MetalTextureCache) -> [MTLTexture] {
        cache.textures(formats: formats, widths: widths, heights: heights, buffers: dataWrap.data, lineSizes: lineSize)
    }

    func widthOfPlane(at planeIndex: Int) -> Int {
        widths[planeIndex]
    }

    func heightOfPlane(at planeIndex: Int) -> Int {
        heights[planeIndex]
    }

    func image() -> CGImage? {
        let image: CGImage?
        if format == AV_PIX_FMT_RGB24 {
            image = CGImage.make(rgbData: dataWrap.data[0]!.contents().assumingMemoryBound(to: UInt8.self), linesize: Int(lineSize[0]), width: width, height: height)
        } else {
            let scale = VideoSwresample(dstFormat: AV_PIX_FMT_RGB24, forceTransfer: true)
            image = scale.transfer(format: format, width: Int32(width), height: Int32(height), data: dataWrap.data.map { $0?.contents().assumingMemoryBound(to: UInt8.self) }, linesize: lineSize)
            scale.shutdown()
        }
        return image
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
    func osType() -> OSType? {
        switch self {
        case AV_PIX_FMT_ABGR: return kCVPixelFormatType_32ABGR
        case AV_PIX_FMT_ARGB: return kCVPixelFormatType_32ARGB
        case AV_PIX_FMT_BGR24: return kCVPixelFormatType_24BGR
        case AV_PIX_FMT_BGR48BE: return kCVPixelFormatType_48RGB
        case AV_PIX_FMT_BGRA: return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_MONOBLACK: return kCVPixelFormatType_1Monochrome
        case AV_PIX_FMT_NV12: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_RGB24: return kCVPixelFormatType_24RGB
        case AV_PIX_FMT_RGB555BE: return kCVPixelFormatType_16BE555
        case AV_PIX_FMT_RGB555LE: return kCVPixelFormatType_16LE555
        case AV_PIX_FMT_RGB565BE: return kCVPixelFormatType_16BE565
        case AV_PIX_FMT_RGB565LE: return kCVPixelFormatType_16LE565
        case AV_PIX_FMT_RGBA: return kCVPixelFormatType_32RGBA
        case AV_PIX_FMT_UYVY422: return kCVPixelFormatType_422YpCbCr8
        case AV_PIX_FMT_YUV420P: return kCVPixelFormatType_420YpCbCr8Planar
//        case AV_PIX_FMT_YUVJ420P:   return kCVPixelFormatType_420YpCbCr8PlanarFullRange
        case AV_PIX_FMT_P010LE: return kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case AV_PIX_FMT_YUV422P10LE: return kCVPixelFormatType_422YpCbCr10
        case AV_PIX_FMT_YUV422P16LE: return kCVPixelFormatType_422YpCbCr16
        case AV_PIX_FMT_YUV444P: return kCVPixelFormatType_444YpCbCr8
        case AV_PIX_FMT_YUV444P10LE: return kCVPixelFormatType_444YpCbCr10
        case AV_PIX_FMT_YUVA444P: return kCVPixelFormatType_4444YpCbCrA8R
        case AV_PIX_FMT_YUVA444P16LE: return kCVPixelFormatType_4444AYpCbCr16
        case AV_PIX_FMT_YUYV422: return kCVPixelFormatType_422YpCbCr8_yuvs
        case AV_PIX_FMT_GRAY8: return kCVPixelFormatType_OneComponent8
        default:
            return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity
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

    func getPixelBuffer(fromFrame frame: AVFrame) -> CVPixelBuffer? {
        var pbuf: CVPixelBuffer?
        let ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self, &pbuf)
        if let pbuf = pbuf, ret == kCVReturnSuccess {
            CVPixelBufferLockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
            let data = Array(tuple: frame.data)
            let linesize = Array(tuple: frame.linesize)
            for i in 0 ..< pbuf.planeCount {
                let height = pbuf.heightOfPlane(at: i)
                let size = Int(linesize[i])
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pbuf, i)
                if bytesPerRow == size {
                    pbuf.baseAddressOfPlane(at: i)?.copyMemory(from: data[i]!, byteCount: height * size)
                } else {
                    let contents = pbuf.baseAddressOfPlane(at: i)
                    let source = data[i]!
                    for j in 0 ..< height {
                        contents?.advanced(by: j * bytesPerRow).copyMemory(from: source.advanced(by: j * size), byteCount: size)
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
            if let aspectRatio = frame.sample_aspect_ratio.size.aspectRatio {
                CVBufferSetAttachment(pbuf, kCVImageBufferPixelAspectRatioKey, aspectRatio, .shouldPropagate)
            }
        }
        return pbuf
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
        channels = Int32(max(min(KSPlayerManager.audioPlayerMaximumChannels, descriptor.inputNumberOfChannels), 2))
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

class AudioDescriptor: Equatable {
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
