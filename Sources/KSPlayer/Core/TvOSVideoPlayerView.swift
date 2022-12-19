//
//  TvOSVideoPlayerView.swift
//  KSPlayer
//
//  Created by Alanko5 on 17/12/2022.
//

import Foundation
import Combine
import AVFAudio
import AVKit
import MediaPlayer

#if os(tvOS)

open class TvOSVideoPlayerView: VideoPlayerView {
    open override func customizeUIComponents() {
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
    }
}


// MARK: -
extension TvOSVideoPlayerView {

}

#endif
