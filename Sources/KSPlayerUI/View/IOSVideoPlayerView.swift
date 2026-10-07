//
//  IOSVideoPlayerView.swift
//  Pods
//
//  Created by kintan on 2018/10/31.
//
#if canImport(UIKit) && canImport(CallKit)
import AVKit
import Combine
import CoreServices
import KSPlayer
import MediaPlayer
import Network
import SwiftUI
import UIKit

open class IOSVideoPlayerView: VideoPlayerView {
    private weak var originalSuperView: UIView?
    private var originalframeConstraints: [NSLayoutConstraint]?
    private var originalFrame = CGRect.zero
    private weak var fullScreenDelegate: PlayerViewFullScreenDelegate?
    private var isVolume = false
    private let volumeView = BrightnessVolume()
    public var volumeViewSlider = UXSlider()
    public var backButton = UIButton()
    public var airplayStatusView: UIView = AirplayStatusView()
    #if !os(visionOS)
    public var routeButton = AVRoutePickerView()
    #endif
    private let routeDetector = AVRouteDetector()
    /// Image view to show video cover
    public var maskImageView = UIImageView()
    public var landscapeButton: UIControl = UIButton()

    // Additional UI components from BoxPlayerView
    public var aspectFillButton = UIButton(type: .system)
    public var screenShotButton = UIButton(type: .system)
    public let previousButton = UIButton(type: .system)
    public let toolBarPlayButton = UIButton(type: .system)
    public let nextButton = UIButton(type: .system)
    public let audioMenuButton = UIButton(type: .system)
    public let subtitleMenuButton = UIButton(type: .system)
    public let unifiedSettingsButton = UIButton(type: .system)
    public let jumpbackButton = UIButton(type: .system)
    public let playPauseButton = UIButton(type: .system)
    public let jumpForwardButton = UIButton(type: .system)

    /// Background views
    private let topLeftBackground = {
        let view = UIView()
        view.backgroundColor = .clear
        view.alpha = 0.4
        return view
    }()

    private let topRightBackground = {
        let view = UIView()
        view.backgroundColor = .clear
        view.alpha = 0.4
        return view
    }()

    private let bottomBackground = {
        let view = UIView()
        view.backgroundColor = .clear
        view.alpha = 0.4
        return view
    }()

