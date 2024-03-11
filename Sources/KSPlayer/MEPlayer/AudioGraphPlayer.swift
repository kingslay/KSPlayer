//
//  AudioGraphPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/16.
//

import AudioToolbox
import AVFAudio
import CoreAudio

public final class AudioGraphPlayer: AudioOutput, AudioDynamicsProcessor {
    public private(set) var audioUnitForDynamicsProcessor: AudioUnit
    private let graph: AUGraph
    private var audioUnitForMixer: AudioUnit!
    private var audioUnitForTimePitch: AudioUnit!
    private var audioUnitForOutput: AudioUnit!
    private var currentRenderReadOffset = UInt32(0)
    private var sourceNodeAudioFormat: AVAudioFormat?
    private var sampleSize = UInt32(MemoryLayout<Float>.size)
    #if os(macOS)
    private var volumeBeforeMute: Float = 0.0
    #endif
    public weak var renderSource: OutputRenderSourceDelegate?
    private var currentRender: AudioFrame? {
        didSet {
            if currentRender == nil {
                currentRenderReadOffset = 0
            }
        }
    }

    public func play() {
        AUGraphStart(graph)
    }

    public func pause() {
        AUGraphStop(graph)
    }

    public var playbackRate: Float {
        get {
            var playbackRate = AudioUnitParameterValue(0.0)
            AudioUnitGetParameter(audioUnitForTimePitch, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, &playbackRate)
            return playbackRate
        }
        set {
            AudioUnitSetParameter(audioUnitForTimePitch, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, newValue, 0)
        }
    }

    public var volume: Float {
        get {
            var volume = AudioUnitParameterValue(0.0)
            #if os(macOS)
            let inID = kStereoMixerParam_Volume
            #else
            let inID = kMultiChannelMixerParam_Volume
            #endif
            AudioUnitGetParameter(audioUnitForMixer, inID, kAudioUnitScope_Input, 0, &volume)
            return volume
        }
        set {
            #if os(macOS)
            let inID = kStereoMixerParam_Volume
            #else
            let inID = kMultiChannelMixerParam_Volume
            #endif
            AudioUnitSetParameter(audioUnitForMixer, inID, kAudioUnitScope_Input, 0, newValue, 0)
        }
    }

    public var isMuted: Bool {
        get {
            var value = AudioUnitParameterValue(1.0)
            #if os(macOS)
            AudioUnitGetParameter(audioUnitForMixer, kStereoMixerParam_Volume, kAudioUnitScope_Input, 0, &value)
            #else
            AudioUnitGetParameter(audioUnitForMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, 0, &value)
            #endif
            return value == 0
        }
        set {
            let value = newValue ? 0 : 1
            #if os(macOS)
            if value == 0 {
                volumeBeforeMute = volume
            }
            AudioUnitSetParameter(audioUnitForMixer, kStereoMixerParam_Volume, kAudioUnitScope_Input, 0, min(Float(value), volumeBeforeMute), 0)
            #else
            AudioUnitSetParameter(audioUnitForMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, 0, AudioUnitParameterValue(value), 0)
            #endif
        }
    }

