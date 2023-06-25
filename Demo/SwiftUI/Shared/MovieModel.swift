//
//  TestURL.swift
//  TracyPlayer
//
//  Created by kintan on 2023/2/2.
//

import Foundation
import KSPlayer

class MEOptions: KSOptions {
    override func process(assetTrack: MediaPlayerTrack) {
        if assetTrack.mediaType == .video {
            if [FFmpegFieldOrder.bb, .bt, .tt, .tb].contains(assetTrack.fieldOrder) {
                videoFilters.append("yadif=mode=1:parity=-1:deint=0")
                hardwareDecode = false
            }
        }
    }

    #if os(tvOS)
    override open func preferredDisplayCriteria(refreshRate: Float, videoDynamicRange: Int32) -> AVDisplayCriteria? {
        AVDisplayCriteria(refreshRate: refreshRate, videoDynamicRange: videoDynamicRange)
    }
    #endif
}

class MovieModel: Hashable {
    public static func == (lhs: MovieModel, rhs: MovieModel) -> Bool {
        lhs.url == rhs.url
    }

    public let name: String
    public let url: URL
    public let options: KSOptions
    public let extinf: [String: String]?
    public let logo: URL?
    public var group: String? {
        extinf?["group-title"]
    }

    public var country: String? {
        extinf?["tvg-country"]
    }

    public var language: String? {
        extinf?["tvg-language"]
    }

    public convenience init(url: URL, options: KSOptions = MEOptions()) {
        self.init(url: url, options: options, name: url.lastPathComponent)
    }

    /**
     Video recource item with defination name and specifying options

     - parameter url:        video url
     - parameter options:    specifying options for the initialization of the AVURLAsset
     - parameter name:       video name
     */
    public init(url: URL, options: KSOptions = MEOptions(), name: String, extinf: [String: String]? = nil) {
        self.url = url
        self.name = name
        self.options = options
        self.extinf = extinf
        logo = extinf?["tvg-logo"].flatMap { URL(string: $0) }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

extension MovieModel: Identifiable {
    var id: URL { url }
}

var testObjects: [MovieModel] = {
    var objects = [MovieModel]()
    for ext in ["mp4", "mkv", "mov", "h264", "flac", "webm"] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) else {
            continue
        }
        for url in urls {
            let options = MEOptions()
            if url.lastPathComponent == "h264.mp4" {
                options.videoFilters = ["hflip", "vflip"]
                options.hardwareDecode = false
                options.startPlayTime = 13
                #if os(macOS)
                let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                options.outputURL = moviesDirectory?.appendingPathComponent("recording.mov")
                #endif
            } else if url.lastPathComponent == "vr.mp4" {
                options.display = .vr
            } else if url.lastPathComponent == "mjpeg.flac" {
                options.videoDisable = true
                options.syncDecodeAudio = true
            } else if url.lastPathComponent == "subrip.mkv" {
                options.asynchronousDecompression = false
                options.videoFilters.append("yadif_videotoolbox=mode=0:parity=auto:deint=1")
            }
            objects.append(MovieModel(url: url, options: options))
        }
    }
    return objects
}()

extension KSVideoPlayerView {
    init(model: MovieModel) {
        self.init(url: model.url, options: model.options)
    }
}
