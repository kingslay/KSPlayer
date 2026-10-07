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

class SettingsView: UIView {
    // Associated object keys for iOS 13 compatibility
    private var switchValueChangedKey: UInt8 = 0
    private var textFieldValueChangedKey: UInt8 = 0
    private var sliderValueChangedKey: UInt8 = 0
    private var buttonActionKey: UInt8 = 0

    private var accSeek: Bool {
        get { KSOptions.isAccurateSeek }
        set { KSOptions.isAccurateSeek = newValue }
    }

    private var hardwareDecode: Bool {
        get { playerView?.playerLayer?.options.videoDecodeType != .software }
        set { playerView?.playerLayer?.options.videoDecodeType = newValue ? .videotoolbox : .software }
    }

    private var asynchronousDecompression: Bool {
        get { playerView?.playerLayer?.options.videoDecodeType != .asynchronousHardware }
        set {
            if newValue {
                playerView?.playerLayer?.options.videoDecodeType = .asynchronousHardware
            }
        }
    }

    private var videoSoftDecodeThreadCount: Int {
        get { KSOptions.videoSoftDecodeThreadCount }
        set { KSOptions.videoSoftDecodeThreadCount = newValue }
    }

    private var isAutoPlay: Bool {
        get { KSOptions.isAutoPlay }
        set { KSOptions.isAutoPlay = newValue }
    }

    private var isSeekedAutoPlay: Bool {
        get { KSOptions.isSeekedAutoPlay }
        set { KSOptions.isSeekedAutoPlay = newValue }
    }

    /// Subtitle options - use KSOptions directly when available
    private var subtitleSize: Int {
        get { Int(KSOptions.subtitleFontSize) }
        set { KSOptions.subtitleFontSize = CGFloat(newValue) }
    }

    private var enableHDRSubtitle: Bool {
        get { KSOptions.enableHDRSubtitle }
        set { KSOptions.enableHDRSubtitle = newValue }
    }

    private var isResizeImageSubtitle: Bool {
        get { KSOptions.isResizeImageSubtitle }
        set { KSOptions.isResizeImageSubtitle = newValue }
    }

    private var textStrokeWidth: Int {
        get { Int(KSOptions.textStrokeWidth) }
        set { KSOptions.textStrokeWidth = CGFloat(newValue) }
    }

    private var verticalMargin: Int {
        get { Int(KSOptions.textPosition.verticalMargin) }
        set { KSOptions.textPosition.verticalMargin = CGFloat(newValue) }
    }

    private var leftMargin: Int {
        get { Int(KSOptions.textPosition.leftMargin) }
        set { KSOptions.textPosition.leftMargin = CGFloat(newValue) }
    }

    private var rightMargin: Int {
        get { Int(KSOptions.textPosition.rightMargin) }
        set { KSOptions.textPosition.rightMargin = CGFloat(newValue) }
    }

    private var isASSUseImageRender: Bool {
        get { KSOptions.isASSUseImageRender }
        set { KSOptions.isASSUseImageRender = newValue }
    }

    private var isSRTUseImageRender: Bool {
        get { KSOptions.isSRTUseImageRender }
        set { KSOptions.isSRTUseImageRender = newValue }
    }

    private var stripSubtitleStyle: Bool {
        get { KSOptions.stripSubtitleStyle }
        set { KSOptions.stripSubtitleStyle = newValue }
    }

    private var textBold: Bool {
        get { KSOptions.textBold }
        set { KSOptions.textBold = newValue }
    }

    private var textItalic: Bool {
        get { KSOptions.textItalic }
        set { KSOptions.textItalic = newValue }
    }

    private var subtitleImageScale: Double {
        get { Double(KSOptions.subtitleImageScale) }
        set { KSOptions.subtitleImageScale = CGFloat(newValue) }
    }

    private var subtitleFontName: String {
        get { KSOptions.textFontName }
        set { KSOptions.textFontName = newValue }
    }

    /// Additional properties for settings
    private var subtitleDelayTime: TimeInterval {
        get {
            playerView?.playerLayer?.subtitleModel.subtitleDelay ?? 0.0
        }
        set {
            playerView?.playerLayer?.subtitleModel.subtitleDelay = newValue
        }
    }

    private var horizontalAlign: HorizontalAlignment {
        get { KSOptions.textPosition.horizontalAlign }
        set { KSOptions.textPosition.horizontalAlign = newValue }
    }

    private var verticalAlign: VerticalAlignment {
        get { KSOptions.textPosition.verticalAlign }
        set { KSOptions.textPosition.verticalAlign = newValue }
    }

    private var subtitleColor: UIColor {
        get { KSOptions.textColor }
        set { KSOptions.textColor = newValue }
    }

    private var subtitleBgColor: UIColor {
        get { KSOptions.textBackgroundColor }
        set { KSOptions.textBackgroundColor = newValue }
    }

    private var textStrokeColor: UIColor {
        get { KSOptions.textStrokeColor }
        set { KSOptions.textStrokeColor = newValue }
    }

    private var textShadowColor: UIColor {
        get { KSOptions.textShadowColor }
        set { KSOptions.textShadowColor = newValue }
    }

    private var brightness: Float {
        get { playerView?.playerLayer?.options.brightness ?? 1.0 }
        set { playerView?.playerLayer?.options.brightness = newValue }
    }

    private var contrast: Float {
        get { playerView?.playerLayer?.options.contrast ?? 1.0 }
        set { playerView?.playerLayer?.options.contrast = newValue }
    }

    private var saturation: Float {
        get { playerView?.playerLayer?.options.saturation ?? 1.0 }
        set { playerView?.playerLayer?.options.saturation = newValue }
    }

    // Tab按钮
    private let videoTabButton = UIButton(type: .system)
    private let audioTabButton = UIButton(type: .system)
    private let subtitleTabButton = UIButton(type: .system)

    /// 关闭按钮
    private let closeButton = UIButton(type: .system)

    /// 内容容器
    private let contentContainer = UIView()

    // Tab内容视图
    private let videoContentView = UIView()
    private let audioContentView = UIView()
    private let subtitleContentView = UIView()

    /// 当前选中的tab
    private var currentTab: Tab = .video

    /// 回调
    var onDismiss: (() -> Void)?

    /// 播放器引用
    weak var playerView: IOSVideoPlayerView?

    /// 视频轨道按钮引用
    private var videoTrackButton: UIButton?

    /// 音频轨道按钮引用
    private var audioTrackButton: UIButton?

