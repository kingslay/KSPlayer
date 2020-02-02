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
    private var inputNumberOfChannels = KSPlayerManager.audioPlayerMaximumChannels
    private var inputSampleRate = KSPlayerManager.audioPlayerSampleRate
    private var inputFormat = AV_SAMPLE_FMT_FLTP

    override func open() -> Bool {
        if super.open() {
            return setupSwrContext()
        }
        return false
    }

    override func fetchReuseFrame() throws -> AudioFrame {
        if inputNumberOfChannels != codecpar.pointee.channels || inputFormat.rawValue != codecpar.pointee.format || inputSampleRate != codecpar.pointee.sample_rate {
            destorySwrContext()
            _ = setupSwrContext()
        }
        let result = avcodec_receive_frame(codecContext, coreFrame)
        if let swrContext = swrContext, result == 0, let coreFrame = coreFrame {
            // 过滤掉不规范的音频
            if codecpar.pointee.channels != coreFrame.pointee.channels || codecpar.pointee.format != coreFrame.pointee.format || codecpar.pointee.sample_rate != coreFrame.pointee.sample_rate {
                throw result
            }
            bestEffortTimestamp = max(coreFrame.pointee.best_effort_timestamp, bestEffortTimestamp)
            var numberOfSamples = coreFrame.pointee.nb_samples
            let nbSamples = swr_get_out_samples(swrContext, numberOfSamples)
            var frameBuffer = Array(tuple: coreFrame.pointee.data).map { UnsafePointer<UInt8>($0) }
            var bufferSize = Int32(0)
            _ = av_samples_get_buffer_size(&bufferSize, Int32(KSPlayerManager.audioPlayerMaximumChannels), nbSamples, AV_SAMPLE_FMT_FLTP, 1)
            let frame = AudioFrame(bufferSize: bufferSize)
            numberOfSamples = swr_convert(swrContext, &frame.dataWrap.data, nbSamples, &frameBuffer, numberOfSamples)
            frame.numberOfSamples = Int(numberOfSamples)
            frame.timebase = timebase
            frame.position = bestEffortTimestamp
            frame.duration = coreFrame.pointee.pkt_duration
            if frame.duration == 0 {
                frame.duration = Int64(numberOfSamples) * Int64(frame.timebase.den) / (Int64(KSPlayerManager.audioPlayerSampleRate) * Int64(frame.timebase.num))
            }
            frame.size = Int64(coreFrame.pointee.pkt_size)
            return frame
        }
        throw result
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
        inputNumberOfChannels = UInt32(codecpar.pointee.channels)
        if inputNumberOfChannels == 0 {
            inputNumberOfChannels = KSPlayerManager.audioPlayerMaximumChannels
        }
        inputSampleRate = codecpar.pointee.sample_rate
        if inputSampleRate == 0 {
            inputSampleRate = KSPlayerManager.audioPlayerSampleRate
        }
        inputFormat = AVSampleFormat(rawValue: codecpar.pointee.format)
        let outChannel = av_get_default_channel_layout(Int32(KSPlayerManager.audioPlayerMaximumChannels))
        let inChannel = av_get_default_channel_layout(Int32(inputNumberOfChannels))
        swrContext = swr_alloc_set_opts(nil, outChannel, AV_SAMPLE_FMT_FLTP, KSPlayerManager.audioPlayerSampleRate, inChannel, inputFormat, inputSampleRate, 0, nil)
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
    }

    deinit {
        swr_free(&swrContext)
    }
}
