//
//  AudioPlayerController.swift
//  VoiceNote
//
//  Created by kintan on 2018/8/16.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
open class AudioPlayerView: PlayerView {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        toolBar.timeType = .min
        toolBar.spacing = 5
        toolBar.addArrangedSubview(toolBar.playButton)
        toolBar.addArrangedSubview(toolBar.currentTimeLabel)
        toolBar.addArrangedSubview(toolBar.timeSlider)
        toolBar.addArrangedSubview(toolBar.totalTimeLabel)
        toolBar.playButton.tintColor = UIColor(hex: 0x2166FF)
        toolBar.timeSlider.setThumbImage(UIColor(hex: 0x2980FF).createImage(size: CGSize(width: 2, height: 15)), for: .normal)
        toolBar.timeSlider.minimumTrackTintColor = UIColor(hex: 0xC8C7CC)
        toolBar.timeSlider.maximumTrackTintColor = UIColor(hex: 0xEDEDED)
        toolBar.timeSlider.trackHeigt = 7
        addSubview(toolBar)
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            toolBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            toolBar.topAnchor.constraint(equalTo: topAnchor),
            toolBar.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
