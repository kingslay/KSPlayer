//
//  ViewController.swift
//  demo-macOS
//
//  Created by kintan on 2018/5/24.
//  Copyright © 2018年 kintan. All rights reserved.
//

import AppKit
import KSPlayer

class ViewController: NSViewController {
    private let playerView = MacVideoPlayerView()
    var url: URL? {
        didSet {
            if let url {
                let res0 = KSPlayerResourceDefinition(url: url, definition: "高清", options: KSOptions())
                let asset = KSPlayerResource(name: url.lastPathComponent, definitions: [res0], cover: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/848px-Big_buck_bunny_poster_big.jpg"))
                playerView.set(resource: asset)
            } else {
                playerView.resetPlayer()
            }
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
