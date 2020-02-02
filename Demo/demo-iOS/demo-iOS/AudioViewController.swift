//
//  AudioViewController.swift
//  demo-iOS
//
//  Created by kintan on 2019/1/4.
//  Copyright © 2019 kintan. All rights reserved.
//
import KSPlayer
import UIKit

class AudioViewController: UIViewController {
    var playerView = AudioPlayerView()
    var resource: KSPlayerResource!
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.lightGray
        view.addSubview(playerView)
        playerView.backgroundColor = UIColor.white
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        view.layoutIfNeeded()

        if let resource = resource {
            playerView.set(url: resource.definitions[0].url, options: KSOptions())
        }
    }
}
