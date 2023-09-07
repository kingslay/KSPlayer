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
        self.init(context: PersistenceController.shared.container.viewContext)
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
    convenience init(url: URL) {
        self.init(url: url, name: url.lastPathComponent)
    }

    convenience init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext, url: URL, name: String, extinf: [String: String]? = nil) {
        self.init(context: context)
        self.name = name
        self.url = url
        logo = extinf?["tvg-logo"].flatMap { URL(string: $0) }
        language = extinf?["tvg-language"]
        country = extinf?["tvg-country"]
        group = extinf?["group-title"]
        tvgID = extinf?["tvg-id"]
        httpReferer = extinf?["http-referrer"] ?? extinf?["http-referer"]
        httpUserAgent = extinf?["http-user-agent"]
    }
}

extension M3UModel {
    convenience init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext, url: URL, name: String? = nil) {
        self.init(context: context)
        self.name = name ?? url.lastPathComponent
        m3uURL = url
        try? context.save()
    }

    @MainActor
    func parsePlaylist(refresh: Bool = false) async -> [PlayModel] {
        let viewContext = managedObjectContext ?? PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<PlayModel>(entityName: "PlayModel")
        request.predicate = NSPredicate(format: "m3uURL == %@", m3uURL!.description)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let array: [PlayModel] = (try? viewContext.fetch(request)) ?? []
        guard refresh || array.isEmpty else {
            return array
        }
        let dic = array.toDictionary {
            $0.m3uURL = nil
            return $0.url
        }
        let result = try? await m3uURL?.parsePlaylist()
        let models = result?.compactMap { name, url, extinf -> PlayModel in
            if let model = dic[url] {
                model.m3uURL = m3uURL
                return model
            } else {
                let model = PlayModel(context: viewContext, url: url, name: name, extinf: extinf)
                model.m3uURL = m3uURL
                return model
            }
        } ?? []
        if count != Int32(models.count) {
            count = Int32(models.count)
        }
        if viewContext.hasChanges {
            Task { @MainActor in
                try? viewContext.save()
            }
        }
        return models
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
        let model = (try? PersistenceController.shared.container.viewContext.fetch(request).first) ?? PlayModel(url: url)
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
        self.init(url: url, options: options) { layer in
            if let layer {
                model.duration = Int16(layer.player.duration)
                if model.duration > 0 {
                    model.current = Int16(layer.player.currentPlaybackTime)
                }
                try? model.managedObjectContext?.save()
            }
        }
    }
}
