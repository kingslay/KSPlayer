//
//  TVPlayerView.swift
//  KSPlayer-iOS
//
//  Created by Alanko5 on 03/03/2021.
//

import UIKit
import AVFoundation
import AVKit

//MARK: - need custom playerView
final class TVPlayerView: VideoPlayerView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.topMaskView.isHidden = true
        self.bottomMaskView.isHidden = true
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        if #available(tvOS 13.0, *) {
            displayCriteria = nil
        }
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
    
    public var subtitleColor: UIColor
    {
        get {
            return self.subtitleTextColor
        }
        set {
            self.subtitleTextColor = newValue
        }
    }
    
    public var subtitleBacgroundColor: UIColor?
    {
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
    
    override public func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        guard state == .readyToPlay, let player = layer.player else { return }
        var fps: Float = 24.0
        var dynamicRange: DynamicRange = .SDR
        
        for track in player.tracks(mediaType: .video) {
            fps = track.nominalFrameRate
            
            if track.codecType.string == "ehvd" /// DolbyVision
            {
                dynamicRange = .DV
            }
            else if let colorPrimaries = track.colorPrimaries, /// HDR
                colorPrimaries.contains("2020")  {
                dynamicRange = .HDR
            }
            //video name: eng bitRate: 0 fps: 23.976025 bitDepth: 10 colorPrimaries: ITU_R_2020 colorPrimaries: SMPTE_ST_2084_PQ yCbCrMatrix: ITU_R_2020 codecType:
            //video name: und bitRate: 17804863 fps: 23.976025 bitDepth: 10 colorPrimaries:  colorPrimaries:  yCbCrMatrix:  codecType:  ehvd
        }
        if #available(tvOS 13.0, *) {
            set(fps: fps, contentMode: dynamicRange)
        }
    }
}

// MARK: - updating display settings
enum DynamicRange: Int {
    case SDR = 0
    case HDR = 2
    case DV = 5
}
@available(tvOS 13.0, *)
extension TVPlayerView {
    private var displayManager: AVDisplayManager? {
        if let avDisplayManager = UIApplication.shared.delegate?.window??.avDisplayManager {
            return avDisplayManager
        }
        return nil
    }
    
    private var displayCriteria: AVDisplayCriteria? {
        get {
            guard let displayManager = displayManager else { return nil }
            return displayManager.preferredDisplayCriteria
        }
        set {
            guard let displayManager = displayManager else { return }
            if displayManager.isDisplayCriteriaMatchingEnabled,
                !displayManager.isDisplayModeSwitchInProgress {
                displayManager.preferredDisplayCriteria = newValue
            }
        }
    }

    
    private func set(fps:Float, contentMode: DynamicRange) {
        let criteria =  AVDisplayCriteria(refreshRate: fps,
                                          videoDynamicRange: Int32(contentMode.rawValue))
        displayCriteria = criteria
    }
}

enum SoundOptions: String, CaseIterable {
    case fullDynamicRange = "fullDynamicRange"
    case reduceLoudSounds = "reduceLoudSounds"
    
    var title:String {
        return self.rawValue
    }
}
