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
enum KSPanDirection {
    case horizontal
    case vertical
}

open class VideoPlayerView: PlayerView {
    private var delayItem: DispatchWorkItem?
    private var bottomMaskView = LayerContainerView()
    private(set) var topMaskView = LayerContainerView()
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
                    if let first = infos.first {
                        srtControl.view.selectedInfo.value = first
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

    /// 是否使用代理url播放。
    var useProxyUrl: Bool {
        get {
            guard let resource = resource, currentDefinition < resource.definitions.count else {
                return false
            }
            let asset = resource.definitions[currentDefinition]
            return playerLayer.url == asset.proxyUrl
        }
        set {
            guard let resource = resource, currentDefinition < resource.definitions.count else {
                return
            }
            let asset = resource.definitions[currentDefinition]
            var url = asset.url
            if newValue, !playerLayer.isWirelessRouteActive, let proxyUrl = asset.proxyUrl {
                url = proxyUrl
            }
            playerLayer.set(url: url, options: asset.options)
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

    public var isLock: Bool {
        return false
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUIComponents()
        addConstraint()
        customizeUIComponents()
        layoutIfNeeded()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUIComponents()
        addConstraint()
        customizeUIComponents()
        layoutIfNeeded()
    }

    // MARK: - Action Response

    @objc open override func onButtonPressed(_ button: UIButton) {
        autoFadeOutViewWithAnimation()
        super.onButtonPressed(button)
        if button.tag == PlayerButtonType.srt.rawValue {
            srtControl.view.isHidden = false
            isMaskShow = false
        }
    }

    /// Add Customize functions here
    open func customizeUIComponents() {}

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
        replayButton.setImage(image(named: "KSPlayer_play"), for: .normal)
        replayButton.setImage(image(named: "KSPlayer_replay"), for: .selected)
        replayButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        replayButton.tag = PlayerButtonType.replay.rawValue
        addSubview(topMaskView)
        addSubview(bottomMaskView)
    }

    open override func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        super.player(layer: layer, currentTime: currentTime, totalTime: totalTime)
        if let subtitle = resource?.subtitle {
            showSubtile(from: subtitle, at: currentTime)
        } else {
            subtitleBackView.isHidden = true
        }
    }

    open override func player(layer: KSPlayerLayer, state: KSPlayerState) {
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

    open override func resetPlayer() {
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

    open override func slider(value: Double, event: ControlEvents) {
        if event == .valueChanged {
            delayItem?.cancel()
        } else if event == .touchUpInside {
            autoFadeOutViewWithAnimation()
        }
        super.slider(value: value, event: event)
    }

    open override func player(layer: KSPlayerLayer, finish error: Error?) {
        if let error = error as NSError?, error.domain == "FFmpeg", useProxyUrl {
            useProxyUrl = false
            play()
            return
        }
        super.player(layer: layer, finish: error)
    }

    open func change(definitionIndex: Int) {
        guard let resource = resource else { return }
        var shouldSeekTo = 0.0
        if playerLayer.state != .playedToTheEnd, let currentTime = playerLayer.player?.currentPlaybackTime {
            shouldSeekTo = currentTime
        }
        currentDefinition = definitionIndex >= resource.definitions.count ? resource.definitions.count - 1 : definitionIndex
        useProxyUrl = true
        if shouldSeekTo > 0 {
            seek(time: shouldSeekTo)
        }
    }

    open override func set(url: URL, options: [String: Any]? = nil) {
        set(resource: KSPlayerResource(url: url, options: options))
    }

    open func set(resource: KSPlayerResource, definitionIndex: Int = 0, isSetUrl: Bool = true) {
        self.resource = resource
        currentDefinition = definitionIndex >= resource.definitions.count ? resource.definitions.count - 1 : definitionIndex
        if isSetUrl {
            useProxyUrl = true
        }
    }
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
        srtControl.view.translatesAutoresizingMaskIntoConstraints = false
        srtControl.selectWithFilePath = { [weak self] subtitle, _ in
            guard let self = self else { return }
            self.resource?.subtitle = subtitle
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
        toolBar.timeSlider.setThumbImage(image(named: "KSPlayer_slider_thumb"), for: .normal)
        toolBar.timeSlider.setThumbImage(image(named: "KSPlayer_slider_thumb_pressed"), for: .highlighted)
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
        ])
    }
}
