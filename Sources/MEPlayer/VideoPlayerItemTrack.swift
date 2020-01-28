//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import CoreVideo
import ffmpeg
import Foundation
import VideoToolbox

final class VideoPlayerItemTrack: FFPlayerItemTrack<VideoVTBFrame> {
    private var scale: SWScale?
    private lazy var width = codecpar.pointee.width
    private lazy var height = codecpar.pointee.height
    private lazy var aspectRatio = codecpar.pointee.aspectRatio
    override func open() -> Bool {
        guard super.open(), codecpar.pointee.format != AV_PIX_FMT_NONE.rawValue else {
            return false
        }
        let format = AVPixelFormat(rawValue: codecpar.pointee.format)
        if !PixelBuffer.isSupported(format: format) {
            scale = SWScale(width: width, height: height, format: format)
            if scale == nil {
                return false
            }
        }
        PixelBufferConverter.share.bufferCount = outputRenderQueue.maxCount
        return true
    }

    override func fetchReuseFrame() throws -> VideoVTBFrame {
        let result = avcodec_receive_frame(codecContext, coreFrame)
        if result == 0, let coreFrame = coreFrame {
            scale?.swsConvert(frame: coreFrame)
            let frame = VideoVTBFrame()
            frame.timebase = timebase
            frame.corePixelBuffer = PixelBuffer(frame: coreFrame, aspectRatio: aspectRatio)
            frame.position = coreFrame.pointee.best_effort_timestamp
            if frame.position == Int64.min || frame.position < 0 {
                frame.position = max(coreFrame.pointee.pkt_dts, 0)
            }
            frame.duration = coreFrame.pointee.pkt_duration
            frame.size = Int64(coreFrame.pointee.pkt_size)
            frame.timebase = timebase
            return frame
        }
        throw result
    }

    override func shutdown() {
        super.shutdown()
        PixelBufferConverter.share.shutdown()
        scale?.shutdown()
    }
}

extension AVCodecParameters {
    var aspectRatio: NSDictionary? {
        let den = sample_aspect_ratio.den
        let num = sample_aspect_ratio.num
        if den > 0, num > 0, den != num {
            return [kCVImageBufferPixelAspectRatioHorizontalSpacingKey: num,
                    kCVImageBufferPixelAspectRatioVerticalSpacingKey: den] as NSDictionary
        } else {
            return nil
        }
    }
}

extension AVPixelFormat {
    var format: OSType {
        switch self {
        case AV_PIX_FMT_MONOBLACK: return kCVPixelFormatType_1Monochrome
        case AV_PIX_FMT_RGB555BE: return kCVPixelFormatType_16BE555
        case AV_PIX_FMT_RGB555LE: return kCVPixelFormatType_16LE555
        case AV_PIX_FMT_RGB565BE: return kCVPixelFormatType_16BE565
        case AV_PIX_FMT_RGB565LE: return kCVPixelFormatType_16LE565
        case AV_PIX_FMT_RGB24: return kCVPixelFormatType_24RGB
        case AV_PIX_FMT_BGR24: return kCVPixelFormatType_24BGR
        case AV_PIX_FMT_0RGB: return kCVPixelFormatType_32ARGB
        case AV_PIX_FMT_BGR0: return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_0BGR: return kCVPixelFormatType_32ABGR
        case AV_PIX_FMT_RGB0: return kCVPixelFormatType_32RGBA
        case AV_PIX_FMT_BGRA: return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_BGR48BE: return kCVPixelFormatType_48RGB
        case AV_PIX_FMT_UYVY422: return kCVPixelFormatType_422YpCbCr8
        case AV_PIX_FMT_YUVA444P: return kCVPixelFormatType_4444YpCbCrA8R
        case AV_PIX_FMT_YUVA444P16LE: return kCVPixelFormatType_4444AYpCbCr16
        case AV_PIX_FMT_YUV444P: return kCVPixelFormatType_444YpCbCr8
//        case AV_PIX_FMT_YUV422P16: return kCVPixelFormatType_422YpCbCr16
//        case AV_PIX_FMT_YUV422P10: return kCVPixelFormatType_422YpCbCr10
//        case AV_PIX_FMT_YUV444P10: return kCVPixelFormatType_444YpCbCr10
        case AV_PIX_FMT_YUV420P: return kCVPixelFormatType_420YpCbCr8Planar
        case AV_PIX_FMT_NV12: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case AV_PIX_FMT_YUYV422: return kCVPixelFormatType_422YpCbCr8_yuvs
        case AV_PIX_FMT_GRAY8: return kCVPixelFormatType_OneComponent8
        default:
            return 0
        }
    }
}

extension OSType {
    var format: AVPixelFormat {
        switch self {
        case kCVPixelFormatType_32ARGB: return AV_PIX_FMT_ARGB
        case kCVPixelFormatType_32BGRA: return AV_PIX_FMT_BGRA
        case kCVPixelFormatType_24RGB: return AV_PIX_FMT_RGB24
        case kCVPixelFormatType_16BE555: return AV_PIX_FMT_RGB555BE
        case kCVPixelFormatType_16BE565: return AV_PIX_FMT_RGB565BE
        case kCVPixelFormatType_16LE555: return AV_PIX_FMT_RGB555LE
        case kCVPixelFormatType_16LE565: return AV_PIX_FMT_RGB565LE
        case kCVPixelFormatType_422YpCbCr8: return AV_PIX_FMT_UYVY422
        case kCVPixelFormatType_422YpCbCr8_yuvs: return AV_PIX_FMT_YUYV422
        case kCVPixelFormatType_444YpCbCr8: return AV_PIX_FMT_YUV444P
        case kCVPixelFormatType_4444YpCbCrA8: return AV_PIX_FMT_YUV444P16LE
        case kCVPixelFormatType_422YpCbCr16: return AV_PIX_FMT_YUV422P16LE
        case kCVPixelFormatType_422YpCbCr10: return AV_PIX_FMT_YUV422P10LE
        case kCVPixelFormatType_444YpCbCr10: return AV_PIX_FMT_YUV444P10LE
        case kCVPixelFormatType_420YpCbCr8Planar: return AV_PIX_FMT_YUV420P
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: return AV_PIX_FMT_NV12
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: return AV_PIX_FMT_NV12
        case kCVPixelFormatType_422YpCbCr8_yuvs: return AV_PIX_FMT_YUYV422
        default:
            return AV_PIX_FMT_NONE
        }
    }
}

extension CVPixelBufferPool {
    func getPixelBuffer(fromFrame frame: AVFrame) -> CVPixelBuffer? {
        var pbuf: CVPixelBuffer?
        let ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self, &pbuf)
//        let dic = [kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
//                       kCVPixelBufferBytesPerRowAlignmentKey: frame.linesize.0] as NSDictionary
//        let ret = CVPixelBufferCreate(kCFAllocatorDefault, Int(frame.width), Int(frame.height), AVPixelFormat(rawValue: frame.format).format, dic, &pbuf)
        if let pbuf = pbuf, ret == kCVReturnSuccess {
            CVPixelBufferLockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
            let data = Array(tuple: frame.data)
            let linesize = Array(tuple: frame.linesize)
            let heights = [frame.height, frame.height / 2, frame.height / 2]
            for i in 0 ..< pbuf.planeCount {
                let perRow = Int(linesize[i])
                pbuf.baseAddressOfPlane(at: i)?.copyMemory(from: data[i]!, byteCount: Int(heights[i]) * perRow)
            }
            CVPixelBufferUnlockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
        }
        return pbuf
    }
}
