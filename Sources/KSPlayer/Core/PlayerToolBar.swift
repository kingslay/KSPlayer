//
//  PlayerToolBar.swift
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
    public var onFocusUpdate: ((_ cofusedItem: UIView) -> Void)?
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
                if isLiveStream {
                    timeSlider.value = Float(todayInterval)
                } else {
                    timeSlider.value = Float(currentTime)
                }
            }
        }
    }

    lazy var startDateTimeInteral: TimeInterval = {
        let date = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let startDate = calendar.date(from: components)
        return startDate?.timeIntervalSince1970 ?? 0
    }()

    var todayInterval: TimeInterval {
        Date().timeIntervalSince1970 - startDateTimeInteral
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
            if isLiveStream {
                timeSlider.maximumValue = Float(60 * 60 * 24)
            }
        }
    }

    public var isLiveStream: Bool {
        totalTime == 0
    }

    public var isSeekable: Bool = true {
        didSet {
            timeSlider.isUserInteractionEnabled = isSeekable
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
        let focusColor = UIColor.white
        let tintColor = UIColor.gray
        distribution = .fill
        currentTimeLabel.textColor = UIColor(rgb: 0x9B9B9B)
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        currentTimeLabel.text = 0.toString(for: timeType)
        totalTimeLabel.textColor = UIColor(rgb: 0x9B9B9B)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        totalTimeLabel.text = 0.toString(for: timeType)

        timeLabel.textColor = UIColor(rgb: 0x9B9B9B)
        timeLabel.textAlignment = .left
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        timeLabel.text = "\(0.toString(for: timeType)) / \(0.toString(for: timeType))"
        timeSlider.minimumValue = 0
        #if os(iOS)
        if #available(macCatalyst 15.0, iOS 15.0, *) {
            timeSlider.preferredBehavioralStyle = .pad
            timeSlider.maximumTrackTintColor = focusColor.withAlphaComponent(0.2)
            timeSlider.minimumTrackTintColor = focusColor
        }
        #endif
        #if !targetEnvironment(macCatalyst)
        timeSlider.maximumTrackTintColor = focusColor.withAlphaComponent(0.2)
        timeSlider.minimumTrackTintColor = focusColor
        #endif
        playButton.tag = PlayerButtonType.play.rawValue
        playButton.setTitleColor(focusColor, for: .focused)
        playButton.setTitleColor(tintColor, for: .normal)
        playbackRateButton.tag = PlayerButtonType.rate.rawValue
        playbackRateButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        playbackRateButton.setTitleColor(focusColor, for: .focused)
        playbackRateButton.setTitleColor(tintColor, for: .normal)
        definitionButton.tag = PlayerButtonType.definition.rawValue
        definitionButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        definitionButton.setTitleColor(focusColor, for: .focused)
        definitionButton.setTitleColor(tintColor, for: .normal)
        audioSwitchButton.tag = PlayerButtonType.audioSwitch.rawValue
        audioSwitchButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        audioSwitchButton.setTitleColor(focusColor, for: .focused)
        audioSwitchButton.setTitleColor(tintColor, for: .normal)
        videoSwitchButton.tag = PlayerButtonType.videoSwitch.rawValue
        videoSwitchButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        videoSwitchButton.setTitleColor(focusColor, for: .focused)
        videoSwitchButton.setTitleColor(tintColor, for: .normal)
        srtButton.tag = PlayerButtonType.srt.rawValue
        srtButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        srtButton.setTitleColor(focusColor, for: .focused)
        srtButton.setTitleColor(tintColor, for: .normal)
        pipButton.tag = PlayerButtonType.pictureInPicture.rawValue
        pipButton.titleFont = .systemFont(ofSize: 14, weight: .medium)
        pipButton.setTitleColor(focusColor, for: .focused)
        pipButton.setTitleColor(tintColor, for: .normal)
        if #available(macOS 11.0, *) {
            pipButton.setImage(UIImage(systemName: "pip.enter"), for: .normal)
            pipButton.setImage(UIImage(systemName: "pip.exit"), for: .selected)
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
            srtButton.setImage(UIImage(systemName: "captions.bubble"), for: .normal)
            definitionButton.setImage(UIImage(systemName: "arrow.up.right.video"), for: .normal)
            audioSwitchButton.setImage(UIImage(systemName: "waveform"), for: .normal)
            videoSwitchButton.setImage(UIImage(systemName: "video.badge.ellipsis"), for: .normal)
            playbackRateButton.setImage(UIImage(systemName: "speedometer"), for: .normal)
        }
        playButton.translatesAutoresizingMaskIntoConstraints = false
        srtButton.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        if #available(tvOS 14.0, *) {
            pipButton.isHidden = !AVPictureInPictureController.isPictureInPictureSupported()
        }
        #if os(tvOS)
        srtButton.fillImage()
        pipButton.fillImage()
        playButton.fillImage()
        definitionButton.fillImage()
        audioSwitchButton.fillImage()
        videoSwitchButton.fillImage()
        playbackRateButton.fillImage()
        playButton.tintColor = tintColor
        playbackRateButton.tintColor = tintColor
        definitionButton.tintColor = tintColor
        audioSwitchButton.tintColor = tintColor
        videoSwitchButton.tintColor = tintColor
        srtButton.tintColor = tintColor
        pipButton.tintColor = tintColor
        timeSlider.tintColor = tintColor
        NSLayoutConstraint.activate([
            playButton.widthAnchor.constraint(equalTo: playButton.heightAnchor),
            playbackRateButton.widthAnchor.constraint(equalTo: playbackRateButton.heightAnchor),
            definitionButton.widthAnchor.constraint(equalTo: definitionButton.heightAnchor),
            audioSwitchButton.widthAnchor.constraint(equalTo: audioSwitchButton.heightAnchor),
            videoSwitchButton.widthAnchor.constraint(equalTo: videoSwitchButton.heightAnchor),
            srtButton.widthAnchor.constraint(equalTo: srtButton.heightAnchor),
            pipButton.widthAnchor.constraint(equalTo: pipButton.heightAnchor),
            heightAnchor.constraint(equalToConstant: 40),
        ])
        #else
        timeSlider.tintColor = .white
        playButton.tintColor = .white
        playbackRateButton.tintColor = .white
        definitionButton.tintColor = .white
        audioSwitchButton.tintColor = .white
        videoSwitchButton.tintColor = .white
        srtButton.tintColor = .white
        pipButton.tintColor = .white
        NSLayoutConstraint.activate([
            playButton.widthAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: 49),
            srtButton.widthAnchor.constraint(equalToConstant: 40),
        ])
        #endif
    }

    override public func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        view.isHidden = false
    }

    #if canImport(UIKit)
    override open func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if let nextFocusedItem = context.nextFocusedItem {
            if let nextFocusedButton = nextFocusedItem as? UIButton {
                nextFocusedButton.tintColor = nextFocusedButton.titleColor(for: .focused)
            }
            if context.previouslyFocusedItem != nil,
               let nextFocusedView = nextFocusedItem as? UIView
            {
                onFocusUpdate?(nextFocusedView)
            }
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
