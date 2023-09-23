//
//  AudioRecognizer.swift
//  KSPlayer
//
//  Created by kintan on 2023/9/23.
//

import Foundation
import Speech

public class AudioRecognizer {
    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest
    private let speechRecognizer: SFSpeechRecognizer
    public init(locale: Locale, handler: @escaping (String) -> Void) {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        speechRecognizer = SFSpeechRecognizer(locale: locale)!
        let recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, _ in
            if let result {
                let text = result.bestTranscription.formattedString
                handler(text)
            }
        }
    }

    func append(frame: AudioFrame) {
        if let sampleBuffer = frame.toCMSampleBuffer() {
            recognitionRequest.appendAudioSampleBuffer(sampleBuffer)
        }
    }
}
