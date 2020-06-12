//
//  AudioOutput.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AudioToolbox
import CoreAudio
import CoreMedia
import QuartzCore

final class AudioOutput: FrameOutput {
    var isPaused: Bool {
        get {
            audioPlayer.isPaused
        }
        set {
            audioPlayer.isPaused = newValue
        }
    }

    private let semaphore = DispatchSemaphore(value: 1)
    private var currentRenderReadOffset = 0
    private var currentRender: AudioFrame? {
        didSet {
            if currentRender == nil {
                currentRenderReadOffset = 0
            }
        }
    }

    weak var renderSource: OutputRenderSourceDelegate?
    let audioPlayer: AudioPlayer = AudioGraphPlayer()

    init() {
        audioPlayer.delegate = self
    }

    func clear() {
        semaphore.wait()
        currentRender = nil
        semaphore.signal()
    }
}

extension AudioOutput: AudioPlayerDelegate {
    func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfFrames: UInt32, numberOfChannels _: UInt32) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        var ioDataWriteOffset = 0
        var numberOfSamples = Int(numberOfFrames)
        while numberOfSamples > 0 {
            if currentRender == nil {
                currentRender = renderSource?.getOutputRender(type: .audio) as? AudioFrame
            }
            guard let currentRender = currentRender else {
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
            for i in 0 ..< min(ioData.count, currentRender.dataWrap.data.count) {
                (ioData[i].mData! + ioDataWriteOffset).copyMemory(from: currentRender.dataWrap.data[i]! + offset, byteCount: bytesToCopy)
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

    func audioPlayerWillRenderSample(sampleTimestamp _: AudioTimeStamp) {}

    func audioPlayerDidRenderSample(sampleTimestamp _: AudioTimeStamp) {
        if let currentRender = currentRender {
            let currentPreparePosition = currentRender.position + currentRender.duration * Int64(currentRenderReadOffset) / Int64(currentRender.numberOfSamples)
            renderSource?.setAudio(time: currentRender.timebase.cmtime(for: currentPreparePosition))
        }
    }
}
