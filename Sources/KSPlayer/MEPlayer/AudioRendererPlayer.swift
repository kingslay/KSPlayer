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
    private var sampleSize = UInt32(MemoryLayout<Float>.size)
    private var isInterleaved = true
    private var sampleRate: CMTimeScale = 44100
    var isPaused: Bool {
        synchronizer.rate == 0
    }

    init() {
        synchronizer.addRenderer(renderer)
        if #available(macOS 11.3, iOS 14.5, tvOS 14.5, *) {
            synchronizer.delaysRateChangeUntilHasSufficientMediaData = false
        }
//        if #available(tvOS 15.0, iOS 15.0, macOS 12.0, *) {
//            renderer.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
//        }
    }

    func prepare(audioFormat: AVAudioFormat) {
        renderer.audioTimePitchAlgorithm = audioFormat.channelCount > 2 ? .spectral : .timeDomain
        sampleSize = audioFormat.sampleSize
        desc = audioFormat.formatDescription
        isInterleaved = audioFormat.isInterleaved
        sampleRate = CMTimeScale(audioFormat.sampleRate)
    }

    func play(time: TimeInterval) {
        synchronizer.setRate(playbackRate, time: CMTime(seconds: time))
        renderer.requestMediaDataWhenReady(on: serializationQueue) { [weak self] in
            guard let self else {
                return
            }
            self.request()
        }
        periodicTimeObserver = synchronizer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: sampleRate), queue: .main) { [weak self] _ in
            guard let self else {
                return
            }
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

    func flush() {}

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
            let sampleCount = CMItemCount(render.numberOfSamples)
            let sstride = Int(sampleSize * render.channels) / n
            let dataByteSize = sampleCount * sstride
            if dataByteSize > render.dataSize {
                assertionFailure("dataByteSize: \(dataByteSize),render.dataSize: \(render.dataSize)")
            }
            for i in 0 ..< n {
                var outBlockBuffer: CMBlockBuffer?
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
            // 因为sampleRate跟timescale没有对齐，所以导致杂音。所以要让duration为invalid
//            let duration = CMTime(value: CMTimeValue(sampleCount), timescale: sampleRate)
            let duration = CMTime.invalid
            let timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: render.cmtime, decodeTimeStamp: .invalid)
            let sampleSizeEntryCount: CMItemCount
            let sampleSizeArray: [Int]?
            if isInterleaved {
                sampleSizeEntryCount = 1
                sampleSizeArray = [sstride]
            } else {
                sampleSizeEntryCount = 0
                sampleSizeArray = nil
            }
            CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: outBlockListBuffer, formatDescription: desc, sampleCount: sampleCount, sampleTimingEntryCount: 1, sampleTimingArray: [timing], sampleSizeEntryCount: sampleSizeEntryCount, sampleSizeArray: sampleSizeArray, sampleBufferOut: &sampleBuffer)
            guard let sampleBuffer else {
                continue
            }
            renderer.enqueue(sampleBuffer)
        }
    }
}
