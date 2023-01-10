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
    private let serializationQueue = DispatchQueue(label: "ks.player.serialization.queue")
    var isPaused: Bool {
        synchronizer.rate == 0
    }

    init() {
        synchronizer.addRenderer(renderer)
//        if #available(tvOS 15.0, iOS 15.0, macOS 12.0, *) {
//            renderer.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
//        }
    }

    func prepare(options: KSOptions, audioDescriptor: AudioDescriptor?) {
        var channels = max(AVAudioChannelCount(audioDescriptor?.inChannel.nb_channels ?? 2), 2)
        #if os(macOS)
        channels = 2
        #else
        let maxChannels = AVAudioChannelCount(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels)
        KSOptions.setAudioSession()
        if channels > maxChannels {
            if #available(tvOS 15.0, iOS 15.0, *) {
                if let port = AVAudioSession.sharedInstance().currentRoute.outputs.first, port.isSpatialAudioEnabled || port.portType == AVAudioSession.Port.bluetoothA2DP {
                } else {
                    channels = maxChannels
                }
            } else {
                channels = maxChannels
            }
        }
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(channels))
        if let audioDescriptor {
            options.channelLayout = audioDescriptor.audioChannelLayout(channels: Int(channels))
        }
        #endif
        renderer.audioTimePitchAlgorithm = channels > 2 ? .spectral : .timeDomain
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: options.sampleRate, interleaved: !KSOptions.isAudioPlanar, channelLayout: options.channelLayout)
        desc = format.formatDescription
    }

    func play(time: TimeInterval) {
        serializationQueue.async {
            self.synchronizer.setRate(self.playbackRate, time: CMTime(seconds: time))
            self.renderer.requestMediaDataWhenReady(on: self.serializationQueue) { [weak self] in
                guard let self else {
                    return
                }
                self.request()
            }
            self.periodicTimeObserver = self.synchronizer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 1000), queue: .main) { [weak self] _ in
                guard let self else {
                    return
                }
                self.renderSource?.setAudio(time: self.synchronizer.currentTime())
            }
        }
    }

    func pause() {
        serializationQueue.async {
            self.synchronizer.rate = 0
            self.renderer.stopRequestingMediaData()
            self.renderer.flush()
            if let periodicTimeObserver = self.periodicTimeObserver {
                self.synchronizer.removeTimeObserver(periodicTimeObserver)
                self.periodicTimeObserver = nil
            }
        }
    }

    private func request() {
        guard let desc else {
            return
        }

        while renderer.isReadyForMoreMediaData, !isPaused {
            guard let render = renderSource?.getAudioOutputRender() else {
                break
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
