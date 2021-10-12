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
        playButton.tag = PlayerButtonType.play.rawValue
        playButton.setImage(KSPlayerManager.image(named: "toolbar_ic_play"), for: .normal)
        playButton.setImage(KSPlayerManager.image(named: "toolbar_ic_pause"), for: .selected)
        currentTimeLabel.textColor = UIColor(hex: 0x9B9B9B)
        currentTimeLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 14)
        currentTimeLabel.text = 0.toString(for: timeType)
        totalTimeLabel.textColor = UIColor(hex: 0x9B9B9B)
        totalTimeLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 14)
        totalTimeLabel.text = 0.toString(for: timeType)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .left
        timeLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 14)
        timeLabel.text = "\(0.toString(for: timeType)) / \(0.toString(for: timeType))"
        timeSlider.minimumValue = 0
        timeSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        timeSlider.minimumTrackTintColor = UIColor(red: 0.0, green: 164 / 255.0, blue: 1.0, alpha: 1.0)
        playbackRateButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        playbackRateButton.setTitle(NSLocalizedString("speed", comment: ""), for: .normal)
        playbackRateButton.tag = PlayerButtonType.rate.rawValue
        definitionButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        definitionButton.tag = PlayerButtonType.definition.rawValue
        srtButton.setTitle(NSLocalizedString("subtitle", comment: ""), for: .normal)
        srtButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        srtButton.tag = PlayerButtonType.srt.rawValue
        pipButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        if #available(iOS 13.0, tvOS 14.0, macOS 10.15, *) {
            pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStartImage, for: .normal)
            pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStopImage, for: .selected)
        } else {
            pipButton.setTitle(NSLocalizedString("pip", comment: ""), for: .normal)
        }
        pipButton.tag = PlayerButtonType.pictureInPicture.rawValue
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

    open func addTarget(_ target: AnyObject?, action: Selector) {
        playButton.addTarget(target, action: action, for: .primaryActionTriggered)
        playbackRateButton.addTarget(target, action: action, for: .primaryActionTriggered)
        definitionButton.addTarget(target, action: action, for: .primaryActionTriggered)
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

public enum TimeType {
    case min
    case hour
    case minOrHour
    case millisecond
}

public extension TimeInterval {
    func toString(for type: TimeType) -> String {
        var second = ceil(self)
        var min = floor(second / 60)
        second -= min * 60
        switch type {
        case .min:
            return String(format: "%02.0f:%02.0f", min, second)
        case .hour:
            let hour = floor(min / 60)
            min -= hour * 60
            return String(format: "%.0f:%02.0f:%02.0f", hour, min, second)
        case .minOrHour:
            let hour = floor(min / 60)
            if hour > 0 {
                min -= hour * 60
                return String(format: "%.0f:%02.0f:%02.0f", hour, min, second)
            } else {
                return String(format: "%02.0f:%02.0f", min, second)
            }
        case .millisecond:
            var time = Int(self * 100)
            let millisecond = time % 100
            time /= 100
            let sec = time % 60
            time /= 60
            let min = time % 60
            time /= 60
            let hour = time % 60
            if hour > 0 {
                return String(format: "%d:%02d:%02d.%02d", hour, min, sec, millisecond)
            } else {
                return String(format: "%02d:%02d.%02d", min, sec, millisecond)
            }
        }
    }
}
