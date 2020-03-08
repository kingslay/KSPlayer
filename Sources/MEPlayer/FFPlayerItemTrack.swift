//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import ffmpeg
import Foundation

class FFPlayerItemTrack: AsyncPlayerItemTrack<Frame> {
    // 第一次seek不要调用avcodec_flush_buffers。否则seek完之后可能会因为不是关键帧而导致蓝屏
    private var firstSeek = true
    private var coreFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    private var codecContextMap = [Int32: UnsafeMutablePointer<AVCodecContext>?]()
    private var bestEffortTimestamp = Int64(0)
    private let swresample: Swresample

    required init(track: TrackProtocol, options: KSOptions) {
        if track.mediaType == .video {
            swresample = VideoSwresample(dstFormat: options.bufferPixelFormatType.format)
        } else {
            swresample = AudioSwresample()
        }
        super.init(track: track, options: options)
    }

    override func shutdown() {
        super.shutdown()
        av_frame_free(&coreFrame)
        codecContextMap.values.forEach { codecContext in
            var content = codecContext
            avcodec_free_context(&content)
        }
        codecContextMap.removeAll()
    }

    override func doFlushCodec() {
        super.doFlushCodec()
        if firstSeek {
            firstSeek = false
        } else {
            codecContextMap.values.forEach { codecContext in
                avcodec_flush_buffers(codecContext)
            }
        }
    }

    override func doDecode(packet: Packet) throws -> [Frame] {
        if codecContextMap.index(forKey: track.streamIndex) == nil {
            let codecContext = codecpar.ceateContext(options: options)
            codecContext?.pointee.time_base = track.timebase.rational
            codecContextMap[track.streamIndex] = codecContext
        }
        guard let codecContext = codecContextMap[track.streamIndex], codecContext != nil else {
            return []
        }
        let result = avcodec_send_packet(codecContext, packet.corePacket)
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
                    } else if codecContextMap.keys.count > 1 {
                        // m3u8多路流需要丢帧
                        throw Int32(0)
                    }
                    let frame = swresample.transfer(avframe: avframe, timebase: track.timebase)
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
                    let error = NSError(result: code, errorCode: track.mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame)
                    KSLog(error)
                    throw error
                }
            } catch {}
        }
        return array
    }

    override func seek(time: TimeInterval) {
        super.seek(time: time)
        bestEffortTimestamp = Int64(0)
    }

    override func decode() {
        super.decode()
        bestEffortTimestamp = Int64(0)
        codecContextMap.values.forEach { codecContext in
            avcodec_flush_buffers(codecContext)
        }
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
        if options.canHardwareDecode(codecpar: self.pointee) {
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
