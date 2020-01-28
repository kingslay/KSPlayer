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
    private let semaphore = DispatchSemaphore(value: 1)
    private var currentRenderReadOffset = Int(0)
    private var audioTime = CMTime.zero
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

    func play() {
        audioPlayer.play()
    }

    func pause() {
        audioPlayer.pause()
    }

    func flush() {
        semaphore.wait()
        currentRender = nil
        audioTime = CMTime.invalid
        semaphore.signal()
    }

    func shutdown() {
        semaphore.wait()
        currentRender = nil
        audioTime = CMTime.zero
        semaphore.signal()
    }
}

extension AudioOutput: AudioPlayerDelegate {
    func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfSamples: UInt32, numberOfChannels: UInt32) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        var ioDataWriteOffset = 0
        var numberOfSamples = Int(numberOfSamples)
        while numberOfSamples > 0 {
            if currentRender == nil {
                currentRender = renderSource?.getOutputRender(type: .audio) as? AudioFrame
            }
            guard let currentRender = currentRender, currentRender.linesize[0] > currentRenderReadOffset else {
                self.currentRender = nil
                return
            }
            if ioDataWriteOffset == 0 {
                let currentPreparePosition = currentRender.position + currentRender.duration * Int64(currentRenderReadOffset) / Int64(currentRender.linesize[0])
                audioTime = currentRender.timebase.cmtime(for: currentPreparePosition)
            }
            let residueLinesize = Int(currentRender.linesize[0]) - currentRenderReadOffset
            let bytesToCopy = min(numberOfSamples * MemoryLayout<Float>.size, residueLinesize)
            for i in 0 ..< min(ioData.count, Int(numberOfChannels)) {
                (ioData[i].mData! + ioDataWriteOffset).copyMemory(from: currentRender.data[i]! + currentRenderReadOffset, byteCount: bytesToCopy)
            }
            numberOfSamples -= bytesToCopy / MemoryLayout<Float>.size
            ioDataWriteOffset += bytesToCopy
            if bytesToCopy == residueLinesize {
                self.currentRender = nil
            } else {
                currentRenderReadOffset += bytesToCopy
            }
        }
    }

    func audioPlayerWillRenderSample(sampleTimestamp _: AudioTimeStamp) {}

    func audioPlayerDidRenderSample(sampleTimestamp _: AudioTimeStamp) {
        if audioTime.isValid {
            renderSource?.setAudio(time: audioTime)
        }
    }
}
