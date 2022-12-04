//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/12/2.
//

import AVFoundation
import Foundation

public class AudioRendererPlayer: FrameOutput {
    weak var renderSource: OutputRenderSourceDelegate?
    var isPaused: Bool = true
    private let renderer = AVSampleBufferAudioRenderer()
    init() {
        var desc: CMAudioFormatDescription?
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(KSOptions.audioPlayerSampleRate), interleaved: false, channelLayout: KSOptions.channelLayout)
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: format.streamDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &desc)
        guard let desc else {
            return
        }
        var enqueued = Int64(0)
        renderer.requestMediaDataWhenReady(on: DispatchQueue(label: "avsbar")) {
            while self.renderer.isReadyForMoreMediaData {
                guard let render = self.renderSource?.getAudioOutputRender() else {
                    continue
                }
                var bBuffer: CMBlockBuffer?
                let bufSize = 0
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bufSize, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: bufSize, flags: 0, blockBufferOut: &bBuffer)
                guard let bBuffer else {
                    continue
                }
                var sampleBuffer: CMSampleBuffer?
                let sampleCount = CMItemCount(0)
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: bBuffer, formatDescription: desc, sampleCount: sampleCount, presentationTimeStamp: CMTime(value: enqueued, timescale: CMTimeScale(format.sampleRate)), packetDescriptions: nil, sampleBufferOut: &sampleBuffer)
                enqueued += Int64(sampleCount)
                guard let sampleBuffer else {
                    continue
                }
                self.renderer.enqueue(sampleBuffer)
            }
        }
    }
}
