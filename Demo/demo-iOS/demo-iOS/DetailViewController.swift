//
//  DetailViewController.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import KSPlayer
import UIKit

class DetailViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    var playerView = IOSVideoPlayerView()
    var resource: KSPlayerResource!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.readableContentGuide.topAnchor),
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        playerView.backBlock = { [unowned self] in
            if UIApplication.shared.statusBarOrientation.isLandscape {
                self.playerView.updateUI(isLandscape: false)
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
        if let resource = resource {
            if resource.name.contains("全景") {
                KSPlayerManager.firstPlayerType = KSVRPlayer.self
            } else {
                KSPlayerManager.firstPlayerType = KSAVPlayer.self
            }
            playerView.set(resource: resource)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
}
