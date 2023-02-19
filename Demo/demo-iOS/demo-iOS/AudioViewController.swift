//
//  AudioViewController.swift
//  demo-iOS
//
//  Created by kintan on 2019/1/4.
//  Copyright © 2019 kintan. All rights reserved.
//
import KSPlayer
import UIKit

class AudioViewController: UIViewController, DetailProtocol {
    var playerView = AudioPlayerView()
    var resource: KSPlayerResource? {
        didSet {
            if let resource {
                playerView.set(url: resource.definitions[0].url, options: KSOptions())
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.lightGray
        view.addSubview(playerView)
        playerView.backgroundColor = UIColor.white
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        view.layoutIfNeeded()

        if let resource {
            playerView.set(url: resource.definitions[0].url, options: KSOptions())
        }
    }
}
