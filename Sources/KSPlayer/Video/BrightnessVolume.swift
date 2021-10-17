//
//  BrightnessVolume.swift
//  KSPlayer
//
//  Created by kintan on 2017/11/3.
//
#if canImport(UIKit)
import UIKit

open class BrightnessVolume {
    private var brightnessObservation: NSKeyValueObservation?
    public static let shared = BrightnessVolume()
    public var progressView: BrightnessVolumeViewProtocol & UIView = ProgressView()
    init() {
        #if !os(tvOS)
        brightnessObservation = UIScreen.main.observe(\.brightness, options: .new) { [weak self] _, change in
            if let self = self, let value = change.newValue {
                self.appearView()
                self.progressView.setProgress(Float(value), type: 0)
            }
        }
        #endif
        let name = NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification")
        NotificationCenter.default.addObserver(self, selector: #selector(volumeIsChanged(notification:)), name: name, object: nil)
        progressView.alpha = 0.0
    }

    public func move(to view: UIView) {
        progressView.move(to: view)
    }

    @objc private func volumeIsChanged(notification: NSNotification) {
        if let changeReason = notification.userInfo?["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String, changeReason == "ExplicitVolumeChange" {
            if let volume = notification.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? CGFloat {
                appearView()
                progressView.setProgress(Float(volume), type: 1)
            }
        }
    }

    private func appearView() {
        if progressView.alpha == 0.0 {
            progressView.alpha = 1.0
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) { [weak self] () -> Void in
                self?.disAppearView()
            }
        }
    }

    private func disAppearView() {
        if progressView.alpha == 1.0 {
            UIView.animate(withDuration: 0.8) { [weak self] () -> Void in
                self?.progressView.alpha = 0.0
            }
        }
    }

    deinit {
        brightnessObservation?.invalidate()
    }
}

public protocol BrightnessVolumeViewProtocol {
    // type: 0 brightness type: 1 volume
    func setProgress(_ progress: Float, type: UInt)
    func move(to view: UIView)
}

private final class SystemView: UIVisualEffectView {
    private let stackView = UIStackView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private lazy var brightnessImage = KSPlayerManager.image(named: "KSPlayer_brightness")
    private lazy var volumeImage = KSPlayerManager.image(named: "KSPlayer_volume")
    private convenience init() {
        self.init(effect: UIBlurEffect(style: .extraLight))
        clipsToBounds = true
        cornerRadius = 10
        imageView.image = brightnessImage
        contentView.addSubview(imageView)
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = UIColor(red: 0.25, green: 0.22, blue: 0.21, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.text = "亮度"
        contentView.addSubview(titleLabel)
        let longView = UIView()
        longView.backgroundColor = titleLabel.textColor
        contentView.addSubview(longView)
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.axis = .horizontal
        stackView.spacing = 1
        longView.addSubview(stackView)
        for _ in 0 ..< 16 {
            let tipView = UIView()
            tipView.backgroundColor = .white
            stackView.addArrangedSubview(tipView)
            tipView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tipView.heightAnchor.constraint(equalTo: stackView.heightAnchor),
            ])
        }
        translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        longView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 79),
            imageView.heightAnchor.constraint(equalToConstant: 76),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            titleLabel.widthAnchor.constraint(equalTo: widthAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 30),
            longView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            longView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            longView.heightAnchor.constraint(equalToConstant: 7),
            longView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            stackView.leadingAnchor.constraint(equalTo: longView.leadingAnchor, constant: 1),
            stackView.trailingAnchor.constraint(equalTo: longView.trailingAnchor, constant: -1),
            stackView.topAnchor.constraint(equalTo: longView.topAnchor, constant: 1),
            stackView.bottomAnchor.constraint(equalTo: longView.bottomAnchor, constant: -1),
        ])
    }
}

extension SystemView: BrightnessVolumeViewProtocol {
    public func setProgress(_ progress: Float, type: UInt) {
        if type == 0 {
            imageView.image = brightnessImage
            titleLabel.text = NSLocalizedString("brightness", comment: "")
        } else {
            imageView.image = volumeImage
            titleLabel.text = NSLocalizedString("volume", comment: "")
        }
        let level = Int(progress * Float(stackView.arrangedSubviews.count))
        for i in 0 ..< stackView.arrangedSubviews.count {
            let view = stackView.arrangedSubviews[i]
            if i <= level, level > 0 {
                view.alpha = 1
            } else {
                view.alpha = 0
            }
        }
    }

    public func move(to view: UIView) {
        if superview != view {
            removeFromSuperview()
            view.addSubview(self)
            translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                centerXAnchor.constraint(equalTo: view.centerXAnchor),
                centerYAnchor.constraint(equalTo: view.centerYAnchor),
                heightAnchor.constraint(equalToConstant: 155),
                widthAnchor.constraint(equalToConstant: 155),
            ])
        }
    }
}

private final class ProgressView: UIView {
    private lazy var brightnessImage = KSPlayerManager.image(named: "ic_light")
    private lazy var volumeImage = KSPlayerManager.image(named: "ic_voice")
    private lazy var brightnessOffImage = KSPlayerManager.image(named: "ic_light_off")
    private lazy var volumeOffImage = KSPlayerManager.image(named: "ic_voice_off")
    private let progressView = UIProgressView()
    private let imageView = UIImageView()

    override init(frame _: CGRect) {
        super.init(frame: .zero)
        addSubview(progressView)
        addSubview(imageView)
        progressView.progressTintColor = UIColor.white
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.5)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.centerRotate(byDegrees: -90)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressView.widthAnchor.constraint(equalToConstant: 115),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            progressView.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressView.topAnchor.constraint(equalTo: topAnchor, constant: 57),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ProgressView: BrightnessVolumeViewProtocol {
    func setProgress(_ progress: Float, type: UInt) {
        progressView.setProgress(progress, animated: false)
        if progress == 0 {
            imageView.image = type == 0 ? brightnessOffImage : volumeOffImage
        } else {
            imageView.image = type == 0 ? brightnessImage : volumeImage
        }
    }

    func move(to view: UIView) {
        if superview != view {
            removeFromSuperview()
            view.addSubview(self)
            translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                trailingAnchor.constraint(equalTo: view.safeTrailingAnchor, constant: -10),
                centerYAnchor.constraint(equalTo: view.centerYAnchor),
                heightAnchor.constraint(equalToConstant: 150),
                widthAnchor.constraint(equalToConstant: 24),
            ])
        }
    }
}
#endif
