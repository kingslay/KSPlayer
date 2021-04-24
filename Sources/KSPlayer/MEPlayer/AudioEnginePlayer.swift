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

import AVFoundation

final class AudioEnginePlayer: FrameOutput {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private let mixer = AVAudioMixerNode()
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
        let format = KSPlayerManager.audioDefaultFormat
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.start()
    }

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, completionHandler: AVAudioNodeCompletionHandler? = nil) {
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else {
                return
            }
            let audioFrame = self.renderSource?.getOutputRender(type: .audio) as? AudioFrame
        }
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
