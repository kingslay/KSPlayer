//
//  MovieModel.swift
//  TracyPlayer
//
//  Created by kintan on 2023/2/2.
//

import CoreData
import Foundation
import KSPlayer
class MEOptions: KSOptions {
    static var isUseDisplayLayer = true
    override init() {
        super.init()
        formatContextOptions["reconnect_on_network_error"] = 1
    }

    override func process(assetTrack: some MediaPlayerTrack) {
        if assetTrack.mediaType == .video {
            if [FFmpegFieldOrder.bb, .bt, .tt, .tb].contains(assetTrack.fieldOrder) {
                videoFilters.append("yadif=mode=0:parity=-1:deint=1")
                hardwareDecode = false
            }
        }
    }

    override func isUseDisplayLayer() -> Bool {
        MEOptions.isUseDisplayLayer && display == .plane
    }

    #if os(tvOS)
    override open func preferredDisplayCriteria(refreshRate: Float, videoDynamicRange: Int32) -> AVDisplayCriteria? {
        AVDisplayCriteria(refreshRate: refreshRate, videoDynamicRange: videoDynamicRange)
    }
    #endif
}

extension CodingUserInfoKey {
    static let managedObjectContext = CodingUserInfoKey(rawValue: "managedObjectContext")!
}

@objc(PlayModel)
public class PlayModel: MovieModel, Codable {
    enum CodingKeys: String, CodingKey {
        case name, url, httpReferer, httpUserAgent
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init(context: PersistenceController.shared.viewContext)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        url = try values.decode(URL.self, forKey: .url)
        name = try values.decode(String.self, forKey: .name)
        httpReferer = try values.decode(String.self, forKey: .httpReferer)
        httpUserAgent = try values.decode(String.self, forKey: .httpUserAgent)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(name, forKey: .name)
        try container.encode(httpReferer, forKey: .httpReferer)
        try container.encode(httpUserAgent, forKey: .httpUserAgent)
    }
}

extension PlayModel {
    convenience init(context: NSManagedObjectContext = PersistenceController.shared.viewContext, url: URL) {
        self.init(context: context, url: url, name: url.lastPathComponent)
    }

    convenience init(context: NSManagedObjectContext = PersistenceController.shared.viewContext, url: URL, name: String, extinf: [String: String]? = nil) {
        self.init(context: context)
        self.name = name
        self.url = url
        setExt(info: extinf)
    }

    func setExt(info: [String: String]? = nil) {
        let logo = info?["tvg-logo"].flatMap { URL(string: $0) }
        if logo != self.logo {
            self.logo = logo
        }
        let language = info?["tvg-language"]
        if language != self.language {
            self.language = language
        }
        let country = info?["tvg-country"]
        if country != self.country {
            self.country = country
        }
        let group = info?["group-title"]
        if group != self.group {
            self.group = group
        }
        let tvgID = info?["tvg-id"]
        if tvgID != self.tvgID {
            self.tvgID = tvgID
        }
        let httpReferer = info?["http-referrer"] ?? info?["http-referer"]
        if httpReferer != self.httpReferer {
            self.httpReferer = httpReferer
        }
        let httpUserAgent = info?["http-user-agent"]
        if httpUserAgent != self.httpUserAgent {
            self.httpUserAgent = httpUserAgent
        }
    }
}

extension M3UModel {
    convenience init(context: NSManagedObjectContext = PersistenceController.shared.viewContext, url: URL, name: String? = nil) {
        self.init(context: context)
        self.name = name ?? url.lastPathComponent
        m3uURL = url
    }

