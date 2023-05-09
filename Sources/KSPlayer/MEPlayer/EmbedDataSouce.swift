//
//  CacheDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
import Libavcodec
import Libavutil

extension FFmpegAssetTrack: SubtitleInfo {
    public func subtitle(isEnabled: Bool) {
        if isImageSubtitle {
            self.isEnabled = isEnabled
        }
    }

    public var subtitleID: String {
        String(trackID)
    }
}

extension FFmpegAssetTrack: KSSubtitleProtocol {
    public func search(for time: TimeInterval) -> SubtitlePart? {
        if isImageSubtitle {
            return subtitle?.outputRenderQueue.pop { item -> Bool in
                item.part < time || item.part == time
            }?.part
        } else {
            return subtitle?.outputRenderQueue.search { item -> Bool in
                item.part == time
            }?.part
        }
    }
}

extension KSMEPlayer: SubtitleDataSouce {
    public var infos: [any SubtitleInfo] {
        tracks(mediaType: .subtitle).compactMap { $0 as? (any SubtitleInfo) }
    }
}
