//
//  AudioUnitPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/16.
//

import AudioToolbox
import AVFAudio
import CoreAudio

public final class AudioUnitPlayer: AudioOutput {
    private var audioUnitForOutput: AudioUnit!
    private var currentRenderReadOffset = UInt32(0)
    private var sourceNodeAudioFormat: AVAudioFormat?
    private var sampleSize = UInt32(MemoryLayout<Float>.size)
    public weak var renderSource: OutputRenderSourceDelegate?
    private var currentRender: AudioFrame? {
        didSet {
            if currentRender == nil {
                currentRenderReadOffset = 0
            }
        }
    }

    private var isPlaying = false
    public func play() {
        if !isPlaying {
            isPlaying = true
            AudioOutputUnitStart(audioUnitForOutput)
        }
    }

    public func pause() {
        if isPlaying {
            isPlaying = false
            AudioOutputUnitStop(audioUnitForOutput)
        }
    }

    public var playbackRate: Float = 1
    public var volume: Float = 1
    public var isMuted: Bool = false
    public var latency = Float64(0)
    public init() {
        var descriptionForOutput = AudioComponentDescription()
        descriptionForOutput.componentType = kAudioUnitType_Output
        descriptionForOutput.componentManufacturer = kAudioUnitManufacturer_Apple
        #if os(macOS)
        descriptionForOutput.componentSubType = kAudioUnitSubType_HALOutput
        #else
        descriptionForOutput.componentSubType = kAudioUnitSubType_RemoteIO
        #endif
        let nodeForOutput = AudioComponentFindNext(nil, &descriptionForOutput)
        AudioComponentInstanceNew(nodeForOutput!, &audioUnitForOutput)
        var value = UInt32(1)
        AudioUnitSetProperty(audioUnitForOutput,
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
        AudioUnitSetProperty(audioUnitForOutput,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0,
                             &audioStreamBasicDescription,
                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        let channelLayout = audioFormat.channelLayout?.layout
        AudioUnitSetProperty(audioUnitForOutput,
                             kAudioUnitProperty_AudioChannelLayout,
                             kAudioUnitScope_Input, 0,
                             channelLayout,
                             UInt32(MemoryLayout<AudioChannelLayout>.size))
        var inputCallbackStruct = renderCallbackStruct()
        AudioUnitSetProperty(audioUnitForOutput,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input, 0,
                             &inputCallbackStruct,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        addRenderNotify(audioUnit: audioUnitForOutput)
        AudioUnitInitialize(audioUnitForOutput)
        var size = UInt32(MemoryLayout<Float64>.size)
        AudioUnitGetProperty(audioUnitForOutput,
                             kAudioUnitProperty_Latency,
                             kAudioUnitScope_Global, 0,
                             &latency,
                             &size)
    }

    public func flush() {
        currentRender = nil
    }

    deinit {
        AudioUnitUninitialize(audioUnitForOutput)
    }
}

extension AudioUnitPlayer {
    private func renderCallbackStruct() -> AURenderCallbackStruct {
        var inputCallbackStruct = AURenderCallbackStruct()
        inputCallbackStruct.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
        inputCallbackStruct.inputProc = { refCon, _, _, _, inNumberFrames, ioData in
            guard let ioData else {
                return noErr
            }
            let `self` = Unmanaged<AudioUnitPlayer>.fromOpaque(refCon).takeUnretainedValue()
            self.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(ioData), numberOfFrames: inNumberFrames)
            return noErr
        }
        return inputCallbackStruct
    }

    private func addRenderNotify(audioUnit: AudioUnit) {
        AudioUnitAddRenderNotify(audioUnit, { refCon, ioActionFlags, inTimeStamp, _, _, _ in
            let `self` = Unmanaged<AudioUnitPlayer>.fromOpaque(refCon).takeUnretainedValue()
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
                    if isMuted {
                        memset(destination + ioDataWriteOffset, 0, bytesToCopy)
                    } else {
                        (destination + ioDataWriteOffset).copyMemory(from: source + offset, byteCount: bytesToCopy)
                    }
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
