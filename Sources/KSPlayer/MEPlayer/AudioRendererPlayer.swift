//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/12/2.
//

import AVFoundation
import Foundation

public class AudioRendererPlayer: AudioPlayer, FrameOutput {
    var playbackRate: Float = 1 {
        didSet {
            if !isPaused {
                synchronizer.rate = playbackRate
            }
        }
    }

    var volume: Float {
        get {
            renderer.volume
        }
        set {
            renderer.volume = newValue
        }
    }

    var isMuted: Bool {
        get {
            renderer.isMuted
        }
        set {
            renderer.isMuted = newValue
        }
    }

    var attackTime: Float = 0

    var releaseTime: Float = 0

    var threshold: Float = 0

    var expansionRatio: Float = 0

    var overallGain: Float = 0

    weak var renderSource: OutputRenderSourceDelegate?
    private var periodicTimeObserver: Any?
    private let renderer = AVSampleBufferAudioRenderer()
    private var desc: CMAudioFormatDescription?
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    var isPaused: Bool {
        get {
            synchronizer.rate == 0
        }
        set {
            if newValue {
                synchronizer.rate = 0
                renderer.flush()
                renderer.stopRequestingMediaData()
                if let periodicTimeObserver {
                    synchronizer.removeTimeObserver(periodicTimeObserver)
                    self.periodicTimeObserver = nil
                }
            } else {
                synchronizer.rate = 1
                synchronizer.rate = playbackRate
                renderer.requestMediaDataWhenReady(on: DispatchQueue(label: "ksasbd")) { [unowned self] in
                    self.request()
                }
                periodicTimeObserver = synchronizer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 1000), queue: .main) { [unowned self] cmTime in
//                    let time = self.synchronizer.currentTime()
                    self.renderSource?.setAudio(time: cmTime)
                }
            }
        }
    }

    init() {
        synchronizer.addRenderer(renderer)
    }

    func prepare(channels: UInt32) {
        #if os(macOS)
        let channels = min(2, channels)
        #else
        let channels = min(UInt32(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels), channels)
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(channels))
        #endif
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(KSOptions.audioPlayerSampleRate), channels: channels, interleaved: !KSOptions.isAudioPlanar) else {
            return
        }
        desc = format.formatDescription
        if let tag = desc?.audioFormatList.first?.mChannelLayoutTag, let layout = AVAudioChannelLayout(layoutTag: tag) {
            KSOptions.channelLayout = layout
        }
    }

    private func request() {
        guard let desc else {
            return
        }

        while renderer.isReadyForMoreMediaData, !isPaused {
            guard let render = renderSource?.getAudioOutputRender() else {
                continue
            }
            var outBlockListBuffer: CMBlockBuffer?
            CMBlockBufferCreateEmpty(allocator: kCFAllocatorDefault, capacity: 0, flags: 0, blockBufferOut: &outBlockListBuffer)
            guard let outBlockListBuffer else {
                continue
            }
            let n = KSOptions.isAudioPlanar ? min(render.data.count, Int(desc.audioFormatList[0].mASBD.mChannelsPerFrame)) : 1
            for i in 0 ..< n {
                var outBlockBuffer: CMBlockBuffer?
                let dataByteSize = render.dataSize[i]
                CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: nil,
                    blockLength: dataByteSize,
                    blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: dataByteSize,
                    flags: kCMBlockBufferAssureMemoryNowFlag,
                    blockBufferOut: &outBlockBuffer
                )
                if let outBlockBuffer {
                    CMBlockBufferReplaceDataBytes(
                        with: render.data[i]!,
                        blockBuffer: outBlockBuffer,
                        offsetIntoDestination: 0,
                        dataLength: dataByteSize
                    )
                    CMBlockBufferAppendBufferReference(
                        outBlockListBuffer,
                        targetBBuf: outBlockBuffer,
                        offsetToData: 0,
                        dataLength: CMBlockBufferGetDataLength(outBlockBuffer),
                        flags: 0
                    )
                }
            }
            var sampleBuffer: CMSampleBuffer?
            let sampleCount = CMItemCount(render.numberOfSamples)
//            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: outBlockListBuffer, formatDescription: desc, sampleCount: sampleCount, presentationTimeStamp: render.cmtime, packetDescriptions: nil, sampleBufferOut: &sampleBuffer)
            CMAudioSampleBufferCreateWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: outBlockListBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: desc, sampleCount: sampleCount, presentationTimeStamp: render.cmtime, packetDescriptions: nil, sampleBufferOut: &sampleBuffer)
            guard let sampleBuffer else {
                continue
            }
            renderer.enqueue(sampleBuffer)
        }
    }
}
