//
//  TVOSViewController.swift
//  KSPlayer
//
//  Created by Alanko5 on 01/02/2021.
//

import UIKit
import AVFoundation

public enum KSPlayerMediaQuality {
    case qSd
    case qHd
    case fullHD
    case ultraHD
}

public struct KSPlayerMediaInfo {
    let title: String
    let description: String?
    let imageUrl: URL?
    let duration: String?
    let quality: KSPlayerMediaQuality?
}

@available(tvOS 13.0, *)
final public class KSPlayerViewController: UIViewController {
    private(set) var playerView: TVPlayerView = TVPlayerView()
    private let progressBar: ProgressToolBarView = ProgressToolBarView()
    private let progressContainer: UIView = UIView()
    private var infoController: KSPanelViewController = KSPanelViewController()
    private let infoControllerContainer: UIView = UIView()

    private var isPlaying: Bool {
        get {
            return self.playerView.playerLayer.player?.isPlaying ?? false
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
        self.addGestures()
        self.view.backgroundColor = .black
        self.navigationController?.navigationBar.isHidden = true
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.playerView.delegate = self
        self.play()
    }

    public override var preferredUserInterfaceStyle: UIUserInterfaceStyle {
        return .dark
    }
    
    deinit {
        print("Deinit")
    }

    // MARK: - Private methods
    private func configureView() {
        self.view.addSubview(self.playerView)
        self.playerView.translatesAutoresizingMaskIntoConstraints = true

        self.playerView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.playerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        self.playerView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.playerView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        
        self.playerView.toolBar.isHidden = true
        self.playerView.toolBar.timeSlider.isHidden = true
    }
    
    private func play() {
        self.progressBar.isSeekable = self.playerView.playerLayer.player?.seekable ?? false
        
        self.playerView.play()
        self.progressBar(show: false)
    }
    
    private func playOrSeek() {
        if self.progressBar.selectedTime != self.progressBar.currentTime {
            self.playerView.seek(time: self.progressBar.selectedTime)
        } else {
            self.playerView.play()
        }
        
        self.progressBar(show: false)
    }
    
    private func pause() {
        self.playerView.pause()
    }
    
    private func stop() {
        self.playerView.resetPlayer()
        DispatchQueue.main.async { [weak self] in
            if self?.navigationController != nil {
                self?.navigationController?.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true, completion: nil)
            }

            self?.playerView.delegate = nil
        }
    }
    
    private func showBuffering() {
        self.progressBar.show(buffering: true)
    }
    
    private func endBuffering() {
        self.progressBar.show(buffering: false)
    }
    
    private func paused() {
        self.progressBar(show: true)
    }
    
    private func error() {
        
    }
    
    private func playNextMovie() {
        
    }
    
    private func progressBar(show: Bool) {
        if show {
            self.view.addSubview(self.progressBar.view)
            self.addChild(self.progressBar)
            self.progressBar.didMove(toParent: self)
            self.progressBar.updateViews()
        } else {
            self.progressBar.willMove(toParent: nil)
            self.progressBar.removeFromParent()
            self.progressBar.view.removeFromSuperview()
        }
    }
}

//MARK: - KS PlayerControllerDelegate
@available(tvOS 13.0, *)
extension KSPlayerViewController: PlayerControllerDelegate {
    public func playerController(state: KSPlayerState) {
        switch state {
        case .notSetURL:
            self.stop()
        case .readyToPlay:
            self.play()
        case .buffering:
            self.showBuffering()
        case .bufferFinished:
            self.endBuffering()
        case .paused:
            self.paused()
        case .playedToTheEnd:
            self.playNextMovie()
        case .error:
            self.error()
        }
    }
    
    public func playerController(currentTime: TimeInterval, totalTime: TimeInterval) {
        self.progressBar.update(currentTime: currentTime, totalTime: totalTime)
    }
    
    public func playerController(finish error: Error?) {
        
    }
    
