//
//  FFStream.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import ffmpeg
import Foundation
typealias SwrContext = OpaquePointer

final class AudioPlayerItemTrack: FFPlayerItemTrack<AudioFrame> {
    private var swrContext: SwrContext?
    private var bestEffortTimestamp = Int64(0)
    private var inputNumberOfChannels = KSDefaultParameter.audioPlayerMaximumChannels
    private var inputSampleRate = KSDefaultParameter.audioPlayerSampleRate
    private var inputFormat = AV_SAMPLE_FMT_FLTP

    override func open() -> Bool {
        if super.open() {
            return setupSwrContext()
        }
        return false
    }

    override func fetchReuseFrame() -> (AudioFrame, Int32) {
        if inputNumberOfChannels != codecpar.pointee.channels || inputFormat.rawValue != codecpar.pointee.format || inputSampleRate != codecpar.pointee.sample_rate {
            destorySwrContext()
            _ = setupSwrContext()
        }
        let frame = AudioFrame()
        frame.timebase = timebase
        let result = avcodec_receive_frame(codecContext, coreFrame)
        if let swrContext = swrContext, result == 0, let coreFrame = coreFrame {
            bestEffortTimestamp = max(coreFrame.pointee.best_effort_timestamp, bestEffortTimestamp)
            frame.position = bestEffortTimestamp
            frame.duration = coreFrame.pointee.pkt_duration
            frame.size = Int64(coreFrame.pointee.pkt_size)
            // 过滤掉不规范的音频
            if codecpar.pointee.channels != coreFrame.pointee.channels || codecpar.pointee.format != coreFrame.pointee.format || codecpar.pointee.sample_rate != coreFrame.pointee.sample_rate {
                return (frame, result)
            }
            var numberOfSamples = coreFrame.pointee.nb_samples
            let nbSamples = swr_get_out_samples(swrContext, numberOfSamples)
            _ = av_samples_get_buffer_size(&frame.bufferSize, KSDefaultParameter.audioPlayerMaximumChannels, nbSamples, AV_SAMPLE_FMT_FLTP, 1)
            var frameBuffer = Array(tuple: coreFrame.pointee.data).map { UnsafePointer<UInt8>($0) }
            numberOfSamples = swr_convert(swrContext, &frame.data, nbSamples, &frameBuffer, numberOfSamples)
            if frame.duration == 0 {
                frame.duration = Int64(numberOfSamples) * Int64(frame.timebase.den) / (Int64(KSDefaultParameter.audioPlayerSampleRate) * Int64(frame.timebase.num))
            }
            let linesize = numberOfSamples * Int32(MemoryLayout<Float>.size)
            for i in 0 ..< Int(KSDefaultParameter.audioPlayerMaximumChannels) {
                frame.linesize[i] = linesize
            }
        } else if IS_AVERROR_EOF(result) {
            avcodec_flush_buffers(codecContext)
        }
        return (frame, result)
    }

    override func seek(time: TimeInterval) {
        super.seek(time: time)
        bestEffortTimestamp = Int64(0)
    }

    override func decode() {
        super.decode()
        bestEffortTimestamp = Int64(0)
    }

    private func setupSwrContext() -> Bool {
        inputNumberOfChannels = codecpar.pointee.channels
        if inputNumberOfChannels == 0 {
            inputNumberOfChannels = KSDefaultParameter.audioPlayerMaximumChannels
        }
        inputSampleRate = codecpar.pointee.sample_rate
        if inputSampleRate == 0 {
            inputSampleRate = KSDefaultParameter.audioPlayerSampleRate
        }
        inputFormat = AVSampleFormat(rawValue: codecpar.pointee.format)
        let outChannel = av_get_default_channel_layout(KSDefaultParameter.audioPlayerMaximumChannels)
        let inChannel = av_get_default_channel_layout(inputNumberOfChannels)
        swrContext = swr_alloc_set_opts(nil, outChannel, AV_SAMPLE_FMT_FLTP, KSDefaultParameter.audioPlayerSampleRate, inChannel, inputFormat, inputSampleRate, 0, nil)
        let result = swr_init(swrContext)
        if result < 0 {
            destorySwrContext()
            return false
        } else {
            return true
        }
    }

    private func destorySwrContext() {
        swr_free(&swrContext)
        swrContext = nil
    }

    deinit {
        swr_free(&swrContext)
        swrContext = nil
    }
}
