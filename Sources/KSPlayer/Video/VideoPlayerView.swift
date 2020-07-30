//
//  VideoPlayerView.swift
//  Pods
//
//  Created by kintan on 16/4/29.
//
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// internal enum to check the pan direction
public enum KSPanDirection {
    case horizontal
    case vertical
}

public protocol LoadingIndector {
    func startAnimating()
    func stopAnimating()
}

#if canImport(UIKit)
extension UIActivityIndicatorView: LoadingIndector {}
#endif

open class VideoPlayerView: PlayerView {
    private var delayItem: DispatchWorkItem?
    /// Gesture used to show / hide control view
    public let tapGesture = UITapGestureRecognizer()
    public let doubleTapGesture = UITapGestureRecognizer()
    public let panGesture = UIPanGestureRecognizer()
    /// 滑动方向
    var scrollDirection = KSPanDirection.horizontal
    var tmpPanValue: Float = 0
    private var isSliderSliding = false

    public let bottomMaskView = LayerContainerView()
    public let topMaskView = LayerContainerView()
    // 是否播放过
    private(set) var isPlayed = false
    private var embedSubtitleDataSouce: SubtitleDataSouce? {
        didSet {
            if oldValue !== embedSubtitleDataSouce {
                if let oldValue = oldValue {
                    srtControl.remove(dataSouce: oldValue)
                }
                if let embedSubtitleDataSouce = embedSubtitleDataSouce {
                    srtControl.add(dataSouce: embedSubtitleDataSouce)
                    let infos = srtControl.filterInfos { $0.subtitleDataSouce === embedSubtitleDataSouce }
                    if KSPlayerManager.autoSelectEmbedSubtitle, let first = infos.first {
                        srtControl.view.selectedInfo.wrappedValue = first
                    }
                }
            }
        }
    }

    public private(set) var currentDefinition = 0 {
        didSet {
            if let resource = resource {
                toolBar.definitionButton.setTitle(resource.definitions[currentDefinition].definition, for: .normal)
            }
        }
    }

    public private(set) var resource: KSPlayerResource? {
        didSet {
            if let resource = resource, oldValue !== resource {
                srtControl.searchSubtitle(name: resource.name)
                titleLabel.text = resource.name
                toolBar.definitionButton.isHidden = resource.definitions.count < 2
                autoFadeOutViewWithAnimation()
                isMaskShow = true
            }
        }
    }

