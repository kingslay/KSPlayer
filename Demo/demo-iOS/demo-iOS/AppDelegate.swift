//
//  AppDelegate.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import AVFoundation
import KSPlayer
import UIKit

@main
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
        } else if UIDevice.current.userInterfaceIdiom == .tv {
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
            let subtitleInfos = srtControl.subtitleInfos
            for subtitleInfo in subtitleInfos {
                print(subtitleInfo.name)
            }
            srtControl.selectedSubtitleInfo = subtitleInfos.first
            for track in layer.player.tracks(mediaType: .audio) {
                print("audio name: \(track.name) language: \(track.language ?? "")")
            }
            for track in layer.player.tracks(mediaType: .video) {
                print("video name: \(track.name) bitRate: \(track.bitRate) fps: \(track.nominalFrameRate) colorPrimaries: \(track.colorPrimaries ?? "") colorPrimaries: \(track.transferFunction ?? "") yCbCrMatrix: \(track.yCbCrMatrix ?? "") codecType:  \(track.mediaSubType.rawValue.string)")
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

class MEOptions: KSOptions {
    override func process(assetTrack: some MediaPlayerTrack) {
        if assetTrack.mediaType == .video {
            if [FFmpegFieldOrder.bb, .bt, .tt, .tb].contains(assetTrack.fieldOrder) {
                videoFilters.append("yadif_videotoolbox=mode=0:parity=-1:deint=1")
                asynchronousDecompression = false
            }
            #if os(tvOS) || os(xrOS)
            runOnMainThread { [weak self] in
                guard let self else {
                    return
                }
                if let displayManager = UIApplication.shared.windows.first?.avDisplayManager,
                   displayManager.isDisplayCriteriaMatchingEnabled
                {
                    let refreshRate = assetTrack.nominalFrameRate
                    if KSOptions.displayCriteriaFormatDescriptionEnabled, let formatDescription = assetTrack.formatDescription, #available(tvOS 17.0, *) {
                        displayManager.preferredDisplayCriteria = AVDisplayCriteria(refreshRate: refreshRate, formatDescription: formatDescription)
                    } else {
                        if let dynamicRange = assetTrack.dynamicRange {
                            let videoDynamicRange = self.availableDynamicRange(dynamicRange) ?? dynamicRange
                            displayManager.preferredDisplayCriteria = AVDisplayCriteria(refreshRate: refreshRate, videoDynamicRange: videoDynamicRange.rawValue)
                        }
                    }
                }
            }
            #endif
        }
    }
}

var testObjects: [KSPlayerResource] = {
    var objects = [KSPlayerResource]()
    if let url = Bundle.main.url(forResource: "test", withExtension: "m3u"), let data = try? Data(contentsOf: url) {
        let result = data.parsePlaylist()
        for (name, url, _) in result {
            objects.append(KSPlayerResource(url: url, options: MEOptions(), name: name))
        }
    }

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
                options.videoFilters.append("yadif_videotoolbox=mode=0:parity=-1:deint=1")
            }
            objects.append(KSPlayerResource(url: url, options: options, name: url.lastPathComponent))
        }
    }
    return objects
}()