    private let leftBackgroundView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.alpha = 0.4
        return view
    }()

    // Status bar and info components
    private var topStatusBar: UIStackView!
    private var currentItemTitleLabel: UILabel!
    private var codecLabel: UILabel!
    private var resolutionLabel: UILabel!
    private var fpsLabel: UILabel!
    private var bitrateLabel: UILabel!
    private var networkSpeedLabel: UILabel!
    private var networkStatusImageView: UIImageView!
    private var batteryImageView: UIImageView!
    private var displayTitleLabel: UILabel!

    /// Video info container
    private let videoInfoContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Tracking properties
    private var watchedProgress: TimeInterval = 0.0
    private var itemId: String?
    public var title: String?
    var selectedAudioTrack: MediaPlayerTrack?
    private var cancellables = Set<AnyCancellable>()
    /// Screenshot preview
    private var screenshotPreviewView: UIView?

    // Progress bar properties
    private var bottomSlimProgressView: UIView?
    private var bottomSlimProgressSlider: KSSlider?

    /// Prompt label
    private let promptLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        label.alpha = 0.0
        return label
    }()

    // Custom delay and animation properties
    private var customDelayItem: DispatchWorkItem?
    private let jumpButtonConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)
    private let playButtonConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)
    private let toolBarPlayButtonConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)

    // Layout constraint properties for dynamic positioning
    private var topStatusLeadingConstraint: NSLayoutConstraint!
    private var topStatusTrailingConstraint: NSLayoutConstraint!
    private var topLeftBackgroundLeadingConstraint: NSLayoutConstraint!
    private var topRightBackgroundTrailingConstraint: NSLayoutConstraint!
    private var leftBackgroundViewLeadingConstraint: NSLayoutConstraint!
    private var bottomBackgroundLeadingConstraint: NSLayoutConstraint!
    private var bottomBackgroundTrailingConstraint: NSLayoutConstraint!
    private var bottomBackgroundHeightConstraint: NSLayoutConstraint!

    // Timer properties
    private var speedUpdateTimer: Timer?
    private var timeLabelUpdateTimer: Timer?
    private var smoothedSpeed: Double = 0

    /// Settings view integration
    private lazy var settingsView: SettingsView = .init()

    override open var isMaskShow: Bool {
        didSet {
            fullScreenDelegate?.player(isMaskShow: isMaskShow, isFullScreen: landscapeButton.isSelected)

            let alpha: CGFloat = isMaskShow && !isLock ? 1.0 : 0.0
            let leftPanelAlpha: CGFloat = isMaskShow ? 1.0 : 0.0

            UIView.animate(withDuration: 0.3) {
                self.videoInfoContainer.alpha = alpha
                self.topLeftBackground.alpha = alpha
                self.topRightBackground.alpha = alpha
                self.bottomBackground.alpha = alpha
                self.leftBackgroundView.alpha = leftPanelAlpha

                self.currentItemTitleLabel?.alpha = alpha
                self.networkStatusImageView?.alpha = alpha
                self.batteryImageView?.alpha = alpha
                self.displayTitleLabel?.alpha = alpha
                self.jumpbackButton.alpha = alpha
                self.playPauseButton.alpha = alpha
                self.jumpForwardButton.alpha = alpha
                self.networkSpeedLabel?.alpha = alpha
                self.layoutIfNeeded()
            }

            if isMaskShow, !isLock {
                customAutoFadeOutViewWithAnimation()
            }
        }
    }

    #if !os(visionOS)
    private var brightness: CGFloat = UIScreen.main.brightness {
        didSet {
            UIScreen.main.brightness = brightness
        }
    }
    #endif

    override open func customizeUIComponents() {
        super.customizeUIComponents()

        // Setup basic components first
        insertSubview(maskImageView, at: 0)
        maskImageView.contentMode = .scaleAspectFit
        // landscapeButton will be added to topLeftButtons instead
        landscapeButton.tag = PlayerButtonType.landscape.rawValue
        landscapeButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        landscapeButton.tintColor = .white
        if let landscapeButton = landscapeButton as? UIButton {
            if #available(iOS 17.0, *) {
                landscapeButton.setImage(UIImage(systemName: "rectangle.landscape.rotate"), for: .normal)
                landscapeButton.setImage(UIImage(systemName: "rectangle.portrait.rotate"), for: .selected)
            } else {
                // Fallback icons for iOS 16 and below
                landscapeButton.setImage(UIImage(systemName: "rotate.right"), for: .normal)
                landscapeButton.setImage(UIImage(systemName: "rotate.left"), for: .selected)
            }
        }
        backButton.tag = PlayerButtonType.back.rawValue
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        backButton.tintColor = .white
        // backButton will be added to topLeftButtons instead

        addSubview(airplayStatusView)
        volumeView.move(to: self)
        #if !targetEnvironment(macCatalyst)
        let tmp = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 0, height: 0))
        if let first = (tmp.subviews.first { $0 is UISlider }) as? UISlider {
            volumeViewSlider = first
        }
        #endif

        // Hide original toolbar components
        toolBar.isHidden = true
        toolBar.timeSlider.isHidden = false
        toolBar.playbackRateButton.isHidden = false
        replayButton.isEnabled = false
        replayButton.isHidden = true

        // Initialize alpha states for new components
        topLeftBackground.alpha = 0
        topRightBackground.alpha = 0
        bottomBackground.alpha = 0
        leftBackgroundView.alpha = 0
        jumpbackButton.alpha = 0
        playPauseButton.alpha = 0
        jumpForwardButton.alpha = 0

        // Setup new UI components
        setupBackgrounds()
        setupTopLeftButtons()
        setupTopRightButton()
        setupSideButtons()
        setupBottomControls()
        setupCenterControls()
        setupVideoInfoLabels()
        setupScreenshotPreview()
        setupTopStatusBar()

        // Initial setup for status components
        currentItemTitleLabel?.alpha = 0
        networkStatusImageView?.alpha = 0
        batteryImageView?.alpha = 0
        displayTitleLabel?.alpha = 0
        networkSpeedLabel?.alpha = 0

        // Set background color
        backgroundColor = .black

        // Setup constraints for existing components
        maskImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            maskImageView.topAnchor.constraint(equalTo: topAnchor),
            maskImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            maskImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            maskImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            airplayStatusView.centerXAnchor.constraint(equalTo: centerXAnchor),
            airplayStatusView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        #if !os(visionOS)
        routeButton.isHidden = true
        #endif
        addNotification()
    }

    // MARK: - Setup Methods

    private func setupBackgrounds() {
        for item in [
            topLeftBackground,
            topRightBackground,
            bottomBackground,
            leftBackgroundView,
        ] {
            item.layer.cornerRadius = 10
            item.clipsToBounds = true
            item.translatesAutoresizingMaskIntoConstraints = false
            item.backgroundColor = .clear
            addSubview(item)
        }

        leftBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5) // 增加透明度以更好地可见

        topLeftBackgroundLeadingConstraint = topLeftBackground.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: UIDevice.isPhone ? 20 : 15
        )
        topRightBackgroundTrailingConstraint = topRightBackground.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: UIDevice.isPhone ? -20 : -15
        )
        leftBackgroundViewLeadingConstraint = leftBackgroundView.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: UIDevice.isPhone ? 33 : 10
        )
        bottomBackgroundLeadingConstraint = bottomBackground.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: UIDevice.isPhone ? 20 : 15
        )
        bottomBackgroundTrailingConstraint = bottomBackground.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: UIDevice.isPhone ? -20 : -15
        )

        bottomBackgroundHeightConstraint = bottomBackground.heightAnchor.constraint(equalToConstant: 100)
        NSLayoutConstraint.activate([
            topLeftBackground.safeAreaLayoutGuide.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            topLeftBackground.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            topLeftBackgroundLeadingConstraint,
            topRightBackground.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            topRightBackgroundTrailingConstraint,

            leftBackgroundViewLeadingConstraint,
            leftBackgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftBackgroundView.widthAnchor.constraint(equalToConstant: 50),
            leftBackgroundView.heightAnchor.constraint(equalToConstant: 100),

            bottomBackgroundLeadingConstraint,
            bottomBackgroundTrailingConstraint,
            bottomBackground.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bottomBackgroundHeightConstraint,
        ])
    }

    private func setupTopLeftButtons() {
        // Create horizontal stack with backButton, aspectFillButton, routeButton, landscapeButton
        var stackViewArrangedSubviews: [UIView] = [backButton, aspectFillButton]

        #if os(visionOS)
        stackViewArrangedSubviews.append(contentsOf: [landscapeButton])
        #else
        stackViewArrangedSubviews.append(contentsOf: [routeButton, landscapeButton])
        #endif
        let stackView = UIStackView(arrangedSubviews: stackViewArrangedSubviews)
        stackView.axis = .horizontal
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        topLeftBackground.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topLeftBackground.topAnchor, constant: -5),
            stackView.leadingAnchor.constraint(equalTo: topLeftBackground.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: topLeftBackground.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: topLeftBackground.bottomAnchor, constant: -10),
        ])
        stackView.heightAnchor.constraint(equalToConstant: 35).isActive = true

        configureButton(aspectFillButton, systemName: "rectangle.arrowtriangle.2.inward", size: 15, weight: .bold)
        aspectFillButton.addTarget(self, action: #selector(handleAspectFillButtonTapped), for: .touchUpInside)

        aspectFillButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        aspectFillButton.heightAnchor.constraint(equalToConstant: 30).isActive = true

        // Configure backButton size to match other buttons
        backButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: 30).isActive = true

        // Configure landscapeButton size to match other buttons
        landscapeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        landscapeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true

        #if !os(visionOS)
        // Configure routeButton size to match other buttons
        routeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        routeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        #endif
    }

    private func setupTopRightButton() {
        let stackView = UIStackView(arrangedSubviews: [
            toolBar.pipButton,
            screenShotButton,
            toolBar.playbackRateButton,
            unifiedSettingsButton,
        ])
        stackView.axis = .horizontal
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        topRightBackground.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topRightBackground.topAnchor, constant: -5),
            stackView.leadingAnchor.constraint(equalTo: topRightBackground.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: topRightBackground.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: topRightBackground.bottomAnchor, constant: -10),
        ])
        stackView.heightAnchor.constraint(equalToConstant: 35).isActive = true

        configureButton(screenShotButton, systemName: "camera.fill", size: 15, weight: .bold)
        screenShotButton.addTarget(self, action: #selector(handleScreenshot), for: .touchUpInside)

        configureButton(unifiedSettingsButton, systemName: "gear", size: 15, weight: .bold)
        unifiedSettingsButton.addTarget(self, action: #selector(handleUnifiedSettingsButtonTapped), for: .touchUpInside)

        let playbackConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        toolBar.playbackRateButton.setImage(UIImage(systemName: "speedometer", withConfiguration: playbackConfig), for: .normal)
        toolBar.playbackRateButton.setTitle("", for: .normal)
        toolBar.playbackRateButton.tintColor = .white

        toolBar.pipButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        toolBar.pipButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        screenShotButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        screenShotButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        unifiedSettingsButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        unifiedSettingsButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        toolBar.playbackRateButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        toolBar.playbackRateButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func setupSideButtons() {
        leftBackgroundView.isHidden = false

        // 重新配置继承的lockButton以适应我们的设计
        // 首先移除父类中添加的约束
        lockButton.removeFromSuperview()

        // 重置所有约束
        lockButton.translatesAutoresizingMaskIntoConstraints = false

        // 重新设置lockButton的样式
        lockButton.backgroundColor = .clear // 移除背景色
        lockButton.layer.cornerRadius = 0 // 移除圆角
        lockButton.isHidden = false // 确保lockButton显示

        // 重新配置按钮图标和样式
        if #available(macOS 11.0, *) {
            let lockConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
            lockButton.setImage(UIImage(systemName: "lock", withConfiguration: lockConfig), for: .normal)
            lockButton.setImage(UIImage(systemName: "lock.open", withConfiguration: lockConfig), for: .selected)
        }
        lockButton.tintColor = .white

        let leftStackView = UIStackView(arrangedSubviews: [lockButton])
        leftStackView.axis = .vertical
        leftStackView.alignment = .center
        leftStackView.spacing = 10
        leftStackView.translatesAutoresizingMaskIntoConstraints = false
        leftBackgroundView.addSubview(leftStackView)

        NSLayoutConstraint.activate([
            lockButton.widthAnchor.constraint(equalToConstant: 50),
            lockButton.heightAnchor.constraint(equalToConstant: 50),
            leftStackView.centerXAnchor.constraint(equalTo: leftBackgroundView.centerXAnchor),
            leftStackView.centerYAnchor.constraint(equalTo: leftBackgroundView.centerYAnchor),
        ])

        toolBar.timeSlider.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func setupCenterControls() {
        let centerStackView = UIStackView(arrangedSubviews: [jumpbackButton, playPauseButton, jumpForwardButton])
        centerStackView.axis = .horizontal
        centerStackView.spacing = 60
        centerStackView.alignment = .center
        centerStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(centerStackView)

        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(handlePlayPause), for: .touchUpInside)

        configureButton(toolBarPlayButton, systemName: "play.fill", size: 15, weight: .bold)
        toolBarPlayButton.tintColor = .white
        toolBarPlayButton.backgroundColor = .clear
        toolBarPlayButton.addTarget(self, action: #selector(handlePlayPause), for: .touchUpInside)

        jumpbackButton.setImage(UIImage(systemName: "gobackward", withConfiguration: jumpButtonConfig), for: .normal)
        jumpbackButton.tintColor = .white

        jumpForwardButton.setImage(UIImage(systemName: "goforward", withConfiguration: jumpButtonConfig), for: .normal)
        jumpForwardButton.tintColor = .white

        jumpbackButton.addTarget(self, action: #selector(handleJumpBack), for: .touchUpInside)
        jumpForwardButton.addTarget(self, action: #selector(handleJumpForward), for: .touchUpInside)

        NSLayoutConstraint.activate([
            centerStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func setupBottomControls() {
        let settingsButtonsStackView = UIStackView(arrangedSubviews: [
            toolBar.definitionButton,
            audioMenuButton,
            subtitleMenuButton,
        ])
        settingsButtonsStackView.axis = .horizontal
        settingsButtonsStackView.spacing = 20
        settingsButtonsStackView.alignment = .center
        settingsButtonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let topRowStackView = UIStackView(arrangedSubviews: [
            videoInfoContainer,
            settingsButtonsStackView,
        ])
        topRowStackView.axis = .horizontal
        topRowStackView.distribution = .equalSpacing
        topRowStackView.alignment = .center
        topRowStackView.translatesAutoresizingMaskIntoConstraints = false

        videoInfoContainer.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        videoInfoContainer.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        settingsButtonsStackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        settingsButtonsStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let progressStackView = UIStackView(arrangedSubviews: [customProgressView])
        progressStackView.axis = .horizontal
        progressStackView.spacing = 10
        progressStackView.alignment = .center
        progressStackView.translatesAutoresizingMaskIntoConstraints = false

        let centerPlayControlsStackView = UIStackView(arrangedSubviews: [
            previousButton,
            toolBarPlayButton,
            nextButton,
        ])
        centerPlayControlsStackView.axis = .horizontal
        centerPlayControlsStackView.spacing = 8
        centerPlayControlsStackView.alignment = .center
        centerPlayControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        // Use spacer views to center the play controls without adding playlistButton
        let leftSpacerView = UIView()
        leftSpacerView.translatesAutoresizingMaskIntoConstraints = false

        let rightSpacerView = UIView()
        rightSpacerView.translatesAutoresizingMaskIntoConstraints = false

        let bottomRowStackView = UIStackView(arrangedSubviews: [
            leftSpacerView,
            centerPlayControlsStackView,
            rightSpacerView,
        ])
        bottomRowStackView.axis = .horizontal
        bottomRowStackView.distribution = .fill
        bottomRowStackView.alignment = .center
        bottomRowStackView.translatesAutoresizingMaskIntoConstraints = false

        bottomBackground.addSubview(topRowStackView)
        bottomBackground.addSubview(progressStackView)
        bottomBackground.addSubview(bottomRowStackView)

        NSLayoutConstraint.activate([
            topRowStackView.topAnchor.constraint(equalTo: bottomBackground.topAnchor, constant: 8),
            topRowStackView.leadingAnchor.constraint(equalTo: bottomBackground.leadingAnchor, constant: 15),
            topRowStackView.trailingAnchor.constraint(equalTo: bottomBackground.trailingAnchor, constant: -15),
            topRowStackView.heightAnchor.constraint(equalToConstant: 30),

            progressStackView.topAnchor.constraint(equalTo: topRowStackView.bottomAnchor, constant: 14),
            progressStackView.leadingAnchor.constraint(equalTo: bottomBackground.leadingAnchor, constant: 7),
            progressStackView.trailingAnchor.constraint(equalTo: bottomBackground.trailingAnchor, constant: -7),
            customProgressView.heightAnchor.constraint(equalToConstant: 30),

            // 第三行：spacer + 播放控制 + spacer - 增加垂直间距
            bottomRowStackView.topAnchor.constraint(equalTo: progressStackView.bottomAnchor, constant: 16),
            bottomRowStackView.leadingAnchor.constraint(equalTo: bottomBackground.leadingAnchor, constant: 15),
            bottomRowStackView.trailingAnchor.constraint(equalTo: bottomBackground.trailingAnchor, constant: -15),
            bottomRowStackView.bottomAnchor.constraint(equalTo: bottomBackground.bottomAnchor, constant: -4),
            bottomRowStackView.heightAnchor.constraint(equalToConstant: 35),

            // 确保左右spacer视图宽度相等，让播放控件居中
            leftSpacerView.widthAnchor.constraint(equalTo: rightSpacerView.widthAnchor),
        ])

        configureButton(previousButton, systemName: "backward.end.fill", size: 15, weight: .bold)
        configureButton(nextButton, systemName: "forward.end.fill", size: 15, weight: .bold)
        configureButton(audioMenuButton, systemName: "speaker.wave.2", size: 15, weight: .bold)
        configureButton(subtitleMenuButton, systemName: "captions.bubble", size: 15, weight: .bold)

        // Add button targets
        audioMenuButton.addTarget(self, action: #selector(handleAudioMenuButtonTapped), for: .touchUpInside)
        subtitleMenuButton.addTarget(self, action: #selector(handleSubtitleMenuButtonTapped), for: .touchUpInside)

        previousButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        previousButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
        nextButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        nextButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
        toolBarPlayButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        toolBarPlayButton.heightAnchor.constraint(equalToConstant: 35).isActive = true

        // Set equal content compression resistance and hugging priority for all buttons
        let buttonPriority = UILayoutPriority(999)
        previousButton.setContentCompressionResistancePriority(buttonPriority, for: .horizontal)
        previousButton.setContentHuggingPriority(buttonPriority, for: .horizontal)
        toolBarPlayButton.setContentCompressionResistancePriority(buttonPriority, for: .horizontal)
        toolBarPlayButton.setContentHuggingPriority(buttonPriority, for: .horizontal)
        nextButton.setContentCompressionResistancePriority(buttonPriority, for: .horizontal)
        nextButton.setContentHuggingPriority(buttonPriority, for: .horizontal)

        // Ensure all buttons have consistent content edge insets
        previousButton.contentEdgeInsets = .zero
        toolBarPlayButton.contentEdgeInsets = .zero
        nextButton.contentEdgeInsets = .zero

        audioMenuButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        audioMenuButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        subtitleMenuButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        subtitleMenuButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        toolBar.definitionButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        toolBar.definitionButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private lazy var customProgressView: CustomProgressView = {
        let view = CustomProgressView(playView: self)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private func createInfoLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.backgroundColor = .clear
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        return label
    }

    private func setupVideoInfoLabels() {
        codecLabel = createInfoLabel("AV1")
        resolutionLabel = createInfoLabel("2160P")
        fpsLabel = createInfoLabel("60FPS")
        bitrateLabel = createInfoLabel("12kbps")

        videoInfoContainer.addArrangedSubview(codecLabel)
        videoInfoContainer.addArrangedSubview(resolutionLabel)
        videoInfoContainer.addArrangedSubview(fpsLabel)
        videoInfoContainer.addArrangedSubview(bitrateLabel)
    }

    private func setupScreenshotPreview() {
        screenshotPreviewView = UIView()
        screenshotPreviewView?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        screenshotPreviewView?.layer.cornerRadius = 12
        screenshotPreviewView?.clipsToBounds = true
        screenshotPreviewView?.translatesAutoresizingMaskIntoConstraints = false
        screenshotPreviewView?.alpha = 0

        screenshotPreviewView?.layer.borderWidth = 2
        screenshotPreviewView?.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor

        if let previewView = screenshotPreviewView {
            addSubview(previewView)

            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.tag = 100

            previewView.addSubview(imageView)

            NSLayoutConstraint.activate([
                previewView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
                previewView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -100),
                previewView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.25),
                previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 9.0 / 16.0),

                imageView.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 0),
                imageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 0),
                imageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 0),
                imageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: 0),
            ])

            let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(dismissScreenshotPreview))
            swipeGesture.direction = .right
            previewView.addGestureRecognizer(swipeGesture)

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissScreenshotPreview))
            previewView.addGestureRecognizer(tapGesture)
        }

        if promptLabel.superview == nil {
            addSubview(promptLabel)
            promptLabel.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                promptLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                promptLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -50),
                promptLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.7),
                promptLabel.heightAnchor.constraint(equalToConstant: 40),
            ])
        }
    }

    private func setupTopStatusBar() {
        currentItemTitleLabel = UILabel()
        currentItemTitleLabel.textColor = .white
        currentItemTitleLabel.font = UIFont.systemFont(ofSize: 14)
        updateTimeLabel()

        networkStatusImageView = UIImageView()
        networkStatusImageView.tintColor = .white
        updateNetworkStatusImageView()
        networkStatusImageView.contentMode = .scaleAspectFit
        networkStatusImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            networkStatusImageView.widthAnchor.constraint(equalToConstant: 20),
            networkStatusImageView.heightAnchor.constraint(equalToConstant: 20),
        ])

        displayTitleLabel = UILabel()
        displayTitleLabel.textColor = .white
        displayTitleLabel.font = UIFont.boldSystemFont(ofSize: 15)
        displayTitleLabel.text = ""
        displayTitleLabel.lineBreakMode = .byTruncatingTail
        displayTitleLabel.numberOfLines = 1
        displayTitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true

        batteryImageView = UIImageView()
        batteryImageView.tintColor = .white
        updateBatteryStatusImageView()
        batteryImageView.contentMode = .scaleAspectFit
        batteryImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            batteryImageView.widthAnchor.constraint(equalToConstant: 20),
            batteryImageView.heightAnchor.constraint(equalToConstant: 20),
        ])

        networkSpeedLabel = UILabel()
        networkSpeedLabel.textColor = .white
        networkSpeedLabel.font = .systemFont(ofSize: 12)
        networkSpeedLabel.textAlignment = .left

        let leftStackView = UIStackView(arrangedSubviews: [
            currentItemTitleLabel,
        ])
        leftStackView.axis = .horizontal
        leftStackView.spacing = 10
        leftStackView.alignment = .center

        let rightStackView = UIStackView(arrangedSubviews: [
            networkSpeedLabel,
            networkStatusImageView,
            batteryImageView,
        ])
        rightStackView.axis = .horizontal
        rightStackView.spacing = 8
        rightStackView.alignment = .center

        topStatusBar = UIStackView(arrangedSubviews: [
            leftStackView,
            displayTitleLabel,
            rightStackView,
        ])
        topStatusBar.axis = .horizontal
        topStatusBar.distribution = .equalSpacing
        topStatusBar.alignment = .center
        topStatusBar.translatesAutoresizingMaskIntoConstraints = false

        addSubview(topStatusBar)

        topStatusLeadingConstraint = topStatusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UIDevice.isPhone ? 30 : 25)
        topStatusTrailingConstraint = topStatusBar.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: UIDevice.isPhone ? -30 : -25
        )

        NSLayoutConstraint.activate([
            topStatusLeadingConstraint,
            topStatusTrailingConstraint,
            topStatusBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            topStatusBar.heightAnchor.constraint(equalToConstant: 30),
        ])

        timeLabelUpdateTimer?.invalidate()
        timeLabelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateTimeLabel()
        }

        UIDevice.current.isBatteryMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        startSpeedUpdateTimer()
        updateBatteryStatusImageView()
    }

    // MARK: - Utility Methods

    private func configureButton(_ button: UIButton, systemName: String, size: CGFloat, weight: UIImage.SymbolWeight) {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .clear
    }

    private func customAutoFadeOutViewWithAnimation() {
        customDelayItem?.cancel()

        guard toolBarPlayButton.isSelected else { return }

        customDelayItem = DispatchWorkItem { [weak self] in
            self?.isMaskShow = false
        }

        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + KSOptions.animateDelayTimeInterval,
            execute: customDelayItem!
        )
    }

    override open func resetPlayer() {
        super.resetPlayer()
        speedUpdateTimer?.invalidate()
        speedUpdateTimer = nil
        timeLabelUpdateTimer?.invalidate()
        timeLabelUpdateTimer = nil
        maskImageView.alpha = 1
        maskImageView.image = nil
        panGesture.isEnabled = false
        #if !os(visionOS)
        routeButton.isHidden = !routeDetector.multipleRoutesDetected
        #endif
    }

    override open func onButtonPressed(type: PlayerButtonType, button: UIButton) {
        if type == .back, viewController is PlayerFullScreenViewController {
            updateUI(isFullScreen: false)
            return
        }
        super.onButtonPressed(type: type, button: button)
        if type == .lock {
            button.isSelected.toggle()
            isMaskShow = !button.isSelected
            button.alpha = 1.0
        } else if type == .landscape {
            updateUI(isFullScreen: !landscapeButton.isSelected)
        }
    }

    open func isHorizonal() -> Bool {
        playerLayer?.player.naturalSize.isHorizonal ?? true
    }

    open func updateUI(isFullScreen: Bool) {
        guard let viewController else {
            return
        }
        landscapeButton.isSelected = isFullScreen
        let isHorizonal = isHorizonal()
        viewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = !isFullScreen
        if isFullScreen {
            if viewController is PlayerFullScreenViewController {
                return
            }
            originalSuperView = superview
            originalframeConstraints = frameConstraints
            if let originalframeConstraints {
                NSLayoutConstraint.deactivate(originalframeConstraints)
            }
            originalFrame = frame
            let fullVC = PlayerFullScreenViewController(isHorizonal: isHorizonal)
            fullScreenDelegate = fullVC
            fullVC.view.addSubview(self)
            translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                topAnchor.constraint(equalTo: fullVC.view.readableTopAnchor),
                leadingAnchor.constraint(equalTo: fullVC.view.leadingAnchor),
                trailingAnchor.constraint(equalTo: fullVC.view.trailingAnchor),
                bottomAnchor.constraint(equalTo: fullVC.view.bottomAnchor),
            ])
            fullVC.modalPresentationStyle = .fullScreen
            fullVC.modalPresentationCapturesStatusBarAppearance = true
            fullVC.transitioningDelegate = self
            viewController.present(fullVC, animated: true) {
                KSOptions.supportedInterfaceOrientations = fullVC.supportedInterfaceOrientations
            }
        } else {
            guard viewController is PlayerFullScreenViewController else {
                return
            }
            let presentingVC = viewController.presentingViewController ?? viewController
            KSOptions.supportedInterfaceOrientations = nil
            presentingVC.dismiss(animated: true) {
                self.originalSuperView?.addSubview(self)
                if let constraints = self.originalframeConstraints, !constraints.isEmpty {
                    NSLayoutConstraint.activate(constraints)
                } else {
                    self.translatesAutoresizingMaskIntoConstraints = true
                    self.frame = self.originalFrame
                }
            }
        }
        let isLandscape = isFullScreen && isHorizonal
        updateUI(isLandscape: isLandscape)
    }

    open func updateUI(isLandscape: Bool) {
        if isLandscape {
            topMaskView.isHidden = KSOptions.topBarShowInCase == .none
        } else {
            topMaskView.isHidden = KSOptions.topBarShowInCase != .always
        }
        toolBar.playbackRateButton.isHidden = false
        toolBar.srtButton.isHidden = playerLayer?.subtitleModel.subtitleInfos.isEmpty ?? true
        if UIDevice.current.userInterfaceIdiom == .phone {
            if isLandscape {
                // landscapeButton now always visible in topLeftButtons
                toolBar.srtButton.isHidden = playerLayer?.subtitleModel.subtitleInfos.isEmpty ?? true

                // Update layout for landscape mode
                topLeftBackgroundLeadingConstraint.constant = 15
                topRightBackgroundTrailingConstraint.constant = -15
                leftBackgroundViewLeadingConstraint.constant = 33
                bottomBackgroundLeadingConstraint.constant = 15
                bottomBackgroundTrailingConstraint.constant = -15
                topStatusLeadingConstraint.constant = 25
                topStatusTrailingConstraint.constant = -25
                bottomBackgroundHeightConstraint.constant = 100
            } else {
                toolBar.srtButton.isHidden = true
                // landscapeButton now always visible in topLeftButtons

                // Update layout for portrait mode
                topLeftBackgroundLeadingConstraint.constant = 20
                topRightBackgroundTrailingConstraint.constant = -20
                leftBackgroundViewLeadingConstraint.constant = 33
                bottomBackgroundLeadingConstraint.constant = 20
                bottomBackgroundTrailingConstraint.constant = -20
                topStatusLeadingConstraint.constant = 30
                topStatusTrailingConstraint.constant = -30
                bottomBackgroundHeightConstraint.constant = 100
            }
            toolBar.playbackRateButton.isHidden = !isLandscape
        } else {
            // landscapeButton now always visible in topLeftButtons

            // iPad layout
            topLeftBackgroundLeadingConstraint.constant = 15
            topRightBackgroundTrailingConstraint.constant = -15
            leftBackgroundViewLeadingConstraint.constant = 33
            bottomBackgroundLeadingConstraint.constant = 15
            bottomBackgroundTrailingConstraint.constant = -15
            topStatusLeadingConstraint.constant = 25
            topStatusTrailingConstraint.constant = -25
            bottomBackgroundHeightConstraint.constant = 100
        }
        judgePanGesture()
    }

    override open func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        airplayStatusView.isHidden = !layer.player.isExternalPlaybackActive
        super.player(layer: layer, currentTime: currentTime, totalTime: totalTime)
    }

    override open func set(resource: KSPlayerResource, definitionIndex: Int = 0, isSetUrl: Bool = true) {
        super.set(resource: resource, definitionIndex: definitionIndex, isSetUrl: isSetUrl)
        maskImageView.image(url: resource.cover)
        // Update displayTitleLabel with resource name
        updateTitle(resource.name)
    }

    override open func change(definitionIndex: Int) {
        Task {
            let image = await playerLayer?.player.thumbnailImageAtCurrentTime()
            if let image {
                self.maskImageView.image = UIImage(cgImage: image)
                self.maskImageView.alpha = 1
            }
            super.change(definitionIndex: definitionIndex)
        }
    }

    override open func panGestureBegan(location point: CGPoint, direction: KSPanDirection) {
        if direction == .vertical {
            if point.x > bounds.size.width / 2 {
                isVolume = true
                tmpPanValue = volumeViewSlider.value
            } else {
                isVolume = false
            }
        } else {
            super.panGestureBegan(location: point, direction: direction)
        }
    }

    override open func panGestureChanged(velocity point: CGPoint, direction: KSPanDirection) {
        if direction == .vertical {
            if isVolume {
                if KSOptions.enableVolumeGestures {
                    tmpPanValue += panValue(velocity: point, direction: direction, currentTime: Float(toolBar.currentTime), totalTime: Float(totalTime))
                    tmpPanValue = max(min(tmpPanValue, 1), 0)
                    volumeViewSlider.value = tmpPanValue
                }
            } else if KSOptions.enableBrightnessGestures {
                #if !os(visionOS)
                brightness += CGFloat(panValue(velocity: point, direction: direction, currentTime: Float(toolBar.currentTime), totalTime: Float(totalTime)))
                #endif
            }
        } else {
            super.panGestureChanged(velocity: point, direction: direction)
        }
    }

    open func judgePanGesture() {
        if landscapeButton.isSelected || UIDevice.current.userInterfaceIdiom == .pad {
            panGesture.isEnabled = isPlayed && !replayButton.isSelected
        } else {
            panGesture.isEnabled = toolBar.playButton.isSelected
        }
    }

    // MARK: - Action Methods

    @objc
    private func handlePlayPause() {
        guard let player = playerLayer?.player else { return }
        if player.isPlaying {
            pause()
        } else {
            if player.playbackState == .finished {
                let currentResource = resource
                let currentIndex = currentDefinition
                resetPlayer()
                if let currentResource {
                    set(resource: currentResource, definitionIndex: currentIndex)
                }
            } else {
                play()
            }
        }
    }

    @objc
    private func handleScreenshot() {
        guard let player = playerLayer?.player else { return }

        let flashView = UIView(frame: bounds)
        flashView.backgroundColor = UIColor.white
        flashView.alpha = 0
        addSubview(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.8
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, animations: {
                flashView.alpha = 0
            }, completion: { _ in
                flashView.removeFromSuperview()
            })
        })
        #if !os(visionOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        Task {
            let image = await player.thumbnailImageAtCurrentTime()
            if let image {
                let uiImage = UIImage(cgImage: image)

                DispatchQueue.main.async {
                    if let previewView = self.screenshotPreviewView,
                       let imageView = previewView.viewWithTag(100) as? UIImageView
                    {
                        imageView.image = uiImage

                        previewView.alpha = 0
                        previewView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                            .concatenating(CGAffineTransform(translationX: 50, y: 20))

                        UIView.animate(
                            withDuration: 0.25,
                            delay: 0.1,
                            usingSpringWithDamping: 0.8,
                            initialSpringVelocity: 0.2,
                            options: [],
                            animations: {
                                previewView.alpha = 1.0
                                previewView.transform = .identity
                            },
                            completion: nil
                        )

                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            if previewView.alpha == 1.0 {
                                UIView.animate(withDuration: 0.3) {
                                    previewView.alpha = 0.0
                                }
                            }
                        }
                    }

                    self.showPromptMessage("Screenshot saved")
                }

                UIImageWriteToSavedPhotosAlbum(
                    uiImage,
                    self,
                    #selector(image(_:didFinishSavingWithError:contextInfo:)),
                    nil
                )
            }
        }
    }

    @objc
    private func image(_: UIImage, didFinishSavingWithError error: Error?, contextInfo _: UnsafeRawPointer) {
        if let error {
            print("Error saving screenshot: \(error.localizedDescription)")
        }
    }

    @objc
    private func handleJumpForward() {
        guard let player = playerLayer?.player else { return }
        let currentTime = player.currentPlaybackTime
        playerLayer?.seek(time: currentTime + 10)
    }

    @objc
    private func handleJumpBack() {
        guard let player = playerLayer?.player else { return }
        let currentTime = player.currentPlaybackTime
        playerLayer?.seek(time: currentTime - 10, autoPlay: true)
    }

    @objc
    private func dismissScreenshotPreview() {
        if let previewView = screenshotPreviewView {
            UIView.animate(withDuration: 0.3, animations: {
                previewView.alpha = 0.0
                previewView.transform = CGAffineTransform(translationX: 150, y: 0)
            }, completion: { _ in
                previewView.transform = .identity
            })
        }
    }

    // MARK: - Status Update Methods

    private func updateTimeLabel() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentItemTitleLabel?.text = formatter.string(from: Date())
    }

    private func updateNetworkStatusImageView() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        NetworkMonitor.shared.$type.receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                guard let self else { return }
                if let type {
                    if type == .wifi {
                        networkStatusImageView?.image = UIImage(systemName: "wifi", withConfiguration: configuration)
                    } else if type == .cellular {
                        networkStatusImageView?.image = UIImage(
                            systemName: "antenna.radiowaves.left.and.right",
                            withConfiguration: configuration
                        )
                    } else {
                        networkStatusImageView?.image = UIImage(systemName: "xmark.circle", withConfiguration: configuration)
                    }
                } else {
                    networkStatusImageView?.image = UIImage(systemName: "xmark.circle", withConfiguration: configuration)
                }
            }.store(in: &cancellables)
    }

    private func updateBatteryStatusImageView() {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)

        var batteryImageName: String

        switch batteryState {
        case .charging, .full:
            if batteryLevel >= 0.95 {
                batteryImageName = "battery.100.bolt"
            } else if batteryLevel >= 0.65 {
                batteryImageName = "battery.100.bolt"
            } else if batteryLevel >= 0.35 {
                batteryImageName = "battery.100.bolt"
            } else {
                batteryImageName = "battery.100.bolt"
            }
        case .unplugged:
            if batteryLevel >= 0.95 {
                batteryImageName = "battery.100"
            } else if batteryLevel >= 0.65 {
                batteryImageName = "battery.75"
            } else if batteryLevel >= 0.35 {
                batteryImageName = "battery.50"
            } else {
                batteryImageName = "battery.25"
            }
        case .unknown:
            batteryImageName = "battery.100.bolt"
        @unknown default:
            batteryImageName = "battery.100"
        }

        DispatchQueue.main.async {
            self.batteryImageView?.image = UIImage(systemName: batteryImageName, withConfiguration: configuration)
        }
    }

    @objc
    private func batteryStateDidChange(_: Notification) {
        updateBatteryStatusImageView()
    }

    @objc
    private func batteryLevelDidChange(_: Notification) {
        updateBatteryStatusImageView()
    }

    private func startSpeedUpdateTimer() {
        speedUpdateTimer?.invalidate()
        speedUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNetworkSpeed()
        }
    }

    private func updateNetworkSpeed() {
        guard let speed = playerLayer?.player.dynamicInfo.networkSpeed else {
            networkSpeedLabel?.text = "0 KB/s"
            return
        }

        smoothedSpeed = smoothedSpeed * 0.7 + Double(speed) * 0.3
        networkSpeedLabel?.text = formatNetworkSpeed(Int64(smoothedSpeed))
    }

    private func formatNetworkSpeed(_ bytesPerSecond: Int64) -> String {
        let kb = Double(bytesPerSecond) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.1f MB/s", mb)
        } else {
            return String(format: "%.0f KB/s", kb)
        }
    }

    func showPromptMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            promptLabel.removeFromSuperview()
            promptLabel.text = message
            addSubview(promptLabel)
            promptLabel.translatesAutoresizingMaskIntoConstraints = false
            bringSubviewToFront(promptLabel)

            NSLayoutConstraint.activate([
                promptLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 50),
                promptLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                promptLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
                promptLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            ])

            promptLabel.alpha = 0
            UIView.animate(withDuration: 0.3, animations: {
                self.promptLabel.transform = .identity
                self.promptLabel.alpha = 1.0
            })

            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hidePrompt), object: nil)
            perform(#selector(hidePrompt), with: nil, afterDelay: 5.0)
        }
    }

    @objc
    private func hidePrompt() {
        UIView.animate(withDuration: 0.3, animations: {
            self.promptLabel.alpha = 0.0
        }) { _ in
            self.promptLabel.transform = .identity
        }
    }

    func updateTitle(_ title: String) {
        displayTitleLabel?.text = title
        topStatusBar?.layoutIfNeeded()
    }

    func toggleBottomSlimProgress() {
        // This method is called from settings, but we removed the functionality
        // Keep as empty method to maintain compatibility
    }

    // MARK: - Button Action Handlers

    @objc
    private func handleUnifiedSettingsButtonTapped() {
        showUnifiedSettings()
    }

    @objc
    private func handleAudioMenuButtonTapped() {
        if #available(iOS 14.0, *) {
            // For iOS 14+, the menu should be shown automatically
            // But we set up the menu first if it hasn't been set
            if audioMenuButton.menu == nil {
                showAudioMenu()
            }
        } else {
            // For iOS 13, show alert
            showAudioMenu()
        }
    }

    @objc
    private func handleSubtitleMenuButtonTapped() {
        if #available(iOS 14.0, *) {
            // For iOS 14+, the menu should be shown automatically
            // But we set up the menu first if it hasn't been set
            if subtitleMenuButton.menu == nil {
                showSubtitleMenu()
            }
        } else {
            // For iOS 13, show alert
            showSubtitleMenu()
        }
    }

    @objc
    private func handleSettingsButtonTapped() {
        // Directly show unified settings instead of additional menu
        showUnifiedSettings()
    }

    @objc
    private func handleAspectFillButtonTapped() {
        toggleAspectRatio()
    }

    // MARK: - Settings and Menu Methods

    private func showUnifiedSettings() {
        // Hide player controls
        isMaskShow = false

        // Configure and show settings view
        settingsView.playerView = self
        settingsView.onDismiss = { [weak self] in
            self?.hideUnifiedSettings()
        }

        // Show the settings view
        settingsView.show(in: self)
    }

    private func hideUnifiedSettings() {
        settingsView.hide()
        // Restore player controls
        isMaskShow = true
    }

    private func showAudioMenu() {
        guard let player = playerLayer?.player else {
            showPromptMessage("播放器未就绪")
            return
        }

        let audioTracks = player.tracks(mediaType: .audio)
        guard !audioTracks.isEmpty else {
            showPromptMessage("没有可用的音频轨道")
            return
        }

        if #available(iOS 14.0, *) {
            // Use UIMenu for iOS 14+
            var menuItems: [UIAction] = []

            for (index, track) in audioTracks.enumerated() {
                let trackTitle = track.description.isEmpty ? "音频轨道 \(index + 1)" : track.description
                let isSelected = track.isEnabled

                let action = UIAction(
                    title: trackTitle,
                    state: isSelected ? .on : .off
                ) { [weak self] _ in
                    player.select(track: track)
                    self?.showPromptMessage("已切换到：\(trackTitle)")
                }
                menuItems.append(action)
            }

            let menu = UIMenu(title: "选择音频轨道", children: menuItems)
            audioMenuButton.menu = menu
            audioMenuButton.showsMenuAsPrimaryAction = true
        } else {
            // Use UIAlertController for iOS 13
            showAudioMenuAlert(audioTracks: audioTracks, player: player)
        }
    }

    private func showAudioMenuAlert(audioTracks: [MediaPlayerTrack], player: MediaPlayerProtocol) {
        let alert = UIAlertController(title: "选择音频轨道", message: nil, preferredStyle: .actionSheet)

        for (index, track) in audioTracks.enumerated() {
            let trackTitle = track.description.isEmpty ? "音频轨道 \(index + 1)" : track.description
            let isSelected = track.isEnabled

            let alertAction = UIAlertAction(
                title: isSelected ? "✓ \(trackTitle)" : trackTitle,
                style: .default
            ) { [weak self] _ in
                player.select(track: track)
                self?.showPromptMessage("已切换到：\(trackTitle)")
            }
            alert.addAction(alertAction)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = audioMenuButton
            popover.sourceRect = audioMenuButton.bounds
        }

        viewController?.present(alert, animated: true)
    }

    /// 刷新字幕菜单（每次调用都会重新生成最新的菜单）
    private func refreshSubtitleMenu() {
        if #available(iOS 14.0, *) {
            // 创建第1字幕子菜单
            let firstSubtitleMenu = createSubtitleSubMenu(
                title: "First Subtitle",
                isSecondary: false
            )

            // 创建第2字幕子菜单
            let secondSubtitleMenu = createSubtitleSubMenu(
                title: "Second Subtitle",
                isSecondary: true
            )

            // 组合主字幕菜单并设置到独立的字幕按钮
            let mainSrtMenu = UIMenu(
                title: "Subtitles",
                children: [firstSubtitleMenu, secondSubtitleMenu]
            )

            // 设置独立的字幕菜单按钮
            subtitleMenuButton.menu = mainSrtMenu
        }
    }

    /// 创建字幕子菜单的通用方法
    @available(iOS 14.0, *)
    private func createSubtitleSubMenu(title: String, isSecondary: Bool) -> UIMenu {
        // 2. 分类字幕类型
        let ffmpegSubs = playerLayer?.subtitleModel.subtitleInfos.compactMap { $0 as? FFmpegAssetTrack } ?? []
        let urlSubs = playerLayer?.subtitleModel.subtitleInfos.compactMap { $0 as? URLSubtitleInfo } ?? []

        // 3. 重新创建 `ffmpegMenu` 和 `urlMenu`，确保选中状态正确
        let ffmpegMenu = generateFFmpegMenu(
            selectedSubtitle: isSecondary ?
                playerLayer?.subtitleModel.secondarySubtitleInfo as? FFmpegAssetTrack :
                playerLayer?.subtitleModel.selectedSubtitleInfo as? FFmpegAssetTrack,
            list: ffmpegSubs,
            isSecondary: isSecondary
        )
        let urlMenu = generateURLMenu(
            selectedSubtitle: isSecondary ?
                playerLayer?.subtitleModel.secondarySubtitleInfo as? URLSubtitleInfo :
                playerLayer?.subtitleModel.selectedSubtitleInfo as? URLSubtitleInfo,
            list: urlSubs,
            isSecondary: isSecondary
        )

        let closeAction = UIAction(
            title: "Disable Subtitle",
            state: isSecondary ?
                (playerLayer?.subtitleModel.secondarySubtitleInfo == nil ? .on : .off) :
                (playerLayer?.subtitleModel.selectedSubtitleInfo == nil ? .on : .off)
        ) { [weak self] _ in
            guard let self else { return }
            if isSecondary {
                playerLayer?.subtitleModel.secondarySubtitleInfo = nil
            } else {
                playerLayer?.subtitleModel.selectedSubtitleInfo = nil
            }
            refreshSubtitleMenu()
        }

        // 为每个字幕子菜单添加本地字幕和在线搜索功能
        let localSubtitle = UIAction(title: "Local Subtitle") { [weak self] _ in
            self?.openFilePicker(isSecondary: isSecondary)
        }

        return UIMenu(
            title: title,
            children: [ffmpegMenu, urlMenu, closeAction, localSubtitle]
        )
    }

    /// 生成 FFmpeg 字幕菜单
    @available(iOS 14.0, *)
    private func generateFFmpegMenu(selectedSubtitle: FFmpegAssetTrack?, list: [FFmpegAssetTrack], isSecondary: Bool) -> UIMenu {
        var actions: [UIAction] = []

        for subtitle in list {
            let isSelected = selectedSubtitle === subtitle
            let action = UIAction(
                title: subtitle.name.isEmpty ? "Track \(subtitle.trackID)" : subtitle.name,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                if isSecondary {
                    playerLayer?.subtitleModel.secondarySubtitleInfo = subtitle
                } else {
                    playerLayer?.select(subtitleInfo: subtitle)
                }
                refreshSubtitleMenu()
                showPromptMessage("Switched to: \(subtitle.name.isEmpty ? "Track \(subtitle.trackID)" : subtitle.name)")
            }
            actions.append(action)
        }

        if actions.isEmpty {
            let noTrackAction = UIAction(title: "No FFmpeg Subtitles", attributes: .disabled) { _ in }
            actions.append(noTrackAction)
        }

        return UIMenu(title: "Internal Subtitles", children: actions)
    }

    /// 生成 URL 字幕菜单
    @available(iOS 14.0, *)
    private func generateURLMenu(selectedSubtitle: URLSubtitleInfo?, list: [URLSubtitleInfo], isSecondary: Bool) -> UIMenu {
        var actions: [UIAction] = []

        for subtitle in list {
            let isSelected = selectedSubtitle === subtitle
            let action = UIAction(
                title: subtitle.name,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                if isSecondary {
                    playerLayer?.subtitleModel.secondarySubtitleInfo = subtitle
                } else {
                    playerLayer?.select(subtitleInfo: subtitle)
                }
                refreshSubtitleMenu()
                showPromptMessage("Switched to: \(subtitle.name)")
            }
            actions.append(action)
        }

        if actions.isEmpty {
            let noTrackAction = UIAction(title: "No External Subtitles", attributes: .disabled) { _ in }
            actions.append(noTrackAction)
        }

        return UIMenu(title: "External Subtitles", children: actions)
    }

    private func showSubtitleMenu() {
        guard let subtitleModel = playerLayer?.subtitleModel else {
            showPromptMessage("字幕功能未就绪")
            return
        }

        if #available(iOS 14.0, *) {
            // Use the new comprehensive subtitle menu
            refreshSubtitleMenu()
            subtitleMenuButton.showsMenuAsPrimaryAction = true
        } else {
            // Use UIAlertController for iOS 13 - fallback to simple menu
            let subtitles = subtitleModel.subtitleInfos
            showSubtitleMenuAlert(subtitles: subtitles, subtitleModel: subtitleModel)
        }
    }

    private func showSubtitleMenuAlert(subtitles: [SubtitleInfo], subtitleModel: SubtitleModel) {
        let alert = UIAlertController(title: "选择字幕", message: nil, preferredStyle: .actionSheet)

        // Add "None" option
        let noneTitle = subtitleModel.selectedSubtitleInfo == nil ? "✓ 关闭字幕" : "关闭字幕"
        let noneAction = UIAlertAction(title: noneTitle, style: .default) { [weak self] _ in
            self?.playerLayer?.select(subtitleInfo: nil)
            self?.showPromptMessage("已关闭字幕")
        }
        alert.addAction(noneAction)

        // Add subtitle options
        for subtitle in subtitles {
            let isSelected = subtitleModel.selectedSubtitleInfo === subtitle
            let title = isSelected ? "✓ \(subtitle.name)" : subtitle.name

            let alertAction = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.playerLayer?.select(subtitleInfo: subtitle)
                self?.showPromptMessage("已切换到：\(subtitle.name)")
            }
            alert.addAction(alertAction)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = subtitleMenuButton
            popover.sourceRect = subtitleMenuButton.bounds
        }

        viewController?.present(alert, animated: true)
    }

    // MARK: - Helper Methods for Subtitle Functions

    /// 打开文件选择器来选择本地字幕文件
    private func openFilePicker(isSecondary: Bool) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypePlainText as String, "public.subtitle"], in: .open)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false

        // Store the isSecondary flag for use in the delegate method
        objc_setAssociatedObject(documentPicker, &AssociatedKeys.isSecondarySubtitle, isSecondary, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        viewController?.present(documentPicker, animated: true, completion: nil)
    }

    private func toggleAspectRatio() {
        guard let player = playerLayer?.player else { return }

        let currentContentMode = player.contentMode
        let nextContentMode: UIView.ContentMode
        let message: String

        switch currentContentMode {
        case .scaleAspectFit:
            nextContentMode = .scaleAspectFill
            message = "切换到：裁剪填充"
        case .scaleAspectFill:
            nextContentMode = .scaleToFill
            message = "切换到：拉伸填充"
        case .scaleToFill:
            nextContentMode = .scaleAspectFit
            message = "切换到：适应填充"
        default:
            nextContentMode = .scaleAspectFit
            message = "切换到：适应填充"
        }

        player.contentMode = nextContentMode
        showPromptMessage(message)
    }

    private func setSleepTimer(seconds: Int) {
        // Implementation for setting sleep timer
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(seconds)) {
            // Stop playback or perform other sleep timer actions
            self.pause()
        }
    }

    private func cancelSleepTimer() {
        // Implementation for canceling sleep timer
        // You might want to track and cancel the timer here
    }

    override open func play() {
        super.play()
        playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: playButtonConfig), for: .normal)
        toolBarPlayButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: toolBarPlayButtonConfig), for: .normal)
    }

    override open func pause() {
        super.pause()
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
        toolBarPlayButton.setImage(UIImage(systemName: "play.fill", withConfiguration: toolBarPlayButtonConfig), for: .normal)
    }

    override open func tapGestureAction(_: UITapGestureRecognizer) {
        isMaskShow.toggle()
    }

    override open func doubleTapGestureAction() {
        let touchLocation = doubleTapGesture.location(in: self)
        let screenWidth = bounds.width
        let isLeftSide = touchLocation.x < screenWidth / 2

        guard let player = playerLayer?.player else { return }
        let currentTime = player.currentPlaybackTime

        if isLeftSide {
            playerLayer?.seek(time: currentTime - 10, autoPlay: true)
        } else {
            playerLayer?.seek(time: currentTime + 10, autoPlay: true)
        }
    }

    override open func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)

        switch state {
        case .readyToPlay:
            updateVideMetaLabel()
            toolBarPlayButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: toolBarPlayButtonConfig), for: .normal)
            playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: playButtonConfig), for: .normal)
            jumpbackButton.setImage(UIImage(systemName: "gobackward", withConfiguration: jumpButtonConfig), for: .normal)
            jumpForwardButton.setImage(UIImage(systemName: "goforward", withConfiguration: jumpButtonConfig), for: .normal)
            playPauseButton.alpha = 0
            jumpbackButton.alpha = 0
            jumpForwardButton.alpha = 0

            // Animate mask image fade out
            UIView.animate(withDuration: 0.3) {
                self.maskImageView.alpha = 0.0
            }

            // Set initial time if watched progress exists
            if watchedProgress > 0 {
                let startOffset = watchedProgress * totalTime - 10 // Go back 10 seconds from saved position
                layer.seek(time: max(0, startOffset), autoPlay: true)
            }

        case .paused:
            toolBarPlayButton.setImage(UIImage(systemName: "play.fill", withConfiguration: toolBarPlayButtonConfig), for: .normal)
            playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)

        case .buffering, .bufferFinished:
            toolBarPlayButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: toolBarPlayButtonConfig), for: .normal)
            playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: playButtonConfig), for: .normal)
            jumpbackButton.setImage(UIImage(systemName: "gobackward.15", withConfiguration: jumpButtonConfig), for: .normal)
            jumpForwardButton.setImage(UIImage(systemName: "goforward.15", withConfiguration: jumpButtonConfig), for: .normal)

        case .playedToTheEnd, .error:
            if state == .playedToTheEnd {
                playPauseButton.isHidden = false
                jumpbackButton.isHidden = false
                jumpForwardButton.isHidden = false

                playPauseButton.alpha = 1
                jumpbackButton.alpha = 1
                jumpForwardButton.alpha = 1

                playPauseButton.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: playButtonConfig), for: .normal)
                jumpbackButton.isHidden = true
                jumpForwardButton.isHidden = true
            }

        default:
            break
        }

        judgePanGesture()
    }

    open func updateVideMetaLabel() {
        let videoInfo = getVideoMeta()
        if let codecFormat = videoInfo["Codec Format"] {
            codecLabel?.text = codecFormat
        } else {
            codecLabel?.alpha = 0
        }
        if let resolution = videoInfo["Resolution"] {
            resolutionLabel?.text = resolution
        } else {
            resolutionLabel?.alpha = 0
        }
        if let frameRate = videoInfo["Frame Rate"] {
            fpsLabel?.text = frameRate
        } else {
            fpsLabel?.alpha = 0
        }
        if let bitrate = videoInfo["Bitrate"] {
            bitrateLabel?.text = bitrate
        } else {
            bitrateLabel?.alpha = 0
        }
    }

    private func getVideoMeta() -> [String: String] {
        var videoInfo: [String: String] = [:]
        if let player = playerLayer?.player {
            let videoTracks = player.tracks(mediaType: .video)
            if let videoTrack = videoTracks.first(where: { $0.isEnabled }) as? AVMediaPlayerTrack {
                videoInfo = [
                    "Codec Format": videoTrack.formatDescription?.mediaSubType.description ?? "Unknown",
                    "Title": videoTrack.name,
                    "Frame Rate": "\(String(format: "%.2f", videoTrack.nominalFrameRate))FPS",
                    "Bitrate": "\(player.dynamicInfo.videoBitrate / 1024)Kbps",
                    "Color Depth": "\(videoTrack.bitDepth)bit",
                ]
            } else if let videoTrack = videoTracks.first(where: { $0.isEnabled }) as? FFmpegAssetTrack {
                videoInfo = [
                    "Codec Format": videoTrack.codecName,
                    "Title": videoTrack.name,
                    "Resolution": videoTrack.naturalSize.string,
                    "Frame Rate": "\(String(format: "%.2f", videoTrack.nominalFrameRate))FPS",
                    "Bitrate": "\(player.dynamicInfo.videoBitrate / 1024)Kbps",
                    "Color Depth": "\(videoTrack.bitDepth)bit",
                ]
            }
        }
        return videoInfo
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}

