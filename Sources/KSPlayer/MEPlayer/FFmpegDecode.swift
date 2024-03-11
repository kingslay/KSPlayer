//
//  FFmpegDecode.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Foundation
import Libavcodec

class FFmpegDecode: DecodeProtocol {
    private let options: KSOptions
    private var coreFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var bestEffortTimestamp = Int64(0)
    private let frameChange: FrameChange
    private let filter: MEFilter
    private let seekByBytes: Bool
    required init(assetTrack: FFmpegAssetTrack, options: KSOptions) {
        self.options = options
        seekByBytes = assetTrack.seekByBytes
        do {
            codecContext = try assetTrack.createContext(options: options)
        } catch {
            KSLog(error as CustomStringConvertible)
        }
        codecContext?.pointee.time_base = assetTrack.timebase.rational
        filter = MEFilter(timebase: assetTrack.timebase, isAudio: assetTrack.mediaType == .audio, nominalFrameRate: assetTrack.nominalFrameRate, options: options)
        if assetTrack.mediaType == .video {
            frameChange = VideoSwresample(fps: assetTrack.nominalFrameRate, isDovi: assetTrack.dovi != nil)
        } else {
            frameChange = AudioSwresample(audioDescriptor: assetTrack.audioDescriptor!)
        }
    }

    func decodeFrame(from packet: Packet, completionHandler: @escaping (Result<MEFrame, Error>) -> Void) {
        guard let codecContext, avcodec_send_packet(codecContext, packet.corePacket) == 0 else {
            return
        }
        while true {
            let result = avcodec_receive_frame(codecContext, coreFrame)
            if result == 0, let avframe = coreFrame {
                if packet.assetTrack.mediaType == .video {
                    if Int32(codecContext.pointee.properties) & FF_CODEC_PROPERTY_CLOSED_CAPTIONS > 0, packet.assetTrack.closedCaptionsTrack == nil {
                        var codecpar = AVCodecParameters()
                        codecpar.codec_type = AVMEDIA_TYPE_SUBTITLE
                        codecpar.codec_id = AV_CODEC_ID_EIA_608
                        if let assetTrack = FFmpegAssetTrack(codecpar: codecpar) {
                            assetTrack.name = "Closed Captions"
                            assetTrack.startTime = packet.assetTrack.startTime
                            assetTrack.timebase = packet.assetTrack.timebase
                            let subtitle = SyncPlayerItemTrack<SubtitleFrame>(mediaType: .subtitle, frameCapacity: 255, options: options)
                            assetTrack.subtitle = subtitle
                            packet.assetTrack.closedCaptionsTrack = assetTrack
                            subtitle.decode()
                        }
                    }
                    if let sideData = av_frame_get_side_data(avframe, AV_FRAME_DATA_A53_CC),
                       let closedCaptionsTrack = packet.assetTrack.closedCaptionsTrack,
                       let subtitle = closedCaptionsTrack.subtitle
                    {
                        let closedCaptionsPacket = Packet()
                        if let corePacket = packet.corePacket {
                            closedCaptionsPacket.corePacket?.pointee.pts = corePacket.pointee.pts
                            closedCaptionsPacket.corePacket?.pointee.dts = corePacket.pointee.dts
                            closedCaptionsPacket.corePacket?.pointee.pos = corePacket.pointee.pos
                            closedCaptionsPacket.corePacket?.pointee.time_base = corePacket.pointee.time_base
                            closedCaptionsPacket.corePacket?.pointee.stream_index = corePacket.pointee.stream_index
                        }
                        closedCaptionsPacket.corePacket?.pointee.flags |= AV_PKT_FLAG_KEY
                        closedCaptionsPacket.corePacket?.pointee.size = Int32(sideData.pointee.size)
                        let buffer = av_buffer_ref(sideData.pointee.buf)
                        closedCaptionsPacket.corePacket?.pointee.data = buffer?.pointee.data
                        closedCaptionsPacket.corePacket?.pointee.buf = buffer
                        closedCaptionsPacket.assetTrack = closedCaptionsTrack
                        subtitle.putPacket(packet: closedCaptionsPacket)
                    }
                    if let sideData = av_frame_get_side_data(avframe, AV_FRAME_DATA_SEI_UNREGISTERED) {
                        let size = sideData.pointee.size
                        if size > AV_UUID_LEN {
                            let str = String(cString: sideData.pointee.data.advanced(by: Int(AV_UUID_LEN)))
                            options.sei(string: str)
                        }
                    }
                }
                filter.filter(options: options, inputFrame: avframe) { avframe in
                    do {
                        var frame = try frameChange.change(avframe: avframe)
                        if let videoFrame = frame as? VideoVTBFrame, let pixelBuffer = videoFrame.corePixelBuffer as? PixelBuffer {
                            pixelBuffer.formatDescription = packet.assetTrack.formatDescription
                        }
                        frame.timebase = filter.timebase
                        //                frame.timebase = Timebase(avframe.pointee.time_base)
                        frame.size = packet.size
                        frame.position = packet.position
                        frame.duration = avframe.pointee.duration
                        if frame.duration == 0, avframe.pointee.sample_rate != 0, frame.timebase.num != 0 {
                            frame.duration = Int64(avframe.pointee.nb_samples) * Int64(frame.timebase.den) / (Int64(avframe.pointee.sample_rate) * Int64(frame.timebase.num))
                        }
                        var timestamp = avframe.pointee.best_effort_timestamp
                        if timestamp < 0 {
                            timestamp = avframe.pointee.pts
                        }
                        if timestamp < 0 {
                            timestamp = avframe.pointee.pkt_dts
                        }
                        if timestamp < 0 {
                            timestamp = bestEffortTimestamp
                        }
                        frame.timestamp = timestamp
                        bestEffortTimestamp = timestamp + frame.duration
                        completionHandler(.success(frame))
                    } catch {
                        completionHandler(.failure(error))
                    }
                }
            } else {
                if result == AVError.eof.code {
                    avcodec_flush_buffers(codecContext)
                    break
                } else if result == AVError.tryAgain.code {
                    break
                } else {
                    let error = NSError(errorCode: packet.assetTrack.mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame, avErrorCode: result)
                    KSLog(error)
                    completionHandler(.failure(error))
                }
            }
        }
    }

    func doFlushCodec() {
        bestEffortTimestamp = Int64(0)
        // seek之后要清空下，不然解码可能还会有缓存，导致返回的数据是之前seek的。
        avcodec_flush_buffers(codecContext)
    }

    func shutdown() {
        av_frame_free(&coreFrame)
        avcodec_free_context(&codecContext)
        frameChange.shutdown()
    }

    func decode() {
        bestEffortTimestamp = Int64(0)
        if codecContext != nil {
            avcodec_flush_buffers(codecContext)
        }
    }
}
