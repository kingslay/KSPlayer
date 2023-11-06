//
//  MEPlayerViewController.swift
//  demo-iOS
//
//  Created by kintan on 2023/10/9.
//  Copyright © 2023 kintan. All rights reserved.
//

import Foundation
import KSPlayer
import UIKit

class MEPlayerViewController: UIViewController {
    private var player: MediaPlayerProtocol!
    override func viewDidLoad() {
        super.viewDidLoad()
        let definition = testObjects[0].definitions[0]
        player = KSMEPlayer(url: definition.url, options: definition.options)
        player.delegate = self
        player.view?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        player.view?.frame = view.bounds
        player.contentMode = .scaleAspectFill
        player.prepareToPlay()
        view.addSubview(player.view!)
    }
}

extension MEPlayerViewController: MediaPlayerDelegate {
    func readyToPlay(player: some KSPlayer.MediaPlayerProtocol) {
        player.play()
    }

    func changeLoadState(player _: some KSPlayer.MediaPlayerProtocol) {}

    func changeBuffering(player _: some KSPlayer.MediaPlayerProtocol, progress _: Int) {}

    func playBack(player _: some KSPlayer.MediaPlayerProtocol, loopCount _: Int) {}

    func finish(player _: some KSPlayer.MediaPlayerProtocol, error _: Error?) {}
}
