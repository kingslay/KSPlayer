//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import CoreVideo
import ffmpeg
import Foundation

final class VideoPlayerItemTrack: FFPlayerItemTrack<VideoVTBFrame>, PixelFormat {
    var pixelFormatType: OSType = KSDefaultParameter.bufferPixelFormatType
    private var pool: CVPixelBufferPool?
    private var imgConvertCtx: OpaquePointer?
    private var dstFrame: UnsafeMutablePointer<AVFrame>?
    private lazy var width = codecpar.pointee.width
    private lazy var height = codecpar.pointee.height
    private lazy var aspectRatio = codecpar.pointee.aspectRatio
    override func open() -> Bool {
        guard super.open(), codecpar.pointee.format != AV_PIX_FMT_NONE.rawValue else {
            return false
        }
        var convert = false
        if pixelFormatType == kCVPixelFormatType_32BGRA {
            convert = codecpar.pointee.format != AV_PIX_FMT_BGRA.rawValue
        } else {
            convert = codecpar.pointee.format != AV_PIX_FMT_NV12.rawValue
            //                    && codecpar.pointee.format != AV_PIX_FMT_YUV420P.rawValue
        }
        if convert {
            let dstFormat = pixelFormatType == kCVPixelFormatType_32BGRA ? AV_PIX_FMT_BGRA : AV_PIX_FMT_NV12
            imgConvertCtx = sws_getContext(width, height, AVPixelFormat(rawValue: codecpar.pointee.format), width, height, dstFormat, SWS_BICUBIC, nil, nil, nil)
            dstFrame = av_frame_alloc()
            guard imgConvertCtx != nil, let dstFrame = dstFrame else {
                return false
            }
            dstFrame.pointee.width = width
            dstFrame.pointee.height = height
            dstFrame.pointee.format = dstFormat.rawValue
            av_image_alloc(&dstFrame.pointee.data.0, &dstFrame.pointee.linesize.0, width, height, AVPixelFormat(rawValue: dstFrame.pointee.format), 64)
            pool = create(bytesPerRowAlignment: dstFrame.pointee.linesize.0)
            if pool == nil {
                return false
            }
        }
        return true
    }

    override func fetchReuseFrame() -> (VideoVTBFrame, Int32) {
        let frame = VideoVTBFrame()
        frame.timebase = timebase
        let result = avcodec_receive_frame(codecContext, coreFrame)
        if result == 0, let coreFrame = coreFrame {
            let convertFrame = swsConvert(frame: coreFrame.pointee)
            if pool == nil || convertFrame.width != width || convertFrame.height != height {
                width = convertFrame.width
                height = convertFrame.height
                if let pool = pool {
                    CVPixelBufferPoolFlush(pool, CVPixelBufferPoolFlushFlags(rawValue: 0))
                }
                pool = create(bytesPerRowAlignment: convertFrame.linesize.0)
            }
            if let pool = pool {
                frame.corePixelBuffer = pool.getPixelBuffer(fromFrame: convertFrame)
                if let buffer = frame.corePixelBuffer, let aspectRatio = aspectRatio {
                    CVBufferSetAttachment(buffer, kCVImageBufferPixelAspectRatioKey, aspectRatio, .shouldPropagate)
                }
                frame.position = coreFrame.pointee.best_effort_timestamp
                if frame.position == Int64.min || frame.position < 0 {
                    frame.position = max(coreFrame.pointee.pkt_dts, 0)
                }
                frame.duration = coreFrame.pointee.pkt_duration
                frame.size = Int64(coreFrame.pointee.pkt_size)
                frame.timebase = timebase
            }
        } else if IS_AVERROR_EOF(result) {
            avcodec_flush_buffers(codecContext)
        }
        return (frame, result)
    }

    override func shutdown() {
        super.shutdown()
        if let pool = pool {
            CVPixelBufferPoolFlush(pool, CVPixelBufferPoolFlushFlags(rawValue: 0))
        }
        pool = nil
        if let imgConvertCtx = imgConvertCtx {
            sws_freeContext(imgConvertCtx)
        }
        imgConvertCtx = nil
        av_frame_free(&dstFrame)
        dstFrame = nil
    }

    private func swsConvert(frame: AVFrame) -> AVFrame {
        guard let dstFrame = dstFrame, codecpar.pointee.format == frame.format else {
            return frame
        }
        let sourceData = Array(tuple: frame.data).map { UnsafePointer<UInt8>($0) }
        let result = sws_scale(imgConvertCtx, sourceData, Array(tuple: frame.linesize), 0, frame.height, &dstFrame.pointee.data.0, &dstFrame.pointee.linesize.0)
        if result > 0 {
            dstFrame.pointee.best_effort_timestamp = frame.best_effort_timestamp
            dstFrame.pointee.pkt_duration = frame.pkt_duration
            dstFrame.pointee.pkt_size = frame.pkt_size
            return dstFrame.pointee
        } else {
            return frame
        }
    }

