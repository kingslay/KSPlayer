//
//  AudioPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/16.
//

import AudioToolbox
protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfSamples: UInt32, numberOfChannels: UInt32)
    func audioPlayerWillRenderSample(sampleTimestamp: AudioTimeStamp)
    func audioPlayerDidRenderSample(sampleTimestamp: AudioTimeStamp)
}

final class AudioPlayer {
    private let graph: AUGraph
    private var audioUnitForMixer: AudioUnit!
    private var audioUnitForTimePitch: AudioUnit!
    private var audioStreamBasicDescription = KSDefaultParameter.outputFormat()

    private var isPlaying: Bool {
        var running = DarwinBoolean(false)
        if AUGraphIsRunning(graph, &running) == noErr {
            return running.boolValue
        }
        return false
    }

    private var sampleRate: Float64 {
        return audioStreamBasicDescription.mSampleRate
    }

    private var numberOfChannels: UInt32 {
        return audioStreamBasicDescription.mChannelsPerFrame
    }

    weak var delegate: AudioPlayerDelegate?
    var playbackRate: Float {
        get {
            var playbackRate = AudioUnitParameterValue(0.0)
            AudioUnitGetParameter(audioUnitForMixer, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, &playbackRate)
            return playbackRate
        }
        set {
            AudioUnitSetParameter(audioUnitForTimePitch, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, newValue, 0)
        }
    }

    var volume: Float {
        get {
            var volume = AudioUnitParameterValue(0.0)
            AudioUnitGetParameter(audioUnitForMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, &volume)
            return volume
        }
        set {
            AudioUnitSetParameter(audioUnitForMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, newValue, 0)
        }
    }

    init() {
        var newGraph: AUGraph!
        NewAUGraph(&newGraph)
        graph = newGraph
        var descriptionForTimePitch = AudioComponentDescription()
        descriptionForTimePitch.componentType = kAudioUnitType_FormatConverter
        descriptionForTimePitch.componentSubType = kAudioUnitSubType_NewTimePitch
        descriptionForTimePitch.componentManufacturer = kAudioUnitManufacturer_Apple

        var descriptionForMixer = AudioComponentDescription()
        descriptionForMixer.componentType = kAudioUnitType_Mixer
        descriptionForMixer.componentManufacturer = kAudioUnitManufacturer_Apple
        var descriptionForOutput = AudioComponentDescription()
        descriptionForOutput.componentType = kAudioUnitType_Output
        descriptionForOutput.componentManufacturer = kAudioUnitManufacturer_Apple
        #if os(macOS)
        descriptionForMixer.componentSubType = kAudioUnitSubType_StereoMixer
        descriptionForOutput.componentSubType = kAudioUnitSubType_DefaultOutput
        #else
        descriptionForMixer.componentSubType = kAudioUnitSubType_MultiChannelMixer
        descriptionForOutput.componentSubType = kAudioUnitSubType_RemoteIO
        #endif
        var nodeForTimePitch = AUNode()
        var nodeForMixer = AUNode()
        var nodeForOutput = AUNode()
        var audioUnitForOutput: AudioUnit!
        AUGraphAddNode(graph, &descriptionForTimePitch, &nodeForTimePitch)
        AUGraphAddNode(graph, &descriptionForMixer, &nodeForMixer)
        AUGraphAddNode(graph, &descriptionForOutput, &nodeForOutput)
        AUGraphOpen(graph)
        AUGraphConnectNodeInput(graph, nodeForTimePitch, 0, nodeForMixer, 0)
        AUGraphConnectNodeInput(graph, nodeForMixer, 0, nodeForOutput, 0)
        AUGraphNodeInfo(graph, nodeForTimePitch, &descriptionForTimePitch, &audioUnitForTimePitch)
        AUGraphNodeInfo(graph, nodeForMixer, &descriptionForMixer, &audioUnitForMixer)
        AUGraphNodeInfo(graph, nodeForOutput, &descriptionForOutput, &audioUnitForOutput)
        let inDataSize = UInt32(MemoryLayout.size(ofValue: KSDefaultParameter.audioPlayerMaximumFramesPerSlice))
        AudioUnitSetProperty(audioUnitForTimePitch,
                             kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global, 0,
                             &KSDefaultParameter.audioPlayerMaximumFramesPerSlice,
                             inDataSize)
        AudioUnitSetProperty(audioUnitForMixer,
                             kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global, 0,
                             &KSDefaultParameter.audioPlayerMaximumFramesPerSlice,
                             inDataSize)
        AudioUnitSetProperty(audioUnitForOutput,
                             kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global, 0,
                             &KSDefaultParameter.audioPlayerMaximumFramesPerSlice,
                             inDataSize)
        var inputCallbackStruct = renderCallbackStruct()
        AUGraphSetNodeInputCallback(graph, nodeForTimePitch, 0, &inputCallbackStruct)
        addRenderNotify(audioUnit: audioUnitForOutput)
        let audioStreamBasicDescriptionSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        AudioUnitSetProperty(audioUnitForTimePitch,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0,
                             &audioStreamBasicDescription,
                             audioStreamBasicDescriptionSize)
        AudioUnitSetProperty(audioUnitForTimePitch,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output, 0,
                             &audioStreamBasicDescription,
                             audioStreamBasicDescriptionSize)
        AudioUnitSetProperty(audioUnitForMixer,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0,
                             &audioStreamBasicDescription,
                             audioStreamBasicDescriptionSize)
        AudioUnitSetProperty(audioUnitForMixer,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output, 0,
                             &audioStreamBasicDescription,
                             audioStreamBasicDescriptionSize)
        AudioUnitSetProperty(audioUnitForOutput,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0,
                             &audioStreamBasicDescription,
                             audioStreamBasicDescriptionSize)
        AudioUnitSetProperty(audioUnitForOutput,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0,
                             &audioStreamBasicDescription,
                             audioStreamBasicDescriptionSize)
        AUGraphInitialize(graph)
    }

