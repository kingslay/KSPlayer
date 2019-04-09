//
//  AppDelegate.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import ffmpeg
import KSPlayer
import UIKit
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
//        KSPlayerManager.firstPlayerType = KSAVPlayer.self
        KSPlayerManager.isLoopPlay = true
        KSPlayerManager.isSecondOpen = true
        KSPlayerManager.isAccurateSeek = true
        KSPlayerManager.secondPlayerType = KSMEPlayer.self
        KSDefaultParameter.logLevel = AV_LOG_DEBUG
        KSDefaultParameter.enableVideotoolbox = true
        window.rootViewController = UINavigationController(rootViewController: MasterViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func applicationWillResignActive(_: UIApplication) {}

    func applicationDidEnterBackground(_: UIApplication) {}

    func applicationWillEnterForeground(_: UIApplication) {}

    func applicationDidBecomeActive(_: UIApplication) {}

    func applicationWillTerminate(_: UIApplication) {}
}
