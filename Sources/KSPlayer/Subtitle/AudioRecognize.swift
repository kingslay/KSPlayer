//
//  AudioRecognize.swift
//  KSPlayer
//
//  Created by kintan on 2023/9/23.
//

import Foundation

public protocol AudioRecognize: SubtitleInfo {
    func append(frame: AudioFrame)
}
