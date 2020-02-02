//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import ffmpeg
import Foundation
class FFPlayerItemTrack<Frame: MEFrame>: AsyncPlayerItemTrack<Frame> {
    // 第一次seek不要调用avcodec_flush_buffers。否则seek完之后可能会因为不是关键帧而导致蓝屏
    private var firstSeek = true
    private(set) var coreFrame: UnsafeMutablePointer<AVFrame>?
    private(set) var codecContext: UnsafeMutablePointer<AVCodecContext>? {
        didSet {
            codecContext?.pointee.time_base = timebase.rational
        }
    }

    override func shutdown() {
        super.shutdown()
        av_frame_free(&coreFrame)
        if let codecContext = codecContext {
            avcodec_close(codecContext)
            avcodec_free_context(&self.codecContext)
        }
    }

    override func open() -> Bool {
        if let codecContext = codecpar.ceateContext(options: options), let coreFrame = av_frame_alloc() {
            self.coreFrame = coreFrame
            self.codecContext = codecContext
            return super.open()
        }
        return false
    }

    override func doFlushCodec() {
        super.doFlushCodec()
        if firstSeek {
            firstSeek = false
        } else {
            if let codecContext = self.codecContext {
                avcodec_flush_buffers(codecContext)
            }
        }
    }

    override func doDecode(packet: Packet) throws -> [Frame] {
        let result = avcodec_send_packet(codecContext, packet.corePacket)
        guard result == 0 else {
            return []
        }
        var array = [Frame]()
        while true {
            do {
                array.append(try fetchReuseFrame())
            } catch let code as Int32 {
                if code == 0 || AVFILTER_EOF(code) {
                    if IS_AVERROR_EOF(code) {
                        avcodec_flush_buffers(codecContext)
                    }
                    break
                } else {
                    let error = NSError(result: code, errorCode: mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame)
                    KSLog(error)
                    throw error
                }
            } catch {}
        }
        return array
    }

    func fetchReuseFrame() throws -> Frame {
        fatalError("Abstract method")
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
        guard let codec = avcodec_find_decoder(codecContext.pointee.codec_id) else {
            avcodec_free_context(&codecContextOption)
            return nil
        }
        codecContext.pointee.codec_id = codec.pointee.id
        var avOptions = options.decoderOptions.avOptions
        if options.threadsAuto, av_dict_get(avOptions, "threads", nil, 0) != nil {
            av_dict_set(&avOptions, "threads", "auto", 0)
        }
        if options.refcountedFrames, av_dict_get(avOptions, "refcounted_frames", nil, 0) != nil,
            codecContext.pointee.codec_type == AVMEDIA_TYPE_VIDEO || codecContext.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
            av_dict_set(&avOptions, "refcounted_frames", "1", 0)
        }
        result = avcodec_open2(codecContext, codec, &avOptions)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            return nil
        }
        return codecContext
    }
}
