//
//  SubtitleDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
public class EmptySubtitleInfo: SubtitleInfo {
    public let subtitleID: String = ""
    public var delay: TimeInterval = 0
    public let name = NSLocalizedString("no show subtitle", comment: "")
    public func search(for _: TimeInterval) -> [SubtitlePart] {
        []
    }

    public func subtitle(isEnabled _: Bool) {}
}

public class URLSubtitleInfo: KSSubtitle, SubtitleInfo {
    private var downloadURL: URL
    public var delay: TimeInterval = 0
    public private(set) var name: String
    public let subtitleID: String
    public var comment: String?
    public var userInfo: NSMutableDictionary?
    private let userAgent: String?
    public convenience init(url: URL) {
        self.init(subtitleID: url.absoluteString, name: url.lastPathComponent, url: url)
    }

    public init(subtitleID: String, name: String, url: URL, userAgent: String? = nil) {
        self.subtitleID = subtitleID
        self.name = name
        self.userAgent = userAgent
        downloadURL = url
        super.init()
        if !url.isFileURL, name.isEmpty {
            url.download(userAgent: userAgent) { [weak self] filename, tmpUrl in
                guard let self else {
                    return
                }
                self.name = filename
                self.downloadURL = tmpUrl
                var fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                fileURL.appendPathComponent(filename)
                try? FileManager.default.moveItem(at: tmpUrl, to: fileURL)
                self.downloadURL = fileURL
            }
        }
    }

    public func subtitle(isEnabled: Bool) {
        if isEnabled, parts.isEmpty {
            Task {
                try? await parse(url: downloadURL, userAgent: userAgent)
            }
        }
    }
}

public protocol SubtitleDataSouce: AnyObject {
    var infos: [any SubtitleInfo] { get }
}

public protocol SearchSubtitleDataSouce: SubtitleDataSouce {
    func searchSubtitle(url: URL) async throws
}

public extension KSOptions {
    static var subtitleDataSouces: [SubtitleDataSouce] = [DirectorySubtitleDataSouce()]
}

public extension SubtitleDataSouce {
    func addCache(subtitleID: String, downloadURL: URL) {
        CacheDataSouce.singleton.addCache(subtitleID: subtitleID, downloadURL: downloadURL)
    }
}