// MARK: - CustomProgressView

class CustomProgressView: UIView {
    let playView: IOSVideoPlayerView

    private var progressSlider: KSSlider
    private var currentTimeLabel: UILabel
    private var totalTimeLabel: UILabel

    init(playView: IOSVideoPlayerView, frame: CGRect = .zero) {
        self.playView = playView
        progressSlider = playView.toolBar.timeSlider
        currentTimeLabel = playView.toolBar.currentTimeLabel
        totalTimeLabel = playView.toolBar.totalTimeLabel

        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear

        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        progressSlider.minimumTrackTintColor = .white
        progressSlider.maximumTrackTintColor = UIColor.gray

        let clearThumbImage = makeClearThumbImage()
        progressSlider.setThumbImage(clearThumbImage, for: .normal)
        progressSlider.setThumbImage(clearThumbImage, for: .highlighted)
        progressSlider.setThumbImage(clearThumbImage, for: .selected)

        progressSlider.setMinimumTrackImage(nil, for: .normal)
        progressSlider.setMaximumTrackImage(nil, for: .normal)

        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        currentTimeLabel.font = timeFont
        totalTimeLabel.font = timeFont

        currentTimeLabel.textColor = .white
        totalTimeLabel.textColor = .white

        addSubview(progressSlider)
        addSubview(currentTimeLabel)
        addSubview(totalTimeLabel)

        NSLayoutConstraint.activate([
            progressSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 12),
            progressSlider.trailingAnchor.constraint(equalTo: totalTimeLabel.leadingAnchor, constant: -12),
            progressSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressSlider.heightAnchor.constraint(equalToConstant: 30),

            currentTimeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            currentTimeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            totalTimeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            totalTimeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func makeClearThumbImage() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

extension IOSVideoPlayerView: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented _: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let originalSuperView, let animationView = playerLayer?.player.view {
            return PlayerTransitionAnimator(containerView: originalSuperView, animationView: animationView)
        }
        return nil
    }

    public func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let originalSuperView, let animationView = playerLayer?.player.view {
            return PlayerTransitionAnimator(containerView: originalSuperView, animationView: animationView, isDismiss: true)
        } else {
            return nil
        }
    }
}

