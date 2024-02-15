//
//  AudioEnginePlayer.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import CoreAudio

public protocol AudioOutput: FrameOutput {
    var playbackRate: Float { get set }
    var volume: Float { get set }
    var isMuted: Bool { get set }
    init()
    func prepare(audioFormat: AVAudioFormat)
    func play()
}

public protocol AudioDynamicsProcessor {
    var audioUnitForDynamicsProcessor: AudioUnit { get }
}

public extension AudioDynamicsProcessor {
    var attackTime: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    var releaseTime: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    var threshold: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    var expansionRatio: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    var overallGain: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(audioUnitForDynamicsProcessor, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }
}

public final class AudioEngineDynamicsPlayer: AudioEnginePlayer, AudioDynamicsProcessor {
    private let dynamicsProcessor = AVAudioUnitEffect(audioComponentDescription:
        AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                  componentSubType: kAudioUnitSubType_DynamicsProcessor,
                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                  componentFlags: 0,
                                  componentFlagsMask: 0))
    public var audioUnitForDynamicsProcessor: AudioUnit {
        dynamicsProcessor.audioUnit
    }

    override func audioNodes() -> [AVAudioNode] {
        var nodes: [AVAudioNode] = [dynamicsProcessor]
        nodes.append(contentsOf: super.audioNodes())
        return nodes
    }

    public required init() {
        super.init()
        engine.attach(dynamicsProcessor)
    }
}

public class AudioEnginePlayer: AudioOutput {
    public let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sourceNodeAudioFormat: AVAudioFormat?

//    private let reverb = AVAudioUnitReverb()
//    private let nbandEQ = AVAudioUnitEQ()
//    private let distortion = AVAudioUnitDistortion()
//    private let delay = AVAudioUnitDelay()
    private let timePitch = AVAudioUnitTimePitch()
    private var sampleSize = UInt32(MemoryLayout<Float>.size)
    private var currentRenderReadOffset = UInt32(0)
    public weak var renderSource: OutputRenderSourceDelegate?
    private var currentRender: AudioFrame? {
        didSet {
            if currentRender == nil {
                currentRenderReadOffset = 0
            }
        }
    }

    public var playbackRate: Float {
        get {
            timePitch.rate
        }
        set {
            timePitch.rate = min(32, max(1 / 32, newValue))
        }
    }

    public var volume: Float {
        get {
            sourceNode?.volume ?? 1
        }
        set {
            sourceNode?.volume = newValue
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

    public required init() {
        engine.attach(timePitch)
        if let audioUnit = engine.outputNode.audioUnit {
            addRenderNotify(audioUnit: audioUnit)
        }
    }

    public func prepare(audioFormat: AVAudioFormat) {
        if sourceNodeAudioFormat == audioFormat {
            return
        }
        sourceNodeAudioFormat = audioFormat
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(audioFormat.channelCount))
        KSLog("[audio] set preferredOutputNumberOfChannels: \(audioFormat.channelCount)")
        #endif
        KSLog("[audio] outputFormat AudioFormat: \(audioFormat)")
        if let channelLayout = audioFormat.channelLayout {
            KSLog("[audio] outputFormat channelLayout \(channelLayout.channelDescriptions)")
        }
        let isRunning = engine.isRunning
        engine.stop()
        engine.reset()
        sourceNode = AVAudioSourceNode(format: audioFormat) { [weak self] _, timestamp, frameCount, audioBufferList in
            if timestamp.pointee.mSampleTime == 0 {
                return noErr
            }
            self?.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(audioBufferList), numberOfFrames: frameCount)
            return noErr
        }
        guard let sourceNode else {
            return
        }
        KSLog("[audio] new sourceNode inputFormat: \(sourceNode.inputFormat(forBus: 0))")
        sampleSize = audioFormat.sampleSize
        engine.attach(sourceNode)
        var nodes: [AVAudioNode] = [sourceNode]
        nodes.append(contentsOf: audioNodes())
        if audioFormat.channelCount > 2 {
            nodes.append(engine.outputNode)
        }
        // 一定要传入format，这样多音轨音响才不会有问题。
        engine.connect(nodes: nodes, format: audioFormat)
        engine.prepare()
        if isRunning {
            try? engine.start()
            // 从多声道切换到2声道马上调用start会不生效。需要异步主线程才可以
            DispatchQueue.main.async { [weak self] in
                self?.play()
            }
        }
    }

    func audioNodes() -> [AVAudioNode] {
        [timePitch, engine.mainMixerNode]
    }

    public func play() {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                KSLog(error)
            }
        }
    }

    public func pause() {
        if engine.isRunning {
            engine.pause()
        }
    }

    public func flush() {
        currentRender = nil
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

//    private func addRenderCallback(audioUnit: AudioUnit, streamDescription: UnsafePointer<AudioStreamBasicDescription>) {
//        _ = AudioUnitSetProperty(audioUnit,
//                                 kAudioUnitProperty_StreamFormat,
//                                 kAudioUnitScope_Input,
//                                 0,
//                                 streamDescription,
//                                 UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
//        var inputCallbackStruct = AURenderCallbackStruct()
//        inputCallbackStruct.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
//        inputCallbackStruct.inputProc = { refCon, _, _, _, inNumberFrames, ioData in
//            guard let ioData else {
//                return noErr
//            }
//            let `self` = Unmanaged<AudioEnginePlayer>.fromOpaque(refCon).takeUnretainedValue()
//            self.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(ioData), numberOfFrames: inNumberFrames)
//            return noErr
//        }
//        _ = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inputCallbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
//    }

    private func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfFrames: UInt32) {
        var ioDataWriteOffset = 0
        var numberOfSamples = numberOfFrames
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
            if sourceNodeAudioFormat != currentRender.audioFormat {
                runOnMainThread { [weak self] in
                    guard let self else {
                        return
                    }
                    self.prepare(audioFormat: currentRender.audioFormat)
                }
                return
            }
            let framesToCopy = min(numberOfSamples, residueLinesize)
            let bytesToCopy = Int(framesToCopy * sampleSize)
            let offset = Int(currentRenderReadOffset * sampleSize)
            for i in 0 ..< min(ioData.count, currentRender.data.count) {
                if let source = currentRender.data[i], let destination = ioData[i].mData {
                    (destination + ioDataWriteOffset).copyMemory(from: source + offset, byteCount: bytesToCopy)
                }
            }
            numberOfSamples -= framesToCopy
            ioDataWriteOffset += bytesToCopy
            currentRenderReadOffset += framesToCopy
        }
        let sizeCopied = (numberOfFrames - numberOfSamples) * sampleSize
        for i in 0 ..< ioData.count {
            let sizeLeft = Int(ioData[i].mDataByteSize - sizeCopied)
            if sizeLeft > 0 {
                memset(ioData[i].mData! + Int(sizeCopied), 0, sizeLeft)
            }
        }
    }

    private func audioPlayerDidRenderSample(sampleTimestamp _: AudioTimeStamp) {
        if let currentRender {
            let currentPreparePosition = currentRender.timestamp + currentRender.duration * Int64(currentRenderReadOffset) / Int64(currentRender.numberOfSamples)
            if currentPreparePosition > 0 {
                renderSource?.setAudio(time: currentRender.timebase.cmtime(for: currentPreparePosition), position: currentRender.position)
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