    public var navigationBar = UIStackView()
    public var titleLabel = UILabel()
    public var subtitleLabel = UILabel()
    public var subtitleBackView = UIView()
    /// Activty Indector for loading
    public var loadingIndector: UIView & LoadingIndector = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
    public var seekToView: UIView & SeekViewProtocol = SeekView()
    public var replayButton = UIButton()
    public let srtControl = KSSubtitleController()
    public var isLock: Bool { false }
    open var isMaskShow = true {
        didSet {
            let alpha: CGFloat = isMaskShow && !isLock ? 1.0 : 0.0
            UIView.animate(withDuration: 0.3) {
                if self.isPlayed {
                    self.replayButton.alpha = self.isMaskShow ? 1.0 : 0.0
                }
                self.topMaskView.alpha = alpha
                self.bottomMaskView.alpha = alpha
                self.delegate?.playerController(maskShow: self.isMaskShow)
                self.layoutIfNeeded()
            }
            if isMaskShow {
                autoFadeOutViewWithAnimation()
            }
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUIComponents()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUIComponents()
    }

    // MARK: - Action Response

    override open func onButtonPressed(type: PlayerButtonType, button: UIButton) {
        autoFadeOutViewWithAnimation()
        super.onButtonPressed(type: type, button: button)
        if type == .srt {
            srtControl.view.isHidden = false
            isMaskShow = false
        } else if type == .rate {
            changePlaybackRate(button: button)
        } else if type == .definition {
            guard let resource = resource, resource.definitions.count > 1 else { return }
            let alertController = UIAlertController(title: NSLocalizedString("select video quality", comment: ""), message: nil, preferredStyle: preferredStyle())
            for (index, definition) in resource.definitions.enumerated() {
                let action = UIAlertAction(title: definition.definition, style: .default) { [weak self] _ in
                    guard let self = self, index != self.currentDefinition else { return }
                    self.change(definitionIndex: index)
                }
                action.setValue(index == currentDefinition, forKey: "checked")
                alertController.addAction(action)
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            viewController?.present(alertController, animated: true, completion: nil)
        }
    }

    open func changePlaybackRate(button: UIButton) {
        let alertController = UIAlertController(title: NSLocalizedString("select speed", comment: ""), message: nil, preferredStyle: preferredStyle())
        [0.75, 1.0, 1.25, 1.5, 2.0].forEach { rate in
            let title = "\(rate)X"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                button.setTitle(title, for: .normal)
                self.playerLayer.player?.playbackRate = Float(rate)
            }
            action.setValue(title == button.title, forKey: "checked")
            alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        viewController?.present(alertController, animated: true, completion: nil)
    }

    open func setupUIComponents() {
        addSubview(playerLayer)
        backgroundColor = .black
        setupSrtControl()
        #if os(macOS)
        topMaskView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.5).cgColor]
        #else
        topMaskView.gradientLayer.colors = [UIColor.black.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
        #endif
        bottomMaskView.gradientLayer.colors = topMaskView.gradientLayer.colors
        topMaskView.gradientLayer.startPoint = .zero
        topMaskView.gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        bottomMaskView.gradientLayer.startPoint = CGPoint(x: 0, y: 1)
        bottomMaskView.gradientLayer.endPoint = .zero

        loadingIndector.isHidden = true
        addSubview(loadingIndector)
        // Top views
        topMaskView.addSubview(navigationBar)
        navigationBar.addArrangedSubview(titleLabel)
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16)
        // Bottom views
        bottomMaskView.addSubview(toolBar)
        toolBar.timeSlider.delegate = self
        addSubview(seekToView)
        addSubview(replayButton)
        replayButton.cornerRadius = 32
        replayButton.titleFont = .systemFont(ofSize: 16)
        replayButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        replayButton.setImage(KSPlayerManager.image(named: "KSPlayer_play"), for: .normal)
        replayButton.setImage(KSPlayerManager.image(named: "KSPlayer_replay"), for: .selected)
        replayButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .primaryActionTriggered)
        replayButton.tag = PlayerButtonType.replay.rawValue
        addSubview(topMaskView)
        addSubview(bottomMaskView)
        addConstraint()
        customizeUIComponents()
        layoutIfNeeded()
    }

    /// Add Customize functions here
    open func customizeUIComponents() {
        tapGesture.addTarget(self, action: #selector(tapGestureAction(_:)))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)
        panGesture.addTarget(self, action: #selector(panGestureAction(_:)))
        addGestureRecognizer(panGesture)
        doubleTapGesture.addTarget(self, action: #selector(doubleTapGestureAction))
        doubleTapGesture.numberOfTapsRequired = 2
        tapGesture.require(toFail: doubleTapGesture)
        addGestureRecognizer(doubleTapGesture)
        #if os(tvOS)
        toolBar.isHidden = true
        toolBar.timeSlider.isHidden = true
        #endif
    }

    override open func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        guard !isSliderSliding else { return }
        super.player(layer: layer, currentTime: currentTime, totalTime: totalTime)
        if let subtitle = resource?.subtitle {
            showSubtile(from: subtitle, at: currentTime)
        } else {
            subtitleBackView.isHidden = true
        }
    }

    override open func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        switch state {
        case .readyToPlay:
            toolBar.timeSlider.isPlayable = true
            embedSubtitleDataSouce = layer.player?.subtitleDataSouce
        case .buffering:
            isPlayed = true
            replayButton.isHidden = true
            replayButton.isSelected = false
            showLoader()
        case .bufferFinished:
            isPlayed = true
            replayButton.isHidden = true
            replayButton.isSelected = false
            hideLoader()
            autoFadeOutViewWithAnimation()
        case .paused, .playedToTheEnd, .error:
            hideLoader()
            replayButton.isHidden = false
            seekToView.isHidden = true
            delayItem?.cancel()
            isMaskShow = true
            if state == .playedToTheEnd {
                replayButton.isSelected = true
            }
        default:
            break
        }
    }

    override open func resetPlayer() {
        super.resetPlayer()
        delayItem = nil
        resource = nil
        toolBar.reset()
        isMaskShow = false
        hideLoader()
        replayButton.isSelected = false
        replayButton.isHidden = false
        seekToView.isHidden = true
        isPlayed = false
        embedSubtitleDataSouce = nil
    }

    // MARK: - KSSliderDelegate

    override open func slider(value: Double, event: ControlEvents) {
        if event == .valueChanged {
            delayItem?.cancel()
        } else if event == .touchUpInside {
            autoFadeOutViewWithAnimation()
        }
        super.slider(value: value, event: event)
        if event == .touchDown {
            isSliderSliding = true
        } else if event == .touchUpInside {
            isSliderSliding = false
        }
    }

    open func change(definitionIndex: Int) {
        guard let resource = resource else { return }
        var shouldSeekTo = 0.0
        if playerLayer.state != .playedToTheEnd, let currentTime = playerLayer.player?.currentPlaybackTime {
            shouldSeekTo = currentTime
        }
        currentDefinition = definitionIndex >= resource.definitions.count ? resource.definitions.count - 1 : definitionIndex
        let asset = resource.definitions[currentDefinition]
        super.set(url: asset.url, options: asset.options)
        if shouldSeekTo > 0 {
            seek(time: shouldSeekTo)
        }
    }

    open func set(resource: KSPlayerResource, definitionIndex: Int = 0, isSetUrl: Bool = true) {
        self.resource = resource
        currentDefinition = definitionIndex >= resource.definitions.count ? resource.definitions.count - 1 : definitionIndex
        if isSetUrl {
            let asset = resource.definitions[currentDefinition]
            super.set(url: asset.url, options: asset.options)
        }
    }

    override open func set(url: URL, options: KSOptions) {
        set(resource: KSPlayerResource(url: url, options: options))
    }

    @objc open func doubleTapGestureAction() {
        toolBar.playButton.sendActions(for: .primaryActionTriggered)
        isMaskShow = true
    }

    @objc open func tapGestureAction(_: UITapGestureRecognizer) {
        if srtControl.view.isHidden {
            isMaskShow.toggle()
        } else {
            srtControl.view.isHidden = true
        }
    }

    open func panGestureBegan(location _: CGPoint, direction: KSPanDirection) {
        if direction == .horizontal {
            // 给tmpPanValue初值
            if totalTime > 0 {
                tmpPanValue = toolBar.timeSlider.value
            }
        }
    }

    open func panGestureChanged(velocity point: CGPoint, direction: KSPanDirection) {
        if direction == .horizontal {
            if !KSPlayerManager.enablePlaytimeGestures {
                return
            }
            isSliderSliding = true
            if totalTime > 0 {
                // 每次滑动需要叠加时间，通过一定的比例，使滑动一直处于统一水平
                tmpPanValue += max(min(Float(point.x) / 0x40000, 0.01), -0.01) * Float(totalTime)
                tmpPanValue = max(min(tmpPanValue, Float(totalTime)), 0)
                showSeekToView(second: Double(tmpPanValue), isAdd: point.x > 0)
            }
        }
    }

    open func panGestureEnded() {
        // 移动结束也需要判断垂直或者平移
        // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
        if scrollDirection == .horizontal, KSPlayerManager.enablePlaytimeGestures {
            hideSeekToView()
            isSliderSliding = false
            slider(value: Double(tmpPanValue), event: .touchUpInside)
            tmpPanValue = 0.0
        }
    }

    #if !os(macOS) && !targetEnvironment(macCatalyst)
    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let presse = presses.first else {
            return
        }
        switch presse.type {
        case .playPause:
            if playerLayer.state.isPlaying {
                pause()
            } else {
                play()
            }
        default: super.pressesBegan(presses, with: event)
        }
    }
    #endif
}