// MARK: - private functions

extension IOSVideoPlayerView {
    private func addNotification() {
//        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routesAvailableDidChange), name: .AVRouteDetectorMultipleRoutesDetectedDidChange, object: nil)
    }

    @objc private func routesAvailableDidChange(notification _: Notification) {
        #if !os(visionOS)
        routeButton.isHidden = !routeDetector.multipleRoutesDetected
        #endif
    }

    @objc private func orientationChanged(notification _: Notification) {
        guard isHorizonal() else {
            return
        }
        updateUI(isFullScreen: UIApplication.isLandscape)
    }
}

public class AirplayStatusView: UIView {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        let airplayicon = UIImageView(image: UIImage(systemName: "airplayvideo"))
        addSubview(airplayicon)
        let airplaymessage = UILabel()
        airplaymessage.backgroundColor = .clear
        airplaymessage.textColor = .white
        airplaymessage.font = .systemFont(ofSize: 14)
        airplaymessage.text = NSLocalizedString("AirPlay 投放中", bundle: .module, comment: "")
        airplaymessage.textAlignment = .center
        addSubview(airplaymessage)
        translatesAutoresizingMaskIntoConstraints = false
        airplayicon.translatesAutoresizingMaskIntoConstraints = false
        airplaymessage.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 100),
            heightAnchor.constraint(equalToConstant: 115),
            airplayicon.topAnchor.constraint(equalTo: topAnchor),
            airplayicon.centerXAnchor.constraint(equalTo: centerXAnchor),
            airplayicon.widthAnchor.constraint(equalToConstant: 100),
            airplayicon.heightAnchor.constraint(equalToConstant: 100),
            airplaymessage.bottomAnchor.constraint(equalTo: bottomAnchor),
            airplaymessage.leadingAnchor.constraint(equalTo: leadingAnchor),
            airplaymessage.trailingAnchor.constraint(equalTo: trailingAnchor),
            airplaymessage.heightAnchor.constraint(equalToConstant: 15),
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - menu

