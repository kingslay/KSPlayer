//
//  PositionViews.swift
//  KSPlayer
//
//  Created by Alanko5 on 02/02/2021.
//

import UIKit

@available(tvOS 13.0, *)
final class CurrentPositionView: UIView {
    private var currentPositionIndicator: UIView = UIView()
    private var currentTimeLabel: UILabel = UILabel()
    private var bufferingIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .medium)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init() {
        super.init(frame: .zero)
        self.configureView()
    }
    
    func set(currentTime:String) {
        self.currentTimeLabel.text = currentTime
    }
    
    func show(buffering:Bool) {
        if buffering {
            self.bufferingIndicator.startAnimating()
        } else {
            self.bufferingIndicator.stopAnimating()
        }
    }
    
    private func configureView() {
        self.addSubview(self.currentPositionIndicator)
        self.addSubview(self.currentTimeLabel)
        self.addSubview(self.bufferingIndicator)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.currentPositionIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.bufferingIndicator.translatesAutoresizingMaskIntoConstraints = false

        self.currentPositionIndicator.heightAnchor.constraint(equalToConstant: 10).isActive = true
        self.currentPositionIndicator.widthAnchor.constraint(equalToConstant: 2).isActive = true
        self.currentPositionIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.currentPositionIndicator.topAnchor.constraint(equalTo: self.topAnchor, constant: 10).isActive = true
        
        self.currentTimeLabel.topAnchor.constraint(equalTo: self.currentPositionIndicator.bottomAnchor, constant: 10).isActive = true
        self.currentTimeLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        self.currentTimeLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.currentTimeLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        
        self.bufferingIndicator.leftAnchor.constraint(equalTo: self.currentTimeLabel.rightAnchor, constant: 10).isActive = true
        self.bufferingIndicator.centerYAnchor.constraint(equalTo: self.currentTimeLabel.centerYAnchor).isActive = true
        
        self.currentTimeLabel.textColor = .label
        self.currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        self.currentPositionIndicator.backgroundColor = .label
        self.bufferingIndicator.hidesWhenStopped = true
    }
}

@available(tvOS 13.0, *)
final class SeekPositionView: UIView {
    private var positionIndicator: UIView = UIView()
    private var timeLabel: UILabel = UILabel()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init() {
        super.init(frame: .zero)
        self.configureView()
    }
    
    func set(currentTime:String) {
        self.timeLabel.text = currentTime
    }
    
    private func configureView() {
        self.addSubview(self.positionIndicator)
        self.addSubview(self.timeLabel)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.positionIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.timeLabel.translatesAutoresizingMaskIntoConstraints = false

        self.timeLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
        self.timeLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        self.timeLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.timeLabel.bottomAnchor.constraint(equalTo: self.positionIndicator.topAnchor, constant: -8).isActive = true
        
        self.positionIndicator.heightAnchor.constraint(equalToConstant: 15).isActive = true
        self.positionIndicator.widthAnchor.constraint(equalToConstant: 2).isActive = true
        self.positionIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.positionIndicator.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
        
        self.timeLabel.textColor = .label
        self.timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        self.positionIndicator.backgroundColor = .label
    }
}
