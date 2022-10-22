//
//  AudioOutput.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import CoreAudio

protocol AudioPlayer: AnyObject {
    var playbackRate: Float { get set }
    var volume: Float { get set }
    var isMuted: Bool { get set }
    var isPaused: Bool { get set }
    var attackTime: Float { get set }
    var releaseTime: Float { get set }
    var threshold: Float { get set }
    var expansionRatio: Float { get set }
    var overallGain: Float { get set }
}

public final class AudioEnginePlayer: AudioPlayer, FrameOutput {
    public var attackTime: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var releaseTime: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var threshold: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var expansionRatio: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var overallGain: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    private let engine = AVAudioEngine()

//    private let reverb = AVAudioUnitReverb()
//    private let nbandEQ = AVAudioUnitEQ()
//    private let distortion = AVAudioUnitDistortion()
//    private let delay = AVAudioUnitDelay()
    private let playback = AVAudioUnitVarispeed()
    private let dynamicsProcessor = AVAudioUnitEffect(audioComponentDescription:
        AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                  componentSubType: kAudioUnitSubType_DynamicsProcessor,
                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                  componentFlags: 0,
                                  componentFlagsMask: 0))
    private var currentRenderReadOffset = 0
    weak var renderSource: OutputRenderSourceDelegate?
    private var currentRender: AudioFrame? {
        didSet {
            if currentRender == nil {
                currentRenderReadOffset = 0
            }
        }
    }

    var isPaused: Bool {
        get {
            engine.isRunning
        }
        set {
            if newValue {
                engine.pause()
            } else {
                if !engine.isRunning {
                    try? engine.start()
                }
            }
        }
    }

    var playbackRate: Float {
        get {
            playback.rate
        }
        set {
            playback.rate = min(2, max(0.5, newValue))
        }
    }

    var volume: Float {
        get {
            engine.mainMixerNode.volume
        }
        set {
            engine.mainMixerNode.volume = newValue
        }
    }

    public var isMuted: Bool {
        get {
            engine.mainMixerNode.outputVolume == 0.0
        }
        set {
            engine.mainMixerNode.outputVolume = newValue ? 0.0 : 1.0
        }
    }

    init() {
        KSOptions.setAudioSession()
        engine.attach(dynamicsProcessor)
        var format = engine.outputNode.outputFormat(forBus: 0)
        KSOptions.audioPlayerSampleRate = Int32(format.sampleRate)
        if let channelLayout = format.channelLayout, KSOptions.channelLayout != channelLayout {
            format = AVAudioFormat(commonFormat: format.commonFormat, sampleRate: format.sampleRate, interleaved: format.isInterleaved, channelLayout: KSOptions.channelLayout)
        }
//        engine.attach(nbandEQ)
//        engine.attach(distortion)
//        engine.attach(delay)
        let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            self?.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(audioBufferList), numberOfFrames: frameCount)
            return noErr
        }
        engine.attach(sourceNode)
        engine.attach(playback)
        engine.connect(nodes: [sourceNode, dynamicsProcessor, playback, engine.mainMixerNode, engine.outputNode], format: format)

        if let audioUnit = engine.outputNode.audioUnit {
            addRenderNotify(audioUnit: audioUnit)
        }
        engine.prepare()
    }

    private func addRenderNotify(audioUnit: AudioUnit) {
        AudioUnitAddRenderNotify(audioUnit, { refCon, ioActionFlags, inTimeStamp, _, _, _ in
            let `self` = Unmanaged<AudioEnginePlayer>.fromOpaque(refCon).takeUnretainedValue()
            autoreleasepool {
                if ioActionFlags.pointee.contains(.unitRenderAction_PostRender) {
                    self.audioPlayerDidRenderSample(sampleTimestamp: inTimeStamp.pointee)
                }
            }
            return noErr
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func addRenderCallback(audioUnit: AudioUnit, streamDescription: UnsafePointer<AudioStreamBasicDescription>) {
        _ = AudioUnitSetProperty(audioUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 streamDescription,
                                 UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        var inputCallbackStruct = AURenderCallbackStruct()
        inputCallbackStruct.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
        inputCallbackStruct.inputProc = { refCon, _, _, _, inNumberFrames, ioData in
            guard let ioData else {
                return noErr
            }
            let `self` = Unmanaged<AudioEnginePlayer>.fromOpaque(refCon).takeUnretainedValue()
            self.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(ioData), numberOfFrames: inNumberFrames)
            return noErr
        }
        _ = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inputCallbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
    }

    private func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfFrames: UInt32) {
        var ioDataWriteOffset = 0
        var numberOfSamples = Int(numberOfFrames)
        while numberOfSamples > 0 {
            if currentRender == nil {
                currentRender = renderSource?.getAudioOutputRender()
            }
            guard let currentRender else {
                break
            }
            let residueLinesize = currentRender.numberOfSamples - currentRenderReadOffset
            guard residueLinesize > 0 else {
                self.currentRender = nil
                continue
            }
            let framesToCopy = min(numberOfSamples, residueLinesize)
            let bytesToCopy = framesToCopy * MemoryLayout<Float>.size
            let offset = currentRenderReadOffset * MemoryLayout<Float>.size
            for i in 0 ..< min(ioData.count, currentRender.data.count) {
                (ioData[i].mData! + ioDataWriteOffset).copyMemory(from: currentRender.data[i]! + offset, byteCount: bytesToCopy)
            }
            numberOfSamples -= framesToCopy
            ioDataWriteOffset += bytesToCopy
            currentRenderReadOffset += framesToCopy
        }
        let sizeCopied = (Int(numberOfFrames) - numberOfSamples) * MemoryLayout<Float>.size
        for i in 0 ..< ioData.count {
            let sizeLeft = Int(ioData[i].mDataByteSize) - sizeCopied
            if sizeLeft > 0 {
                memset(ioData[i].mData! + sizeCopied, 0, sizeLeft)
            }
        }
    }

    private func audioPlayerDidRenderSample(sampleTimestamp _: AudioTimeStamp) {
        if let currentRender {
            let currentPreparePosition = currentRender.position + currentRender.duration * Int64(currentRenderReadOffset) / Int64(currentRender.numberOfSamples)
            if currentPreparePosition > 0 {
                renderSource?.setAudio(time: currentRender.timebase.cmtime(for: currentPreparePosition))
            }
        }
    }
}

extension AVAudioEngine {
    func connect(nodes: [AVAudioNode], format: AVAudioFormat?) {
        if nodes.count < 2 {
            return
        }
        for i in 0 ..< nodes.count - 1 {
            connect(nodes[i], to: nodes[i + 1], format: format)
        }
    }
}

extension AVAudioFormat {
    func toPCMBuffer(frame: AudioFrame) -> AVAudioPCMBuffer? {
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self, frameCapacity: UInt32(frame.dataSize[0]) / streamDescription.pointee.mBytesPerFrame) else {
            return nil
        }
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        for i in 0 ..< min(Int(pcmBuffer.format.channelCount), frame.data.count) {
            frame.data[i]?.withMemoryRebound(to: Float.self, capacity: Int(pcmBuffer.frameCapacity)) { srcFloatsForChannel in
                pcmBuffer.floatChannelData?[i].assign(from: srcFloatsForChannel, count: Int(pcmBuffer.frameCapacity))
            }
        }
        return pcmBuffer
    }
}