extension IOSVideoPlayerView {
    override open var canBecomeFirstResponder: Bool {
        true
    }

    override open func canPerformAction(_ action: Selector, withSender _: Any?) -> Bool {
        if action == #selector(IOSVideoPlayerView.openFileAction) {
            return true
        }
        return true
    }

    @objc fileprivate func openFileAction(_: AnyObject) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeAudio, kUTTypeMovie, kUTTypePlainText] as [String], in: .open)
        documentPicker.delegate = self
        viewController?.present(documentPicker, animated: true, completion: nil)
    }
}

// MARK: - AssociatedKeys for storing temporary data

private enum AssociatedKeys {
    @MainActor
    static var isSecondarySubtitle: UInt8 = 0
}

extension IOSVideoPlayerView: UIDocumentPickerDelegate {
    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            if url.isMovie {
                set(url: url, options: KSOptions())
            } else {
                // Check if this is for secondary subtitle
                let picker = viewController?.presentedViewController as? UIDocumentPickerViewController
                let isSecondary = objc_getAssociatedObject(picker, &AssociatedKeys.isSecondarySubtitle) as? Bool ?? false

                let subtitleInfo = URLSubtitleInfo(url: url)

                if isSecondary {
                    playerLayer?.subtitleModel.secondarySubtitleInfo = subtitleInfo
                    showPromptMessage("Added second subtitle: \(subtitleInfo.name)")
                } else {
                    playerLayer?.select(subtitleInfo: subtitleInfo)
                    showPromptMessage("Added subtitle: \(subtitleInfo.name)")
                }

                // Refresh the menu to show the new subtitle
                if #available(iOS 14.0, *) {
                    refreshSubtitleMenu()
                }
            }
        }
    }
}

