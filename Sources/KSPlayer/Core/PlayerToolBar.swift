//
//  ChooseButton.swift
//  Pods
//
//  Created by kintan on 16/5/21.
//
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import AVKit
public class PlayerToolBar: UIStackView {
    public let srtButton = UIButton()
    public let timeLabel = UILabel()
    public let currentTimeLabel = UILabel()
    public let totalTimeLabel = UILabel()
    public let playButton = UIButton()
    public let timeSlider = KSSlider()
    public let playbackRateButton = UIButton()
    public let videoSwitchButton = UIButton()
    public let audioSwitchButton = UIButton()
    public let definitionButton = UIButton()
    public let pipButton = UIButton()
    public var timeType = TimeType.minOrHour {
        didSet {
            if timeType != oldValue {
                let currentTimeText = currentTime.toString(for: timeType)
                let totalTimeText = totalTime.toString(for: timeType)
                currentTimeLabel.text = currentTimeText
                totalTimeLabel.text = totalTimeText
                timeLabel.text = "\(currentTimeText) / \(totalTimeText)"
            }
        }
    }

    public var currentTime: TimeInterval = 0 {
        didSet {
            guard !currentTime.isNaN else {
                currentTime = 0
                return
            }
            if currentTime != oldValue {
                let text = currentTime.toString(for: timeType)
                currentTimeLabel.text = text
                timeLabel.text = "\(text) / \(totalTime.toString(for: timeType))"
                timeSlider.value = Float(currentTime)
            }
        }
    }

    public var totalTime: TimeInterval = 0 {
        didSet {
            guard !totalTime.isNaN else {
                totalTime = 0
                return
            }
            if totalTime != oldValue {
                let text = totalTime.toString(for: timeType)
                totalTimeLabel.text = text
                timeLabel.text = "\(currentTime.toString(for: timeType)) / \(text)"
                timeSlider.maximumValue = Float(totalTime)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initUI()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initUI() {
        distribution = .fill
        currentTimeLabel.textColor = UIColor(hex: 0x9B9B9B)
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        currentTimeLabel.text = 0.toString(for: timeType)
        totalTimeLabel.textColor = UIColor(hex: 0x9B9B9B)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        totalTimeLabel.text = 0.toString(for: timeType)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .left
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        timeLabel.text = "\(0.toString(for: timeType)) / \(0.toString(for: timeType))"
        timeSlider.minimumValue = 0
        timeSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        timeSlider.minimumTrackTintColor = UIColor(red: 0.0, green: 164 / 255.0, blue: 1.0, alpha: 1.0)
        playButton.tag = PlayerButtonType.play.rawValue
        playButton.setImage(KSOptions.image(named: "toolbar_ic_play"), for: .normal)
        playButton.setImage(KSOptions.image(named: "toolbar_ic_pause"), for: .selected)
        playButton.setTitleColor(.brown, for: .focused)
        playbackRateButton.tag = PlayerButtonType.rate.rawValue
        playbackRateButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        playbackRateButton.setTitle(NSLocalizedString("speed", comment: ""), for: .normal)
        playbackRateButton.setTitleColor(.brown, for: .focused)
        definitionButton.tag = PlayerButtonType.definition.rawValue
        definitionButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        definitionButton.setTitleColor(.brown, for: .focused)
        audioSwitchButton.tag = PlayerButtonType.audioSwitch.rawValue
        audioSwitchButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        audioSwitchButton.setTitle(NSLocalizedString("switch audio", comment: ""), for: .normal)
        audioSwitchButton.setTitleColor(.brown, for: .focused)
        videoSwitchButton.tag = PlayerButtonType.videoSwitch.rawValue
        videoSwitchButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        videoSwitchButton.setTitle(NSLocalizedString("switch video", comment: ""), for: .normal)
        videoSwitchButton.setTitleColor(.brown, for: .focused)
        srtButton.tag = PlayerButtonType.srt.rawValue
        srtButton.setTitle(NSLocalizedString("subtitle", comment: ""), for: .normal)
        srtButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        srtButton.setTitleColor(.brown, for: .focused)
        pipButton.tag = PlayerButtonType.pictureInPicture.rawValue
        pipButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        pipButton.setTitleColor(.brown, for: .focused)
        if #available(tvOS 14.0, *) {
            pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStartImage, for: .normal)
            pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStopImage, for: .selected)
        } else {
            pipButton.setTitle(NSLocalizedString("pip", comment: ""), for: .normal)
        }
        playButton.translatesAutoresizingMaskIntoConstraints = false
        srtButton.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playButton.widthAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: 49),
            srtButton.widthAnchor.constraint(equalToConstant: 40),
        ])
    }

    override public func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        view.isHidden = false
    }

    #if canImport(UIKit)
    override open func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if let nextFocusedItem = context.nextFocusedItem as? UIButton {
            nextFocusedItem.tintColor = nextFocusedItem.titleColor(for: .focused)
        }
        if let previouslyFocusedItem = context.previouslyFocusedItem as? UIButton {
            if previouslyFocusedItem.isSelected {
                previouslyFocusedItem.tintColor = previouslyFocusedItem.titleColor(for: .selected)
            } else if previouslyFocusedItem.isHighlighted {
                previouslyFocusedItem.tintColor = previouslyFocusedItem.titleColor(for: .highlighted)
            } else {
                previouslyFocusedItem.tintColor = previouslyFocusedItem.titleColor(for: .normal)
            }
        }
    }
    #endif

    open func addTarget(_ target: AnyObject?, action: Selector) {
        playButton.addTarget(target, action: action, for: .primaryActionTriggered)
        playbackRateButton.addTarget(target, action: action, for: .primaryActionTriggered)
        definitionButton.addTarget(target, action: action, for: .primaryActionTriggered)
        audioSwitchButton.addTarget(target, action: action, for: .primaryActionTriggered)
        videoSwitchButton.addTarget(target, action: action, for: .primaryActionTriggered)
        srtButton.addTarget(target, action: action, for: .primaryActionTriggered)
        pipButton.addTarget(target, action: action, for: .primaryActionTriggered)
    }

    public func reset() {
        currentTime = 0
        totalTime = 0
        playButton.isSelected = false
        timeSlider.value = 0.0
        timeSlider.isPlayable = false
        playbackRateButton.setTitle(NSLocalizedString("speed", comment: ""), for: .normal)
    }
}

extension KSOptions {
    static func image(named: String) -> UIImage? {
        #if canImport(UIKit)
        return UIImage(named: named, in: .module, compatibleWith: nil)
        #else
        return Bundle.module.image(forResource: named)
        #endif
    }
}
