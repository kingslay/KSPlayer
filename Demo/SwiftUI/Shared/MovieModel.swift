//
//  MovieModel.swift
//  TracyPlayer
//
//  Created by kintan on 2023/2/2.
//

import CoreData
import CoreMedia
import Foundation
import KSPlayer
#if canImport(UIKit)
import UIKit
#endif
class MEOptions: KSOptions {
    #if os(iOS)
    static var isUseDisplayLayer = true
    #else
    static var isUseDisplayLayer = false
    #endif
    override init() {
        super.init()
        audioLocale = Locale(identifier: "en-US")
    }

    override func process(assetTrack: some MediaPlayerTrack) {
        super.process(assetTrack: assetTrack)
    }

    override func isUseDisplayLayer() -> Bool {
        MEOptions.isUseDisplayLayer && display == .plane
    }
}

@objc(MovieModel)
public class MovieModel: NSManagedObject, Codable {
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

extension MovieModel {
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

    func delete() {
        guard let context = managedObjectContext, let m3uURL else {
            return
        }
        context.delete(self)
        let request = M3UModel.fetchRequest()
        request.predicate = NSPredicate(format: "m3uURL == %@", m3uURL.description)
        do {
            if let array = try? context.fetch(request), array.isEmpty {
                let movieRequest = NSFetchRequest<MovieModel>(entityName: "MovieModel")
                movieRequest.predicate = NSPredicate(format: "m3uURL == %@", m3uURL.description)
                for model in try context.fetch(movieRequest) {
                    context.delete(model)
                }
//            let deleteRequest = NSBatchDeleteRequest(fetchRequest: movieRequest)
//            _ = try? context.execute(deleteRequest)
            }
            try context.save()
        } catch {
            KSLog(level: .error, error.localizedDescription)
        }
    }

    func getMovieModels() async -> [MovieModel] {
        let viewContext = managedObjectContext ?? PersistenceController.shared.viewContext
        let m3uURL = await viewContext.perform {
            self.m3uURL
        }
        guard let m3uURL else {
            return []
        }
        return await viewContext.perform {
            let request = NSFetchRequest<MovieModel>(entityName: "MovieModel")
            request.predicate = NSPredicate(format: "m3uURL == %@", m3uURL.description)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            return (try? viewContext.fetch(request)) ?? []
        }
    }

    func parsePlaylist() async throws -> [MovieModel] {
        let array = await getMovieModels()
        let viewContext = managedObjectContext ?? PersistenceController.shared.viewContext
        let m3uURL = await viewContext.perform {
            self.m3uURL
        }
        guard let m3uURL else {
            return []
        }
        let result = try await m3uURL.parsePlaylist()
        guard result.count > 0 else {
            delete()
            return []
        }
        return await viewContext.perform {
            var dic = [URL?: MovieModel]()
            for model in array {
                if let oldModel = dic[model.url] {
                    if oldModel.playmodel == nil {
                        viewContext.delete(oldModel)
                        dic[model.url] = model
                    } else {
                        viewContext.delete(model)
                    }
                } else {
                    dic[model.url] = model
                }
            }
            let models = result.map { name, url, extinf -> MovieModel in
                if let model = dic[url] {
                    dic.removeValue(forKey: url)
                    if name != model.name {
                        model.name = name
                    }
                    model.setExt(info: extinf)
                    return model
                } else {
                    let model = MovieModel(context: viewContext, url: url, name: name, extinf: extinf)
                    model.m3uURL = self.m3uURL
                    return model
                }
            }
            if self.count != Int32(models.count) {
                self.count = Int32(models.count)
            }
            viewContext.perform {
                if viewContext.hasChanges {
                    for model in dic.values {
                        viewContext.delete(model)
                    }
                    try? viewContext.save()
                }
            }
            return models
        }
    }
}

extension MovieModel {
    static var playTimeRequest: NSFetchRequest<MovieModel> {
        let request = MovieModel.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(
                keyPath: \MovieModel.playmodel?.playTime,
                ascending: false
            ),
        ]
        request.predicate = NSPredicate(format: "playmodel.playTime != nil")
        request.fetchLimit = 20
        return request
    }

    public var isFavorite: Bool {
        get {
            playmodel?.isFavorite ?? false
        }
        set {
            let playmodel = getPlaymodel()
            playmodel.isFavorite = newValue
        }
    }

    func getPlaymodel() -> PlayModel {
        if let playmodel {
            return playmodel
        }
        let model = PlayModel()
        playmodel = model
        model.save()
        return model
    }
}

extension NSManagedObject {
    func save() {
        guard let context = managedObjectContext else {
            return
        }
        context.perform {
            do {
                try context.save()
            } catch {}
        }
    }
}

extension PlayModel {
    convenience init() {
        self.init(context: PersistenceController.shared.viewContext)
    }
}

extension KSVideoPlayerView {
    init(url: URL) {
        let request = NSFetchRequest<MovieModel>(entityName: "MovieModel")
        request.predicate = NSPredicate(format: "url == %@", url.description)
        let model = (try? PersistenceController.shared.viewContext.fetch(request).first) ?? MovieModel(url: url)
        self.init(model: model)
    }

    init(model: MovieModel) {
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
            options.videoFilters.append("yadif_videotoolbox=mode=\(MEOptions.yadifMode):parity=-1:deint=1")
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
        if let httpUserAgent = model.httpUserAgent {
            options.userAgent = httpUserAgent
        }
        let playmodel = model.getPlaymodel()
        playmodel.playTime = Date()
        if playmodel.duration > 0, playmodel.current > 0, playmodel.duration > playmodel.current + 120 {
            options.startPlayTime = TimeInterval(playmodel.current)
        }
        playmodel.save()
        model.save()
        self.init(url: url, options: options, title: model.name)
    }
}
