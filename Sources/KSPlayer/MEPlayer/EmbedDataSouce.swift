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
    let subtitle: FFPlayerItemTrack<SubtitleFrame>
    private let isImageSubtitle: Bool
    public var userInfo: NSMutableDictionary?
    public weak var subtitleDataSouce: SubtitleDataSouce?
    public let name: String
    public let subtitleID: String
    public var comment: String?
    init(subtitleID: String, name: String, subtitle: FFPlayerItemTrack<SubtitleFrame>, isImageSubtitle: Bool) {
        self.subtitleID = subtitleID
        self.name = name
        self.subtitle = subtitle
        self.isImageSubtitle = isImageSubtitle
    }

    public func enableSubtitle(completion: @escaping (Result<KSSubtitleProtocol, NSError>) -> Void) {
        completion(.success(self))
    }

    public static func == (lhs: EmbedSubtitleInfo, rhs: EmbedSubtitleInfo) -> Bool {
        lhs.subtitleID == rhs.subtitleID
    }
}

extension EmbedSubtitleInfo: KSSubtitleProtocol {
    public func search(for time: TimeInterval) -> SubtitlePart? {
        let frame: MEFrame?
        if isImageSubtitle {
            frame = subtitle.outputRenderQueue.pop { item -> Bool in
                item.part < time || item.part == time
            }
        } else {
            frame = subtitle.outputRenderQueue.search { item -> Bool in
                item.part == time
            }
        }
        if let frame = frame as? SubtitleFrame {
            return frame.part
        }
        return nil
    }
}

extension MEPlayerItem: SubtitleDataSouce {
    func searchSubtitle(name _: String, completion: @escaping ([SubtitleInfo]?) -> Void) {
        let infos = assetTracks.filter { $0.mediaType == .subtitle }.flatMap(\.subtitle)
        completion(infos)
    }

    func fetchSubtitleDetail(info _: SubtitleInfo, completion _: @escaping (SubtitleInfo, NSError?) -> Void) {}
}
