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
    var coreFrame: UnsafeMutablePointer<AVFrame>?
    var codecContext: UnsafeMutablePointer<AVCodecContext>? {
        didSet {
            codecContext?.pointee.time_base = timebase.rational
        }
    }

    override func shutdown() {
        super.shutdown()
        if let codecContext = self.codecContext {
            avcodec_close(codecContext)
            avcodec_free_context(&self.codecContext)
            self.codecContext = nil
        }
        av_frame_free(&coreFrame)
        coreFrame = nil
    }

    override func open() -> Bool {
        if let coreFrame = av_frame_alloc(), let codecContext = codecpar.ceateContext() {
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

    override func doDecode(packet: Packet) -> Result<[Frame], NSError> {
        let result = avcodec_send_packet(codecContext, packet.corePacket)
        guard result == 0 else {
            return .success([])
        }
        var array = [Frame]()
        while true {
            do {
                array.append(try fetchReuseFrame().get())
            } catch let code as Int32 {
                if code == 0 || AVFILTER_EOF(code) {
                    if IS_AVERROR_EOF(code) {
                        avcodec_flush_buffers(codecContext)
                    }
                    break
                } else {
                    let error = NSError(result: code, errorCode: mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame)
                    KSLog(error)
                    return .failure(error)
                }
            } catch {}
        }
        return .success(array)
    }

    func fetchReuseFrame() -> Result<Frame, Int32> {
        fatalError("Abstract method")
    }
}

extension UnsafeMutablePointer where Pointee == AVCodecParameters {
    func ceateContext() -> UnsafeMutablePointer<AVCodecContext>? {
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
        result = avcodec_open2(codecContext, codec, nil)
        guard result == 0 else {
            avcodec_free_context(&codecContextOption)
            return nil
        }
        return codecContext
    }
}
