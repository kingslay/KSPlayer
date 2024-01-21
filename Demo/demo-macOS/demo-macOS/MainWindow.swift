//
//  MainWindow.swift
//  demo-macOS
//
//  Created by kintan on 2018/10/29.
//  Copyright © 2018 kintan. All rights reserved.
//

import Cocoa
import KSPlayer

class MainWindow: NSWindow {
    let vc: ViewController
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.logLevel = .debug
        KSOptions.isAutoPlay = true
        KSOptions.isSeekedAutoPlay = true
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
