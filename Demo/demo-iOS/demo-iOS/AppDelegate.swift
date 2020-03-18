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
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
        KSPlayerManager.canBackgroundPlay = true
        KSPlayerManager.logLevel = .debug
        KSPlayerManager.firstPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
        KSOptions.isLoopPlay = true
        KSOptions.hardwareDecodeH265 = true
        KSOptions.hardwareDecodeH264 = true
        if UIDevice.current.userInterfaceIdiom == .phone {
            window.rootViewController = UINavigationController(rootViewController: MasterViewController())
        } else {
            let splitViewController = UISplitViewController()
            splitViewController.preferredDisplayMode = .primaryOverlay
            splitViewController.delegate = self
            let detailVC = DetailViewController()
            splitViewController.viewControllers = [UINavigationController(rootViewController: MasterViewController()),UINavigationController(rootViewController: detailVC)]
            detailVC.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            detailVC.navigationItem.leftItemsSupplementBackButton = true
            window.rootViewController = splitViewController
        }
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
