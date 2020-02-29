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
    private var coreFrame: UnsafeMutablePointer<AVFrame>?
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

    override func open() -> Bool {
        if let coreFrame = av_frame_alloc() {
            self.coreFrame = coreFrame
            return super.open()
        }
        return false
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
                        //m3u8多路流需要丢帧
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