    func parsePlaylist(refresh: Bool = false) async throws -> [PlayModel] {
        let viewContext = managedObjectContext ?? PersistenceController.shared.viewContext
        let m3uURL = await viewContext.perform {
            self.m3uURL
        }
        guard let m3uURL else {
            return []
        }
        let array: [PlayModel] = await viewContext.perform {
            let request = NSFetchRequest<PlayModel>(entityName: "PlayModel")
            request.predicate = NSPredicate(format: "m3uURL == %@", m3uURL.description)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            return (try? viewContext.fetch(request)) ?? []
        }

        guard refresh || array.isEmpty else {
            return array
        }
        let result = try await m3uURL.parsePlaylist()
        guard result.count > 0 else {
            await viewContext.perform {
                viewContext.delete(self)
            }
            return []
        }
        return await viewContext.perform {
            var dic = array.toDictionary {
                $0.url
            }
            let models = result.map { name, url, extinf -> PlayModel in
                if let model = dic[url] {
                    dic.removeValue(forKey: url)
                    if name != model.name {
                        model.name = name
                    }
                    model.setExt(info: extinf)
                    return model
                } else {
                    let model = PlayModel(context: viewContext, url: url, name: name, extinf: extinf)
                    model.m3uURL = self.m3uURL
                    return model
                }
            }
            if self.count != Int32(models.count) {
                self.count = Int32(models.count)
            }
            viewContext.perform {
                if viewContext.hasChanges {
                    try? viewContext.save()
                    for model in dic.values {
                        viewContext.delete(model)
                    }
                }
            }
            return models
        }
    }
}

extension PlayModel {
    static var playTimeRequest: NSFetchRequest<PlayModel> {
        let request = NSFetchRequest<PlayModel>(entityName: "PlayModel")
        request.sortDescriptors = [
            NSSortDescriptor(
                keyPath: \PlayModel.playTime,
                ascending: false
            ),
        ]
        request.predicate = NSPredicate(format: "playTime != nil")
        request.fetchLimit = 20
        return request
    }
}

extension KSVideoPlayerView {
    init(url: URL) {
        let request = NSFetchRequest<PlayModel>(entityName: "PlayModel")
        request.predicate = NSPredicate(format: "url == %@", url.description)
        let model = PlayModel(url: url)
        self.init(model: model)
    }

    init(model: PlayModel) {
        let url = model.url!
        let options = MEOptions()
        #if DEBUG
        if url.lastPathComponent == "h264.mp4" {
//            options.videoFilters = ["hflip", "vflip"]
//            options.hardwareDecode = false
            options.startPlayTime = 13
        } else if url.lastPathComponent == "vr.mp4" {
            options.display = .vr
        } else if url.lastPathComponent == "mjpeg.flac" {
//            options.videoDisable = true
            options.syncDecodeAudio = true
        } else if url.lastPathComponent == "subrip.mkv" {
            options.asynchronousDecompression = false
            options.videoFilters.append("yadif_videotoolbox=mode=0:parity=-1:deint=1")
        } else if url.lastPathComponent == "big_buck_bunny.mp4" {
            options.startPlayTime = 25
        } else if url.lastPathComponent == "bipbopall.m3u8" {
            #if os(macOS)
            let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            options.outputURL = moviesDirectory?.appendingPathComponent("recording.mov")
            #endif
        }
        #endif
        options.referer = model.httpReferer
        options.userAgent = model.httpUserAgent
        model.playTime = Date()
        if model.duration > 0, model.current > 0, model.duration > model.current + 120 {
            options.startPlayTime = TimeInterval(model.current)
        }
        // There is total different meaning for 'listen_timeout' option in rtmp
        // set 'listen_timeout' = -1 for rtmp、rtsp
        if url.absoluteString.starts(with: "rtmp") || url.absoluteString.starts(with: "rtsp") {
            options.formatContextOptions["listen_timeout"] = -1
            options.formatContextOptions["fflags"] = ["nobuffer", "autobsf"]
        } else {
            options.formatContextOptions["listen_timeout"] = 3
        }
        self.init(url: url, options: options, title: model.name) { layer in
            if let layer {
                model.duration = Int16(layer.player.duration)
                if model.duration > 0 {
                    model.current = Int16(layer.player.currentPlaybackTime)
                }
                model.managedObjectContext?.perform {
                    try? model.managedObjectContext?.save()
                }
            }
        }
    }
}
