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

    public func disableSubtitle() {
        if isImageSubtitle {
            setIsEnabled(false)
        }
    }

    public func enableSubtitle(completion: @escaping (Result<KSSubtitleProtocol, NSError>) -> Void) {
        setIsEnabled(true)
        completion(.success(self))
    }
}

extension FFmpegAssetTrack: KSSubtitleProtocol {
    public func search(for time: TimeInterval) -> SubtitlePart? {
        let time = time + startTime
        return subtitle?.outputRenderQueue.pop { item -> Bool in
            item.part < time || item.part == time
        }?.part
    }
}

extension KSMEPlayer: SubtitleDataSouce {
    public var infos: [SubtitleInfo]? {
        tracks(mediaType: .subtitle) as? [FFmpegAssetTrack]
    }

    public func searchSubtitle(name _: String, completion: @escaping (() -> Void)) {
        completion()
    }
}