    public init() {
        var newGraph: AUGraph!
        NewAUGraph(&newGraph)
        graph = newGraph
        var descriptionForTimePitch = AudioComponentDescription()
        descriptionForTimePitch.componentType = kAudioUnitType_FormatConverter
        descriptionForTimePitch.componentSubType = kAudioUnitSubType_NewTimePitch
        descriptionForTimePitch.componentManufacturer = kAudioUnitManufacturer_Apple
        var descriptionForDynamicsProcessor = AudioComponentDescription()
        descriptionForDynamicsProcessor.componentType = kAudioUnitType_Effect
        descriptionForDynamicsProcessor.componentManufacturer = kAudioUnitManufacturer_Apple
        descriptionForDynamicsProcessor.componentSubType = kAudioUnitSubType_DynamicsProcessor
        var descriptionForMixer = AudioComponentDescription()
        descriptionForMixer.componentType = kAudioUnitType_Mixer
        descriptionForMixer.componentManufacturer = kAudioUnitManufacturer_Apple
        #if os(macOS)
        descriptionForMixer.componentSubType = kAudioUnitSubType_StereoMixer
        #else
        descriptionForMixer.componentSubType = kAudioUnitSubType_MultiChannelMixer
        #endif
        var descriptionForOutput = AudioComponentDescription()
        descriptionForOutput.componentType = kAudioUnitType_Output
        descriptionForOutput.componentManufacturer = kAudioUnitManufacturer_Apple
        #if os(macOS)
        descriptionForOutput.componentSubType = kAudioUnitSubType_DefaultOutput
        #else
        descriptionForOutput.componentSubType = kAudioUnitSubType_RemoteIO
        #endif
        var nodeForTimePitch = AUNode()
        var nodeForDynamicsProcessor = AUNode()
        var nodeForMixer = AUNode()
        var nodeForOutput = AUNode()
        AUGraphAddNode(graph, &descriptionForTimePitch, &nodeForTimePitch)
        AUGraphAddNode(graph, &descriptionForMixer, &nodeForMixer)
        AUGraphAddNode(graph, &descriptionForDynamicsProcessor, &nodeForDynamicsProcessor)
        AUGraphAddNode(graph, &descriptionForOutput, &nodeForOutput)
        AUGraphOpen(graph)
        AUGraphConnectNodeInput(graph, nodeForTimePitch, 0, nodeForDynamicsProcessor, 0)
        AUGraphConnectNodeInput(graph, nodeForDynamicsProcessor, 0, nodeForMixer, 0)
        AUGraphConnectNodeInput(graph, nodeForMixer, 0, nodeForOutput, 0)
        AUGraphNodeInfo(graph, nodeForTimePitch, &descriptionForTimePitch, &audioUnitForTimePitch)
        var audioUnitForDynamicsProcessor: AudioUnit?
        AUGraphNodeInfo(graph, nodeForDynamicsProcessor, &descriptionForDynamicsProcessor, &audioUnitForDynamicsProcessor)
        self.audioUnitForDynamicsProcessor = audioUnitForDynamicsProcessor!
        AUGraphNodeInfo(graph, nodeForMixer, &descriptionForMixer, &audioUnitForMixer)
        AUGraphNodeInfo(graph, nodeForOutput, &descriptionForOutput, &audioUnitForOutput)
        addRenderNotify(audioUnit: audioUnitForOutput)
        var value = UInt32(1)
        AudioUnitSetProperty(audioUnitForTimePitch,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output, 0,
                             &value,
                             UInt32(MemoryLayout<UInt32>.size))
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
        sampleSize = audioFormat.sampleSize
        var audioStreamBasicDescription = audioFormat.formatDescription.audioStreamBasicDescription
        let audioStreamBasicDescriptionSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let channelLayout = audioFormat.channelLayout?.layout
        [audioUnitForTimePitch, audioUnitForDynamicsProcessor, audioUnitForMixer, audioUnitForOutput].forEach { unit in
            guard let unit else { return }
            AudioUnitSetProperty(unit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input, 0,
                                 &audioStreamBasicDescription,
                                 audioStreamBasicDescriptionSize)
            AudioUnitSetProperty(unit,
                                 kAudioUnitProperty_AudioChannelLayout,
                                 kAudioUnitScope_Input, 0,
                                 channelLayout,
                                 UInt32(MemoryLayout<AudioChannelLayout>.size))
            if unit != audioUnitForOutput {
                AudioUnitSetProperty(unit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output, 0,
                                     &audioStreamBasicDescription,
                                     audioStreamBasicDescriptionSize)
                AudioUnitSetProperty(unit,
                                     kAudioUnitProperty_AudioChannelLayout,
                                     kAudioUnitScope_Output, 0,
                                     channelLayout,
                                     UInt32(MemoryLayout<AudioChannelLayout>.size))
            }
            if unit == audioUnitForTimePitch {
                var inputCallbackStruct = renderCallbackStruct()
                AudioUnitSetProperty(unit,
                                     kAudioUnitProperty_SetRenderCallback,
                                     kAudioUnitScope_Input, 0,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
            }
        }
        AUGraphInitialize(graph)
    }

    public func flush() {
        currentRender = nil
    }

    deinit {
        AUGraphStop(graph)
        AUGraphUninitialize(graph)
        AUGraphClose(graph)
        DisposeAUGraph(graph)
    }
}

extension AudioGraphPlayer {
    private func renderCallbackStruct() -> AURenderCallbackStruct {
        var inputCallbackStruct = AURenderCallbackStruct()
        inputCallbackStruct.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
        inputCallbackStruct.inputProc = { refCon, _, _, _, inNumberFrames, ioData in
            guard let ioData else {
                return noErr
            }
            let `self` = Unmanaged<AudioGraphPlayer>.fromOpaque(refCon).takeUnretainedValue()
            self.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(ioData), numberOfFrames: inNumberFrames)
            return noErr
        }
        return inputCallbackStruct
    }

    private func addRenderNotify(audioUnit: AudioUnit) {
        AudioUnitAddRenderNotify(audioUnit, { refCon, ioActionFlags, inTimeStamp, _, _, _ in
            let `self` = Unmanaged<AudioGraphPlayer>.fromOpaque(refCon).takeUnretainedValue()
            autoreleasepool {
                if ioActionFlags.pointee.contains(.unitRenderAction_PostRender) {
                    self.audioPlayerDidRenderSample(sampleTimestamp: inTimeStamp.pointee)
                }
            }
            return noErr
        }, Unmanaged.passUnretained(self).toOpaque())
    }

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
