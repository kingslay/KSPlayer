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
    private var menuController: MenuController!
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
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return KSPlayerManager.supportedInterfaceOrientations
    }
    #endif

    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            menuController = MenuController(with: builder)
        }
    }
}
