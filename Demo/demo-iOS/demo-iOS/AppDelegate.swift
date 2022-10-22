//
//  AppDelegate.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import KSPlayer
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
        KSOptions.canBackgroundPlay = true
        KSOptions.logLevel = .debug
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
//        KSOptions.supportedInterfaceOrientations = .all
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
//        KSOptions.isLoopPlay = true
        if UIDevice.current.userInterfaceIdiom == .phone {
            window.rootViewController = UINavigationController(rootViewController: MasterViewController())
        } else {
            let splitViewController = UISplitViewController()
            splitViewController.preferredDisplayMode = .primaryOverlay
            splitViewController.delegate = self
            let detailVC = DetailViewController()
            splitViewController.viewControllers = [UINavigationController(rootViewController: MasterViewController()), UINavigationController(rootViewController: detailVC)]
            #if os(iOS)
            detailVC.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            detailVC.navigationItem.leftItemsSupplementBackButton = true
            #endif
            window.rootViewController = splitViewController
        }
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    #if os(iOS)
    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        KSOptions.supportedInterfaceOrientations
    }

    private var menuController: MenuController!
    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            menuController = MenuController(with: builder)
        }
    }
    #endif
}

class MEOptions: KSOptions {
    #if os(tvOS)
    override open func preferredDisplayCriteria(refreshRate _: Float, videoDynamicRange _: Int32) -> AVDisplayCriteria? {
//         AVDisplayCriteria(refreshRate: refreshRate, videoDynamicRange: videoDynamicRange)
    }
    #endif
}

var objects: [KSPlayerResource] = {
    var objects = [KSPlayerResource]()
    if let path = Bundle.main.path(forResource: "h264", ofType: "mp4") {
        let options = KSOptions()
        options.videoFilters = "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p -pix_fmt yuv420p -color_range tv -colorspace bt709 -color_trc bt709 -color_primaries bt709"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地视频"))
    }
    if let path = Bundle.main.path(forResource: "subrip", ofType: "mkv") {
        let options = KSOptions()
        options.videoFilters = "hflip,vflip"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "文字字幕"))
    }
    if let path = Bundle.main.path(forResource: "dvd_subtitle", ofType: "mkv") {
        let options = KSOptions()
//        options.videoFilters = "hflip,vflip"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "图片字幕"))
    }
    if let url = URL(string: "https://github.com/qiudaomao/MPVColorIssue/raw/master/MPVColorIssue/resources/captain.marvel.2019.2160p.uhd.bluray.x265-terminal.sample.mkv") {
        objects.append(KSPlayerResource(url: url, options: MEOptions(), name: "HDR MKV"))
    }
    if let path = Bundle.main.path(forResource: "vr", ofType: "mp4") {
        let options = KSOptions()
        options.display = .vr
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地全景视频"))
    }
    if let path = Bundle.main.path(forResource: "mjpeg", ofType: "flac") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "本地音频"))
    }
    if let path = Bundle.main.path(forResource: "hevc", ofType: "mkv") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "h265视频"))
    }
    if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
        let options = KSOptions()
        options.autoDeInterlace = true
        options.videoFilters = "hflip,vflip"
        let res0 = KSPlayerResourceDefinition(url: url, definition: "标准", options: options)
        let res1 = KSPlayerResourceDefinition(url: url, definition: "颠倒", options: options)
        let asset = KSPlayerResource(name: "http视频", definitions: [res0, res1], cover: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/848px-Big_buck_bunny_poster_big.jpg"))
        objects.append(asset)
    }

    if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "m3u8视频"))
    }

    if let url = URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "fmp4"))
    }

    if let url = URL(string: "http://116.199.5.51:8114/00000000/hls/index.m3u8?Fsv_chan_hls_se_idx=188&FvSeid=1&Fsv_ctype=LIVES&Fsv_otype=1&Provider_id=&Pcontent_id=.m3u8") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "tvb视频"))
    }

    if let url = URL(string: "http://dash.edgesuite.net/akamai/bbb_30fps/bbb_30fps.mpd") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "dash视频"))
    }
    if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2019/244gmopitz5ezs2kkq/244/hls_vod_mvp.m3u8") {
        let options = KSOptions()
        objects.append(KSPlayerResource(url: url, options: options, name: "https视频"))
    }

    if let url = URL(string: "rtsp://rtsp.stream/pattern") {
        let options = KSOptions()
        objects.append(KSPlayerResource(url: url, options: options, name: "rtsp video"))
    }

    if let path = Bundle.main.path(forResource: "raw", ofType: "h264") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "raw h264"))
    }

    if let path = Bundle.main.path(forResource: "mjpeg", ofType: "flac") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "音乐播放器界面"))
    }
    return objects
}()

class CustomVideoPlayerView: VideoPlayerView {
    override func customizeUIComponents() {
        super.customizeUIComponents()
        toolBar.isHidden = true
        toolBar.timeSlider.isHidden = true
    }

    override open func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        if state == .readyToPlay {
            print(layer.player.naturalSize)
            // list the all subtitles
            let subtitleInfos = srtControl.filterInfos { _ in true }
            subtitleInfos.forEach {
                print($0.name)
            }
            subtitleInfos.first?.enableSubtitle { result in
                self.resource?.subtitle = try? result.get()
            }
            for track in layer.player.tracks(mediaType: .audio) {
                print("audio name: \(track.name) language: \(track.language ?? "")")
            }
            for track in layer.player.tracks(mediaType: .video) {
                print("video name: \(track.name) bitRate: \(track.bitRate) fps: \(track.nominalFrameRate) depth: \(track.depth) colorPrimaries: \(track.colorPrimaries ?? "") colorPrimaries: \(track.transferFunction ?? "") yCbCrMatrix: \(track.yCbCrMatrix ?? "") codecType:  \(track.mediaSubType.rawValue.string)")
            }
        }
    }

    override func onButtonPressed(type: PlayerButtonType, button: UIButton) {
        if type == .landscape {
            // xx
        } else {
            super.onButtonPressed(type: type, button: button)
        }
    }
}