// MARK: - seekToView

extension VideoPlayerView {
    /**
     Call when User use the slide to seek function

     - parameter second:     target time
     - parameter isAdd:         isAdd
     */
    public func showSeekToView(second: TimeInterval, isAdd: Bool) {
        isMaskShow = true
        seekToView.isHidden = false
        toolBar.currentTime = second
        seekToView.set(text: second.toString(for: toolBar.timeType), isAdd: isAdd)
    }

    public func hideSeekToView() {
        seekToView.isHidden = true
    }
}

// MARK: - private functions

extension VideoPlayerView {
    @objc private func panGestureAction(_ pan: UIPanGestureRecognizer) {
        // 播放结束时，忽略手势,锁屏状态忽略手势
        guard !replayButton.isSelected, !isLock else { return }
        // 根据上次和本次移动的位置，算出一个速率的point
        let velocityPoint = pan.velocity(in: self)
        switch pan.state {
        case .began:
            // 使用绝对值来判断移动的方向
            if abs(velocityPoint.x) > abs(velocityPoint.y) {
                scrollDirection = .horizontal
            } else {
                scrollDirection = .vertical
            }
            panGestureBegan(location: pan.location(in: self), direction: scrollDirection)
        case .changed:
            panGestureChanged(velocity: velocityPoint, direction: scrollDirection)
        case .ended:
            panGestureEnded()
        default:
            break
        }
    }