    // 字幕设置标签引用
    private var subtitleDelayLabel = UILabel()
    private var subtitleSizeLabel = UILabel()
    private var strokeWidthLabel = UILabel()
    private var horizontalMarginLabel = UILabel()
    private var verticalMarginLabel = UILabel()
    private var leftMarginLabel = UILabel()
    private var rightMarginLabel = UILabel()

    /// 视频设置标签引用
    private var threadCountLabel = UILabel()

    enum Tab: CaseIterable {
        case video
        case audio
        case subtitle

        var title: String {
            switch self {
            case .video: "Video"
            case .audio: "Audio"
            case .subtitle: "Subtitle"
            }
        }
    }

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 12
        clipsToBounds = true

        setupTabBar()
        setupContentArea()
        setupVideoTab()
        setupAudioTab()
        setupSubtitleTab()

        // 默认显示视频tab
        selectTab(.video)
    }

    private func setupTabBar() {
        // 创建顶部tab栏
        let tabStackView = UIStackView()
        tabStackView.axis = .horizontal
        tabStackView.distribution = .fillEqually
        tabStackView.spacing = 0
        tabStackView.translatesAutoresizingMaskIntoConstraints = false

        // 配置tab按钮
        let tabs = Tab.allCases
        let buttons = [videoTabButton, audioTabButton, subtitleTabButton]

        for (index, tab) in tabs.enumerated() {
            let button = buttons[index]
            button.setTitle(tab.title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.tag = index
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            tabStackView.addArrangedSubview(button)
        }

        // 关闭按钮
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(tabStackView)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            tabStackView.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            tabStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            tabStackView.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -20),
            tabStackView.heightAnchor.constraint(equalToConstant: 32),

            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    private func setupContentArea() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = .clear
        addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: 60),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -40),
        ])

        // 添加所有内容视图
        let contentViews = [videoContentView, audioContentView, subtitleContentView]
        for view in contentViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .clear
            view.isHidden = true
            contentContainer.addSubview(view)

            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            ])
        }
    }

    private func setupVideoTab() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        videoContentView.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: videoContentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: videoContentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: videoContentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: videoContentView.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // 添加视频设置项
        // 第一区域：屏幕宽高比
        addSectionTitle("ContentMode", to: contentView, top: 0)
        let aspectRatioButtons = createAspectRatioButtons()
        addButtonGroup(aspectRatioButtons, to: contentView, top: 25)

        // 分割线
        addDivider(to: contentView, top: 75)

        // 第二区域：视频轨道
        addSectionTitle("VideoTrack", to: contentView, top: 85)
        let videoTrackMenu = createVideoTrackMenu()
        addView(videoTrackMenu, to: contentView, top: 110)

        // 分割线
        addDivider(to: contentView, top: 160)

        // 第三区域：播放器选项
        addSectionTitle("Player Settings", to: contentView, top: 170)

        let hardwareDecodeSwitch = createSwitchRow("Hardware Decode", defaultValue: hardwareDecode) { [weak self] isOn in
            self?.hardwareDecode = isOn
            // 重置播放器以应用硬件解码设置
            self?.resetPlayer()
        }
        addView(hardwareDecodeSwitch, to: contentView, top: 195)

        let asyncDecompressionSwitch = createSwitchRow(
            "Async Decompression",
            defaultValue: asynchronousDecompression
        ) { [weak self] isOn in
            self?.asynchronousDecompression = isOn
        }
        addView(asyncDecompressionSwitch, to: contentView, top: 235)

        let autoPlaySwitch = createSwitchRow("Auto Play", defaultValue: isAutoPlay) { [weak self] isOn in
            self?.isAutoPlay = isOn
        }
        addView(autoPlaySwitch, to: contentView, top: 275)
        let accSeekSwitch = createSwitchRow("Accurate Seek", defaultValue: accSeek) { [weak self] isOn in
            self?.accSeek = isOn
        }
        addView(accSeekSwitch, to: contentView, top: 315)

        let seekedAutoPlaySwitch = createSwitchRow("Auto Play After Seek", defaultValue: isSeekedAutoPlay) { [weak self] isOn in
            self?.isSeekedAutoPlay = isOn
        }
        addView(seekedAutoPlaySwitch, to: contentView, top: 355)

        let threadCountRow = createStepperRow(
            title: "Soft Decoder Threads",
            valueLabel: &threadCountLabel,
            currentValue: "\(videoSoftDecodeThreadCount)",
            decreaseAction: #selector(decreaseThreadCount),
            increaseAction: #selector(increaseThreadCount)
        )
        addView(threadCountRow, to: contentView, top: 395)

        // 分割线
        addDivider(to: contentView, top: 445)

        // 第四区域：色彩均衡器
        addSectionTitle("Color Adjust", to: contentView, top: 455)

        let brightnessSlider = createColorSliderRow(
            "Brightness",
            value: Float(brightness),
            minValue: -1.0,
            maxValue: 1.0
        ) { [weak self] value in
            self?.brightness = value
            self?.playerView?.playerLayer?.options.brightness = value
        }
        addView(brightnessSlider, to: contentView, top: 480)

        let contrastSlider = createColorSliderRow(
            "Contrast",
            value: Float(contrast),
            minValue: -1.0,
            maxValue: 1.0
        ) { [weak self] value in
            self?.contrast = value
            self?.playerView?.playerLayer?.options.contrast = value
        }
        addView(contrastSlider, to: contentView, top: 520)

        let saturationSlider = createColorSliderRow(
            "Saturation",
            value: Float(saturation),
            minValue: -1.0,
            maxValue: 1.0
        ) { [weak self] value in
            self?.saturation = value
            self?.playerView?.playerLayer?.options.saturation = value
        }
        addView(saturationSlider, to: contentView, top: 560)

        // 设置内容高度
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: 615),
        ])
    }

    private func setupAudioTab() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        audioContentView.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: audioContentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: audioContentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: audioContentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: audioContentView.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // 第一区域：音频轨道选择
        addSectionTitle("Audio Track", to: contentView, top: 0)
        let audioTrackMenu = createAudioTrackMenu()
        addView(audioTrackMenu, to: contentView, top: 25)

        // 分割线
        addDivider(to: contentView, top: 75)

        // 设置内容高度
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: 200),
        ])
    }

    private func setupSubtitleTab() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        subtitleContentView.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: subtitleContentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: subtitleContentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: subtitleContentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: subtitleContentView.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        var currentTop: CGFloat = 0

