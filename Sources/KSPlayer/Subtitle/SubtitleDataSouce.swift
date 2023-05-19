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
    public func search(for _: TimeInterval) -> SubtitlePart? {
        nil
    }

    public func subtitle(isEnabled _: Bool) {}
}

public class URLSubtitleInfo: SubtitleInfo {
    private var subtitles: KSURLSubtitle?
//    private let fetchSubtitleDetail: (((NSError?) -> Void) -> Void)?
    private var downloadURL: URL
    public var delay: TimeInterval = 0
    public private(set) var name: String
    public let subtitleID: String
    public var comment: String?
    public var userInfo: NSMutableDictionary?
    public convenience init(url: URL) {
        self.init(subtitleID: url.absoluteString, name: url.lastPathComponent, url: url)
    }

    public init(subtitleID: String, name: String, url: URL) {
        self.subtitleID = subtitleID
        self.name = name
        downloadURL = url
        if !url.isFileURL {
            URLSession.shared.downloadTask(with: url) { [weak self] url, response, _ in
                guard let self, let url, let response = response as? HTTPURLResponse else {
                    return
                }
                let httpFileName = "attachment; filename="
                if var filename = response.value(forHTTPHeaderField: "Content-Disposition"), filename.hasPrefix(httpFileName) {
                    filename.removeFirst(httpFileName.count)
                    self.name = filename
                }
                // 下载的临时文件要马上就用。不然可能会马上被清空
                self.downloadURL = url
                let subtitles = KSURLSubtitle()
                do {
                    try subtitles.parse(url: url)
                } catch {}

                self.subtitles = subtitles
            }.resume()
        }
    }

    public func search(for time: TimeInterval) -> SubtitlePart? {
        subtitles?.search(for: time)
    }

    public func subtitle(isEnabled: Bool) {
        if isEnabled, subtitles == nil {
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                do {
                    let subtitles = KSURLSubtitle()
                    try subtitles.parse(url: self.downloadURL)
                    self.subtitles = subtitles
                } catch {}
            }
        }
    }
}

public protocol SubtitleDataSouce: AnyObject {
    var infos: [any SubtitleInfo] { get }
}

public protocol SearchSubtitleDataSouce: SubtitleDataSouce {
    func searchSubtitle(url: URL, completion: @escaping (() -> Void))
}

extension KSOptions {
    static var subtitleDataSouces: [SubtitleDataSouce] = [DirectorySubtitleDataSouce(), ShooterSubtitleDataSouce()]
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

    public func searchSubtitle(url: URL, completion: @escaping (() -> Void)) {
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
        completion()
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

    public func searchSubtitle(url: URL, completion: @escaping (() -> Void)) {
        infos.removeAll()
        if url.isFileURL {
            let subtitleURLs: [URL] = (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil).filter(\.isSubtitle)) ?? []
            infos.append(contentsOf: subtitleURLs.map { URLSubtitleInfo(url: $0) })
        }
        completion()
    }
}

public class ShooterSubtitleDataSouce: SearchSubtitleDataSouce {
    public var infos = [any SubtitleInfo]()
    public func searchSubtitle(url: URL, completion: @escaping (() -> Void)) {
        infos.removeAll()
        guard url.isFileURL, let url = URL(string: "https://www.shooter.cn/api/subapi.php")?
            .add(queryItems: ["format": "json", "pathinfo": url.path, "filehash": url.shooterFilehash])
        else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data, let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }
            json.forEach { sub in
                let filesDic = sub["Files"] as? [[String: String]]
                let desc = sub["Desc"] as? String ?? ""
                let delay = TimeInterval(sub["Delay"] as? Int ?? 0) / 1000.0
                let result = filesDic?.compactMap { dic in
                    if let string = dic["Link"], let url = URL(string: string) {
                        let info = URLSubtitleInfo(url: url)
                        info.delay = delay
                        return info
                    }
                    return nil
                } ?? [URLSubtitleInfo]()
                self.infos.append(contentsOf: result)
            }
            DispatchQueue.main.async(execute: completion)
        }.resume()
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
            return (file.readData(ofLength: 4096) as NSData).md5()
        }.joined(separator: ";")
        return hash
    }
}

import CommonCrypto
extension NSData {
    func md5() -> String {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        let md5Buffer = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLength)

        CC_MD5(bytes, CC_LONG(length), md5Buffer)

        let output = NSMutableString(capacity: Int(CC_MD5_DIGEST_LENGTH * 2))
        for i in 0 ..< digestLength {
            output.appendFormat("%02x", md5Buffer[i])
        }

        md5Buffer.deallocate()
        return NSString(format: output) as String
    }
}
