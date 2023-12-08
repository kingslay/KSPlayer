//
//  AudioRendererPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2022/12/2.
//

import AVFoundation
import Foundation

public class AudioRendererPlayer: AudioOutput {
    public var playbackRate: Float = 1 {
        didSet {
            if !isPaused {
                synchronizer.rate = playbackRate
            }
        }
    }

    public var volume: Float {
        get {
            renderer.volume
        }
        set {
            renderer.volume = newValue
        }
    }

    public var isMuted: Bool {
        get {
            renderer.isMuted
        }
        set {
            renderer.isMuted = newValue
        }
    }

    public weak var renderSource: OutputRenderSourceDelegate?
    private var periodicTimeObserver: Any?
    private let renderer = AVSampleBufferAudioRenderer()
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private let serializationQueue = DispatchQueue(label: "ks.player.serialization.queue")
    var isPaused: Bool {
        synchronizer.rate == 0
    }

    public required init() {
        synchronizer.addRenderer(renderer)
        if #available(macOS 11.3, iOS 14.5, tvOS 14.5, *) {
            synchronizer.delaysRateChangeUntilHasSufficientMediaData = false
        }
//        if #available(tvOS 15.0, iOS 15.0, macOS 12.0, *) {
//            renderer.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
//        }
    }

    public func prepare(audioFormat _: AVAudioFormat) {}

    public func play(time: TimeInterval) {
        synchronizer.setRate(playbackRate, time: CMTime(seconds: time))
        renderer.requestMediaDataWhenReady(on: serializationQueue) { [weak self] in
            guard let self else {
                return
            }
            self.request()
        }
        periodicTimeObserver = synchronizer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: .main) { [weak self] time in
            guard let self else {
                return
            }
            self.renderSource?.setAudio(time: time, position: -1)
        }
    }

    public func pause() {
        synchronizer.rate = 0
        renderer.stopRequestingMediaData()
        if let periodicTimeObserver {
            synchronizer.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
    }

    public func flush() {
        renderer.flush()
    }

    private func request() {
        while renderer.isReadyForMoreMediaData, !isPaused {
            guard var render = renderSource?.getAudioOutputRender() else {
                break
            }
            var array = [render]
            let loopCount = Int32(render.audioFormat.sampleRate) / 20 / Int32(render.numberOfSamples) - 1
            if loopCount > 0 {
                for _ in 0 ..< loopCount {
                    if let render = renderSource?.getAudioOutputRender() {
                        array.append(render)
                    }
                }
            }
            if array.count > 1 {
                render = AudioFrame(array: array)
            }
            if let sampleBuffer = render.toCMSampleBuffer() {
                renderer.audioTimePitchAlgorithm = render.audioFormat.channelCount > 2 ? .spectral : .timeDomain
                renderer.enqueue(sampleBuffer)
            }
        }
    }
}
