//
//  AppDelegate.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import KSPlayer
import UIKit
@available(iOS 13.0, tvOS 13.0, *)
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
        KSPlayerManager.canBackgroundPlay = true
        KSPlayerManager.logLevel = .debug
        KSPlayerManager.firstPlayerType = KSMEPlayer.self
        KSPlayerManager.secondPlayerType = KSMEPlayer.self
//        KSPlayerManager.supportedInterfaceOrientations = .all
        KSOptions.preferredForwardBufferDuration = 10
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
        KSOptions.isLoopPlay = true
        KSOptions.hardwareDecodeH265 = true
        KSOptions.hardwareDecodeH264 = true
        if UIDevice.current.userInterfaceIdiom == .phone {
            window.rootViewController = UINavigationController(rootViewController: RootViewController())
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
        KSPlayerManager.supportedInterfaceOrientations
    }

    private var menuController: MenuController!
    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            menuController = MenuController(with: builder)
        }
    }
    #endif
}

var objects: [KSPlayerResource] = {
    var objects = [KSPlayerResource]()
    if let path = Bundle.main.path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "mp4") {
        let options = KSOptions()
        options.videoFilters = "hflip,vflip"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地视频"))
    }
    if let path = Bundle.main.path(forResource: "tos", ofType: "mkv") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "本地mkv"))
    }

    if let path = Bundle.main.path(forResource: "google-help-vr", ofType: "mp4") {
        let options = KSOptions()
        options.display = .vr
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地全景视频"))
    }
    if let path = Bundle.main.path(forResource: "Polonaise", ofType: "flac") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "本地音频"))
    }
    if let path = Bundle.main.path(forResource: "video-h265", ofType: "mkv") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "h265视频"))
    }
    if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
        let res0 = KSPlayerResourceDefinition(url: url, definition: "高清")
        let res1 = KSPlayerResourceDefinition(url: URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!, definition: "标清")
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
        options.formatContextOptions["timeout"] = 0
        objects.append(KSPlayerResource(url: url, options: options, name: "https视频"))
    }

    if let url = URL(string: "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov") {
        let options = KSOptions()
        options.formatContextOptions["timeout"] = 0
        objects.append(KSPlayerResource(url: url, options: options, name: "rtsp video"))
    }

    if let path = Bundle.main.path(forResource: "Polonaise", ofType: "flac") {
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
        if state == .readyToPlay, let player = layer.player {
            print(player.naturalSize)
            // list the all subtitles
            let subtitleInfos = srtControl.filterInfos { _ in true }
            subtitleInfos.forEach {
                print($0.name)
            }
            subtitleInfos.first?.makeSubtitle { result in
                self.resource?.subtitle = try? result.get()
            }
            for track in player.tracks(mediaType: .audio) {
                print("audio name: \(track.name) language: \(track.language ?? "")")
            }
            for track in player.tracks(mediaType: .video) {
                print("video name: \(track.name) bitRate: \(track.bitRate) fps: \(track.nominalFrameRate) bitDepth: \(track.bitDepth) colorPrimaries: \(track.colorPrimaries ?? "") colorPrimaries: \(track.transferFunction ?? "") yCbCrMatrix: \(track.yCbCrMatrix ?? "") codecType:  \(track.codecType.string)")
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
