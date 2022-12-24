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

        toolBar.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        toolBar.playButton.setImage(UIImage(systemName: "play.fill"), for: .selected)
        toolBar.audioSwitchButton.setImage(UIImage(systemName: "waveform"), for: .normal)
        toolBar.definitionButton.setImage(UIImage(systemName: "arrow.up.right.video"), for: .normal)
        toolBar.playbackRateButton.setImage(UIImage(systemName: "speedometer"), for: .normal)
        toolBar.videoSwitchButton.setImage(UIImage(systemName: "video.badge.ellipsis"), for: .normal)
        toolBar.srtButton.setImage(UIImage(systemName: "contextualmenu.and.cursorarrow"), for: .normal)

        toolBar.audioSwitchButton.setTitle(nil, for: .normal)
        toolBar.definitionButton.setTitle(nil, for: .normal)
        toolBar.playbackRateButton.setTitle(nil, for: .normal)
        toolBar.videoSwitchButton.setTitle(nil, for: .normal)
        toolBar.srtButton.setTitle(nil, for: .normal)

        toolBar.playButton.fillImage()
        toolBar.playbackRateButton.fillImage()
        toolBar.definitionButton.fillImage()
        toolBar.audioSwitchButton.fillImage()
        toolBar.videoSwitchButton.fillImage()
        toolBar.srtButton.fillImage()
        toolBar.pipButton.fillImage()

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
        if let playerLayer,
           playerLayer.state.isPlaying
        {
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
