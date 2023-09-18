//
//  Resample.swift
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
//        if let sideData = avframe.pointee.side_data?.pointee?.pointee {
//            if sideData.type == AV_FRAME_DATA_DOVI_RPU_BUFFER {
//                let rpuBuff = sideData.data.withMemoryRebound(to: [UInt8].self, capacity: 1) { $0 }
//            } else if sideData.type == AV_FRAME_DATA_DOVI_METADATA { // AVDOVIMetadata
//                let doviMeta = sideData.data.withMemoryRebound(to: AVDOVIMetadata.self, capacity: 1) { $0 }
//                let header = av_dovi_get_header(doviMeta)
//                let mapping = av_dovi_get_mapping(doviMeta)
//                let color = av_dovi_get_color(doviMeta)
//
//            } else if sideData.type == AV_FRAME_DATA_DYNAMIC_HDR_PLUS { // AVDynamicHDRPlus
//                let hdrPlus = sideData.data.withMemoryRebound(to: AVDynamicHDRPlus.self, capacity: 1) { $0 }.pointee
//
//            } else if sideData.type == AV_FRAME_DATA_DYNAMIC_HDR_VIVID { // AVDynamicHDRVivid
//                let hdrVivid = sideData.data.withMemoryRebound(to: AVDynamicHDRVivid.self, capacity: 1) { $0 }.pointee
//            }
//        }
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
            // vt_pixbuf_set_colorspace
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

typealias SwrContext = OpaquePointer

class AudioSwresample: Swresample {
    private var swrContext: SwrContext?
    private var descriptor: AudioDescriptor
    private var outChannel: AVChannelLayout
    init(audioDescriptor: AudioDescriptor) {
        descriptor = audioDescriptor
        outChannel = audioDescriptor.outChannel
        _ = setup(descriptor: descriptor)
    }

    private func setup(descriptor: AudioDescriptor) -> Bool {
        var result = swr_alloc_set_opts2(&swrContext, &descriptor.outChannel, descriptor.audioFormat.sampleFormat, Int32(descriptor.audioFormat.sampleRate), &descriptor.channel, descriptor.sampleFormat, descriptor.sampleRate, 0, nil)
        result = swr_init(swrContext)
        if result < 0 {
            shutdown()
            return false
        } else {
            outChannel = descriptor.outChannel
            return true
        }
    }

    func transfer(avframe: UnsafeMutablePointer<AVFrame>) throws -> MEFrame {
        let newDescriptor = AudioDescriptor(frame: avframe.pointee)
        if !(descriptor == newDescriptor) || outChannel != descriptor.outChannel {
            newDescriptor.setAudioSession(isUseAudioRenderer: descriptor.audioFormat.isInterleaved)
            if setup(descriptor: newDescriptor) {
                descriptor = newDescriptor
            } else {
                throw NSError(errorCode: .auidoSwrInit, userInfo: ["outChannel": newDescriptor.outChannel, "inChannel": newDescriptor.channel])
            }
        }
        let numberOfSamples = avframe.pointee.nb_samples
        let outSamples = swr_get_out_samples(swrContext, numberOfSamples)
        var frameBuffer = Array(tuple: avframe.pointee.data).map { UnsafePointer<UInt8>($0) }
        let channels = descriptor.outChannel.nb_channels
        var bufferSize = [Int32(0)]
        // 返回值是有乘以声道，所以不用返回值
        _ = av_samples_get_buffer_size(&bufferSize, channels, outSamples, descriptor.audioFormat.sampleFormat, 1)
        let frame = AudioFrame(dataSize: Int(bufferSize[0]), audioFormat: descriptor.audioFormat)
        frame.numberOfSamples = UInt32(swr_convert(swrContext, &frame.data, outSamples, &frameBuffer, numberOfSamples))
        return frame
    }

    func shutdown() {
        swr_free(&swrContext)
    }
}

