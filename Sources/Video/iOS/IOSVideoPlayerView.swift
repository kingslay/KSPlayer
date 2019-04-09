//
//  IOSVideoPlayerView.swift
//  Pods
//
//  Created by kintan on 2018/10/31.
//

import CoreTelephony
import MediaPlayer
import UIKit

open class IOSVideoPlayerView: VideoPlayerView {
    private lazy var callCenter = CTCallCenter()
    /// 滑动方向
    private var scrollDirection = KSPanDirection.horizontal
    private var tmpPanValue: Float = 0
    private var isVolume = false
    private var isSliderSliding = false
    public var volumeViewSlider = UXSlider()
    public var lockButton = UIButton()
    public var backButton = UIButton()
    public let tapGesture = UITapGestureRecognizer()
    public let doubleTapGesture = UITapGestureRecognizer()
    public var airplayStatusView: UIView = AirplayStatusView()
    @objc public var routeButton = MPVolumeView()
    /// Image view to show video cover
    @objc public var maskImageView = UIImageView()
    @objc public var landscapeButton = UIButton()
    /// Gesture used to show / hide control view
    @objc public let panGesture = UIPanGestureRecognizer()
    open override var isMaskShow: Bool {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.lockButton.alpha = self.isMaskShow ? 1.0 : 0.0
            }
        }
    }

    @objc public override var isLock: Bool {
        return lockButton.isSelected
    }

    open override func customizeUIComponents() {
        super.customizeUIComponents()
        if UI_USER_INTERFACE_IDIOM() == .phone {
            subtitleLabel.font = .systemFont(ofSize: 14)
        }
        srtControl.srtListCount.observer = { [weak self] _, count in
            guard let self = self, count > 0 else {
                return
            }
            if UIApplication.shared.statusBarOrientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad {
                self.toolBar.srtButton.isHidden = false
            }
        }
        insertSubview(maskImageView, at: 0)
        maskImageView.contentMode = .scaleAspectFit
        toolBar.addArrangedSubview(landscapeButton)
        landscapeButton.tag = PlayerButtonType.landscape.rawValue
        landscapeButton.setImage(image(named: "KSPlayer_fullscreen"), for: .normal)
        landscapeButton.setImage(image(named: "KSPlayer_portialscreen"), for: .selected)
        landscapeButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        tapGesture.addTarget(self, action: #selector(onTapGestureTapped(_:)))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)
        panGesture.addTarget(self, action: #selector(panDirection(_:)))
        panGesture.isEnabled = false
        addGestureRecognizer(panGesture)
        doubleTapGesture.addTarget(self, action: #selector(doubleGestureAction))
        doubleTapGesture.numberOfTapsRequired = 2
        tapGesture.require(toFail: doubleTapGesture)
        addGestureRecognizer(doubleTapGesture)
        backButton.tag = PlayerButtonType.back.rawValue
        backButton.setImage(image(named: "KSPlayer_back"), for: .normal)
        backButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        navigationBar.insertArrangedSubview(backButton, at: 0)
        lockButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        lockButton.cornerRadius = 32
        lockButton.setImage(image(named: "KSPlayer_unlocking"), for: .normal)
        lockButton.setImage(image(named: "KSPlayer_autoRotationLock"), for: .selected)
        lockButton.tag = PlayerButtonType.lock.rawValue
        lockButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        lockButton.isHidden = true
        addSubview(lockButton)
        routeButton.showsRouteButton = true
        routeButton.showsVolumeSlider = false
        routeButton.sizeToFit()
        routeButton.isHidden = true
        navigationBar.addArrangedSubview(routeButton)
        addSubview(airplayStatusView)
        let tmp = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 0, height: 0))
        UIApplication.shared.keyWindow?.addSubview(tmp)
        if let first = (tmp.subviews.first { $0 is UISlider } as? UISlider) {
            volumeViewSlider = first
        }
        routeButton.translatesAutoresizingMaskIntoConstraints = false
        lockButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        landscapeButton.translatesAutoresizingMaskIntoConstraints = false
        maskImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            maskImageView.topAnchor.constraint(equalTo: topAnchor),
            maskImageView.leftAnchor.constraint(equalTo: leftAnchor),
            maskImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            maskImageView.rightAnchor.constraint(equalTo: rightAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 25),
            lockButton.leftAnchor.constraint(equalTo: safeLeftAnchor, constant: 22),
            lockButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            routeButton.widthAnchor.constraint(equalToConstant: 25),
            landscapeButton.widthAnchor.constraint(equalToConstant: 30),
            srtControl.view.topAnchor.constraint(equalTo: topAnchor),
            srtControl.view.leftAnchor.constraint(equalTo: leftAnchor),
            srtControl.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            srtControl.view.rightAnchor.constraint(equalTo: rightAnchor),
            airplayStatusView.centerXAnchor.constraint(equalTo: centerXAnchor),
            airplayStatusView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        addNotification()
    }

    open override func resetPlayer() {
        super.resetPlayer()
        maskImageView.alpha = 1
        maskImageView.image = nil
        lockButton.isSelected = false
        panGesture.isEnabled = false
        routeButton.isHidden = !routeButton.areWirelessRoutesAvailable
    }

    open override func onButtonPressed(_ button: UIButton) {
        super.onButtonPressed(button)
        if let type = PlayerButtonType(rawValue: button.tag) {
            if type == .lock {
                button.isSelected.toggle()
                isMaskShow = !button.isSelected
                button.alpha = 1.0
            } else if type == .landscape {
                updateUI(isLandscape: !UIApplication.shared.statusBarOrientation.isLandscape)
            } else if type == .rate {
                changePlaybackRate(button: button)
            } else if type == .definition {
                guard let resource = resource, resource.definitions.count > 1 else { return }
                let alertController = UIAlertController(title: "选择画质", message: nil, preferredStyle: UI_USER_INTERFACE_IDIOM() == .phone ? .actionSheet : .alert)
                for (index, definition) in resource.definitions.enumerated() {
                    let action = UIAlertAction(title: definition.definition, style: .default) { [weak self] _ in
                        guard let self = self, index != self.currentDefinition else { return }
                        //                        self.maskImageView.alpha = 1
                        //                        self.maskImageView.image = self.delegate?.thumbnailImageAtCurrentTime?()
                        self.change(definitionIndex: index)
                    }
                    action.setValue(index == currentDefinition, forKey: "checked")
                    alertController.addAction(action)
                }
                alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                viewController?.present(alertController, animated: true, completion: nil)
            }
        }
        BrightnessVolume.shared.move(to: self)
    }

    open func updateUI(isLandscape: Bool) {
        landscapeButton.isSelected = isLandscape
        if isLandscape {
            topMaskView.isHidden = KSPlayerManager.topBarShowInCase == .none
        } else {
            topMaskView.isHidden = KSPlayerManager.topBarShowInCase != .always
        }
        toolBar.playbackRateButton.isHidden = false
        toolBar.srtButton.isHidden = srtControl.srtListCount.value == 0
        srtControl.view.isHidden = true
        if UIDevice.current.userInterfaceIdiom == .phone {
            if isLandscape {
                landscapeButton.isHidden = true
                toolBar.srtButton.isHidden = srtControl.srtListCount.value == 0
            } else {
                toolBar.srtButton.isHidden = true
                if let image = maskImageView.image {
                    landscapeButton.isHidden = image.size.width < image.size.height
                } else {
                    landscapeButton.isHidden = false
                }
            }
            toolBar.playbackRateButton.isHidden = !isLandscape
        } else {
            landscapeButton.isHidden = true
        }
        if UIApplication.shared.statusBarOrientation.isLandscape != isLandscape {
            UIDevice.current.setValue(UIDevice.current.orientation.rawValue, forKey: "orientation")
            UIDevice.current.setValue((isLandscape ? UIInterfaceOrientation.landscapeRight : UIInterfaceOrientation.portrait).rawValue, forKey: "orientation")
        }
        lockButton.isHidden = !isLandscape
        judgePanGesture()
    }

    open override func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        if state == .readyToPlay {
            UIView.animate(withDuration: 0.3) {
                self.maskImageView.alpha = 0.0
            }
        }
        judgePanGesture()
    }

    open override func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        airplayStatusView.isHidden = !(layer.player?.isExternalPlaybackActive ?? false)
        guard !isSliderSliding else { return }
        super.player(layer: layer, currentTime: currentTime, totalTime: totalTime)
    }

    open override func slider(value: Double, event: ControlEvents) {
        super.slider(value: value, event: event)
        if event == .touchDown {
            isSliderSliding = true
        } else if event == .touchUpInside {
            isSliderSliding = false
            judgePanGesture()
        }
    }

    open func changePlaybackRate(button: UIButton) {
        let alertController = UIAlertController(title: "选择倍速", message: nil, preferredStyle: UI_USER_INTERFACE_IDIOM() == .phone ? .actionSheet : .alert)
        [0.75, 1.0, 1.25, 1.5, 2.0].forEach { rate in
            let title = "\(rate)X"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                button.setTitle(title, for: .normal)
                self.playerLayer.player?.playbackRate = Float(rate)
            }
            action.setValue(title == button.titleLabel?.text, forKey: "checked")
            alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        viewController?.present(alertController, animated: true, completion: nil)
    }

    open override func set(resource: KSPlayerResource, definitionIndex: Int = 0, isSetUrl: Bool = true) {
        super.set(resource: resource, definitionIndex: definitionIndex, isSetUrl: isSetUrl)
        maskImageView.image(url: resource.cover)
    }

    @objc open func doubleGestureAction() {
        toolBar.playButton.sendActions(for: .touchUpInside)
        isMaskShow = true
    }
}