    public func playerController(maskShow: Bool) {
        
    }
    
    public func playerController(action: PlayerButtonType) {
        
    }
    
    public func playerController(bufferedCount: Int, consumeTime: TimeInterval) {
        
    }
}

//MARK: - button actions
@available(tvOS 13.0, *)
extension KSPlayerViewController  {
    private func addGestures() {
        self.removeGestures()
        KSLog("KSPlayerViewController addGestures")
        let menuPressRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.menuPressed))
        menuPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.view.addGestureRecognizer(menuPressRecognizer)
        
        let playPausePressRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPausePressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(playPausePressRecognizer)
        
        let selectPressRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectPressed))
        selectPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        self.view.addGestureRecognizer(selectPressRecognizer)
        
        let selectDownRecognizer = UITapGestureRecognizer(target: self, action: #selector(swipedDown(_:)))
        selectDownRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.downArrow.rawValue)]
        self.view.addGestureRecognizer(selectDownRecognizer)
        
        let selectUpRecognizer = UITapGestureRecognizer(target: self, action: #selector(swipedUp(_:)))
        selectUpRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.upArrow.rawValue)]
        self.view.addGestureRecognizer(selectUpRecognizer)
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedUp(_:)) )
        swipeUpRecognizer.direction = .up
        self.view.addGestureRecognizer(swipeUpRecognizer)
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown(_:)) )
        swipeDownRecognizer.direction = .down
        self.view.addGestureRecognizer(swipeDownRecognizer)
//        self.playerView.isUserInteractionEnabled = true
        self.view.isUserInteractionEnabled = true
    }
    
    private func removeGestures() {
        KSLog("KSPlayerViewController removeGestures")
        var views: [UIView] = self.view.subviews
        views.append(self.view)
        for subview in views {
            for gesture in subview.gestureRecognizers ?? [] {
                subview.removeGestureRecognizer(gesture)
            }
        }
    }
    
    @objc func swipedUp(_ gesture: UIGestureRecognizer) {
        KSLog("KSPlayerViewController swipedUp")
        self.dismiss(oldController: self.infoController, animation: true)
    }
    
    @objc func swipedDown(_ gesture: UIGestureRecognizer) {
        KSLog("KSPlayerViewController swipedDown")
        self.infoController.start(with: self.playerView)
        self.infoController.view.backgroundColor = .clear
        self.infoController.modalTransitionStyle = .crossDissolve
        self.infoController.modalPresentationStyle = .overCurrentContext
        self.present(self.infoController, animated: true, completion: nil)
    }
    
    @objc func menuPressed() {
        if self.isPlaying {
            self.stop()
        } else {
            self.play()
        }
    }
    
    @objc func playPausePressed() {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }
    
    @objc func selectPressed() {
        if self.isPlaying {
            self.pause()
        } else {
            self.playOrSeek()
        }
    }
}

//MARK: - controller public methods
@available(tvOS 13.0, *)
extension KSPlayerViewController {

    public func set(_ media: KSPlayerResource, preferedAudioLangCode: String? = nil) {
        self.playerView.set(resource: media)
    }
    
    public func set(_ mediaInfo:KSPlayerMediaInfo) {
        
    }
    
    public func setSrt(size:Float? = nil, color:UIColor = .white) {
        
    }
    
}

// MARK: - add remove vontroller
@available(tvOS 13.0, *)
extension KSPlayerViewController {
    private func present(newContrller:UIViewController, animation:Bool) {
        newContrller.willMove(toParent: self)
        self.view.addSubview(newContrller.view)
        self.addChild(newContrller)
        newContrller.didMove(toParent: self)
        self.removeGestures()
    }

    private func dismiss(oldController:UIViewController, animation:Bool) {
        oldController.willMove(toParent: nil)
        oldController.view.removeFromSuperview()
        oldController.removeFromParent()
        oldController.didMove(toParent: nil)
        self.addGestures()
    }
}
