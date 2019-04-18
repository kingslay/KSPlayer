//
//  MainWindowController.swift
//  demo-macOS
//
//  Created by kintan on 2018/10/29.
//  Copyright © 2018 kintan. All rights reserved.
//

import Cocoa
import ffmpeg
import KSPlayer
class MainWindow: NSWindow {
    let vc: ViewController
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
//        KSPlayerManager.firstPlayerType = KSMEPlayer.self
        KSPlayerManager.secondPlayerType = KSMEPlayer.self
        KSPlayerManager.isAutoPlay = true
        KSPlayerManager.isSeekedAutoPlay = true
        KSDefaultParameter.enableVideotoolbox = true
        KSDefaultParameter.logLevel = AV_LOG_DEBUG
        vc = ViewController()
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        contentViewController = vc
        styleMask = [.closable, .miniaturizable, .resizable, .titled]
    }

    func open(url: URL) {
        if !isVisible {
            makeKeyAndOrderFront(self)
            center()
        }
        vc.url = url
    }
}
