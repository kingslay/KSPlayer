//
//  DetailViewController.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import CoreServices
import KSPlayer
import UIKit
protocol DetailProtocol: UIViewController {
    var resource: KSPlayerResource? { get set }
}

class DetailViewController: UIViewController, DetailProtocol {
    #if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    private let playerView = IOSVideoPlayerView()
    #else
    private let playerView = VideoPlayerView()
    #endif
    var resource: KSPlayerResource? {
        didSet {
            if let resource = resource {
                playerView.set(resource: resource)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        #if os(iOS)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.readableContentGuide.topAnchor),
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        #else
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        #endif
        view.layoutIfNeeded()
        playerView.backBlock = { [unowned self] in
            #if os(iOS)
            if UIApplication.shared.statusBarOrientation.isLandscape {
                self.playerView.updateUI(isLandscape: false)
            } else {
                self.navigationController?.popViewController(animated: true)
            }
            #else
            self.navigationController?.popViewController(animated: true)
            #endif
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .phone {
            navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override open var canBecomeFirstResponder: Bool {
        true
    }

    // The responder chain is asking us which commands you support.
    // Enable/disable certain Edit menu commands.
    override open func canPerformAction(_ action: Selector, withSender _: Any?) -> Bool {
        if action == #selector(openAction(_:)) {
            // User wants to perform a "New" operation.
            return true
        }
        return false
    }

    /// User chose "Open" from the File menu.
    @objc public func openAction(_: AnyObject) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeMPEG4 as String], in: .open)
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
}

extension DetailViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let first = urls.first {
            resource = KSPlayerResource(url: first)
        }
    }
}

#if os(iOS)
class CustomVideoPlayerView: IOSVideoPlayerView {
    override func updateUI(isLandscape: Bool) {
        super.updateUI(isLandscape: isLandscape)
        toolBar.playbackRateButton.isHidden = true
    }

    override func onButtonPressed(type: PlayerButtonType, button: UIButton) {
        if type == .landscape {
            // xx
        } else {
            super.onButtonPressed(type: type, button: button)
        }
    }
}
#endif
