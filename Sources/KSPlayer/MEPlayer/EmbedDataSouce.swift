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
    public var subtitleID: String {
        String(trackID)
    }
}

extension FFmpegAssetTrack: KSSubtitleProtocol {
    public func search(for time: TimeInterval) -> [SubtitlePart] {
        if isImageSubtitle {
            let part = subtitle?.outputRenderQueue.pop { item, _ -> Bool in
                item.part < time || item.part == time
            }?.part
            if let part {
                return [part]
            } else {
                return []
            }
        } else {
            return subtitle?.outputRenderQueue.search { item -> Bool in
                item.part == time
            }.map(\.part) ?? []
        }
    }
}

extension KSMEPlayer: SubtitleDataSouce {
    public var infos: [any SubtitleInfo] {
        tracks(mediaType: .subtitle).compactMap { $0 as? (any SubtitleInfo) }
    }
}