public class AudioDescriptor: Equatable {
    static let defaultValue = AudioDescriptor()
    public let sampleRate: Int32
    fileprivate let sampleFormat: AVSampleFormat
    fileprivate var channel: AVChannelLayout
    fileprivate var outChannel: AVChannelLayout
    var audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channelLayout: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!)
    public var channels: AVAudioChannelCount {
        AVAudioChannelCount(channel.nb_channels)
    }

    private init() {
        channel = AVChannelLayout.defaultValue
        outChannel = channel
        sampleRate = 44100
        sampleFormat = AV_SAMPLE_FMT_FLT
    }

    init(codecpar: AVCodecParameters) {
        channel = codecpar.ch_layout
        outChannel = channel
        let sampleRate = codecpar.sample_rate
        if sampleRate <= 0 {
            self.sampleRate = 44100
        } else {
            self.sampleRate = sampleRate
        }
        sampleFormat = AVSampleFormat(rawValue: codecpar.format)
    }

    init(frame: AVFrame) {
        channel = frame.ch_layout
        outChannel = channel
        let sampleRate = frame.sample_rate
        if sampleRate <= 0 {
            self.sampleRate = 44100
        } else {
            self.sampleRate = sampleRate
        }
        sampleFormat = AVSampleFormat(rawValue: frame.format)
    }

    public static func == (lhs: AudioDescriptor, rhs: AudioDescriptor) -> Bool {
        lhs.sampleFormat == rhs.sampleFormat && lhs.sampleRate == rhs.sampleRate && lhs.channel == rhs.channel
    }

    private func audioFormat(channels: AVAudioChannelCount, isUseAudioRenderer: Bool) {
        if channels != self.channels {
            av_channel_layout_default(&outChannel, Int32(channels))
        }
        let layoutTag: AudioChannelLayoutTag
        if let tag = outChannel.layoutTag {
            layoutTag = tag
        } else {
            av_channel_layout_default(&outChannel, Int32(channels))
            if let tag = outChannel.layoutTag {
                layoutTag = tag
            } else {
                av_channel_layout_default(&outChannel, 2)
                layoutTag = outChannel.layoutTag!
            }
        }
        KSLog("[audio] out channelLayout: \(outChannel)")
        var commonFormat: AVAudioCommonFormat
        var interleaved: Bool
        switch sampleFormat {
        case AV_SAMPLE_FMT_S16:
            commonFormat = .pcmFormatInt16
            interleaved = true
        case AV_SAMPLE_FMT_S32:
            commonFormat = .pcmFormatInt32
            interleaved = true
        case AV_SAMPLE_FMT_FLT:
            commonFormat = .pcmFormatFloat32
            interleaved = true
        case AV_SAMPLE_FMT_DBL:
            commonFormat = .pcmFormatFloat64
            interleaved = true
        case AV_SAMPLE_FMT_S16P:
            commonFormat = .pcmFormatInt16
            interleaved = false
        case AV_SAMPLE_FMT_S32P:
            commonFormat = .pcmFormatInt32
            interleaved = false
        case AV_SAMPLE_FMT_FLTP:
            commonFormat = .pcmFormatFloat32
            interleaved = false
        case AV_SAMPLE_FMT_DBLP:
            commonFormat = .pcmFormatFloat64
            interleaved = false
        default:
            commonFormat = .pcmFormatFloat32
            interleaved = false
        }
        interleaved = isUseAudioRenderer
        if !interleaved {
            commonFormat = .pcmFormatFloat32
        }
        audioFormat = AVAudioFormat(commonFormat: commonFormat, sampleRate: Double(sampleRate), interleaved: interleaved, channelLayout: AVAudioChannelLayout(layoutTag: layoutTag)!)
//        AVAudioChannelLayout(layout: outChannel.layoutTag.channelLayout)
    }

    public func setAudioSession(isUseAudioRenderer: Bool) {
        #if os(macOS)
        let channels = AVAudioChannelCount(2)
        #else
        let channels = KSOptions.outputNumberOfChannels(channels: channels, isUseAudioRenderer: isUseAudioRenderer)
        #endif
        audioFormat(channels: channels, isUseAudioRenderer: isUseAudioRenderer)
    }
}