    private func create(bytesPerRowAlignment: Int32) -> CVPixelBufferPool? {
        let sourcePixelBufferOptions: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferBytesPerRowAlignmentKey: bytesPerRowAlignment,
        ]
        return .create(sourcePixelBufferOptions: sourcePixelBufferOptions, bufferCount: outputRenderQueue.maxCount)
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

extension CVPixelBufferPool {
    static func create(sourcePixelBufferOptions: NSMutableDictionary, bufferCount: Int = 24) -> CVPixelBufferPool? {
        var outputPool: CVPixelBufferPool?
        sourcePixelBufferOptions[kCVPixelBufferIOSurfacePropertiesKey] = NSDictionary()
        let pixelBufferPoolOptions: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: bufferCount]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferPoolOptions, sourcePixelBufferOptions, &outputPool)
        return outputPool
    }

    func getPixelBuffer(fromFrame frame: AVFrame) -> CVPixelBuffer? {
        var pbuf: CVPixelBuffer?
        let ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self, &pbuf)
        //    let dic = [kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        //               kCVPixelBufferBytesPerRowAlignmentKey: frame.linesize.0] as NSDictionary
        //    let ret = CVPixelBufferCreate(kCFAllocatorDefault, Int(frame.width), Int(frame.height), KSDefaultParameter.bufferPixelFormatType, dic, &pbuf)
        if let pbuf = pbuf, ret == kCVReturnSuccess {
            CVPixelBufferLockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
            var base = pbuf.baseAddressOfPlane(at: 0)
            base?.copyMemory(from: frame.data.0!, byteCount: Int(frame.linesize.0 * frame.height))
            if pbuf.isPlanar {
                base = pbuf.baseAddressOfPlane(at: 1)
                if frame.format == AV_PIX_FMT_NV12.rawValue {
                    base?.copyMemory(from: frame.data.1!, byteCount: Int(frame.linesize.1 * frame.height / 2))
                } else if frame.format == AV_PIX_FMT_YUV420P.rawValue {
                    let dstPlaneSize = Int(frame.linesize.1 * frame.height / 2)
                    for index in 0 ..< dstPlaneSize {
                        base?.storeBytes(of: frame.data.1![index], toByteOffset: 2 * index, as: UInt8.self)
                        base?.storeBytes(of: frame.data.2![index], toByteOffset: 2 * index + 1, as: UInt8.self)
                    }
                } else if frame.format == AV_PIX_FMT_YUV444P.rawValue {
                    let width = Int(frame.linesize.1 / 2)
                    let height = Int(frame.height / 2)
                    for i in 0 ..< height {
                        for j in 0 ..< width {
                            let index = i * width * 2 + 2 * j
                            let index1 = 2 * i * width * 2 + 2 * j
                            let index2 = index1 + 1
                            let index3 = index1 + width * 2
                            let index4 = index3 + 1
                            var data1 = UInt16(frame.data.1![index1])
                            var data2 = UInt16(frame.data.1![index2])
                            var data3 = UInt16(frame.data.1![index3])
                            var data4 = UInt16(frame.data.1![index4])
                            base?.storeBytes(of: UInt8((data1 + data2 + data3 + data4) / 4), toByteOffset: index, as: UInt8.self)
                            data1 = UInt16(frame.data.2![index1])
                            data2 = UInt16(frame.data.2![index2])
                            data3 = UInt16(frame.data.2![index3])
                            data4 = UInt16(frame.data.2![index4])
                            base?.storeBytes(of: UInt8((data1 + data2 + data3 + data4) / 4), toByteOffset: index + 1, as: UInt8.self)
                        }
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(pbuf, CVPixelBufferLockFlags(rawValue: 0))
        }
        return pbuf
    }
}

extension CVPixelBuffer {
    var drawableSize: CGSize {
        // Check if the pixel buffer exists
        if let ratio = CVBufferGetAttachment(self, kCVImageBufferPixelAspectRatioKey, nil)?.takeUnretainedValue() as? NSDictionary,
            let horizontal = (ratio[kCVImageBufferPixelAspectRatioHorizontalSpacingKey] as? NSNumber)?.intValue,
            let vertical = (ratio[kCVImageBufferPixelAspectRatioVerticalSpacingKey] as? NSNumber)?.intValue,
            horizontal > 0, vertical > 0, horizontal != vertical {
            return CGSize(width: width, height: height * vertical / horizontal)
        } else {
            return size
        }
    }

    var width: Int {
        return CVPixelBufferGetWidth(self)
    }

    var height: Int {
        return CVPixelBufferGetHeight(self)
    }

    var size: CGSize {
        return CGSize(width: width, height: height)
    }

    var isPlanar: Bool {
        return CVPixelBufferIsPlanar(self)
    }

    var planeCount: Int {
        return CVPixelBufferGetPlaneCount(self)
    }

    func widthOfPlane(at planeIndex: Int) -> Int {
        return CVPixelBufferGetWidthOfPlane(self, planeIndex)
    }

    func heightOfPlane(at planeIndex: Int) -> Int {
        return CVPixelBufferGetHeightOfPlane(self, planeIndex)
    }

    func baseAddressOfPlane(at planeIndex: Int) -> UnsafeMutableRawPointer? {
        return CVPixelBufferGetBaseAddressOfPlane(self, planeIndex)
    }
}