public class CacheDataSouce: SearchSubtitleDataSouce {
    public static let singleton = CacheDataSouce()
    public var infos = [any SubtitleInfo]()
    private let cacheFolder = (NSTemporaryDirectory() as NSString).appendingPathComponent("KSSubtitleCache")
    private var srtCacheInfoPath: String
    // 因为plist不能保存URL
    private var srtInfoCaches = [String: String]()
    private init() {
        if !FileManager.default.fileExists(atPath: cacheFolder) {
            try? FileManager.default.createDirectory(atPath: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        }
        srtCacheInfoPath = (cacheFolder as NSString).appendingPathComponent("KSSrtInfo.plist")
    }

    public func searchSubtitle(url: URL) async throws {
        infos.removeAll()
        srtCacheInfoPath = (cacheFolder as NSString).appendingPathComponent("KSSrtInfo_\(url.lastPathComponent).plist")
        if FileManager.default.fileExists(atPath: srtCacheInfoPath), let files = NSMutableDictionary(contentsOfFile: srtCacheInfoPath) as? [String: String] {
            srtInfoCaches = files.filter { FileManager.default.fileExists(atPath: $1) }
            if srtInfoCaches.isEmpty {
                infos = []
            } else {
                let array = srtInfoCaches.map { subtitleID, downloadURL -> (any SubtitleInfo) in
                    let info = URLSubtitleInfo(subtitleID: subtitleID, name: (downloadURL as NSString).lastPathComponent, url: URL(fileURLWithPath: downloadURL))
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
            infos = []
        }
    }

    public func addCache(subtitleID: String, downloadURL: URL) {
        srtInfoCaches[subtitleID] = downloadURL.path
        (srtInfoCaches as NSDictionary).write(toFile: srtCacheInfoPath, atomically: false)
    }
}

public class URLSubtitleDataSouce: SubtitleDataSouce {
    public let infos: [any SubtitleInfo]
    public init(urls: [URL]) {
        infos = urls.map { URLSubtitleInfo(url: $0) }
    }
}

public class DirectorySubtitleDataSouce: SearchSubtitleDataSouce {
    public var infos = [any SubtitleInfo]()
    public init() {}

    public func searchSubtitle(url: URL) async throws {
        infos.removeAll()
        if url.isFileURL {
            let subtitleURLs: [URL] = (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil).filter(\.isSubtitle)) ?? []
            let contents = subtitleURLs.map { URLSubtitleInfo(url: $0) }.sorted { left, right in
                left.name < right.name
            }
            infos.append(contentsOf: contents)
        }
    }
}

public class ShooterSubtitleDataSouce: SearchSubtitleDataSouce {
    public var infos = [any SubtitleInfo]()
    public init() {}
    public func searchSubtitle(url: URL) async throws {
        infos.removeAll()
        guard url.isFileURL, let url = URL(string: "https://www.shooter.cn/api/subapi.php")?
            .add(queryItems: ["format": "json", "pathinfo": url.path, "filehash": url.shooterFilehash])
        else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        json.forEach { sub in
            let filesDic = sub["Files"] as? [[String: String]]
//                let desc = sub["Desc"] as? String ?? ""
            let delay = TimeInterval(sub["Delay"] as? Int ?? 0) / 1000.0
            let result = filesDic?.compactMap { dic in
                if let string = dic["Link"], let url = URL(string: string) {
                    let info = URLSubtitleInfo(subtitleID: string, name: "", url: url)
                    info.delay = delay
                    return info
                }
                return nil
            } ?? [URLSubtitleInfo]()
            self.infos.append(contentsOf: result)
        }
    }
}

public class AssrtSubtitleDataSouce: SearchSubtitleDataSouce {
    private let token: String
    public var infos = [any SubtitleInfo]()
    public init(token: String) {
        self.token = token
    }

    public func searchSubtitle(url: URL) async throws {
        infos.removeAll()
        let query = url.deletingPathExtension().lastPathComponent
        guard let searchApi = URL(string: "https://api.assrt.net/v1/sub/search")?.add(queryItems: ["q": query]) else {
            return
        }
        var request = URLRequest(url: searchApi)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        guard let status = json["status"] as? Int, status == 0 else {
            return
        }
        guard let subDict = json["sub"] as? [String: Any], let subArray = subDict["subs"] as? [[String: Any]] else {
            return
        }
        for sub in subArray {
            if let assrtSubID = sub["id"] as? Int {
                try await infos.append(contentsOf: loadDetails(assrtSubID: String(assrtSubID)))
            }
        }
    }

    func loadDetails(assrtSubID: String) async throws -> [URLSubtitleInfo] {
        var infos = [URLSubtitleInfo]()
        guard let detailApi = URL(string: "https://api.assrt.net/v1/sub/detail")?.add(queryItems: ["id": assrtSubID]) else {
            return infos
        }
        var request = URLRequest(url: detailApi)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return infos
        }
        guard let status = json["status"] as? Int, status == 0 else {
            return infos
        }
        guard let subDict = json["sub"] as? [String: Any], let subArray = subDict["subs"] as? [[String: Any]], let sub = subArray.first else {
            return infos
        }
        if let fileList = sub["filelist"] as? [[String: String]] {
            fileList.forEach { dic in
                if let urlString = dic["url"], let filename = dic["f"], let url = URL(string: urlString) {
                    let info = URLSubtitleInfo(subtitleID: urlString, name: filename, url: url)
                    infos.append(info)
                }
            }
        } else if let urlString = sub["url"] as? String, let filename = sub["filename"] as? String, let url = URL(string: urlString) {
            let info = URLSubtitleInfo(subtitleID: urlString, name: filename, url: url)
            infos.append(info)
        }
        return infos
    }
}

extension URL {
    public var components: URLComponents? {
        URLComponents(url: self, resolvingAgainstBaseURL: true)
    }

    func add(queryItems: [String: String]) -> URL? {
        guard var urlComponents = components else {
            return nil
        }
        var reserved = CharacterSet.urlQueryAllowed
        reserved.remove(charactersIn: ": #[]@!$&'()*+, ;=")
        urlComponents.percentEncodedQueryItems = queryItems.compactMap { key, value in
            URLQueryItem(name: key.addingPercentEncoding(withAllowedCharacters: reserved) ?? key, value: value.addingPercentEncoding(withAllowedCharacters: reserved))
        }
        return urlComponents.url
    }

    var shooterFilehash: String {
        let file: FileHandle
        do {
            file = try FileHandle(forReadingFrom: self)
        } catch {
            return ""
        }
        defer { file.closeFile() }

        file.seekToEndOfFile()
        let fileSize: UInt64 = file.offsetInFile

        guard fileSize >= 12288 else {
            return ""
        }

        let offsets: [UInt64] = [
            4096,
            fileSize / 3 * 2,
            fileSize / 3,
            fileSize - 8192,
        ]

        let hash = offsets.map { offset -> String in
            file.seek(toFileOffset: offset)
            return file.readData(ofLength: 4096).md5()
        }.joined(separator: ";")
        return hash
    }
}

import CryptoKit

public extension Data {
    func md5() -> String {
        let digestData = Insecure.MD5.hash(data: self)
        return String(digestData.map { String(format: "%02hhx", $0) }.joined().prefix(32))
    }
}