//        // 第一区域：基本设置
//        addSectionTitle("基本设置", to: contentView, top: currentTop)
//        currentTop += 25

        let enableHDRSwitch = createSwitchRow("Enable HDR Subtitle", defaultValue: enableHDRSubtitle) { [weak self] isOn in
            self?.enableHDRSubtitle = isOn
            self?.updateSubtitleOptions()
        }
        addView(enableHDRSwitch, to: contentView, top: currentTop)
        currentTop += 40

        let resizeImageSwitch = createSwitchRow("Resize Image Subtitle", defaultValue: isResizeImageSubtitle) { [weak self] isOn in
            self?.isResizeImageSubtitle = isOn
            self?.updateSubtitleOptions()
        }
        addView(resizeImageSwitch, to: contentView, top: currentTop)
        currentTop += 40

        let assImageSwitch = createSwitchRow("ASS Use Image Render", defaultValue: isASSUseImageRender) { [weak self] isOn in
            self?.isASSUseImageRender = isOn
            self?.updateSubtitleOptions()
        }
        addView(assImageSwitch, to: contentView, top: currentTop)
        currentTop += 40

        let srtImageSwitch = createSwitchRow("SRT Use Image Render", defaultValue: isSRTUseImageRender) { [weak self] isOn in
            self?.isSRTUseImageRender = isOn
            self?.updateSubtitleOptions()
        }
        addView(srtImageSwitch, to: contentView, top: currentTop)
        currentTop += 40

        let stripStyleSwitch = createSwitchRow("Strip Subtitle Style", defaultValue: stripSubtitleStyle) { [weak self] isOn in
            self?.stripSubtitleStyle = isOn
            self?.updateSubtitleOptions()
        }
        addView(stripStyleSwitch, to: contentView, top: currentTop)
        currentTop += 40

        let delayRow = createStepperRow(
            title: "Subtitle Delay",
            valueLabel: &subtitleDelayLabel,
            currentValue: String(format: "%.1fs", subtitleDelayTime),
            decreaseAction: #selector(decreaseSubtitleDelay),
            increaseAction: #selector(increaseSubtitleDelay)
        )
        addView(delayRow, to: contentView, top: currentTop)
        currentTop += 40

        // 分割线
        addDivider(to: contentView, top: currentTop)
        currentTop += 10

        // 第二区域：字体设置
        addSectionTitle("Subtitle Font", to: contentView, top: currentTop)
        currentTop += 25

        let fontSizeRow = createStepperRow(
            title: "Font Size",
            valueLabel: &subtitleSizeLabel,
            currentValue: "\(subtitleSize)pt",
            decreaseAction: #selector(decreaseSubtitleSize),
            increaseAction: #selector(increaseSubtitleSize)
        )
        addView(fontSizeRow, to: contentView, top: currentTop)
        currentTop += 40

        let imageScaleRow = createCompactSliderRow(
            "Subtitle Image Scale",
            value: Float(subtitleImageScale),
            minValue: 0.1,
            maxValue: 1.0
        ) { [weak self] value in
            self?.subtitleImageScale = Double(value)
            self?.updateSubtitleOptions()
        }
        addView(imageScaleRow, to: contentView, top: currentTop)
        currentTop += 40

        let strokeWidthRow = createStepperRow(
            title: "Text Stroke Width",
            valueLabel: &strokeWidthLabel,
            currentValue: "\(textStrokeWidth)px",
            decreaseAction: #selector(decreaseStrokeWidth),
            increaseAction: #selector(increaseStrokeWidth)
        )
        addView(strokeWidthRow, to: contentView, top: currentTop)
        currentTop += 40

        let boldSwitch = createSwitchRow("Text Bold", defaultValue: textBold) { [weak self] isOn in
            self?.textBold = isOn
            self?.updateSubtitleOptions()
        }
        addView(boldSwitch, to: contentView, top: currentTop)
        currentTop += 40

        let italicSwitch = createSwitchRow("Text Italic", defaultValue: textItalic) { [weak self] isOn in
            self?.textItalic = isOn
            self?.updateSubtitleOptions()
        }
        addView(italicSwitch, to: contentView, top: currentTop)
        currentTop += 50

        // 分割线
        addDivider(to: contentView, top: currentTop)
        currentTop += 10

        // 第三区域：位置设置
        addSectionTitle("Position", to: contentView, top: currentTop)
        currentTop += 25

        let verticalMarginRow = createStepperRow(
            title: "Vertical Offset",
            valueLabel: &verticalMarginLabel,
            currentValue: "\(verticalMargin)px",
            decreaseAction: #selector(decreaseVerticalMargin),
            increaseAction: #selector(increaseVerticalMargin)
        )
        addView(verticalMarginRow, to: contentView, top: currentTop)
        currentTop += 40

        let leftMarginRow = createStepperRow(
            title: "Left Margin",
            valueLabel: &leftMarginLabel,
            currentValue: "\(leftMargin)px",
            decreaseAction: #selector(decreaseLeftMargin),
            increaseAction: #selector(increaseLeftMargin)
        )
        addView(leftMarginRow, to: contentView, top: currentTop)
        currentTop += 40

        let rightMarginRow = createStepperRow(
            title: "Right Margin",
            valueLabel: &rightMarginLabel,
            currentValue: "\(rightMargin)px",
            decreaseAction: #selector(decreaseRightMargin),
            increaseAction: #selector(increaseRightMargin)
        )
        addView(rightMarginRow, to: contentView, top: currentTop)
        currentTop += 40

        let horizontalAlignMenu = createHorizontalAlignMenu()
        addView(horizontalAlignMenu, to: contentView, top: currentTop)
        currentTop += 50

        // 分割线
        addDivider(to: contentView, top: currentTop)
        currentTop += 10

        // 第四区域：颜色设置
        addSectionTitle("Color", to: contentView, top: currentTop)
        currentTop += 25

        let textColorRow = createColorPickerRow("Subtitle Color", color: subtitleColor) { [weak self] color in
            self?.subtitleColor = color
            self?.updateSubtitleOptions()
        }
        addView(textColorRow, to: contentView, top: currentTop)
        currentTop += 50

        let backgroundColorRow = createColorPickerRow("Subtitle Bg Color", color: subtitleBgColor) { [weak self] color in
            self?.subtitleBgColor = color
            self?.updateSubtitleOptions()
        }
        addView(backgroundColorRow, to: contentView, top: currentTop)
        currentTop += 50

        let strokeColorRow = createColorPickerRow("Text Stroke Color", color: textStrokeColor) { [weak self] color in
            self?.textStrokeColor = color
            self?.updateSubtitleOptions()
        }
        addView(strokeColorRow, to: contentView, top: currentTop)
        currentTop += 50

        let shadowColorRow = createColorPickerRow("Text Shadow Color", color: textShadowColor) { [weak self] color in
            self?.textShadowColor = color
            self?.updateSubtitleOptions()
        }
        addView(shadowColorRow, to: contentView, top: currentTop)
        currentTop += 50

        // 设置内容高度
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: currentTop),
        ])
    }

    // MARK: - Helper Methods

    private func addSectionTitle(_ title: String, to view: UIView, top: CGFloat) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: top),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
    }

    private func createAspectRatioButtons() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let ratios = ["Default", "Scale To Fill", "Scale Aspect Fill"]
        for (index, ratio) in ratios.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(ratio, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.backgroundColor = index == 0 ? .white : .clear
            button.setTitleColor(index == 0 ? .black : .white, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.cornerRadius = 6
            button.tag = index
            button.addTarget(self, action: #selector(aspectRatioButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        return stackView
    }

    private func addButtonGroup(_ stackView: UIStackView, to view: UIView, top: CGFloat) {
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: top),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func createVideoTrackMenu() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle("Video Track", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        // Store reference to the button so we can set up the menu later
        videoTrackButton = button

        containerView.addSubview(button)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    private func setupVideoTrackMenu(for button: UIButton) {
        guard let playerView else {
            return
        }

        guard let player = playerView.playerLayer?.player else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupVideoTrackMenu(for: button)
            }
            return
        }

        let videoTracks = player.tracks(mediaType: .video)

        let currentVideoTrack = videoTracks.first { $0.isEnabled }

        var menuItems: [UIAction] = []

        for (index, track) in videoTracks.enumerated() {
            let trackTitle = track.description.isEmpty ? "Video Track \(index + 1)" : track.description
            let action = UIAction(
                title: trackTitle,
                state: track.isEnabled ? .on : .off
            ) { [weak self] _ in
                // 切换到选中的视频轨道
                player.select(track: track)
                // 更新按钮标题
                button.setTitle(trackTitle, for: .normal)
                // 重新设置菜单以更新选中状态
                self?.setupVideoTrackMenu(for: button)
            }
            menuItems.append(action)
        }

        if menuItems.isEmpty {
            let noTrackAction = UIAction(title: "无可用视频轨道", attributes: .disabled) { _ in }
            menuItems.append(noTrackAction)

            // Retry after a delay if no tracks are found
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.setupVideoTrackMenu(for: button)
            }
        }

        if #available(iOS 14.0, *) {
            let menu = UIMenu(title: "Video Track", children: menuItems)
            button.menu = menu
            button.showsMenuAsPrimaryAction = true
        } else {
            // For iOS 13, use target-action to show alert
            button.removeTarget(nil, action: nil, for: .allEvents)
            button.addTarget(self, action: #selector(showVideoTrackAlert(_:)), for: .touchUpInside)
        }

        // 设置按钮标题为当前选中的轨道
        if let currentTrack = currentVideoTrack {
            let trackTitle = currentTrack.description.isEmpty ? "Video Track" : currentTrack.description
            button.setTitle(trackTitle, for: .normal)
        }
    }

    /// Public method to refresh video track menu (can be called when media is loaded)
    func refreshVideoTrackMenu() {
        if let button = videoTrackButton {
            setupVideoTrackMenu(for: button)
        }
    }

    @objc
    private func showVideoTrackAlert(_ sender: UIButton) {
        guard let playerView, let player = playerView.playerLayer?.player else { return }

        let videoTracks = player.tracks(mediaType: .video)
        showVideoTrackAlertForTracks(videoTracks, player: player, button: sender)
    }

    private func showVideoTrackAlertForTracks(_ videoTracks: [MediaPlayerTrack], player: MediaPlayerProtocol, button: UIButton) {
        let alert = UIAlertController(title: "Video Track", message: nil, preferredStyle: .actionSheet)

        for (index, track) in videoTracks.enumerated() {
            let trackTitle = track.description.isEmpty ? "Video Track \(index + 1)" : track.description
            let isSelected = track.isEnabled

            let alertAction = UIAlertAction(
                title: isSelected ? "✓ \(trackTitle)" : trackTitle,
                style: .default
            ) { [weak self] _ in
                player.select(track: track)
                button.setTitle(trackTitle, for: .normal)
                // Refresh the menu
                self?.setupVideoTrackMenu(for: button)
            }
            alert.addAction(alertAction)
        }

        if videoTracks.isEmpty {
            let noTrackAction = UIAlertAction(title: "无可用视频轨道", style: .default, handler: nil)
            noTrackAction.isEnabled = false
            alert.addAction(noTrackAction)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }

        playerView?.viewController?.present(alert, animated: true)
    }

    @objc
    private func showAudioTrackAlert(_ sender: UIButton) {
        guard let playerView, let player = playerView.playerLayer?.player else { return }

        let audioTracks = player.tracks(mediaType: .audio)
        showAudioTrackAlertForTracks(audioTracks, player: player, button: sender)
    }

    private func showAudioTrackAlertForTracks(_ audioTracks: [MediaPlayerTrack], player: MediaPlayerProtocol, button: UIButton) {
        let alert = UIAlertController(title: "Audio Track", message: nil, preferredStyle: .actionSheet)

        for (index, track) in audioTracks.enumerated() {
            let trackTitle = track.description.isEmpty ? "Audio Track \(index + 1)" : track.description
            let isSelected = track.isEnabled

            let alertAction = UIAlertAction(
                title: isSelected ? "✓ \(trackTitle)" : trackTitle,
                style: .default
            ) { [weak self] _ in
                player.select(track: track)
                button.setTitle(trackTitle, for: .normal)
                // Refresh the menu
                self?.setupAudioTrackMenu(for: button)
            }
            alert.addAction(alertAction)
        }

        if audioTracks.isEmpty {
            let noTrackAction = UIAlertAction(title: "无可用音频轨道", style: .default, handler: nil)
            noTrackAction.isEnabled = false
            alert.addAction(noTrackAction)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }

        playerView?.viewController?.present(alert, animated: true)
    }

    /// Public method to refresh audio track menu (can be called when media is loaded)
    func refreshAudioTrackMenu() {
        if let button = audioTrackButton {
            setupAudioTrackMenu(for: button)
        }
    }

    private func createAudioTrackMenu() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle("Audio Track", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        // Store reference to the button so we can set up the menu later
        audioTrackButton = button

        containerView.addSubview(button)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    private func setupAudioTrackMenu(for button: UIButton) {
        guard let playerView else {
            // Retry after a delay if player is not ready yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupAudioTrackMenu(for: button)
            }
            return
        }

        guard let player = playerView.playerLayer?.player else {
            // Retry after a delay if player is not ready yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupAudioTrackMenu(for: button)
            }
            return
        }

        let audioTracks = player.tracks(mediaType: .audio)

        let currentAudioTrack = audioTracks.first { $0.isEnabled }

        var menuItems: [UIAction] = []

        for (index, track) in audioTracks.enumerated() {
            let trackTitle = track.description.isEmpty ? "Audio Track \(index + 1)" : track.description
            let action = UIAction(
                title: trackTitle,
                state: track.isEnabled ? .on : .off
            ) { [weak self] _ in
                // 切换到选中的音频轨道
                player.select(track: track)
                // 更新按钮标题
                button.setTitle(trackTitle, for: .normal)
                // 重新设置菜单以更新选中状态
                self?.setupAudioTrackMenu(for: button)
            }
            menuItems.append(action)
        }

        if menuItems.isEmpty {
            let noTrackAction = UIAction(title: "无可用音频轨道", attributes: .disabled) { _ in }
            menuItems.append(noTrackAction)

            // Retry after a delay if no tracks are found
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.setupAudioTrackMenu(for: button)
            }
        }

        if #available(iOS 14.0, *) {
            let menu = UIMenu(title: "Audio Track", children: menuItems)
            button.menu = menu
            button.showsMenuAsPrimaryAction = true
        } else {
            // For iOS 13, use target-action to show alert
            button.removeTarget(nil, action: nil, for: .allEvents)
            button.addTarget(self, action: #selector(showAudioTrackAlert(_:)), for: .touchUpInside)
        }

        // 设置按钮标题为当前选中的轨道
        if let currentTrack = currentAudioTrack {
            let trackTitle = currentTrack.description.isEmpty ? "Audio Track" : currentTrack.description
            button.setTitle(trackTitle, for: .normal)
        }
    }

    private func createHorizontalAlignMenu() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle(getCurrentHorizontalAlignName(), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        let alignmentOptions = [
            ("Leading", "leading"),
            ("Center", "center"),
            ("Trailing", "trailing"),
        ]

        var menuItems: [UIAction] = []

        for (title, value) in alignmentOptions {
            let isSelected = getCurrentHorizontalAlignValue() == value
            let action = UIAction(
                title: title,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.setHorizontalAlign(value)
                button.setTitle(title, for: .normal)
                // Recreate menu to update selection state
                self?.recreateHorizontalAlignMenu(for: button)
                self?.updateSubtitleOptions()
            }
            menuItems.append(action)
        }

        if #available(iOS 14.0, *) {
            let menu = UIMenu(title: "Horizontal Align", children: menuItems)
            button.menu = menu
            button.showsMenuAsPrimaryAction = true
        } else {
            // For iOS 13, use target-action to show alert
            button.removeTarget(nil, action: nil, for: .allEvents)
            button.addTarget(self, action: #selector(showHorizontalAlignAlert(_:)), for: .touchUpInside)
        }

        containerView.addSubview(button)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    private func getCurrentHorizontalAlignName() -> String {
        switch getCurrentHorizontalAlignValue() {
        case "leading":
            return "Leading"
        case "center":
            return "Center"
        case "trailing":
            return "Trailing"
        default:
            return "Center"
        }
    }

    private func getCurrentHorizontalAlignValue() -> String {
        switch horizontalAlign {
        case .leading:
            return "leading"
        case .center:
            return "center"
        case .trailing:
            return "trailing"
        default:
            return "center"
        }
    }

    private func setHorizontalAlign(_ value: String) {
        switch value {
        case "leading":
            horizontalAlign = .leading
        case "center":
            horizontalAlign = .center
        case "trailing":
            horizontalAlign = .trailing
        default:
            horizontalAlign = .center
        }
    }

    private func recreateHorizontalAlignMenu(for button: UIButton) {
        let alignmentOptions = [
            ("Leading", "leading"),
            ("Center", "center"),
            ("Trailing", "trailing"),
        ]

        var menuItems: [UIAction] = []

        for (title, value) in alignmentOptions {
            let isSelected = getCurrentHorizontalAlignValue() == value
            let action = UIAction(
                title: title,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.setHorizontalAlign(value)
                button.setTitle(title, for: .normal)
                // Recreate menu to update selection state
                self?.recreateHorizontalAlignMenu(for: button)
                self?.updateSubtitleOptions()
            }
            menuItems.append(action)
        }

        if #available(iOS 14.0, *) {
            let menu = UIMenu(title: "Center", children: menuItems)
            button.menu = menu
        }
    }

    @objc
    private func showHorizontalAlignAlert(_ sender: UIButton) {
        let alignmentOptions = [
            ("Leading", "leading"),
            ("Center", "center"),
            ("Trailing", "trailing"),
        ]

        let alert = UIAlertController(title: "Horizontal Align", message: nil, preferredStyle: .actionSheet)

        for (title, value) in alignmentOptions {
            let isSelected = getCurrentHorizontalAlignValue() == value

            let alertAction = UIAlertAction(
                title: isSelected ? "✓ \(title)" : title,
                style: .default
            ) { [weak self] _ in
                self?.setHorizontalAlign(value)
                sender.setTitle(title, for: .normal)
                self?.updateSubtitleOptions()
            }
            alert.addAction(alertAction)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }

        playerView?.viewController?.present(alert, animated: true)
    }

    /// iOS 13 compatibility methods
    @objc private func switchValueChanged(_ sender: UISwitch) {
        if let onValueChanged = objc_getAssociatedObject(sender, &switchValueChangedKey) as? (Bool) -> Void {
            onValueChanged(sender.isOn)
        }
    }

    @objc private func textFieldValueChanged(_ sender: UITextField) {
        if let onValueChanged = objc_getAssociatedObject(sender, &textFieldValueChangedKey) as? (String) -> Void {
            onValueChanged(sender.text ?? "")
        }
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        if let onValueChanged = objc_getAssociatedObject(sender, &sliderValueChangedKey) as? (Float) -> Void {
            onValueChanged(sender.value)
        }
    }

    @objc private func buttonActionTriggered(_ sender: UIButton) {
        if let action = objc_getAssociatedObject(sender, &buttonActionKey) as? () -> Void {
            action()
        }
    }

    private func updateSubtitleOptions() {
        // Most options are already handled by computed properties that directly set KSOptions
        // Only need to handle the ones that require special conversion or aren't handled automatically

        // 字幕位置设置 - handle alignment conversions
        switch horizontalAlign {
        case .leading:
            KSOptions.textPosition.horizontalAlign = .leading
        case .center:
            KSOptions.textPosition.horizontalAlign = .center
        case .trailing:
            KSOptions.textPosition.horizontalAlign = .trailing
        default:
            KSOptions.textPosition.horizontalAlign = .leading
        }

        switch verticalAlign {
        case .top:
            KSOptions.textPosition.verticalAlign = .top
        case .center:
            KSOptions.textPosition.verticalAlign = .center
        case .bottom:
            KSOptions.textPosition.verticalAlign = .bottom
        default:
            KSOptions.textPosition.verticalAlign = .bottom
        }

        // 颜色设置需要转换为平台颜色
        #if os(iOS)
        KSOptions.textColor = subtitleColor
        KSOptions.textBackgroundColor = subtitleBgColor
        KSOptions.textShadowColor = textShadowColor
        KSOptions.textStrokeColor = textStrokeColor
        #endif
    }

    // MARK: - Subtitle Stepper Actions

    @objc
    private func decreaseSubtitleDelay() {
        subtitleDelayTime = max(0.0, subtitleDelayTime - 0.5)
        subtitleDelayLabel.text = String(format: "%.1fs", subtitleDelayTime)
    }

    @objc
    private func increaseSubtitleDelay() {
        subtitleDelayTime = min(100.0, subtitleDelayTime + 0.5)
        subtitleDelayLabel.text = String(format: "%.1fs", subtitleDelayTime)
    }

    @objc
    private func decreaseSubtitleSize() {
        subtitleSize = max(1, subtitleSize - 1)
        subtitleSizeLabel.text = "\(subtitleSize)pt"
        updateSubtitleOptions()
    }

    @objc
    private func increaseSubtitleSize() {
        subtitleSize = min(50, subtitleSize + 1)
        subtitleSizeLabel.text = "\(subtitleSize)pt"
        updateSubtitleOptions()
    }

    @objc
    private func decreaseStrokeWidth() {
        textStrokeWidth = max(0, textStrokeWidth - 1)
        strokeWidthLabel.text = "\(textStrokeWidth)px"
        updateSubtitleOptions()
    }

    @objc
    private func increaseStrokeWidth() {
        textStrokeWidth = min(50, textStrokeWidth + 1)
        strokeWidthLabel.text = "\(textStrokeWidth)px"
        updateSubtitleOptions()
    }

    @objc
    private func decreaseVerticalMargin() {
        verticalMargin = max(0, verticalMargin - 10)
        verticalMarginLabel.text = "\(verticalMargin)px"
        updateSubtitleOptions()
    }

    @objc
    private func increaseVerticalMargin() {
        verticalMargin = min(1000, verticalMargin + 10)
        verticalMarginLabel.text = "\(verticalMargin)px"
        updateSubtitleOptions()
    }

    @objc
    private func decreaseLeftMargin() {
        leftMargin = max(0, leftMargin - 10)
        leftMarginLabel.text = "\(leftMargin)px"
        updateSubtitleOptions()
    }

    @objc
    private func increaseLeftMargin() {
        leftMargin = min(1000, leftMargin + 10)
        leftMarginLabel.text = "\(leftMargin)px"
        updateSubtitleOptions()
    }

    @objc
    private func decreaseRightMargin() {
        rightMargin = max(0, rightMargin - 10)
        rightMarginLabel.text = "\(rightMargin)px"
        updateSubtitleOptions()
    }

    @objc
    private func increaseRightMargin() {
        rightMargin = min(1000, rightMargin + 10)
        rightMarginLabel.text = "\(rightMargin)px"
        updateSubtitleOptions()
    }

    @objc
    private func decreaseThreadCount() {
        videoSoftDecodeThreadCount = max(1, videoSoftDecodeThreadCount - 1)
        threadCountLabel.text = "\(videoSoftDecodeThreadCount)"
    }

    @objc
    private func increaseThreadCount() {
        videoSoftDecodeThreadCount = min(16, videoSoftDecodeThreadCount + 1)
        threadCountLabel.text = "\(videoSoftDecodeThreadCount)"
    }

    private func applyColorSettings() {
        guard let playerView else { return }
        playerView.playerLayer?.options.brightness = Float(brightness)
        playerView.playerLayer?.options.contrast = Float(contrast)
        playerView.playerLayer?.options.saturation = Float(saturation)
    }

    private func resetPlayer() {
        // 重置播放器以应用新的解码设置
        guard let playerView else { return }
        let currentResource = playerView.resource
        let currentIndex = playerView.currentDefinition
        playerView.resetPlayer()
        if let currentResource {
            playerView.set(resource: currentResource, definitionIndex: currentIndex)
        }
    }

    private func createSwitchRow(_ title: String, defaultValue: Bool, onValueChanged: ((Bool) -> Void)? = nil) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let switchControl = UISwitch()
        switchControl.isOn = defaultValue
        switchControl.onTintColor = .systemGreen
        switchControl.translatesAutoresizingMaskIntoConstraints = false

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                switchControl.addAction(UIAction { _ in
                    onValueChanged(switchControl.isOn)
                }, for: .valueChanged)
            } else {
                switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
                // Store the closure for later use
                objc_setAssociatedObject(switchControl, &switchValueChangedKey, onValueChanged, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(switchControl)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            switchControl.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])

        return containerView
    }

    private func createNumberField(_ defaultValue: String, placeholder: String, onValueChanged: ((String) -> Void)? = nil) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let textField = UITextField()
        textField.text = defaultValue
        textField.placeholder = placeholder
        textField.textColor = .white
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.layer.cornerRadius = 6
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        textField.leftViewMode = .always
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                textField.addAction(UIAction { _ in
                    onValueChanged(textField.text ?? "")
                }, for: .editingChanged)
            } else {
                textField.addTarget(self, action: #selector(textFieldValueChanged(_:)), for: .editingChanged)
                objc_setAssociatedObject(textField, &textFieldValueChangedKey, onValueChanged, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(textField)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            textField.topAnchor.constraint(equalTo: containerView.topAnchor),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    private func createSliderRow(
        _ title: String,
        value: Float,
        minValue: Float,
        maxValue: Float,
        onValueChanged: ((Float) -> Void)? = nil
    ) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = String(format: "%.1f", value)
        valueLabel.textColor = .white
        valueLabel.font = UIFont.systemFont(ofSize: 12)
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let slider = UISlider()
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = value
        slider.minimumTrackTintColor = .systemBlue
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.thumbTintColor = .white
        slider.translatesAutoresizingMaskIntoConstraints = false

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                slider.addAction(UIAction { _ in
                    valueLabel.text = String(format: "%.1f", slider.value)
                    onValueChanged(slider.value)
                }, for: .valueChanged)
            } else {
                slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
                // We need a custom handler for this case since we have multiple operations
                let handler: (Float) -> Void = { value in
                    valueLabel.text = String(format: "%.1f", value)
                    onValueChanged(value)
                }
                objc_setAssociatedObject(slider, &sliderValueChangedKey, handler, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(valueLabel)
        containerView.addSubview(slider)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),

            valueLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 50),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
        ])

        return containerView
    }

    private func createCompactSliderRow(
        _ title: String,
        value: Float,
        minValue: Float,
        maxValue: Float,
        onValueChanged: ((Float) -> Void)? = nil
    ) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = String(format: "%.1f", value)
        valueLabel.textColor = .white
        valueLabel.font = UIFont.systemFont(ofSize: 12)
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let slider = UISlider()
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = value
        slider.minimumTrackTintColor = .systemBlue
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.thumbTintColor = .white
        slider.translatesAutoresizingMaskIntoConstraints = false

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                slider.addAction(UIAction { _ in
                    valueLabel.text = String(format: "%.1f", slider.value)
                    onValueChanged(slider.value)
                }, for: .valueChanged)
            } else {
                slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
                // We need a custom handler for this case since we have multiple operations
                let handler: (Float) -> Void = { value in
                    valueLabel.text = String(format: "%.1f", value)
                    onValueChanged(value)
                }
                objc_setAssociatedObject(slider, &sliderValueChangedKey, handler, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(valueLabel)
        containerView.addSubview(slider)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 80),

            slider.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            slider.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 50),
        ])

        return containerView
    }

    private func createColorSliderRow(
        _ title: String,
        value: Float,
        minValue: Float,
        maxValue: Float,
        defaultValue: Float = 1.0,
        onValueChanged: ((Float) -> Void)? = nil
    ) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        // 转换为 -100 到 100 的显示范围
        let displayValue = Int(value * 100)
        valueLabel.text = "\(displayValue)"
        valueLabel.textColor = .white
        valueLabel.font = UIFont.systemFont(ofSize: 12)
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let slider = UISlider()
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = value
        slider.minimumTrackTintColor = .systemBlue
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.thumbTintColor = .white
        slider.translatesAutoresizingMaskIntoConstraints = false

        // 重置按钮
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        resetButton.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.3)
        resetButton.layer.cornerRadius = 6
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        // 重置按钮点击事件
        if #available(iOS 14.0, *) {
            resetButton.addAction(UIAction { _ in
                slider.value = defaultValue
                let displayValue = Int(defaultValue * 100)
                valueLabel.text = "\(displayValue)"
                onValueChanged?(defaultValue)
            }, for: .touchUpInside)
        } else {
            resetButton.addTarget(self, action: #selector(buttonActionTriggered(_:)), for: .touchUpInside)
            let action: () -> Void = {
                slider.value = defaultValue
                let displayValue = Int(defaultValue * 100)
                valueLabel.text = "\(displayValue)"
                onValueChanged?(defaultValue)
            }
            objc_setAssociatedObject(resetButton, &buttonActionKey, action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                slider.addAction(UIAction { _ in
                    // 更新显示值为 -100 到 100 的范围
                    let displayValue = Int(slider.value * 100)
                    valueLabel.text = "\(displayValue)"
                    onValueChanged(slider.value)
                }, for: .valueChanged)
            } else {
                slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
                let handler: (Float) -> Void = { value in
                    let displayValue = Int(value * 100)
                    valueLabel.text = "\(displayValue)"
                    onValueChanged(value)
                }
                objc_setAssociatedObject(slider, &sliderValueChangedKey, handler, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(slider)
        containerView.addSubview(valueLabel)
        containerView.addSubview(resetButton)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),

            // 标题在左侧
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 60),

            // 滑块在中间
            slider.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            slider.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            // 数值标签在滑块右侧
            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 30),

            // 重置按钮在最右侧
            resetButton.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 10),
            resetButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            resetButton.widthAnchor.constraint(equalToConstant: 50),
            resetButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        return containerView
    }

    private func createStepperRow(
        title: String,
        valueLabel: inout UILabel,
        currentValue: String,
        decreaseAction: Selector,
        increaseAction: Selector
    ) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let minusButton = createButton(title: "−", action: decreaseAction)
        let plusButton = createButton(title: "+", action: increaseAction)

        valueLabel.text = currentValue
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        valueLabel.backgroundColor = UIColor.clear
        valueLabel.layer.cornerRadius = 0

        let buttonStack = UIStackView(arrangedSubviews: [minusButton, valueLabel, plusButton])
        buttonStack.spacing = 8
        buttonStack.alignment = .center

        let rowStack = UIStackView(arrangedSubviews: [titleLabel, buttonStack])
        rowStack.axis = .horizontal
        rowStack.spacing = 40
        rowStack.distribution = .equalSpacing
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        // 设置高度约束
        NSLayoutConstraint.activate([
            rowStack.heightAnchor.constraint(equalToConstant: 40),
        ])

        return rowStack
    }

    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.3) // 让按钮颜色更暗
        button.layer.cornerRadius = 6 // 圆角更小
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func createNumberFieldRow(
        _ title: String,
        defaultValue: String,
        placeholder: String,
        onValueChanged: ((String) -> Void)? = nil
    ) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textField = UITextField()
        textField.text = defaultValue
        textField.placeholder = placeholder
        textField.textColor = .white
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.layer.cornerRadius = 6
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        textField.leftViewMode = .always
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                textField.addAction(UIAction { _ in
                    onValueChanged(textField.text ?? "")
                }, for: .editingChanged)
            } else {
                textField.addTarget(self, action: #selector(textFieldValueChanged(_:)), for: .editingChanged)
                objc_setAssociatedObject(textField, &textFieldValueChangedKey, onValueChanged, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(textField)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textField.widthAnchor.constraint(equalToConstant: 80),
        ])

        return containerView
    }

    private func createTextFieldRow(
        _ title: String,
        defaultValue: String,
        placeholder: String,
        onValueChanged: ((String) -> Void)? = nil
    ) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textField = UITextField()
        textField.text = defaultValue
        textField.placeholder = placeholder
        textField.textColor = .white
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.layer.cornerRadius = 6
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false

        if let onValueChanged {
            if #available(iOS 14.0, *) {
                textField.addAction(UIAction { _ in
                    onValueChanged(textField.text ?? "")
                }, for: .editingChanged)
            } else {
                textField.addTarget(self, action: #selector(textFieldValueChanged(_:)), for: .editingChanged)
                objc_setAssociatedObject(textField, &textFieldValueChangedKey, onValueChanged, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(textField)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 80),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 40),
        ])

        return containerView
    }

    private func addView(_ view: UIView, to containerView: UIView, top: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: top),
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }

    private func addDivider(to containerView: UIView, top: CGFloat) {
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        divider.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(divider)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: containerView.topAnchor, constant: top),
            divider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    private func createColorPickerRow(
        _ title: String,
        color: UIColor,
        onColorChanged: @escaping (UIColor) -> Void
    ) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 颜色显示按钮
        let colorButton = UIButton(type: .custom)
        colorButton.backgroundColor = color
        colorButton.layer.cornerRadius = 12
        colorButton.layer.borderWidth = 2
        colorButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        colorButton.translatesAutoresizingMaskIntoConstraints = false

        // 预设颜色选择
        let colorsStackView = UIStackView()
        colorsStackView.axis = .horizontal
        colorsStackView.spacing = 8
        colorsStackView.translatesAutoresizingMaskIntoConstraints = false

        // 常用颜色
        let presetColors: [UIColor] = [
            .white, .black, .red, .green, .blue, .yellow, .orange, .purple, .clear,
        ]

        for (index, presetColor) in presetColors.enumerated() {
            let presetButton = UIButton(type: .custom)
            presetButton.backgroundColor = presetColor
            presetButton.layer.cornerRadius = 8
            presetButton.layer.borderWidth = 1
            presetButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
            presetButton.tag = index
            presetButton.translatesAutoresizingMaskIntoConstraints = false

            // 为透明色添加特殊样式
            if presetColor == .clear {
                presetButton.backgroundColor = UIColor.clear
                presetButton.layer.borderWidth = 2
                presetButton.layer.borderColor = UIColor.white.cgColor
                // 添加斜线表示透明
                let line = UIView()
                line.backgroundColor = UIColor.red
                line.translatesAutoresizingMaskIntoConstraints = false
                presetButton.addSubview(line)
                NSLayoutConstraint.activate([
                    line.centerXAnchor.constraint(equalTo: presetButton.centerXAnchor),
                    line.centerYAnchor.constraint(equalTo: presetButton.centerYAnchor),
                    line.widthAnchor.constraint(equalToConstant: 20),
                    line.heightAnchor.constraint(equalToConstant: 2),
                ])
                line.transform = CGAffineTransform(rotationAngle: .pi / 4)
            }

            if #available(iOS 14.0, *) {
                presetButton.addAction(UIAction { _ in
                    colorButton.backgroundColor = presetColor
                    onColorChanged(presetColor)
                }, for: .touchUpInside)
            } else {
                presetButton.addTarget(self, action: #selector(buttonActionTriggered(_:)), for: .touchUpInside)
                let action: () -> Void = {
                    colorButton.backgroundColor = presetColor
                    onColorChanged(presetColor)
                }
                objc_setAssociatedObject(presetButton, &buttonActionKey, action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }

            NSLayoutConstraint.activate([
                presetButton.widthAnchor.constraint(equalToConstant: 16),
                presetButton.heightAnchor.constraint(equalToConstant: 16),
            ])

            colorsStackView.addArrangedSubview(presetButton)
        }

        containerView.addSubview(titleLabel)
        containerView.addSubview(colorButton)
        containerView.addSubview(colorsStackView)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 80),

            colorButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            colorButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            colorButton.widthAnchor.constraint(equalToConstant: 24),
            colorButton.heightAnchor.constraint(equalToConstant: 24),

            colorsStackView.leadingAnchor.constraint(equalTo: colorButton.trailingAnchor, constant: 15),
            colorsStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            colorsStackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -10),
        ])

        return containerView
    }

    // MARK: - Actions

    @objc
    private func tabButtonTapped(_ sender: UIButton) {
        let tab = Tab.allCases[sender.tag]
        selectTab(tab)
    }

    @objc
    private func aspectRatioButtonTapped(_ sender: UIButton) {
        // 更新按钮状态
        if let stackView = sender.superview as? UIStackView {
            for case let button as UIButton in stackView.arrangedSubviews {
                let isSelected = button.tag == sender.tag
                button.backgroundColor = isSelected ? .white : .clear
                button.setTitleColor(isSelected ? .black : .white, for: .normal)
            }
        }
        switch sender.tag {
        case 0:
            playerView?.playerLayer?.player.contentMode = .scaleAspectFit
        case 1: // 拉伸 - scaleToFill
            playerView?.playerLayer?.player.contentMode = .scaleToFill
        case 2: // 填充 - scaleAspectFill
            playerView?.playerLayer?.player.contentMode = .scaleAspectFill
        default:
            // 对于16:9和4:3，暂时使用scaleAspectFit
            playerView?.playerLayer?.player.contentMode = .scaleAspectFit
        }
    }

    @objc
    private func closeButtonTapped() {
        onDismiss?()
    }

    private func selectTab(_ tab: Tab) {
        currentTab = tab

        // 更新tab按钮状态
        let buttons = [videoTabButton, audioTabButton, subtitleTabButton]
        for (index, button) in buttons.enumerated() {
            let isSelected = Tab.allCases[index] == tab
            if isSelected {
                button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                button.layer.cornerRadius = 8
                button.layer.masksToBounds = true
            } else {
                button.backgroundColor = .clear
                button.layer.cornerRadius = 0
            }
            button.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.7), for: .normal)
        }

        // 显示对应的内容视图
        let contentViews = [videoContentView, audioContentView, subtitleContentView]
        for (index, view) in contentViews.enumerated() {
            view.isHidden = Tab.allCases[index] != tab
        }
    }

    func show(in parentView: UIView) {
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        // 设置从右侧滑入的约束，紧贴屏幕边界
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            topAnchor.constraint(equalTo: parentView.topAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            widthAnchor.constraint(equalToConstant: 400), // 设置固定宽度
        ])

        // 强制立即应用约束布局
        parentView.layoutIfNeeded()

        // 初始位置：从右侧屏幕外开始
        let viewWidth: CGFloat = 400
        transform = CGAffineTransform(translationX: viewWidth + 20, y: 0)
        alpha = 0

        // 添加从右侧滑入的动画
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.transform = .identity
            self.alpha = 1.0
        }, completion: nil)

        // 现在设置轨道菜单，因为playerView应该已经设置了
        setupVideoTrackMenuIfNeeded()
        setupAudioTrackMenuIfNeeded()

        // 应用设置到播放器
        applyColorSettings()
        updateSubtitleOptions()
    }

    private func setupVideoTrackMenuIfNeeded() {
        if let button = videoTrackButton {
            setupVideoTrackMenu(for: button)
        }
    }

    private func setupAudioTrackMenuIfNeeded() {
        if let button = audioTrackButton {
            setupAudioTrackMenu(for: button)
        }
    }

    func hide() {
        let viewWidth: CGFloat = 400
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: viewWidth + 20, y: 0)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
#endif
