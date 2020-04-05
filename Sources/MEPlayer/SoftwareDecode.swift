//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import ffmpeg
import Foundation

class SoftwareDecode: DecodeProtocol {
    private let assetTrack: TrackProtocol
    private let options: KSOptions
    // 第一次seek不要调用avcodec_flush_buffers。否则seek完之后可能会因为不是关键帧而导致蓝屏
    private var firstSeek = true
    private var coreFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var bestEffortTimestamp = Int64(0)
    private let swresample: Swresample
    required init(assetTrack: TrackProtocol, options: KSOptions) {
        self.assetTrack = assetTrack
        self.options = options
        codecContext = assetTrack.stream.pointee.codecpar.ceateContext(options: options)
        codecContext?.pointee.time_base = assetTrack.timebase.rational
        if assetTrack.mediaType == .video {
            swresample = VideoSwresample(dstFormat: options.bufferPixelFormatType.format)
        } else {
            swresample = AudioSwresample()
        }
    }

    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws -> [Frame] {
        guard let codecContext = codecContext else {
            return []
        }
        let result = avcodec_send_packet(codecContext, packet)
        guard result == 0 else {
            return []
        }
        var array = [Frame]()
        while true {
            do {
                let result = avcodec_receive_frame(codecContext, coreFrame)
                if result == 0, let avframe = coreFrame {
                    let timestamp = avframe.pointee.best_effort_timestamp
                    if timestamp >= bestEffortTimestamp {
                        bestEffortTimestamp = timestamp
                    } else {
                    }
                    let frame = swresample.transfer(avframe: avframe, timebase: assetTrack.timebase)
                    if frame.position < 0 {
                        frame.position = bestEffortTimestamp
                    }
                    bestEffortTimestamp += frame.duration
                    array.append(frame)
                } else {
                    throw result
                }
            } catch let code as Int32 {
                if code == 0 || AVFILTER_EOF(code) {
                    if IS_AVERROR_EOF(code) {
                        avcodec_flush_buffers(codecContext)
                    }
                    break
                } else {
                    let error = NSError(result: code, errorCode: assetTrack.mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame)
                    KSLog(error)
                    throw error
                }
            } catch {}
        }
        return array
    }

    func doFlushCodec() {
        if firstSeek {
            firstSeek = false
        } else {
            avcodec_flush_buffers(codecContext)
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
        avcodec_flush_buffers(codecContext)
    }

    deinit {
        swresample.shutdown()
    }
}

extension UnsafeMutablePointer where Pointee == AVCodecParameters {
    func ceateContext(options: KSOptions) -> UnsafeMutablePointer<AVCodecContext>? {
        var codecContextOption = avcodec_alloc_context3(nil)
        guard let codecContext = codecContextOption else {
            return nil
        }
        var result = avcodec_parameters_to_context(codecContext, self)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            return nil
        }
        if options.canHardwareDecode(codecpar: pointee) {
            codecContext.pointee.opaque = Unmanaged.passUnretained(options).toOpaque()
            codecContext.pointee.get_format = { ctx, fmt -> AVPixelFormat in

                guard let fmt = fmt, let ctx = ctx else {
                    return AV_PIX_FMT_NONE
                }
                let options = Unmanaged<KSOptions>.fromOpaque(ctx.pointee.opaque).takeUnretainedValue()
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
                            // swiftlint:disable force_cast
                            let framesCtxData = framesCtx.pointee.data as! UnsafeMutablePointer<AVHWFramesContext>
                            // swiftlint:enable force_cast
                            framesCtxData.pointee.format = AV_PIX_FMT_VIDEOTOOLBOX
                            framesCtxData.pointee.sw_format = options.bufferPixelFormatType.format
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
        guard let codec = avcodec_find_decoder(codecContext.pointee.codec_id) else {
            avcodec_free_context(&codecContextOption)
            return nil
        }
        codecContext.pointee.codec_id = codec.pointee.id
        var avOptions = options.decoderOptions.avOptions
        result = avcodec_open2(codecContext, codec, &avOptions)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            return nil
        }
        return codecContext
    }
}
