//
//  AudioPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/16.
//

import AudioToolbox
import CoreAudio

protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfFrames: UInt32, numberOfChannels: UInt32)
    func audioPlayerWillRenderSample(sampleTimestamp: AudioTimeStamp)
    func audioPlayerDidRenderSample(sampleTimestamp: AudioTimeStamp)
}

protocol AudioPlayer: AnyObject {
    var delegate: AudioPlayerDelegate? { get set }
    var playbackRate: Float { get set }
    var volume: Float { get set }
    var isMuted: Bool { get set }
    var isPaused: Bool { get set }
}

final class AudioGraphPlayer: AudioPlayer {
    private let graph: AUGraph
    private var audioUnitForMixer: AudioUnit!
    private var audioUnitForTimePitch: AudioUnit!
    private var audioStreamBasicDescription = KSPlayerManager.outputFormat()
    var isPaused: Bool {
        get {
            var running = DarwinBoolean(false)
            if AUGraphIsRunning(graph, &running) == noErr {
                return !running.boolValue
            }
            return true
        }
        set {
            if newValue != isPaused {
                if newValue {
                    AUGraphStop(graph)
                } else {
                    AUGraphStart(graph)
                }
            }
        }
    }

    private var sampleRate: Float64 { audioStreamBasicDescription.mSampleRate }

    private var numberOfChannels: UInt32 { audioStreamBasicDescription.mChannelsPerFrame }

    weak var delegate: AudioPlayerDelegate?
    var playbackRate: Float {
        set {
            AudioUnitSetParameter(audioUnitForTimePitch, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, newValue, 0)
        }
        get {
            var playbackRate = AudioUnitParameterValue(0.0)
            AudioUnitGetParameter(audioUnitForMixer, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, &playbackRate)
            return playbackRate
        }
    }

    var volume: Float {
        set {
            AudioUnitSetParameter(audioUnitForMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, newValue, 0)
        }
        get {
            var volume = AudioUnitParameterValue(0.0)
            AudioUnitGetParameter(audioUnitForMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, &volume)
            return volume
        }
    }

    public var isMuted: Bool {
        set {
            let value = newValue ? 0 : 1
            AudioUnitSetParameter(audioUnitForMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, 0, AudioUnitParameterValue(value), 0)
        }
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(audioUnitForMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, 0, &value)
            return value == 0
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
        #if os(macOS) || targetEnvironment(macCatalyst)
        descriptionForMixer.componentSubType = kAudioUnitSubType_SpatialMixer
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
        var inputCallbackStruct = renderCallbackStruct()
        AUGraphSetNodeInputCallback(graph, nodeForTimePitch, 0, &inputCallbackStruct)
        addRenderNotify(audioUnit: audioUnitForOutput)
        let audioStreamBasicDescriptionSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let inDataSize = UInt32(MemoryLayout.size(ofValue: KSPlayerManager.audioPlayerMaximumFramesPerSlice))
        [audioUnitForTimePitch, audioUnitForMixer, audioUnitForOutput].forEach { unit in
            guard let unit = unit else { return }
            AudioUnitSetProperty(unit,
                                 kAudioUnitProperty_MaximumFramesPerSlice,
                                 kAudioUnitScope_Global, 0,
                                 &KSPlayerManager.audioPlayerMaximumFramesPerSlice,
                                 inDataSize)
            AudioUnitSetProperty(unit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input, 0,
                                 &audioStreamBasicDescription,
                                 audioStreamBasicDescriptionSize)
            AudioUnitSetProperty(unit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, 0,
                                 &audioStreamBasicDescription,
                                 audioStreamBasicDescriptionSize)
        }
        AUGraphInitialize(graph)
    }

    private func renderCallbackStruct() -> AURenderCallbackStruct {
        var inputCallbackStruct = AURenderCallbackStruct()
        inputCallbackStruct.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
        inputCallbackStruct.inputProc = { refCon, _, _, _, inNumberFrames, ioData in
            guard let ioData = ioData else {
                return noErr
            }
            let `self` = Unmanaged<AudioGraphPlayer>.fromOpaque(refCon).takeUnretainedValue()
            self.delegate?.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(ioData), numberOfFrames: inNumberFrames, numberOfChannels: self.numberOfChannels)
            return noErr
        }
        return inputCallbackStruct
    }

    private func addRenderNotify(audioUnit: AudioUnit) {
        AudioUnitAddRenderNotify(audioUnit, { refCon, ioActionFlags, inTimeStamp, _, _, _ in
            let `self` = Unmanaged<AudioGraphPlayer>.fromOpaque(refCon).takeUnretainedValue()
            if ioActionFlags.pointee.contains(.unitRenderAction_PreRender) {
                self.delegate?.audioPlayerWillRenderSample(sampleTimestamp: inTimeStamp.pointee)
            } else if ioActionFlags.pointee.contains(.unitRenderAction_PostRender) {
                self.delegate?.audioPlayerDidRenderSample(sampleTimestamp: inTimeStamp.pointee)
            }
            return noErr
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        AUGraphStop(graph)
        AUGraphUninitialize(graph)
        AUGraphClose(graph)
        DisposeAUGraph(graph)
    }
}

import Accelerate
import AVFoundation

@available(OSX 10.13, tvOS 11.0, iOS 11.0, *)
final class AudioEnginePlayer: AudioPlayer {
    var isPaused: Bool {
        get {
            engine.isRunning
        }
        set {
            if newValue {
                if !engine.isRunning {
                    try? engine.start()
                }
                player.play()
            } else {
                player.pause()
                engine.pause()
            }
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let picth = AVAudioUnitTimePitch()
    weak var delegate: AudioPlayerDelegate?

    var playbackRate: Float {
        get {
            picth.rate
        }
        set {
            picth.rate = min(32, max(1.0 / 32.0, newValue))
        }
    }

    var volume: Float {
        get {
            player.volume
        }
        set {
            player.volume = newValue
        }
    }

    var isMuted: Bool {
        get {
            volume == 0
        }
        set {}
    }

    init() {
        engine.attach(player)
        engine.attach(picth)
        let format = KSPlayerManager.audioDefaultFormat
        engine.connect(player, to: picth, format: format)
        engine.connect(picth, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.enableManualRenderingMode(.realtime, format: format, maximumFrameCount: KSPlayerManager.audioPlayerMaximumFramesPerSlice)
//        engine.inputNode.setManualRenderingInputPCMFormat(format) { count -> UnsafePointer<AudioBufferList>? in
//            self.delegate?.audioPlayerShouldInputData(ioData: <#T##UnsafeMutableAudioBufferListPointer#>, numberOfSamples: <#T##UInt32#>, numberOfChannels: <#T##UInt32#>)
//        }
    }

    func audioPlay(buffer: AVAudioPCMBuffer) {
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}

extension AVAudioFormat {
    func toPCMBuffer(data: NSData) -> AVAudioPCMBuffer? {
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self, frameCapacity: UInt32(data.length) / streamDescription.pointee.mBytesPerFrame) else {
            return nil
        }
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: pcmBuffer.floatChannelData, count: Int(pcmBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]), length: data.length)
        return pcmBuffer
    }
}
