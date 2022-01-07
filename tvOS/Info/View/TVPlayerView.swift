//
//  TVPlayerView.swift
//  KSPlayer-iOS
//
//  Created by Alanko5 on 03/03/2021.
//

import UIKit
import AVFoundation

//MARK: - need custom playerView
final class TVPlayerView: VideoPlayerView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.topMaskView.isHidden = true
        self.bottomMaskView.isHidden = true
    }
    
    public func setSubtitlesBackgorund(color:UIColor) {
        subtitleBackView.backgroundColor = color.withAlphaComponent(0.4)
    }
    
    var isKSMEPlayer: Bool {
        get {
            return ((self.playerLayer.player as? KSMEPlayer) != nil)
        }
    }
    
    public var subtitlesDelay: Double {
        get {
            return self.resource?.definitions[self.currentDefinition].options.subtitleDelay ?? 0
        }
        set {
            self.resource?.definitions[self.currentDefinition].options.subtitleDelay = newValue
        }
    }
    
    public var subtitleColor: UIColor {
        get {
            return self.subtitleTextColor
        }
        set {
            self.subtitleTextColor = newValue
        }
    }
    
    public var subtitleBacgroundColor: UIColor? {
        get {
            return subtitleBackViewColor
        }
        set {
            subtitleBackViewColor = newValue
        }
    }
    
    public var subtitleSize: CGFloat {
        get {
            return self.subtitleLabel.font.pointSize
        }
        set {
            self.subtitleLabel.font = .systemFont(ofSize: newValue)
        }
    }
    
    public var selecetdDefionition: KSPlayerResourceDefinition? {
        get {
            self.resource?.definitions[safe: self.currentDefinition]
        }
        set {
            guard let newValue = newValue,
                  let index = self.resource?.definitions.firstIndex(of: newValue),
                  index != self.currentDefinition else { return }
            self.change(definitionIndex: index)
        }
    }
    
    public var soundOptions: SoundOptions {
        get {
            guard let player = self.playerLayer.player as? KSMEPlayer else { return .fullDynamicRange }
            return player.attackTime == 0.0249 ? .reduceLoudSounds : .fullDynamicRange
        }
        set {
            if newValue == .reduceLoudSounds {
                self.reduceLoudSounds()
            } else {
                self.fullDynamicRange()
            }
        }
    }
    
    private func reduceLoudSounds() {
        guard let player = self.playerLayer.player as? KSMEPlayer else { return }
        player.attackTime = 0.0249
        player.releaseTime = 0.2629
        player.threshold = -23.8
        player.expansionRatio = 20
        player.overallGain = 7.5
    }
    
    private func fullDynamicRange() {
        guard let player = self.playerLayer.player as? KSMEPlayer else { return }
        player.attackTime = 0.001
        player.releaseTime = 0.05
        player.threshold = -20
        player.expansionRatio = 2
        player.overallGain = 0
    }
}

enum SoundOptions: String, CaseIterable {
    case fullDynamicRange = "fullDynamicRange"
    case reduceLoudSounds = "reduceLoudSounds"
    
    var title:String {
        return self.rawValue
    }
}