    private func setupSrtControl() {
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleBackView.cornerRadius = 2
        subtitleBackView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        subtitleBackView.addSubview(subtitleLabel)
        subtitleBackView.isHidden = true
        addSubview(subtitleBackView)
        addSubview(srtControl.view)
        srtControl.view.isHidden = true
        srtControl.selectWithFilePath = { [weak self] result in
            guard let self = self else { return }
            self.resource?.subtitle = try? result.get()
        }
    }

    /**
     auto fade out controll view with animtion
     */
    private func autoFadeOutViewWithAnimation() {
        delayItem?.cancel()
        // 播放的时候才自动隐藏
        guard toolBar.playButton.isSelected else { return }
        delayItem = DispatchWorkItem { [weak self] in
            self?.isMaskShow = false
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + KSPlayerManager.animateDelayTimeInterval,
                                      execute: delayItem!)
    }

    private func showLoader() {
        loadingIndector.isHidden = false
        loadingIndector.startAnimating()
    }

    private func hideLoader() {
        loadingIndector.isHidden = true
        loadingIndector.stopAnimating()
    }

    private func showSubtile(from subtitle: KSSubtitleProtocol, at time: TimeInterval) {
        if let text = subtitle.search(for: time) {
            subtitleBackView.isHidden = false
            subtitleLabel.attributedText = text
        } else {
            subtitleBackView.isHidden = true
        }
    }