// MARK: - UIDevice Extension

extension UIDevice {
    static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

#endif

#if os(iOS)
@MainActor
public class MenuController {
    public init(with builder: UIMenuBuilder) {
        builder.remove(menu: .format)
        builder.insertChild(MenuController.openFileMenu(), atStartOfMenu: .file)
//        builder.insertChild(MenuController.openURLMenu(), atStartOfMenu: .file)
//        builder.insertChild(MenuController.navigationMenu(), atStartOfMenu: .file)
    }

    class func openFileMenu() -> UIMenu {
        let openCommand = UIKeyCommand(input: "O", modifierFlags: .command, action: #selector(IOSVideoPlayerView.openFileAction(_:)))
        openCommand.title = NSLocalizedString("Open File", bundle: .module, comment: "")
        return UIMenu(title: "",
                      image: nil,
                      identifier: UIMenu.Identifier("com.example.apple-samplecode.menus.openFileMenu"),
                      options: .displayInline,
                      children: [openCommand])
    }

//    class func openURLMenu() -> UIMenu {
//        let openCommand = UIKeyCommand(input: "O", modifierFlags: [.command, .shift], action: #selector(IOSVideoPlayerView.openURLAction(_:)))
//        openCommand.title = NSLocalizedString("Open URL", comment: "")
//        let openMenu = UIMenu(title: "",
//                              image: nil,
//                              identifier: UIMenu.Identifier("com.example.apple-samplecode.menus.openURLMenu"),
//                              options: .displayInline,
//                              children: [openCommand])
//        return openMenu
//    }
//    class func navigationMenu() -> UIMenu {
//        let arrowKeyChildrenCommands = Arrows.allCases.map { arrow in
//            UIKeyCommand(title: arrow.localizedString(),
//                         image: nil,
//                         action: #selector(IOSVideoPlayerView.navigationMenuAction(_:)),
//                         input: arrow.command,
//                         modifierFlags: .command)
//        }
//        return UIMenu(title: NSLocalizedString("NavigationTitle", comment: ""),
//                      image: nil,
//                      identifier: UIMenu.Identifier("com.example.apple-samplecode.menus.navigationMenu"),
//                      options: [],
//                      children: arrowKeyChildrenCommands)
//    }

    enum Arrows: String, CaseIterable {
        case rightArrow
        case leftArrow
        case upArrow
        case downArrow
        func localizedString() -> String {
            NSLocalizedString(rawValue, comment: "")
        }

        @MainActor
        var command: String {
            switch self {
            case .rightArrow:
                return UIKeyCommand.inputRightArrow
            case .leftArrow:
                return UIKeyCommand.inputLeftArrow
            case .upArrow:
                return UIKeyCommand.inputUpArrow
            case .downArrow:
                return UIKeyCommand.inputDownArrow
            }
        }
    }
}
#endif
