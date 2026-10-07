//
//  VideoPlayerView.swift
//  Pods
//
//  Created by kintan on 16/4/29.
//
//
import AVKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import Combine
import KSPlayer
import MediaPlayer

/// internal enum to check the pan direction
public enum KSPanDirection {
    case horizontal
    case vertical
}

public protocol LoadingIndector {
    @MainActor
    func startAnimating()
    @MainActor
    func stopAnimating()
}

#if canImport(UIKit)
extension UIActivityIndicatorView: LoadingIndector {}
#endif
// swiftlint:disable type_body_length file_length
open class VideoPlayerView: PlayerView {
    private var delayItem: Task<Void, Error>?
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
    private var cancellables = [AnyCancellable]()
    public private(set) var currentDefinition = 0 {
        didSet {
            if let resource {
                toolBar.definitionButton.setTitle(resource.definitions[currentDefinition].definition, for: .normal)
            }
        }
    }

    public private(set) var resource: KSPlayerResource? {
        didSet {
            if let resource, oldValue != resource {
                if let subtitleDataSource = resource.subtitleDataSource {
                    playerLayer?.subtitleModel.addSubtitle(dataSource: subtitleDataSource)
                }
                toolBar.definitionButton.isHidden = resource.definitions.count < 2
                if #available(iOS 14.0, tvOS 15.0, *) {
                    #if !os(tvOS)
                    toolBar.definitionButton.setMenu(title: NSLocalizedString("video quality", bundle: .module, comment: ""), current: resource.definitions[currentDefinition], list: resource.definitions) { value in
                        value.definition
                    } completion: { [weak self] value in
                        guard let self else { return }
                        if let value, let index = self.resource?.definitions.firstIndex(of: value) {
                            change(definitionIndex: index)
                        }
                    }
                    #if os(iOS)
                    toolBar.definitionButton.showsMenuAsPrimaryAction = true
                    #endif
                    #endif
                }
                isMaskShow = true
                MPNowPlayingInfoCenter.default().nowPlayingInfo = resource.nowPlayingInfo?.nowPlayingInfo
            }
        }
    }

    public let contentOverlayView = UIView()
    public let controllerView = UIView()
    /// Activty Indector for loading
    public var loadingIndector: UIView & LoadingIndector = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
    public var seekToView: UIView & SeekViewProtocol = SeekView()
    public var replayButton = UIButton()
    public var lockButton = UIButton()
    public var isLock: Bool {
        lockButton.isSelected
    }

    open var isMaskShow = true {
        didSet {
            let alpha: CGFloat = isMaskShow && !isLock ? 1.0 : 0.0
            UIView.animate(withDuration: 0.3) {
                if self.isPlayed {
                    self.replayButton.alpha = self.isMaskShow ? 1.0 : 0.0
                }
                self.lockButton.alpha = self.isMaskShow ? 1.0 : 0.0
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

    override public var playerLayer: KSPlayerLayer? {
        didSet {
            oldValue?.player.view.removeFromSuperview()
            if let playerLayer {
                let view = playerLayer.player.view
                #if canImport(UIKit)
                insertSubview(view, belowSubview: contentOverlayView)
                #else
                addSubview(view, positioned: .below, relativeTo: contentOverlayView)
                #endif
                view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    view.topAnchor.constraint(equalTo: topAnchor),
                    view.leadingAnchor.constraint(equalTo: leadingAnchor),
                    view.bottomAnchor.constraint(equalTo: bottomAnchor),
                    view.trailingAnchor.constraint(equalTo: trailingAnchor),
                ])
            }
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUIComponents()
        toolBar.onFocusUpdate = { [weak self] _ in
            self?.autoFadeOutViewWithAnimation()
        }
    }

    // MARK: - Action Response

    override open func onButtonPressed(type: PlayerButtonType, button: UIButton) {
        autoFadeOutViewWithAnimation()
        super.onButtonPressed(type: type, button: button)
        if type == .pictureInPicture {
            if #available(tvOS 14.0, *) {
                if let playerLayer = playerLayer as? KSComplexPlayerLayer {
                    if playerLayer.isPictureInPictureActive {
                        playerLayer.pipStop(restoreUserInterface: true)
                        button.isSelected = false
                    } else {
                        playerLayer.pipStart()
                        button.isSelected = true
                    }
                }
            }
        }
        #if os(tvOS)
        if type == .srt {
            changeSrt(button: button)
        } else if type == .rate {
            changePlaybackRate(button: button)
        } else if type == .definition {
            changeDefinitions(button: button)
        } else if type == .audioSwitch || type == .videoSwitch {
            changeAudioVideo(type, button: button)
        }
        #elseif os(macOS)
//        if let menu = button.menu, let event = NSApplication.shared.currentEvent {
//            NSMenu.popUpContextMenu(menu, with: event, for: button)
//        }
        #endif
    }

    // MARK: - setup UI

    open func setupUIComponents() {
        addSubview(contentOverlayView)
        addSubview(controllerView)
        #if os(macOS)
        topMaskView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.5).cgColor]
        #else
        topMaskView.gradientLayer.colors = [UIColor.black.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
        #endif
        bottomMaskView.gradientLayer.colors = topMaskView.gradientLayer.colors
        topMaskView.isHidden = KSOptions.topBarShowInCase != .always
        topMaskView.gradientLayer.startPoint = .zero
        topMaskView.gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        bottomMaskView.gradientLayer.startPoint = CGPoint(x: 0, y: 1)
        bottomMaskView.gradientLayer.endPoint = .zero

        loadingIndector.isHidden = true
        controllerView.addSubview(loadingIndector)
        // Top views
        // Bottom views
        bottomMaskView.addSubview(toolBar)
        toolBar.timeSlider.delegate = self
        controllerView.addSubview(seekToView)
        controllerView.addSubview(replayButton)
        replayButton.cornerRadius = 32
        replayButton.titleFont = .systemFont(ofSize: 16)
        replayButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        replayButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .primaryActionTriggered)
        replayButton.tag = PlayerButtonType.replay.rawValue
        lockButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        lockButton.cornerRadius = 32
        lockButton.tag = PlayerButtonType.lock.rawValue
        lockButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .primaryActionTriggered)
        lockButton.isHidden = true
        if #available(macOS 11.0, *) {
            replayButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            replayButton.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .selected)
            lockButton.setImage(UIImage(systemName: "lock.open"), for: .normal)
            lockButton.setImage(UIImage(systemName: "lock"), for: .selected)
        }
        lockButton.tintColor = .white
        replayButton.tintColor = .white
        controllerView.addSubview(lockButton)
        controllerView.addSubview(topMaskView)
        controllerView.addSubview(bottomMaskView)
        addConstraint()
        customizeUIComponents()
        layoutIfNeeded()
    }

    /// Add Customize functions here
    open func customizeUIComponents() {
        tapGesture.addTarget(self, action: #selector(tapGestureAction(_:)))
        tapGesture.numberOfTapsRequired = 1
        controllerView.addGestureRecognizer(tapGesture)
        panGesture.addTarget(self, action: #selector(panGestureAction(_:)))
        controllerView.addGestureRecognizer(panGesture)
        panGesture.isEnabled = false
        doubleTapGesture.addTarget(self, action: #selector(doubleTapGestureAction))
        doubleTapGesture.numberOfTapsRequired = 2
        tapGesture.require(toFail: doubleTapGesture)
        controllerView.addGestureRecognizer(doubleTapGesture)
        #if canImport(UIKit)
        addRemoteControllerGestures()
        #endif
    }

    override open func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        guard !isSliderSliding else { return }
        super.player(layer: layer, currentTime: currentTime, totalTime: totalTime)
    }

    override open func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        switch state {
        case .readyToPlay:
            toolBar.videoSwitchButton.isHidden = layer.player.tracks(mediaType: .video).count < 2
            toolBar.audioSwitchButton.isHidden = layer.player.tracks(mediaType: .audio).count < 2
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
        case .initialized, .preparing:
            break
        }
    }

    override open func resetPlayer() {
        super.resetPlayer()
        delayItem = nil
        toolBar.reset()
        isMaskShow = false
        hideLoader()
        replayButton.isSelected = false
        replayButton.isHidden = false
        seekToView.isHidden = true
        isPlayed = false
        lockButton.isSelected = false
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
        guard let resource else { return }
        var shouldSeekTo = 0.0
        if let playerLayer, playerLayer.state != .playedToTheEnd {
            shouldSeekTo = playerLayer.player.currentPlaybackTime
        }
        currentDefinition = definitionIndex >= resource.definitions.count ? resource.definitions.count - 1 : definitionIndex
        let asset = resource.definitions[currentDefinition]
        asset.options.startPlayTime = shouldSeekTo
        super.set(url: asset.url, options: asset.options)
    }

    open func set(resource: KSPlayerResource, definitionIndex: Int = 0, isSetUrl: Bool = true) {
        currentDefinition = definitionIndex >= resource.definitions.count ? resource.definitions.count - 1 : definitionIndex
        if isSetUrl {
            let asset = resource.definitions[currentDefinition]
            super.set(url: asset.url, options: asset.options)
        }
        self.resource = resource
    }

    override open func set(url: URL, options: KSOptions) {
        set(resource: KSPlayerResource(url: url, options: options))
    }

    @objc open func doubleTapGestureAction() {
        toolBar.playButton.sendActions(for: .primaryActionTriggered)
        isMaskShow = true
    }

    @objc open func tapGestureAction(_: UITapGestureRecognizer) {
        isMaskShow.toggle()
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
            if !KSOptions.enablePlaytimeGestures {
                return
            }
            isSliderSliding = true
            if totalTime > 0 {
                // 每次滑动需要叠加时间，通过一定的比例，使滑动一直处于统一水平
                tmpPanValue += panValue(velocity: point, direction: direction, currentTime: Float(toolBar.currentTime), totalTime: Float(totalTime))
                tmpPanValue = max(min(tmpPanValue, Float(totalTime)), 0)
                showSeekToView(second: Double(tmpPanValue), isAdd: point.x > 0)
            }
        }
    }

    open func panValue(velocity point: CGPoint, direction: KSPanDirection, currentTime _: Float, totalTime: Float) -> Float {
        if direction == .horizontal {
            return max(min(Float(point.x) / 0x40000, 0.01), -0.01) * totalTime
        } else {
            return -Float(point.y) / 0x2800
        }
    }

    open func panGestureEnded() {
        // 移动结束也需要判断垂直或者平移
        // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
        if scrollDirection == .horizontal, KSOptions.enablePlaytimeGestures {
            hideSeekToView()
            isSliderSliding = false
            slider(value: Double(tmpPanValue), event: .touchUpInside)
            tmpPanValue = 0.0
        }
    }
}

