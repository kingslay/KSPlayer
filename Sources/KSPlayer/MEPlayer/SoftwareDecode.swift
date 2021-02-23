//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Libavcodec
import FFmpeg
import Foundation

class SoftwareDecode: DecodeProtocol {
    private let mediaType: AVFoundation.AVMediaType
    private let timebase: Timebase
    private let options: KSOptions
    // 第一次seek不要调用avcodec_flush_buffers。否则seek完之后可能会因为不是关键帧而导致蓝屏
    private var firstSeek = true
    private var coreFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var bestEffortTimestamp = Int64(0)
    private let swresample: Swresample
    required init(assetTrack: TrackProtocol, options: KSOptions) {
        timebase = assetTrack.timebase
        mediaType = assetTrack.mediaType
        self.options = options
        do {
            codecContext = try assetTrack.stream.pointee.codecpar.ceateContext(options: options)
        } catch {
            KSLog(error as CustomStringConvertible)
        }
        codecContext?.pointee.time_base = timebase.rational
        if mediaType == .video {
            swresample = VideoSwresample()
        } else {
            swresample = AudioSwresample()
        }
    }

    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws -> [MEFrame] {
        guard let codecContext = codecContext, avcodec_send_packet(codecContext, packet) == 0 else {
            return []
        }
        var array = [MEFrame]()
        while true {
            let result = avcodec_receive_frame(codecContext, coreFrame)
            if result == 0, let avframe = coreFrame {
                let timestamp = max(avframe.pointee.best_effort_timestamp, avframe.pointee.pts, avframe.pointee.pkt_dts)
                if timestamp >= bestEffortTimestamp {
                    bestEffortTimestamp = timestamp
                }
                var frame = swresample.transfer(avframe: avframe, timebase: timebase)
                frame.position = bestEffortTimestamp
                bestEffortTimestamp += frame.duration
                array.append(frame)
            } else {
                if AVFILTER_EOF(result) {
                    if IS_AVERROR_EOF(result) {
                        avcodec_flush_buffers(codecContext)
                    }
                    break
                } else {
                    let error = NSError(errorCode: mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame, ffmpegErrnum: result)
                    KSLog(error)
                    throw error
                }
            }
        }
        return array
    }

    func doFlushCodec() {
        if firstSeek {
            firstSeek = false
        } else {
            if codecContext != nil {
                avcodec_flush_buffers(codecContext)
            }
        }
    }

    func shutdown() {
        av_frame_free(&coreFrame)
        avcodec_free_context(&codecContext)
    }

    func seek(time _: TimeInterval) {
        bestEffortTimestamp = Int64(0)
    }

    func decode() {
        bestEffortTimestamp = Int64(0)
        if codecContext != nil {
            avcodec_flush_buffers(codecContext)
        }
    }

    deinit {
        swresample.shutdown()
    }
}

extension UnsafeMutablePointer where Pointee == AVCodecParameters {
    func ceateContext(options: KSOptions) throws -> UnsafeMutablePointer<AVCodecContext> {
        var codecContextOption = avcodec_alloc_context3(nil)
        guard let codecContext = codecContextOption else {
            throw NSError(errorCode: .codecContextCreate)
        }
        var result = avcodec_parameters_to_context(codecContext, self)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codecContextSetParam, ffmpegErrnum: result)
        }
//        if options.canHardwareDecode(codecpar: pointee) {
//            codecContext.getFormat()
//        }
        guard let codec = avcodec_find_decoder(codecContext.pointee.codec_id) else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codecContextFindDecoder, ffmpegErrnum: result)
        }
        codecContext.pointee.codec_id = codec.pointee.id
        codecContext.pointee.flags2 |= AV_CODEC_FLAG2_FAST
        var lowres = options.lowres
        if lowres > codec.pointee.max_lowres {
            lowres = codec.pointee.max_lowres
        }
        codecContext.pointee.lowres = Int32(lowres)
        var avOptions = options.decoderOptions.avOptions
        if lowres > 0 {
            av_dict_set_int(&avOptions, "lowres", Int64(lowres), 0)
        }
        result = avcodec_open2(codecContext, codec, &avOptions)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            throw NSError(errorCode: .codesContextOpen, ffmpegErrnum: result)
        }
        return codecContext
    }
}

extension UnsafeMutablePointer where Pointee == AVCodecContext {
    func getFormat() {
        pointee.get_format = { ctx, fmt -> AVPixelFormat in
            guard let fmt = fmt, let ctx = ctx else {
                return AV_PIX_FMT_NONE
            }
            var i = 0
            while fmt[i] != AV_PIX_FMT_NONE {
                if fmt[i] == AV_PIX_FMT_VIDEOTOOLBOX {
                    var deviceCtx = av_hwdevice_ctx_alloc(AV_HWDEVICE_TYPE_VIDEOTOOLBOX)
                    if deviceCtx == nil {
                        break
                    }
                    av_buffer_unref(&deviceCtx)
                    var framesCtx = av_hwframe_ctx_alloc(deviceCtx)
                    if let framesCtx = framesCtx {
                        let framesCtxData = UnsafeMutableRawPointer(framesCtx.pointee.data)
                            .bindMemory(to: AVHWFramesContext.self, capacity: 1)
                        framesCtxData.pointee.format = AV_PIX_FMT_VIDEOTOOLBOX
                        framesCtxData.pointee.sw_format = ctx.pointee.pix_fmt.bestPixelFormat()
                        framesCtxData.pointee.width = ctx.pointee.width
                        framesCtxData.pointee.height = ctx.pointee.height
                    }
                    if av_hwframe_ctx_init(framesCtx) != 0 {
                        av_buffer_unref(&framesCtx)
                        break
                    }
                    ctx.pointee.hw_frames_ctx = framesCtx
                    return fmt[i]
                }
                i += 1
            }
            return fmt[0]
        }
    }
}
