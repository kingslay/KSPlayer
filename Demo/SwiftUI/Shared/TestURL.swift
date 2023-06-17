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
    var id: MovieModel { self }
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

    if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
        let options = MEOptions()
        options.startPlayTime = 25
        objects.append(MovieModel(url: url, options: options, name: "mp4视频"))
    }

    if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
        let options = MEOptions()
        #if os(macOS)
        let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        options.outputURL = moviesDirectory?.appendingPathComponent("recording.mp4")
        #endif
        objects.append(MovieModel(url: url, options: options, name: "m3u8视频"))
    }

    if let url = URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8") {
        let options = MEOptions()
        objects.append(MovieModel(url: url, options: options, name: "fmp4"))
    }

    if let url = URL(string: "http://116.199.5.51:8114/00000000/hls/index.m3u8?Fsv_chan_hls_se_idx=188&FvSeid=1&Fsv_ctype=LIVES&Fsv_otype=1&Provider_id=&Pcontent_id=.m3u8") {
        objects.append(MovieModel(url: url, options: MEOptions(), name: "tvb视频"))
    }

    if let url = URL(string: "http://dash.edgesuite.net/akamai/bbb_30fps/bbb_30fps.mpd") {
        objects.append(MovieModel(url: url, options: MEOptions(), name: "dash视频"))
    }
    if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2019/244gmopitz5ezs2kkq/244/hls_vod_mvp.m3u8") {
        let options = MEOptions()
        objects.append(MovieModel(url: url, options: options, name: "https视频"))
    }

    if let url = URL(string: "rtsp://rtsp.stream/pattern") {
        let options = MEOptions()
        objects.append(MovieModel(url: url, options: options, name: "rtsp video"))
    }

    if let url = URL(string: "https://github.com/qiudaomao/MPVColorIssue/raw/master/MPVColorIssue/resources/captain.marvel.2019.2160p.uhd.bluray.x265-terminal.sample.mkv") {
        objects.append(MovieModel(url: url, options: MEOptions(), name: "HDR MKV"))
    }
    return objects
}()

extension KSVideoPlayerView {
    init(model: MovieModel) {
        self.init(url: model.url, options: model.options)
    }
}
