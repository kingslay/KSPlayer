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
                videoFilters = "yadif=mode=1:parity=-1:deint=0"
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

var testObjects: [KSPlayerResource] = {
    var objects = [KSPlayerResource]()
    if let path = Bundle.main.path(forResource: "h264", ofType: "mp4") {
        let options = MEOptions()
        options.videoFilters = "hflip,vflip"
        options.hardwareDecode = false
        options.startPlayTime = 13
        #if os(macOS)
        let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        options.outputURL = moviesDirectory?.appendingPathComponent("recording.mov")
        #endif
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地视频"))
    }
    if let path = Bundle.main.path(forResource: "subrip", ofType: "mkv") {
        let options = MEOptions()
        options.asynchronousDecompression = false
        options.videoFilters = "yadif_videotoolbox=mode=0:parity=auto:deint=1"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "文字字幕"))
    }
    if let path = Bundle.main.path(forResource: "dvd_subtitle", ofType: "mkv") {
        let options = MEOptions()
        //        options.videoFilters = "hflip,vflip"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "图片字幕"))
    }
    if let path = Bundle.main.path(forResource: "dolby-digital-plus-channel", ofType: "mkv") {
        let options = MEOptions()
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "dolby-digital-plus"))
    }
    if let path = Bundle.main.path(forResource: "vr", ofType: "mp4") {
        let options = MEOptions()
        options.display = .vr
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地全景视频"))
    }
    if let path = Bundle.main.path(forResource: "mjpeg", ofType: "flac") {
        let options = MEOptions()
        options.videoDisable = true
        options.syncDecodeAudio = true
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地音频"))
    }
    if let path = Bundle.main.path(forResource: "hevc", ofType: "mkv") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: MEOptions(), name: "h265视频"))
    }

    if let path = Bundle.main.path(forResource: "raw", ofType: "h264") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: MEOptions(), name: "raw h264"))
    }

    if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
        let options = MEOptions()
        options.startPlayTime = 25
        objects.append(KSPlayerResource(url: url, options: options, name: "mp4视频"))
    }

    if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
        let options = MEOptions()
        #if os(macOS)
        let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        options.outputURL = moviesDirectory?.appendingPathComponent("recording.mp4")
        #endif
        objects.append(KSPlayerResource(url: url, options: options, name: "m3u8视频"))
    }

    if let url = URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8") {
        let options = MEOptions()
        options.dropVideoFrame = false
        objects.append(KSPlayerResource(url: url, options: options, name: "fmp4"))
    }

    if let url = URL(string: "http://116.199.5.51:8114/00000000/hls/index.m3u8?Fsv_chan_hls_se_idx=188&FvSeid=1&Fsv_ctype=LIVES&Fsv_otype=1&Provider_id=&Pcontent_id=.m3u8") {
        objects.append(KSPlayerResource(url: url, options: MEOptions(), name: "tvb视频"))
    }

    if let url = URL(string: "http://dash.edgesuite.net/akamai/bbb_30fps/bbb_30fps.mpd") {
        objects.append(KSPlayerResource(url: url, options: MEOptions(), name: "dash视频"))
    }
    if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2019/244gmopitz5ezs2kkq/244/hls_vod_mvp.m3u8") {
        let options = MEOptions()
        objects.append(KSPlayerResource(url: url, options: options, name: "https视频"))
    }

    if let url = URL(string: "rtsp://rtsp.stream/pattern") {
        let options = MEOptions()
        objects.append(KSPlayerResource(url: url, options: options, name: "rtsp video"))
    }

    if let url = URL(string: "https://github.com/qiudaomao/MPVColorIssue/raw/master/MPVColorIssue/resources/captain.marvel.2019.2160p.uhd.bluray.x265-terminal.sample.mkv") {
        objects.append(KSPlayerResource(url: url, options: MEOptions(), name: "HDR MKV"))
    }
    return objects
}()
