//
//  CacheDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation

public protocol SubtitleInfo: AnyObject {
    var userInfo: NSMutableDictionary? { get set }
    var subtitleDataSouce: SubtitleDataSouce? { get set }
    var name: String { get }
    var subtitleID: String { get }
    var comment: String? { get }
    func makeSubtitle(completion: @escaping (Result<KSSubtitleProtocol?, NSError>) -> Void)
}

public class URLSubtitleInfo: SubtitleInfo {
    public weak var subtitleDataSouce: SubtitleDataSouce?
    public let name: String
    public let subtitleID: String
    public var comment: String?
    public var downloadURL: URL?
    public var userInfo: NSMutableDictionary?
    public init(subtitleID: String, name: String) {
        self.subtitleID = subtitleID
        self.name = name
    }

    public func makeSubtitle(completion: @escaping (Result<KSSubtitleProtocol?, NSError>) -> Void) {
        let block = { (url: URL) in
            let subtitles = KSURLSubtitle()
            do {
                try subtitles.parse(url: url)
                completion(.success(subtitles))
            } catch {
                completion(.failure(error as NSError))
            }
        }
        if let downloadURL = downloadURL {
            block(downloadURL)
        } else if let subtitleDataSouce = subtitleDataSouce {
            subtitleDataSouce.fetchSubtitleDetail(info: self) { [weak self] _, error in
                guard let self = self else { return }
                if let error = error {
                    completion(.failure(error))
                } else if let downloadURL = self.downloadURL {
                    block(downloadURL)
                    if let cache = subtitleDataSouce as? SubtitletoCache {
                        cache.addCache(subtitleID: self.subtitleID, downloadURL: downloadURL)
                    }
                } else {
                    completion(.success(nil))
                }
            }
        } else {
            completion(.success(nil))
        }
    }
}

public protocol SubtitletoCache: AnyObject {
    var cache: CacheDataSouce? { get set }
}

public extension SubtitletoCache {
    func addCache(subtitleID: String, downloadURL: URL) {
        cache?.addCache(subtitleID: subtitleID, downloadURL: downloadURL)
    }
}

public protocol SubtitleDataSouce: AnyObject {
    func searchSubtitle(name: String, completion: @escaping ([SubtitleInfo]?) -> Void)
    func fetchSubtitleDetail(info: SubtitleInfo, completion: @escaping (SubtitleInfo, NSError?) -> Void)
}

public class CacheDataSouce: SubtitleDataSouce {
    private let cacheFolder = (NSTemporaryDirectory() as NSString).appendingPathComponent("KSSubtitleCache")
    private var srtCacheInfoPath: String
    // 因为plist不能保存URL
    private var srtInfoCaches = [String: String]()
    init() {
        if !FileManager.default.fileExists(atPath: cacheFolder) {
            try? FileManager.default.createDirectory(atPath: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        }
        srtCacheInfoPath = (cacheFolder as NSString).appendingPathComponent("KSSrtInfo.plist")
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