// MARK: - playback rate, definitions, audio and video tracks change

public extension VideoPlayerView {
    private func changeAudioVideo(_ type: PlayerButtonType, button _: UIButton) {
        guard let tracks = playerLayer?.player.tracks(mediaType: type == .audioSwitch ? .audio : .video) else {
            return
        }
        let alertController = UIAlertController(
            title: type == .audioSwitch ? NSLocalizedString("switch audio", bundle: .module, comment: "") : NSLocalizedString("switch video", bundle: .module, comment: ""),
            message: nil,
            preferredStyle: preferredStyle()
        )
        for track in tracks {
            let isEnabled = track.isEnabled
            var title = track.name
            if type == .videoSwitch {
                title += " \(track.naturalSize.width)x\(track.naturalSize.height)"
            }
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self, !isEnabled else { return }
                playerLayer?.player.select(track: track)
            }
            alertController.addAction(action)
            if isEnabled {
                alertController.preferredAction = action
                action.setValue(isEnabled, forKey: "checked")
            }
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", bundle: .module, comment: ""), style: .cancel, handler: nil))
        viewController?.present(alertController, animated: true, completion: nil)
    }

    private func changeDefinitions(button _: UIButton) {
        guard let resource, resource.definitions.count > 1 else { return }
        let alertController = UIAlertController(title: NSLocalizedString("select video quality", bundle: .module, comment: ""), message: nil, preferredStyle: preferredStyle())
        for (index, definition) in resource.definitions.enumerated() {
            let action = UIAlertAction(title: definition.definition, style: .default) { [weak self] _ in
                guard let self, index != currentDefinition else { return }
                change(definitionIndex: index)
            }
            alertController.addAction(action)
            if index == currentDefinition {
                alertController.preferredAction = action
                action.setValue(true, forKey: "checked")
            }
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", bundle: .module, comment: ""), style: .cancel, handler: nil))
        viewController?.present(alertController, animated: true, completion: nil)
    }

    private func changeSrt(button _: UIButton) {
        guard let srtControl = playerLayer?.subtitleModel else {
            return
        }
        let availableSubtitles = srtControl.subtitleInfos
        guard !availableSubtitles.isEmpty else { return }
        let alertController = UIAlertController(title: NSLocalizedString("subtitle", bundle: .module, comment: ""),
                                                message: nil,
                                                preferredStyle: preferredStyle())

        let currentSub = srtControl.selectedSubtitleInfo
        let disableAction = UIAlertAction(title: NSLocalizedString("Disabled", bundle: .module, comment: ""), style: .default) { [weak self] _ in
            self?.playerLayer?.select(subtitleInfo: nil)
        }
        alertController.addAction(disableAction)
        if currentSub == nil {
            alertController.preferredAction = disableAction
            disableAction.setValue(true, forKey: "checked")
        }
        for (_, srt) in availableSubtitles.enumerated() {
            let action = UIAlertAction(title: srt.name, style: .default) { [weak self] _ in
                self?.playerLayer?.select(subtitleInfo: srt)
            }
            alertController.addAction(action)
            if currentSub?.subtitleID == srt.subtitleID {
                alertController.preferredAction = action
                action.setValue(true, forKey: "checked")
            }
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", bundle: .module, comment: ""), style: .cancel, handler: nil))
        viewController?.present(alertController, animated: true, completion: nil)
    }

    private func changePlaybackRate(button: UIButton) {
        let alertController = UIAlertController(title: NSLocalizedString("select speed", bundle: .module, comment: ""), message: nil, preferredStyle: preferredStyle())
        for rate in [0.75, 1.0, 1.25, 1.5, 2.0] {
            let title = "\(rate) x"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                button.setTitle(title, for: .normal)
                playerLayer?.player.playbackRate = Float(rate)
            }
            alertController.addAction(action)

            if Float(rate) == playerLayer?.player.playbackRate {
                alertController.preferredAction = action
                action.setValue(true, forKey: "checked")
            }
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", bundle: .module, comment: ""), style: .cancel, handler: nil))
        viewController?.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - seekToView

public extension VideoPlayerView {
    /**
     Call when User use the slide to seek function

     - parameter second:     target time
     - parameter isAdd:         isAdd
     */
    func showSeekToView(second: TimeInterval, isAdd: Bool) {
        isMaskShow = true
        seekToView.isHidden = false
        toolBar.currentTime = second
        seekToView.set(text: second.toString(for: toolBar.timeType), isAdd: isAdd)
    }

    func hideSeekToView() {
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

    /**
     auto fade out controll view with animtion
     */
    private func autoFadeOutViewWithAnimation() {
        delayItem?.cancel()
        // 播放的时候才自动隐藏
        guard toolBar.playButton.isSelected else { return }
        delayItem = Task { @MainActor [weak self] in
            try await Task.sleep(nanoseconds: UInt64(KSOptions.animateDelayTimeInterval * 1_000_000_000.0))
            guard let self else { return }
            if playerLayer?.state == .bufferFinished {
                isMaskShow = false
            }
        }
    }

    private func showLoader() {
        loadingIndector.isHidden = false
        loadingIndector.startAnimating()
    }

    private func hideLoader() {
        loadingIndector.isHidden = true
        loadingIndector.stopAnimating()
    }

    private func addConstraint() {
        if #available(macOS 11.0, *) {
            #if !targetEnvironment(macCatalyst)
            toolBar.timeSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
            #if os(macOS)
            toolBar.timeSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .highlighted)
            #else
            toolBar.timeSlider.setThumbImage(UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .highlighted)
            #endif
            #endif
        }
        bottomMaskView.addSubview(toolBar.timeSlider)
        toolBar.audioSwitchButton.isHidden = true
        toolBar.videoSwitchButton.isHidden = true
        toolBar.pipButton.isHidden = true
        contentOverlayView.translatesAutoresizingMaskIntoConstraints = false
        controllerView.translatesAutoresizingMaskIntoConstraints = false
        toolBar.timeSlider.translatesAutoresizingMaskIntoConstraints = false
        topMaskView.translatesAutoresizingMaskIntoConstraints = false
        bottomMaskView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndector.translatesAutoresizingMaskIntoConstraints = false
        seekToView.translatesAutoresizingMaskIntoConstraints = false
        replayButton.translatesAutoresizingMaskIntoConstraints = false
        lockButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentOverlayView.topAnchor.constraint(equalTo: topAnchor),
            contentOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            controllerView.topAnchor.constraint(equalTo: topAnchor),
            controllerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            controllerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            controllerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topMaskView.topAnchor.constraint(equalTo: topAnchor),
            topMaskView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topMaskView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topMaskView.heightAnchor.constraint(equalToConstant: 105),
            bottomMaskView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomMaskView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomMaskView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomMaskView.heightAnchor.constraint(equalToConstant: 105),
            loadingIndector.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingIndector.centerXAnchor.constraint(equalTo: centerXAnchor),
            seekToView.centerYAnchor.constraint(equalTo: centerYAnchor),
            seekToView.centerXAnchor.constraint(equalTo: centerXAnchor),
            seekToView.widthAnchor.constraint(equalToConstant: 100),
            seekToView.heightAnchor.constraint(equalToConstant: 40),
            replayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            replayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            lockButton.leadingAnchor.constraint(equalTo: safeLeadingAnchor, constant: 22),
            lockButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        configureToolBarConstraints()
    }

    private func configureToolBarConstraints() {
        #if os(tvOS)
        toolBar.spacing = 10
        toolBar.addArrangedSubview(toolBar.playButton)
        toolBar.addArrangedSubview(toolBar.timeLabel)
        toolBar.addArrangedSubview(toolBar.playbackRateButton)
        toolBar.addArrangedSubview(toolBar.definitionButton)
        toolBar.addArrangedSubview(toolBar.audioSwitchButton)
        toolBar.addArrangedSubview(toolBar.videoSwitchButton)
        toolBar.addArrangedSubview(toolBar.srtButton)
        toolBar.addArrangedSubview(toolBar.pipButton)

        toolBar.setCustomSpacing(20, after: toolBar.timeLabel)
        toolBar.setCustomSpacing(20, after: toolBar.playbackRateButton)
        toolBar.setCustomSpacing(20, after: toolBar.definitionButton)
        toolBar.setCustomSpacing(20, after: toolBar.srtButton)

        NSLayoutConstraint.activate([
            toolBar.bottomAnchor.constraint(equalTo: bottomMaskView.safeBottomAnchor),
            toolBar.leadingAnchor.constraint(equalTo: bottomMaskView.safeLeadingAnchor, constant: 10),
            toolBar.trailingAnchor.constraint(equalTo: bottomMaskView.safeTrailingAnchor, constant: -15),
            toolBar.timeSlider.bottomAnchor.constraint(equalTo: toolBar.topAnchor, constant: -8),
            toolBar.timeSlider.leadingAnchor.constraint(equalTo: bottomMaskView.safeLeadingAnchor, constant: 15),
            toolBar.timeSlider.trailingAnchor.constraint(equalTo: bottomMaskView.safeTrailingAnchor, constant: -15),
            toolBar.timeSlider.heightAnchor.constraint(equalToConstant: 16),
        ])

        #else

        toolBar.playButton.tintColor = .white
        toolBar.playbackRateButton.tintColor = .white
        toolBar.definitionButton.tintColor = .white
        toolBar.audioSwitchButton.tintColor = .white
        toolBar.videoSwitchButton.tintColor = .white
        toolBar.srtButton.tintColor = .white
        toolBar.pipButton.tintColor = .white

        toolBar.spacing = 10
        toolBar.addArrangedSubview(toolBar.playButton)
        toolBar.addArrangedSubview(toolBar.timeLabel)
        toolBar.addArrangedSubview(toolBar.playbackRateButton)
        toolBar.addArrangedSubview(toolBar.definitionButton)
        toolBar.addArrangedSubview(toolBar.audioSwitchButton)
        toolBar.addArrangedSubview(toolBar.videoSwitchButton)
        toolBar.addArrangedSubview(toolBar.srtButton)
        toolBar.addArrangedSubview(toolBar.pipButton)

        toolBar.setCustomSpacing(20, after: toolBar.timeLabel)
        toolBar.setCustomSpacing(20, after: toolBar.playbackRateButton)
        toolBar.setCustomSpacing(20, after: toolBar.definitionButton)
        toolBar.setCustomSpacing(20, after: toolBar.srtButton)

        NSLayoutConstraint.activate([
            toolBar.bottomAnchor.constraint(equalTo: bottomMaskView.safeBottomAnchor),
            toolBar.leadingAnchor.constraint(equalTo: bottomMaskView.safeLeadingAnchor, constant: 10),
            toolBar.trailingAnchor.constraint(equalTo: bottomMaskView.safeTrailingAnchor, constant: -15),
            toolBar.timeSlider.bottomAnchor.constraint(equalTo: toolBar.topAnchor),
            toolBar.timeSlider.leadingAnchor.constraint(equalTo: bottomMaskView.safeLeadingAnchor, constant: 15),
            toolBar.timeSlider.trailingAnchor.constraint(equalTo: bottomMaskView.safeTrailingAnchor, constant: -15),
            toolBar.timeSlider.heightAnchor.constraint(equalToConstant: 30),
        ])
        #endif
    }

    private func preferredStyle() -> UIAlertController.Style {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone ? .actionSheet : .alert
        #else
        return .alert
        #endif
    }

    #if canImport(UIKit)
    private func addRemoteControllerGestures() {
        let rightPressRecognizer = UITapGestureRecognizer()
        rightPressRecognizer.addTarget(self, action: #selector(rightArrowButtonPressed(_:)))
        rightPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        addGestureRecognizer(rightPressRecognizer)

        let leftPressRecognizer = UITapGestureRecognizer()
        leftPressRecognizer.addTarget(self, action: #selector(leftArrowButtonPressed(_:)))
        leftPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        addGestureRecognizer(leftPressRecognizer)

        let selectPressRecognizer = UITapGestureRecognizer()
        selectPressRecognizer.addTarget(self, action: #selector(selectButtonPressed(_:)))
        selectPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        addGestureRecognizer(selectPressRecognizer)

        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedUp(_:)))
        swipeUpRecognizer.direction = .up
        addGestureRecognizer(swipeUpRecognizer)

        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown(_:)))
        swipeDownRecognizer.direction = .down
        addGestureRecognizer(swipeDownRecognizer)
    }

    @objc
    private func rightArrowButtonPressed(_: UITapGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying, toolBar.isSeekable else { return }
        playerLayer.seek(time: toolBar.currentTime + 15)
    }

    @objc
    private func leftArrowButtonPressed(_: UITapGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying, toolBar.isSeekable else { return }
        playerLayer.seek(time: toolBar.currentTime - 15)
    }

    @objc
    private func selectButtonPressed(_: UITapGestureRecognizer) {
        guard toolBar.isSeekable else { return }
        if let playerLayer, playerLayer.state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    @objc
    private func swipedUp(_: UISwipeGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying else { return }
        if isMaskShow == false {
            isMaskShow = true
        }
    }

    @objc
    private func swipedDown(_: UISwipeGestureRecognizer) {
        guard let playerLayer, playerLayer.state.isPlaying else { return }
        if isMaskShow == true {
            isMaskShow = false
        }
    }
    #endif
}

public enum KSPlayerTopBarShowCase {
    /// 始终显示
    case always
    /// 只在横屏界面显示
    case horizantalOnly
    /// 不显示
    case none
}

import KSPlayer

public extension KSOptions {
    /// 顶部返回、标题、AirPlay按钮 显示选项，默认.Always，可选.HorizantalOnly、.None
    @MainActor
    static var topBarShowInCase = KSPlayerTopBarShowCase.always
    /// 自动隐藏操作栏的时间间隔 默认5秒
    @MainActor
    static var animateDelayTimeInterval = TimeInterval(5)
    /// 开启亮度手势 默认true
    @MainActor
    static var enableBrightnessGestures = true
    /// 开启音量手势 默认true
    @MainActor
    static var enableVolumeGestures = true
    /// 开启进度滑动手势 默认true
    @MainActor
    static var enablePlaytimeGestures = true
}
