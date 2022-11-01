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

        if let pixelBuffer = frame.corePixelBuffer {
            pixelBuffer.colorspace = KSOptions.colorSpace(ycbcrMatrix: pixelBuffer.yCbCrMatrix, transferFunction: pixelBuffer.transferFunction)
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
        if let pbuf {
            pbuf.aspectRatio = frame.sample_aspect_ratio.size
            pbuf.yCbCrMatrix = frame.colorspace.ycbcrMatrix
            pbuf.colorPrimaries = frame.color_primaries.colorPrimaries
            if let transferFunction = frame.color_trc.transferFunction {
                pbuf.transferFunction = transferFunction
                if transferFunction == kCVImageBufferTransferFunction_UseGamma {
                    let gamma = NSNumber(value: frame.color_trc == AVCOL_TRC_GAMMA22 ? 2.2 : 2.8)
                    CVBufferSetAttachment(pbuf, kCVImageBufferGammaLevelKey, gamma, .shouldPropagate)
                }
            }
            if let chroma = frame.chroma_location.chroma {
                CVBufferSetAttachment(pbuf, kCVImageBufferChromaLocationTopFieldKey, chroma, .shouldPropagate)
            }
        }
        return pbuf
    }

    func transfer(format: AVPixelFormat, width: Int32, height: Int32, data: [UnsafeMutablePointer<UInt8>?], linesize: [Int32]) -> CVPixelBuffer? {
        setup(format: format, width: width, height: height, linesize: linesize[0])
        guard let pool else {
            return nil
        }
        return autoreleasepool {
            var pbuf: CVPixelBuffer?
            let ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbuf)
            guard let pbuf, ret == kCVReturnSuccess else {
                return nil
            }
            CVPixelBufferLockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
            let bufferPlaneCount = pbuf.planeCount
            if let imgConvertCtx {
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
    }

    func shutdown() {
        sws_freeContext(imgConvertCtx)
        imgConvertCtx = nil
    }
}

extension BinaryInteger {
    func alignment(value: Self) -> Self {
        let remainder = self % value
        return remainder == 0 ? self : self + value - remainder
    }
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

typealias SwrContext = OpaquePointer

class AudioSwresample: Swresample {
    private var swrContext: SwrContext?
    private var descriptor: AudioDescriptor
    private let channels: Int32
    init(codecpar: AVCodecParameters) {
        descriptor = AudioDescriptor(codecpar: codecpar)
        channels = Int32(max(min(KSOptions.channelLayout.channelCount, descriptor.inputNumberOfChannels), 1))
        _ = setup(descriptor: descriptor)
    }

    private func setup(descriptor: AudioDescriptor) -> Bool {
        var outChannel = AVChannelLayout()
        var inChannel = AVChannelLayout()
        av_channel_layout_default(&outChannel, channels)
        av_channel_layout_default(&inChannel, Int32(descriptor.inputNumberOfChannels))
        _ = swr_alloc_set_opts2(&swrContext, &outChannel, AV_SAMPLE_FMT_FLTP, KSOptions.audioPlayerSampleRate, &inChannel, descriptor.inputFormat, descriptor.inputSampleRate, 0, nil)
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
        numberOfSamples = swr_convert(swrContext, &frame.data, nbSamples, &frameBuffer, numberOfSamples)
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
        inputNumberOfChannels = max(UInt32(codecpar.ch_layout.nb_channels), 1)
        let sampleRate = codecpar.sample_rate
        inputSampleRate = sampleRate == 0 ? KSOptions.audioPlayerSampleRate : sampleRate
        inputFormat = AVSampleFormat(rawValue: codecpar.format)
    }

    init(frame: UnsafeMutablePointer<AVFrame>) {
        inputNumberOfChannels = max(UInt32(frame.pointee.ch_layout.nb_channels), 1)
        let sampleRate = frame.pointee.sample_rate
        inputSampleRate = sampleRate == 0 ? KSOptions.audioPlayerSampleRate : sampleRate
        inputFormat = AVSampleFormat(rawValue: frame.pointee.format)
    }

    static func == (lhs: AudioDescriptor, rhs: AudioDescriptor) -> Bool {
        lhs.inputFormat == rhs.inputFormat && lhs.inputSampleRate == rhs.inputSampleRate && lhs.inputNumberOfChannels == rhs.inputNumberOfChannels
    }

    static func == (lhs: AudioDescriptor, rhs: AVFrame) -> Bool {
        lhs.inputFormat.rawValue == rhs.format && lhs.inputSampleRate == rhs.sample_rate && lhs.inputNumberOfChannels == rhs.ch_layout.nb_channels
    }
}