    private func renderCallbackStruct() -> AURenderCallbackStruct {
        var inputCallbackStruct = AURenderCallbackStruct()
        inputCallbackStruct.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
        inputCallbackStruct.inputProc = { refCon, _, _, _, inNumberFrames, ioData in
            guard let ioData = ioData else {
                return noErr
            }
            let `self` = Unmanaged<AudioPlayer>.fromOpaque(refCon).takeUnretainedValue()
            self.delegate?.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(ioData), numberOfSamples: inNumberFrames, numberOfChannels: self.numberOfChannels)
            return noErr
        }
        return inputCallbackStruct
    }

    private func addRenderNotify(audioUnit: AudioUnit) {
        AudioUnitAddRenderNotify(audioUnit, { refCon, ioActionFlags, inTimeStamp, _, _, _ in
            let `self` = Unmanaged<AudioPlayer>.fromOpaque(refCon).takeUnretainedValue()
            if ioActionFlags.pointee.contains(AudioUnitRenderActionFlags.unitRenderAction_PreRender) {
                self.delegate?.audioPlayerWillRenderSample(sampleTimestamp: inTimeStamp.pointee)
            } else if ioActionFlags.pointee.contains(AudioUnitRenderActionFlags.unitRenderAction_PostRender) {
                self.delegate?.audioPlayerDidRenderSample(sampleTimestamp: inTimeStamp.pointee)
            }
            return noErr
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    func play() {
        if !isPlaying {
            AUGraphStart(graph)
        }
    }

    func pause() {
        if isPlaying {
            AUGraphStop(graph)
        }
    }

    deinit {
        AUGraphStop(graph)
        AUGraphUninitialize(graph)
        AUGraphClose(graph)
        DisposeAUGraph(graph)
    }
}
