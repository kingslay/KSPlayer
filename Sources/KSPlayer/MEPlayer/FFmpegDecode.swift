//
//  VideoPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Foundation
import Libavcodec

class FFmpegDecode: DecodeProtocol {
    private weak var delegate: DecodeResultDelegate?
    private let options: KSOptions
    // 第一次seek不要调用avcodec_flush_buffers。否则seek完之后可能会因为不是关键帧而导致蓝屏
    private var firstSeek = true
    private var coreFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var bestEffortTimestamp = Int64(0)
    private let swresample: Swresample
    private let filter: MEFilter
    required init(assetTrack: FFmpegAssetTrack, options: KSOptions, delegate: DecodeResultDelegate) {
        self.delegate = delegate
        self.options = options
        var codecpar = assetTrack.stream.pointee.codecpar.pointee
        do {
            codecContext = try codecpar.ceateContext(options: options)
        } catch {
            KSLog(error as CustomStringConvertible)
        }
        codecContext?.pointee.time_base = assetTrack.timebase.rational
        filter = MEFilter(timebase: assetTrack.timebase, isAudio: assetTrack.mediaType == .audio, options: options)
        if assetTrack.mediaType == .video {
            swresample = VideoSwresample()
        } else {
            swresample = AudioSwresample(codecpar: codecpar)
        }
    }

    func doDecode(packet: Packet) throws {
        guard let codecContext, avcodec_send_packet(codecContext, packet.corePacket) == 0 else {
            delegate?.decodeResult(frame: nil)
            return
        }
        while true {
            let result = avcodec_receive_frame(codecContext, coreFrame)
            if result == 0, let avframe = coreFrame {
                var frame = try swresample.transfer(avframe: filter.filter(options: options, inputFrame: avframe, hwFramesCtx: codecContext.pointee.hw_frames_ctx))
                frame.timebase = packet.assetTrack.timebase
//                frame.timebase = Timebase(avframe.pointee.time_base)
                frame.duration = avframe.pointee.pkt_duration
                frame.size = Int64(avframe.pointee.pkt_size)
                if packet.assetTrack.mediaType == .audio {
                    bestEffortTimestamp = max(bestEffortTimestamp, avframe.pointee.pts)
                    frame.position = bestEffortTimestamp
                    if frame.duration == 0 {
                        frame.duration = Int64(avframe.pointee.nb_samples) * Int64(frame.timebase.den) / (Int64(avframe.pointee.sample_rate) * Int64(frame.timebase.num))
                    }
                    bestEffortTimestamp += frame.duration
                } else {
                    var position = avframe.pointee.best_effort_timestamp
                    if position < 0 {
                        position = avframe.pointee.pkt_dts
                    }
                    if position < 0 {
                        position = bestEffortTimestamp
                    }
                    frame.position = position
                    bestEffortTimestamp += frame.duration
                }
                delegate?.decodeResult(frame: frame)
            } else {
                if result == AVError.eof.code {
                    avcodec_flush_buffers(codecContext)
                    break
                } else if result == AVError.tryAgain.code {
                    break
                } else {
                    let error = NSError(errorCode: packet.assetTrack.mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame, ffmpegErrnum: result)
                    KSLog(error)
                    throw error
                }
            }
        }
    }

    func doFlushCodec() {
        bestEffortTimestamp = Int64(0)
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
        swresample.shutdown()
    }

    func decode() {
        bestEffortTimestamp = Int64(0)
        if codecContext != nil {
            avcodec_flush_buffers(codecContext)
        }
    }
}
