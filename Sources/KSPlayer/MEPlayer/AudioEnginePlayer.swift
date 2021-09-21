//
//  AudioOutput.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import AudioToolbox
import AVFoundation
import CoreAudio
import CoreMedia
import QuartzCore

final class AudioEnginePlayer: AudioPlayer, FrameOutput {
    var attackTime: Float = 0

    var releaseTime: Float = 0

    var threshold: Float = 0

    var expansionRatio: Float = 0

    var overallGain: Float = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private let mixer = AVAudioMixerNode()
    private let format = KSPlayerManager.audioDefaultFormat
    weak var renderSource: OutputRenderSourceDelegate?

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

    var playbackRate: Float {
        get {
            pitch.rate
        }
        set {
            pitch.rate = min(32, max(1.0 / 32.0, newValue))
        }
    }

    var volume: Float {
        get {
            mixer.volume
        }
        set {
            mixer.volume = newValue
        }
    }

    public var isMuted: Bool {
        get {
            mixer.outputVolume == 0.0
        }
        set {
            mixer.outputVolume = newValue ? 0.0 : 1.0
        }
    }

    init() {
        engine.attach(player)
        engine.attach(pitch)
        engine.attach(mixer)
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.start()
        schedule()
    }

    func schedule() {
        guard let audioFrame = renderSource?.getOutputRender(type: .audio) as? AudioFrame else {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.schedule()
            }
            return
        }
        guard let buffer = format.toPCMBuffer(frame: audioFrame) else {
            return
        }
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else {
                return
            }
            self.schedule()
        }
    }
}

extension AVAudioFormat {
    func toPCMBuffer(frame: AudioFrame) -> AVAudioPCMBuffer? {
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self, frameCapacity: UInt32(frame.dataWrap.size[0]) / streamDescription.pointee.mBytesPerFrame) else {
            return nil
        }
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        for i in 0 ..< min(Int(pcmBuffer.format.channelCount), frame.dataWrap.size.count) {
            frame.dataWrap.data[i]?.withMemoryRebound(to: Float.self, capacity: Int(pcmBuffer.frameCapacity)) { srcFloatsForChannel in
                pcmBuffer.floatChannelData?[i].assign(from: srcFloatsForChannel, count: Int(pcmBuffer.frameCapacity))
            }
        }
        return pcmBuffer
    }
}
