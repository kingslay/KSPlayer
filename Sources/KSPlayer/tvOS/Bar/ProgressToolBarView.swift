//
//  ProgressToolBarView.swift
//  KSPlayer
//
//  Created by Alanko5 on 02/02/2021.
//

import UIKit

//MARK: - Movie progress view
@available(tvOS 13.0, *)
final class ProgressToolBarView: UIViewController {
    var isSeekable:Bool = false
    
    private let progressView: UIProgressView = UIProgressView()
    private let elapsedToEndLabel: UILabel = UILabel()
    
    private let currentPosition: CurrentPositionView = CurrentPositionView()
    private var leftConstraint: NSLayoutConstraint?
    private(set) var currentTime: TimeInterval = 0
    private var totalTime: TimeInterval = 0
    
    //Seek
    private let seekPosition: SeekPositionView = SeekPositionView()
    private var leftSeekConstraint: NSLayoutConstraint?
    private(set) var selectedTime: TimeInterval = 0
    private let surfaceTouchScreenFactor: CGFloat = 1 / 8
    private var lastTranslation: CGFloat = 0.0
    private let numberOfFrames: CGFloat = 100
    private var decelerateTimer: Timer?
    
    private var test:[UITapGestureRecognizer] = []
    
    private var isShowed: Bool = true
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.progressView.progress = 0
        self.preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: 300)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.isShowed = true
        self.updateViews()
        self.seekPosition.set(currentTime: "00:00")
        self.configureSwipeGestures()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.isShowed = false
    }
    
    override var preferredUserInterfaceStyle: UIUserInterfaceStyle {
        return .dark
    }
    
    func update(currentTime: TimeInterval, totalTime: TimeInterval) {
        self.totalTime = totalTime
        self.currentTime = currentTime
        self.selectedTime = currentTime
        
        self.updateViews()
    }
    
    func show(buffering:Bool) {
        self.currentPosition.show(buffering: buffering)
    }
    
    private let proressOffset:CGFloat = 80
    private func configureView() {
        self.view.addSubview(self.progressView)
        self.view.addSubview(self.currentPosition)
        self.view.addSubview(self.elapsedToEndLabel)
        self.view.addSubview(self.seekPosition)
        
        self.progressView.translatesAutoresizingMaskIntoConstraints = false
        self.currentPosition.translatesAutoresizingMaskIntoConstraints = false
        self.elapsedToEndLabel.translatesAutoresizingMaskIntoConstraints = false
        self.seekPosition.translatesAutoresizingMaskIntoConstraints = false
        
        self.progressView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -80).isActive = true
        self.progressView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 0 - self.proressOffset).isActive = true
        self.progressView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: self.proressOffset).isActive = true
        
        self.elapsedToEndLabel.topAnchor.constraint(equalTo: self.progressView.bottomAnchor, constant: 10).isActive = true
        self.elapsedToEndLabel.centerXAnchor.constraint(equalTo: self.progressView.rightAnchor).isActive = true
        self.elapsedToEndLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        self.elapsedToEndLabel.textColor = .label
        self.elapsedToEndLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        
        self.currentPosition.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -50).isActive = true
        self.leftConstraint = self.currentPosition.centerXAnchor.constraint(equalTo: self.progressView.leftAnchor, constant: 0)
        self.leftConstraint?.isActive = true
        
        self.seekPosition.bottomAnchor.constraint(equalTo: self.progressView.bottomAnchor, constant: 0).isActive = true
        self.leftSeekConstraint = self.seekPosition.centerXAnchor.constraint(equalTo: self.progressView.leftAnchor, constant: 0)
        self.leftSeekConstraint?.isActive = true
    }
    
    func updateViews() {
        if self.isShowed, self.totalTime != 0 {
            let timeString = self.currentTime.toString(for: .minOrHour)
            self.currentPosition.set(currentTime:timeString)
            self.seekPosition.set(currentTime: timeString)
            let elapsedTime = self.totalTime - self.currentTime
            self.elapsedToEndLabel.text = elapsedTime.toString(for: .minOrHour)
            let progress = self.currentTime/self.totalTime
            self.progressView.setProgress(Float(progress), animated: false)
            
            let progressWidth = self.view.frame.size.width - (self.proressOffset*2)
            let centerPosition = Double(progressWidth) * progress

            if progress != 0 {
                self.leftConstraint?.constant = CGFloat(centerPosition)
                self.leftSeekConstraint?.constant = CGFloat(centerPosition)
            }
        }
    }
}

// MARK: - seek gestures
@available(tvOS 13.0, *)
extension ProgressToolBarView {
    private func configureSwipeGestures() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.view.addGestureRecognizer(gesture)
    }

    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        self.decelerateTimer?.invalidate()
        switch gesture.state {
        case .cancelled:
            self.selectedTime = self.currentTime
            fallthrough
        case .ended:
            let velocity = gesture.velocity(in: nil)
            let factor = abs(velocity.x / self.progressView.bounds.width * surfaceTouchScreenFactor)
            self.moveByDeceleratingPosition(by: factor * lastTranslation * surfaceTouchScreenFactor)
            self.lastTranslation = 0.0

        case .began, .changed:
            let translation = gesture.translation(in: nil)
            self.movePosition(to: (self.leftSeekConstraint?.constant ?? 0) + (translation.x - lastTranslation) * surfaceTouchScreenFactor)
            self.lastTranslation = translation.x

        default:
            return
        }
    }

    private func moveByDeceleratingPosition(by translation: CGFloat) {
        if abs(translation) > 1 {
            var frame: CGFloat = 0

            guard let startPosition = self.leftSeekConstraint?.constant else { return }
            self.decelerateTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { (_: Timer) in
                let position = easeOut(time: frame,
                                       change: translation,
                                       startPosition: startPosition,
                                       duration: self.numberOfFrames)
                frame += 1
                self.movePosition(to: position)

                if frame > self.numberOfFrames {
                    self.decelerateTimer?.invalidate()
                }
            }
        }
    }
    
    private func movePosition(to position: CGFloat) {
        var newPosition = position
        if newPosition < 0 {
            newPosition = 0
        } else if newPosition > self.progressView.bounds.width {
            newPosition = self.progressView.bounds.width
        }

        let time = totalTime * Double(newPosition / self.progressView.bounds.width)
        self.selectedTime = time
        self.leftSeekConstraint?.constant = CGFloat(newPosition)
        self.seekPosition.set(currentTime: self.selectedTime.toString(for: .minOrHour))
    }
}

// MARK: EaseOut function
func easeOut(time: CGFloat, change: CGFloat, startPosition: CGFloat, duration: CGFloat) -> CGFloat {
    var currentTime: CGFloat = time / duration
    currentTime -= 1
    return change * (currentTime*currentTime*currentTime + 1) + startPosition
}
