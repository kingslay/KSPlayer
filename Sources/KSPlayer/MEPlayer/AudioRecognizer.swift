//
//  AudioRecognizer.swift
//  KSPlayer
//
//  Created by kintan on 2023/9/23.
//

import Foundation

#if enableFeatureAudioRecognizer && canImport(Speech)
import Speech
#endif

public class AudioRecognizer {
    #if enableFeatureAudioRecognizer && canImport(Speech)
    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest
    private let speechRecognizer: SFSpeechRecognizer
    #endif
    public init(locale: Locale, handler: @escaping (String) -> Void) {
        #if enableFeatureAudioRecognizer && canImport(Speech)
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        speechRecognizer = SFSpeechRecognizer(locale: locale)!
        _ = speechRecognizer.recognitionTask(with: recognitionRequest) { result, _ in
            if let result {
                let text = result.bestTranscription.formattedString
                handler(text)
            }
        }
        #endif
    }

    func append(frame: AudioFrame) {
        #if enableFeatureAudioRecognizer && canImport(Speech)
        if let sampleBuffer = frame.toCMSampleBuffer() {
            recognitionRequest.appendAudioSampleBuffer(sampleBuffer)
        }
        #endif
    }
}
