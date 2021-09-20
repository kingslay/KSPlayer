//
//  CacheDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
import Libavcodec
import Libavutil
public class EmbedSubtitleInfo: SubtitleInfo {
    private let subtitle: FFPlayerItemTrack<SubtitleFrame>
    public var userInfo: NSMutableDictionary?
    public weak var subtitleDataSouce: SubtitleDataSouce?
    public let name: String
    public let subtitleID: String
    public var comment: String?
    init(subtitleID: String, name: String, subtitle: FFPlayerItemTrack<SubtitleFrame>) {
        self.subtitleID = subtitleID
        self.name = name
        self.subtitle = subtitle
    }

    public func makeSubtitle(completion: @escaping (Result<KSSubtitleProtocol?, NSError>) -> Void) {
        completion(.success(subtitle))
    }
}

extension FFPlayerItemTrack: KSSubtitleProtocol {
    func search(for time: TimeInterval) -> SubtitlePart? {
        let frame = getOutputRender { item -> Bool in
            if let subtitle = item as? SubtitleFrame {
                return subtitle.part == time
            }
            return false
        }
        if let frame = frame as? SubtitleFrame {
            return frame.part
        }
        return nil
    }
}

extension MEPlayerItem: SubtitleDataSouce {
    func searchSubtitle(name _: String, completion: @escaping ([SubtitleInfo]?) -> Void) {
        let infos = subtitleTracks.map { subtitleDecompress -> SubtitleInfo in
            EmbedSubtitleInfo(subtitleID: "Embed-\(subtitleDecompress.assetTrack.streamIndex)", name: subtitleDecompress.assetTrack.name, subtitle: subtitleDecompress)
        }
        completion(infos)
    }

    func fetchSubtitleDetail(info _: SubtitleInfo, completion _: @escaping (SubtitleInfo, NSError?) -> Void) {}
}
