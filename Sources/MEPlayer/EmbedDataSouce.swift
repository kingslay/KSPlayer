//
//  CacheDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import ffmpeg
import Foundation
public class EmbedSubtitleInfo: SubtitleInfo {
    private let subtitle: SubtitlePlayerItemTrack
    public var userInfo: NSMutableDictionary?
    public weak var subtitleDataSouce: SubtitleDataSouce?
    public let name: String
    public let subtitleID: String
    public var comment: String?
    init(subtitleID: String, name: String, subtitle: SubtitlePlayerItemTrack) {
        self.subtitleID = subtitleID
        self.name = name
        self.subtitle = subtitle
    }
}

extension EmbedSubtitleInfo: MakeSubtitle {
    public func makeSubtitle(completion: @escaping ((Result<KSSubtitleProtocol, NSError>) -> Void)) {
        completion(.success(subtitle))
    }
}

extension SubtitlePlayerItemTrack: KSSubtitleProtocol {
    func search(for time: TimeInterval) -> NSAttributedString? {
        let frame = getOutputRender { item -> Bool in
            if let subtitle = item as? SubtitleFrame, let part = subtitle.part {
                return part == time
            }
            return false
        }
        if let frame = frame as? SubtitleFrame {
            return frame.part?.text
        }
        return nil
    }
}

extension MEPlayerItem: SubtitleDataSouce {
    func searchSubtitle(name: String, completion: @escaping ([SubtitleInfo]?) -> Void) {
        let infos = subtitleTracks.map { subtitleDecompress -> SubtitleInfo in
            var name = NSLocalizedString("内置字幕", comment: "")
            if let entry = av_dict_get(subtitleDecompress.stream.pointee.metadata, "title", nil, 0), let title = entry.pointee.value {
                name = String(cString: title)
            }
            let info = EmbedSubtitleInfo(subtitleID: "Embed-\(subtitleDecompress.stream.pointee.index)", name: name, subtitle: subtitleDecompress)
            return info
        }
        completion(infos)
    }

    func fetchSubtitleDetail(info _: SubtitleInfo, completion _: @escaping (SubtitleInfo, NSError?) -> Void) {}
}
