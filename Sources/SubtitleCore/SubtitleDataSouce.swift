//
//  CacheDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation

@objc public protocol SubtitleInfo {
    var userInfo: NSMutableDictionary? { get set }
    var subtitleDataSouce: SubtitleDataSouce? { get set }
    var name: String { get }
    var subtitleID: String { get }
    var comment: String? { get }
}

public protocol MakeSubtitle {
    func makeSubtitle(completion: @escaping (KSSubtitleProtocol?, Error?) -> Void)
}

@objc public class URLSubtitleInfo: NSObject, SubtitleInfo {
    public weak var subtitleDataSouce: SubtitleDataSouce?
    @objc public let name: String
    @objc public let subtitleID: String
    @objc public var comment: String?
    @objc public var downloadURL: URL?
    @objc public var userInfo: NSMutableDictionary?
    @objc public init(subtitleID: String, name: String) {
        self.subtitleID = subtitleID
        self.name = name
    }
}

extension URLSubtitleInfo: MakeSubtitle {
    public func makeSubtitle(completion: @escaping (KSSubtitleProtocol?, Error?) -> Void) {
        let block = { (url: URL) in
            let subtitles = KSURLSubtitle()
            do {
                try subtitles.parse(url: url)
                completion(subtitles, nil)
            } catch {
                completion(nil, error)
            }
        }
        if let downloadURL = downloadURL {
            block(downloadURL)
        } else if let subtitleDataSouce = subtitleDataSouce {
            subtitleDataSouce.fetchSubtitleDetail(info: self) { [weak self] _, error in
                guard let `self` = self else { return }
                if let error = error {
                    completion(nil, error)
                } else if let downloadURL = self.downloadURL {
                    block(downloadURL)
                    if let cache = subtitleDataSouce as? SubtitletoCache {
                        cache.addCache(subtitleID: self.subtitleID, downloadURL: downloadURL)
                    }
                } else {
                    completion(nil, error)
                }
            }
        } else {
            completion(nil, nil)
        }
    }
}

@objc public protocol SubtitletoCache {
    weak var cache: CacheDataSouce? { get set }
}

extension SubtitletoCache {
    public func addCache(subtitleID: String, downloadURL: URL) {
        cache?.addCache(subtitleID: subtitleID, downloadURL: downloadURL)
    }
}

@objc public protocol SubtitleDataSouce {
    func searchSubtitle(name: String, completion: @escaping ([SubtitleInfo]?) -> Void)
    func fetchSubtitleDetail(info: SubtitleInfo, completion: @escaping (SubtitleInfo, NSError?) -> Void)
}

@objc public class CacheDataSouce: NSObject, SubtitleDataSouce {
    private let cacheFolder = (NSTemporaryDirectory() as NSString).appendingPathComponent("KSSubtitleCache")
    private var srtCacheInfoPath: String
    // 因为plist不能保存URL
    private var srtInfoCaches = [String: String]()
    override init() {
        if !FileManager.default.fileExists(atPath: cacheFolder) {
            try? FileManager.default.createDirectory(atPath: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        }
        srtCacheInfoPath = (cacheFolder as NSString).appendingPathComponent("KSSrtInfo.plist")
        super.init()
    }

    public func searchSubtitle(name: String, completion: @escaping ([SubtitleInfo]?) -> Void) {
        srtCacheInfoPath = (cacheFolder as NSString).appendingPathComponent("KSSrtInfo_\(name).plist")
        if FileManager.default.fileExists(atPath: srtCacheInfoPath), let infos = NSMutableDictionary(contentsOfFile: srtCacheInfoPath) as? [String: String] {
            srtInfoCaches = infos.filter { FileManager.default.fileExists(atPath: $1) }
            if !srtInfoCaches.isEmpty {
                let array = srtInfoCaches.map { subtitleID, downloadURL -> SubtitleInfo in
                    let info = URLSubtitleInfo(subtitleID: subtitleID, name: (downloadURL as NSString).lastPathComponent)
                    info.downloadURL = URL(fileURLWithPath: downloadURL)
                    info.comment = "本地"
                    info.subtitleDataSouce = self
                    return info
                }
                completion(array)
            } else {
                completion(nil)
            }
            if srtInfoCaches.count != infos.count {
                (srtInfoCaches as NSDictionary).write(toFile: srtCacheInfoPath, atomically: false)
            }
        } else {
            srtInfoCaches = [String: String]()
            completion(nil)
        }
    }

    public func fetchSubtitleDetail(info _: SubtitleInfo, completion _: @escaping (SubtitleInfo, NSError?) -> Void) {}

    public func addCache(subtitleID: String, downloadURL: URL) {
        srtInfoCaches[subtitleID] = downloadURL.path
        (srtInfoCaches as NSDictionary).write(toFile: srtCacheInfoPath, atomically: false)
    }
}
