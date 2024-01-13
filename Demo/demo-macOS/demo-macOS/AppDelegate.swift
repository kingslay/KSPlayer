//
//  AppDelegate.swift
//  demo-macOS
//
//  Created by kintan on 2018/5/24.
//  Copyright © 2018年 kintan. All rights reserved.
//

import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var openURLWindow = OpenURLWindowController()
    private var window = MainWindow()

    func applicationWillFinishLaunching(_: Notification) {}

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.servicesProvider = self
        if window.vc.url == nil {
            openDocument(self)
        }
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func openDocument(_: AnyObject) {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("alert.choose_media_file.title", comment: "Choose Media File")
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            for url in panel.urls {
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            }
            if let url = panel.urls.first {
                open(url: url)
            }
        }
    }

    @IBAction func openURL(_: AnyObject) {
        openURLWindow.showWindow(nil)
        openURLWindow.resetFields()
    }

    func application(_: NSApplication, openFile _: String) -> Bool {
        true
    }

    func application(_: NSApplication, openFiles filenames: [String]) {
        if let first = filenames.first {
            open(string: first)
        }
    }

    // MARK: - URL Scheme

    @objc func handleURLEvent(event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        open(string: url)
    }

    // MARK: - Accept dropped string and URL

//    @objc func droppedText(_ pboard: NSPasteboard, userData _: String, error _: NSErrorPointer) {
//        if let url = pboard.string(forType: .string) {
//            open(string: url)
//        }
//    }

    func open(string: String) {
        if string.first == "/" {
            open(url: URL(fileURLWithPath: string))
        } else {
            if let url = URL(string: string) {
                open(url: url)
            }
        }
    }

    func open(url: URL) {
        window.open(url: url)
    }
}