    private func addConstraint() {
        toolBar.playButton.tintColor = .white
        toolBar.playbackRateButton.tintColor = .white
        toolBar.definitionButton.tintColor = .white
        toolBar.timeSlider.setThumbImage(KSPlayerManager.image(named: "KSPlayer_slider_thumb"), for: .normal)
        toolBar.timeSlider.setThumbImage(KSPlayerManager.image(named: "KSPlayer_slider_thumb_pressed"), for: .highlighted)
        bottomMaskView.addSubview(toolBar.timeSlider)
        toolBar.spacing = 10
        toolBar.addArrangedSubview(toolBar.playButton)
        toolBar.addArrangedSubview(toolBar.timeLabel)
        toolBar.addArrangedSubview(toolBar.playbackRateButton)
        toolBar.addArrangedSubview(toolBar.definitionButton)
        toolBar.addArrangedSubview(toolBar.srtButton)
        if #available(iOS 11.0, tvOS 11.0, *) {
            toolBar.setCustomSpacing(20, after: toolBar.timeLabel)
            toolBar.setCustomSpacing(20, after: toolBar.playbackRateButton)
            toolBar.setCustomSpacing(20, after: toolBar.definitionButton)
        }
        toolBar.timeSlider.translatesAutoresizingMaskIntoConstraints = false
        topMaskView.translatesAutoresizingMaskIntoConstraints = false
        bottomMaskView.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingIndector.translatesAutoresizingMaskIntoConstraints = false
        seekToView.translatesAutoresizingMaskIntoConstraints = false
        replayButton.translatesAutoresizingMaskIntoConstraints = false
        subtitleBackView.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        playerLayer.translatesAutoresizingMaskIntoConstraints = false
        srtControl.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerLayer.topAnchor.constraint(equalTo: topAnchor),
            playerLayer.leftAnchor.constraint(equalTo: leftAnchor),
            playerLayer.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerLayer.rightAnchor.constraint(equalTo: rightAnchor),
            topMaskView.topAnchor.constraint(equalTo: topAnchor),
            topMaskView.leftAnchor.constraint(equalTo: leftAnchor),
            topMaskView.rightAnchor.constraint(equalTo: rightAnchor),
            topMaskView.heightAnchor.constraint(equalToConstant: 105),
            navigationBar.topAnchor.constraint(equalTo: topMaskView.topAnchor),
            navigationBar.leftAnchor.constraint(equalTo: topMaskView.safeLeftAnchor, constant: 15),
            navigationBar.rightAnchor.constraint(equalTo: topMaskView.safeRightAnchor, constant: -15),
            navigationBar.heightAnchor.constraint(equalToConstant: 44),
            bottomMaskView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomMaskView.leftAnchor.constraint(equalTo: leftAnchor),
            bottomMaskView.rightAnchor.constraint(equalTo: rightAnchor),
            bottomMaskView.heightAnchor.constraint(equalToConstant: 105),
            toolBar.bottomAnchor.constraint(equalTo: bottomMaskView.safeBottomAnchor),
            toolBar.leftAnchor.constraint(equalTo: bottomMaskView.safeLeftAnchor, constant: 10),
            toolBar.rightAnchor.constraint(equalTo: bottomMaskView.safeRightAnchor, constant: -15),
            toolBar.timeSlider.bottomAnchor.constraint(equalTo: toolBar.topAnchor),
            toolBar.timeSlider.leftAnchor.constraint(equalTo: bottomMaskView.safeLeftAnchor, constant: 15),
            toolBar.timeSlider.rightAnchor.constraint(equalTo: bottomMaskView.safeRightAnchor, constant: -15),
            toolBar.timeSlider.heightAnchor.constraint(equalToConstant: 30),
            loadingIndector.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingIndector.centerXAnchor.constraint(equalTo: centerXAnchor),
            seekToView.centerYAnchor.constraint(equalTo: centerYAnchor),
            seekToView.centerXAnchor.constraint(equalTo: centerXAnchor),
            seekToView.widthAnchor.constraint(equalToConstant: 100),
            seekToView.heightAnchor.constraint(equalToConstant: 40),
            replayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            replayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleBackView.bottomAnchor.constraint(equalTo: safeBottomAnchor, constant: -5),
            subtitleBackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleBackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -10),
            subtitleLabel.leftAnchor.constraint(equalTo: subtitleBackView.leftAnchor, constant: 10),
            subtitleLabel.rightAnchor.constraint(equalTo: subtitleBackView.rightAnchor, constant: -10),
            subtitleLabel.topAnchor.constraint(equalTo: subtitleBackView.topAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: subtitleBackView.bottomAnchor, constant: -2),
            srtControl.view.topAnchor.constraint(equalTo: topAnchor),
            srtControl.view.leftAnchor.constraint(equalTo: leftAnchor),
            srtControl.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            srtControl.view.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }

    private func preferredStyle() -> UIAlertController.Style {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone ? .actionSheet : .alert
        #else
        return .alert
        #endif
    }
}

public enum KSPlayerTopBarShowCase {
    /// 始终显示
    case always
    /// 只在横屏界面显示
    case horizantalOnly
    /// 不显示
    case none
}

extension KSPlayerManager {
    /// 顶部返回、标题、AirPlay按钮 显示选项，默认.Always，可选.HorizantalOnly、.None
    public static var topBarShowInCase = KSPlayerTopBarShowCase.always
    /// 自动隐藏操作栏的时间间隔 默认5秒
    public static var animateDelayTimeInterval = TimeInterval(5)
    /// 开启亮度手势 默认true
    public static var enableBrightnessGestures = true
    /// 开启音量手势 默认true
    public static var enableVolumeGestures = true
    /// 开启进度滑动手势 默认true
    public static var enablePlaytimeGestures = true
    /// 竖屏是否开启手势控制 默认false
    public static var enablePortraitGestures = false
    /// 播放内核选择策略 先使用firstPlayer，失败了自动切换到secondPlayer，播放内核有KSAVPlayer、KSMEPlayer两个选项
    /// 是否能后台播放视频
    public static var canBackgroundPlay = false

    public static var autoSelectEmbedSubtitle = true
}
