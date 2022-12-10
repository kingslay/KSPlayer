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
        synchronizer.rate == 0
    }

    init() {
        KSOptions.setAudioSession()
        synchronizer.addRenderer(renderer)
//        if #available(tvOS 15.0, iOS 15.0, macOS 12.0, *) {
//            renderer.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
//        }
    }

    func prepare(channels: UInt32, options: KSOptions) {
        if channels > 2 {
            renderer.audioTimePitchAlgorithm = .spectral
        }
        #if os(macOS)

        #else
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(channels))
        #endif
        if let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(KSOptions.audioPlayerSampleRate), channels: channels, interleaved: !KSOptions.isAudioPlanar) {
            desc = format.formatDescription
        } else {
            var audioStreamBasicDescription = AudioStreamBasicDescription()
            let floatByteSize = UInt32(MemoryLayout<Float>.size)
            audioStreamBasicDescription.mBitsPerChannel = 8 * floatByteSize
            audioStreamBasicDescription.mBytesPerFrame = floatByteSize * (KSOptions.isAudioPlanar ? 1 : channels)
            audioStreamBasicDescription.mChannelsPerFrame = channels
            audioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat
            if KSOptions.isAudioPlanar {
                audioStreamBasicDescription.mFormatFlags |= kAudioFormatFlagIsNonInterleaved
            }
            audioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM
            audioStreamBasicDescription.mFramesPerPacket = 1
            audioStreamBasicDescription.mBytesPerPacket = audioStreamBasicDescription.mFramesPerPacket * audioStreamBasicDescription.mBytesPerFrame
            audioStreamBasicDescription.mSampleRate = Float64(KSOptions.audioPlayerSampleRate)
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioStreamBasicDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &desc)
        }
        if let tag = desc?.audioFormatList.first?.mChannelLayoutTag, let layout = AVAudioChannelLayout(layoutTag: tag) {
            options.channelLayout = layout
        }
    }

    func play(time: TimeInterval) {
        synchronizer.setRate(playbackRate, time: CMTime(seconds: time))
        renderer.requestMediaDataWhenReady(on: DispatchQueue(label: "ksasbd")) { [unowned self] in
            self.request()
        }
        periodicTimeObserver = synchronizer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 1000), queue: .main) { [unowned self] _ in
            self.renderSource?.setAudio(time: self.synchronizer.currentTime())
        }
    }

    func pause() {
        synchronizer.rate = 0
        renderer.stopRequestingMediaData()
        renderer.flush()
        if let periodicTimeObserver {
            synchronizer.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
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
            let n = render.data.count
            for i in 0 ..< n {
                var outBlockBuffer: CMBlockBuffer?
                let dataByteSize = Int(render.numberOfSamples * UInt32(MemoryLayout<Float>.size) * render.channels) / n
                if dataByteSize > render.dataSize {
                    assertionFailure("dataByteSize: \(dataByteSize),render.dataSize: \(render.dataSize)")
                }
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
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: outBlockListBuffer, formatDescription: desc, sampleCount: sampleCount, presentationTimeStamp: render.cmtime, packetDescriptions: nil, sampleBufferOut: &sampleBuffer)
            guard let sampleBuffer else {
                continue
            }
            renderer.enqueue(sampleBuffer)
        }
    }
}
