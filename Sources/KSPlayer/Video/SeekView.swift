//
//  SeekView.swift
//  KSPlayer-iOS
//
//  Created by kintan on 2018/11/14.
//
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
public protocol SeekViewProtocol {
    func set(text: String, isAdd: Bool)
}

class SeekView: UIView {
    private let seekToViewImage = UIImageView()
    private let seekToLabel = UILabel()
    override public init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(seekToViewImage)
        addSubview(seekToLabel)
        seekToLabel.font = .systemFont(ofSize: 13)
        seekToLabel.textColor = UIColor(red: 0.9098, green: 0.9098, blue: 0.9098, alpha: 1.0)
        backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.7)
        cornerRadius = 4
        clipsToBounds = true
        isHidden = true
        seekToViewImage.image = KSPlayerManager.image(named: "KSPlayer_seek_to_image")
        translatesAutoresizingMaskIntoConstraints = false
        seekToViewImage.translatesAutoresizingMaskIntoConstraints = false
        seekToLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            seekToViewImage.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            seekToViewImage.centerYAnchor.constraint(equalTo: centerYAnchor),
            seekToViewImage.widthAnchor.constraint(equalToConstant: 25),
            seekToViewImage.heightAnchor.constraint(equalToConstant: 15),
            seekToLabel.leadingAnchor.constraint(equalTo: seekToViewImage.trailingAnchor, constant: 10),
            seekToLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SeekView: SeekViewProtocol {
    public func set(text: String, isAdd: Bool) {
        seekToLabel.text = text
        if !isAdd {
            seekToViewImage.backingLayer?.position = CGPoint(x: seekToViewImage.backingLayer!.frame.midX, y: seekToViewImage.backingLayer!.frame.midY)
            seekToViewImage.backingLayer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        seekToViewImage.centerRotate(byDegrees: isAdd ? 0.0 : 180)
    }
}