// MARK: - private functions

extension IOSVideoPlayerView {
    private func addNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
        orientationChanged()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routesAvailableDidChange), name: .MPVolumeViewWirelessRoutesAvailableDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(wirelessRouteActiveDidChange(notification:)), name: .MPVolumeViewWirelessRouteActiveDidChange, object: nil)

        #if !targetEnvironment(simulator)
        var isplay = false
        callCenter.callEventHandler = { [weak self] call in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if call.callState == CTCallStateIncoming {
                    isplay = self.playerLayer.state.isPlaying
                    if isplay {
                        self.pause()
                    }
                } else if call.callState == CTCallStateDisconnected {
                    if isplay {
                        self.play()
                    }
                }
            }
        }
        #endif
    }

    @objc private func routesAvailableDidChange(notification _: Notification) {
        routeButton.isHidden = !routeButton.areWirelessRoutesAvailable
    }

    @objc private func wirelessRouteActiveDidChange(notification: Notification) {
        guard let volumeView = notification.object as? MPVolumeView, playerLayer.isWirelessRouteActive != volumeView.isWirelessRouteActive else { return }
        if volumeView.isWirelessRouteActive {
            if useProxyUrl || !(playerLayer.player?.allowsExternalPlayback ?? false) {
                playerLayer.isWirelessRouteActive = true
                useProxyUrl = false
            }
            playerLayer.player?.usesExternalPlaybackWhileExternalScreenIsActive = true
        }
        playerLayer.isWirelessRouteActive = volumeView.isWirelessRouteActive
    }

    @objc private func applicationDidEnterBackground() {
        if KSPlayerManager.canBackgroundPlay {
            return
        }
        if playerLayer.player?.isExternalPlaybackActive ?? false {
            return
        }
        pause()
    }

    @objc private func orientationChanged() {
        updateUI(isLandscape: UIApplication.shared.statusBarOrientation.isLandscape)
    }

    @objc private func onTapGestureTapped(_: UITapGestureRecognizer) {
        isMaskShow = !isMaskShow
    }

    @objc private func panDirection(_ pan: UIPanGestureRecognizer) {
        // 播放结束时，忽略手势,锁屏状态忽略手势
        guard !replayButton.isSelected, !isLock else { return }
        // 根据上次和本次移动的位置，算出一个速率的point
        let velocityPoint = pan.velocity(in: self)
        switch pan.state {
        case .began:
            // 使用绝对值来判断移动的方向
            if abs(velocityPoint.x) > abs(velocityPoint.y) {
                scrollDirection = .horizontal
                // 给tmpPanValue初值
                if totalTime > 0 {
                    tmpPanValue = toolBar.timeSlider.value
                }
            } else {
                scrollDirection = .vertical
                if pan.location(in: self).x > bounds.size.width / 2 {
                    isVolume = true
                    tmpPanValue = volumeViewSlider.value
                } else {
                    isVolume = false
                }
            }

        case .changed:
            switch scrollDirection {
            case .horizontal:
                horizontalMoved(velocityPoint.x)
            case .vertical:
                verticalMoved(velocityPoint.y)
            }

        case .ended:
            gestureEnd()
        default:
            break
        }
    }

    private func verticalMoved(_ value: CGFloat) {
        if isVolume {
            if KSPlayerManager.enableVolumeGestures {
                tmpPanValue -= Float(value) / 0x2800
                tmpPanValue = max(min(tmpPanValue, 1), 0)
                volumeViewSlider.value = tmpPanValue
            }
        } else if KSPlayerManager.enableBrightnessGestures {
            UIScreen.main.brightness -= value / 0x2800
        }
    }

    private func horizontalMoved(_ value: CGFloat) {
        if !KSPlayerManager.enablePlaytimeGestures {
            return
        }
        isSliderSliding = true
        if totalTime > 0 {
            // 每次滑动需要叠加时间，通过一定的比例，使滑动一直处于统一水平
            tmpPanValue += max(min(Float(value) / 0x40000, 0.01), -0.01) * Float(totalTime)
            tmpPanValue = max(min(tmpPanValue, Float(totalTime)), 0)
            showSeekToView(second: Double(tmpPanValue), isAdd: value > 0)
        }
    }

    private func gestureEnd() {
        // 移动结束也需要判断垂直或者平移
        // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
        switch scrollDirection {
        case .horizontal:
            if KSPlayerManager.enablePlaytimeGestures {
                hideSeekToView()
                isSliderSliding = false
                slider(value: Double(tmpPanValue), event: .touchUpInside)
                tmpPanValue = 0.0
            }
        case .vertical:
            isVolume = false
        }
    }

    private func judgePanGesture() {
        if UIApplication.shared.statusBarOrientation.isLandscape {
            panGesture.isEnabled = isPlayed && !replayButton.isSelected
        } else {
            if KSPlayerManager.enablePortraitGestures {
                panGesture.isEnabled = toolBar.playButton.isSelected
            } else {
                panGesture.isEnabled = false
            }
        }
    }
}

public class AirplayStatusView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        let airplayicon = UIImageView(image: image(named: "airplayicon_play"))
        addSubview(airplayicon)
        let airplaymessage = UILabel()
        airplaymessage.backgroundColor = .clear
        airplaymessage.textColor = .white
        airplaymessage.font = .systemFont(ofSize: 14)
        airplaymessage.text = NSLocalizedString("AirPlay 投放中", comment: "")
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
            airplaymessage.leftAnchor.constraint(equalTo: leftAnchor),
            airplaymessage.rightAnchor.constraint(equalTo: rightAnchor),
            airplaymessage.heightAnchor.constraint(equalToConstant: 15),
        ])
        isHidden = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
