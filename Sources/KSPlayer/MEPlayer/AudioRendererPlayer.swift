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

    private let renderer = AVSampleBufferAudioRenderer()
    private var desc: CMAudioFormatDescription?
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    init() {
        synchronizer.addRenderer(renderer)
    }

    func prepare(channels: UInt32) {
        #if !os(macOS)
        let channels = min(UInt32(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels), channels)
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(channels))
        #endif
        var descriptionForOutput = AudioComponentDescription()
        descriptionForOutput.componentType = kAudioUnitType_Output
        descriptionForOutput.componentManufacturer = kAudioUnitManufacturer_Apple
        #if os(macOS)
        descriptionForOutput.componentSubType = kAudioUnitSubType_DefaultOutput
        #else
        descriptionForOutput.componentSubType = kAudioUnitSubType_RemoteIO
        #endif
        if let comp = AudioComponentFindNext(nil, &descriptionForOutput) {
            var audioUnit: AudioUnit?
            AudioComponentInstanceNew(comp, &audioUnit)
            if let audioUnit {
                AudioUnitInitialize(audioUnit)
                KSOptions.channelLayout = AVAudioChannelLayout(layout: audioUnit.channelLayout)
            }
        }
        var audioStreamBasicDescription = AudioStreamBasicDescription()
        let floatByteSize = UInt32(MemoryLayout<Float>.size)
        audioStreamBasicDescription.mBitsPerChannel = 8 * floatByteSize
        audioStreamBasicDescription.mBytesPerFrame = floatByteSize
        audioStreamBasicDescription.mChannelsPerFrame = KSOptions.channelLayout.channelCount
        audioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        audioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM
        audioStreamBasicDescription.mFramesPerPacket = 1
        audioStreamBasicDescription.mBytesPerPacket = audioStreamBasicDescription.mFramesPerPacket * audioStreamBasicDescription.mBytesPerFrame
        audioStreamBasicDescription.mSampleRate = Float64(KSOptions.audioPlayerSampleRate)
        CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioStreamBasicDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &desc)
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
            for i in 0 ..< render.data.count {
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
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: outBlockListBuffer, formatDescription: desc, sampleCount: sampleCount, presentationTimeStamp: render.cmtime, packetDescriptions: nil, sampleBufferOut: &sampleBuffer)
            guard let sampleBuffer else {
                continue
            }
            renderer.enqueue(sampleBuffer)
        }
    }
}
