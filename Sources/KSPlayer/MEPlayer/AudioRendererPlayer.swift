//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/12/2.
//

import AVFoundation
import Foundation

public class AudioRendererPlayer: AudioPlayer, FrameOutput {
    var playbackRate: Float  {
        get {
            synchronizer.rate
        }
        set {
            synchronizer.rate = newValue
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
    var isPaused: Bool = true
    private let renderer = AVSampleBufferAudioRenderer()
    private var desc: CMAudioFormatDescription?
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private var enqueued = Int64(0)
    private let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "asbd"))
    init() {
        synchronizer.addRenderer(renderer)
    }

    func prepare(channels: UInt32) {
        #if !os(macOS)
        let channels = min(UInt32(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels), channels)
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(channels))
        #endif
        var audioStreamBasicDescription = AudioStreamBasicDescription()
        let floatByteSize = UInt32(MemoryLayout<Float>.size)
        audioStreamBasicDescription.mBitsPerChannel = 8 * floatByteSize
        audioStreamBasicDescription.mBytesPerFrame = floatByteSize
        audioStreamBasicDescription.mChannelsPerFrame = channels
        audioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        audioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM
        audioStreamBasicDescription.mFramesPerPacket = 1
        audioStreamBasicDescription.mBytesPerPacket = audioStreamBasicDescription.mFramesPerPacket * audioStreamBasicDescription.mBytesPerFrame
        audioStreamBasicDescription.mSampleRate = Float64(KSOptions.audioPlayerSampleRate)
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &audioStreamBasicDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &desc)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            self?.request()
        }
        timer.activate()
    }

    private func request() {
        guard let desc, let render = renderSource?.getAudioOutputRender() else {
            return
        }
        var bBuffer: CMBlockBuffer?
        let bufSize = render.dataSize.reduce(0, +)
        let memoryBlock = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: MemoryLayout<Int8>.alignment)
        var offer = 0
        for i in 0 ..< render.data.count {
            memoryBlock.advanced(by: offer).copyMemory(from: render.data[i]!, byteCount: render.dataSize[i])
            offer += render.dataSize[i]
        }
        CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: memoryBlock, blockLength: bufSize, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: bufSize, flags: 0, blockBufferOut: &bBuffer)
        guard let bBuffer else {
            return
        }
        var sampleBuffer: CMSampleBuffer?
        let sampleCount = CMItemCount(render.numberOfSamples)
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: bBuffer, formatDescription: desc, sampleCount: sampleCount, presentationTimeStamp: CMTime(value: enqueued, timescale: CMTimeScale(KSOptions.audioPlayerSampleRate)), packetDescriptions: nil, sampleBufferOut: &sampleBuffer)
        enqueued += Int64(sampleCount)
        guard let sampleBuffer else {
            return
        }
        if renderer.isReadyForMoreMediaData {
            renderer.enqueue(sampleBuffer)
        }
        renderSource?.setAudio(time: render.cmtime)
    }
}
