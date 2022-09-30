//
//  CacheDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation

public class URLSubtitleInfo: SubtitleInfo {
    public let name: String
    public let subtitleID: String
    public var comment: String?
    public var downloadURL: URL?
    public var userInfo: NSMutableDictionary?
    private let fetchSubtitleDetail: (((NSError?) -> Void) -> Void)?
    public init(subtitleID: String, name: String, fetchSubtitleDetail: (((NSError?) -> Void) -> Void)? = nil) {
        self.subtitleID = subtitleID
        self.name = name
        self.fetchSubtitleDetail = fetchSubtitleDetail
    }

    public func disableSubtitle() {}

    public func enableSubtitle(completion: @escaping (Result<KSSubtitleProtocol, NSError>) -> Void) {
        let block = { (url: URL) in
            let subtitles = KSURLSubtitle()
            do {
                try subtitles.parse(url: url)
                completion(.success(subtitles))
            } catch {
                completion(.failure(error as NSError))
            }
        }
        if let downloadURL {
            block(downloadURL)
        } else if let fetchSubtitleDetail {
            fetchSubtitleDetail { [weak self] error in
                guard let self else { return }
                if let error {
                    completion(.failure(error))
                } else {
                    if let downloadURL = self.downloadURL {
                        block(downloadURL)
                    } else {
                        completion(.failure(NSError(errorCode: .subtitleParamsEmpty)))
                    }
                }
            }
        } else {
            completion(.failure(NSError(errorCode: .subtitleParamsEmpty)))
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
    var infos: [SubtitleInfo]? { get }
    func searchSubtitle(name: String, completion: @escaping (() -> Void))
}

public class CacheDataSouce: SubtitleDataSouce {
    public var infos: [SubtitleInfo]?
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

    public func searchSubtitle(name: String, completion: @escaping (() -> Void)) {
        srtCacheInfoPath = (cacheFolder as NSString).appendingPathComponent("KSSrtInfo_\(name).plist")
        if FileManager.default.fileExists(atPath: srtCacheInfoPath), let files = NSMutableDictionary(contentsOfFile: srtCacheInfoPath) as? [String: String] {
            srtInfoCaches = files.filter { FileManager.default.fileExists(atPath: $1) }
            if srtInfoCaches.isEmpty {
                infos = nil
            } else {
                let array = srtInfoCaches.map { subtitleID, downloadURL -> SubtitleInfo in
                    let info = URLSubtitleInfo(subtitleID: subtitleID, name: (downloadURL as NSString).lastPathComponent)
                    info.downloadURL = URL(fileURLWithPath: downloadURL)
                    info.comment = "本地"
                    return info
                }
                infos = array
            }
            if srtInfoCaches.count != files.count {
                (srtInfoCaches as NSDictionary).write(toFile: srtCacheInfoPath, atomically: false)
            }
        } else {
            srtInfoCaches = [String: String]()
            infos = nil
        }
        completion()
    }

    public func addCache(subtitleID: String, downloadURL: URL) {
        srtInfoCaches[subtitleID] = downloadURL.path
        (srtInfoCaches as NSDictionary).write(toFile: srtCacheInfoPath, atomically: false)
    }
}
