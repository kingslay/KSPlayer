//
//  TvOSVideoPlayerView.swift
//  KSPlayer
//
//  Created by Alanko5 on 17/12/2022.
//

import AVFAudio
import AVKit
import Combine
import Foundation
import MediaPlayer

#if os(tvOS)

open class TvOSVideoPlayerView: VideoPlayerView {
    override open func customizeUIComponents() {
        super.customizeUIComponents()
        srtButton.fillImage()
        pipButton.fillImage()
        playButton.fillImage()
        definitionButton.fillImage()
        audioSwitchButton.fillImage()
        videoSwitchButton.fillImage()
        playbackRateButton.fillImage()
        if #available(tvOS 14.0, *) {
            toolBar.pipButton.isHidden = !AVPictureInPictureController.isPictureInPictureSupported()
        }
        addRemoteControllerGestures()
    }
}

// MARK: - remote controller interactions

extension TvOSVideoPlayerView {
    internal func addRemoteControllerGestures() {
        let rightPressRecognizer = UITapGestureRecognizer()
        rightPressRecognizer.addTarget(self, action: #selector(rightArrowButtonPressed(_:)))
        rightPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        addGestureRecognizer(rightPressRecognizer)

        let leftPressRecognizer = UITapGestureRecognizer()
        leftPressRecognizer.addTarget(self, action: #selector(leftArrowButtonPressed(_:)))
        leftPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        addGestureRecognizer(leftPressRecognizer)

        let selectPressRecognizer = UITapGestureRecognizer()
        selectPressRecognizer.addTarget(self, action: #selector(selectButtonPressed(_:)))
        selectPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        addGestureRecognizer(selectPressRecognizer)

        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedUp(_:)))
        swipeUpRecognizer.direction = .up
        addGestureRecognizer(swipeUpRecognizer)

        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown(_:)))
        swipeDownRecognizer.direction = .down
        addGestureRecognizer(swipeDownRecognizer)
    }

    @objc
    private func rightArrowButtonPressed(_: UITapGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying, toolBar.isSeekable else { return }
        Task {
            await seek(time: toolBar.currentTime + 15)
        }
    }

    @objc
    private func leftArrowButtonPressed(_: UITapGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying, toolBar.isSeekable else { return }
        Task {
            await seek(time: toolBar.currentTime - 15)
        }
    }

    @objc
    private func selectButtonPressed(_: UITapGestureRecognizer) {
        guard toolBar.isSeekable else { return }
        if let playerLayer, playerLayer.state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    @objc
    private func swipedUp(_: UISwipeGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying else { return }
        if isMaskShow == false {
            isMaskShow = true
        }
    }

    @objc
    private func swipedDown(_: UISwipeGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying else { return }
        if isMaskShow == true {
            isMaskShow = false
        }
    }
}

#endif
