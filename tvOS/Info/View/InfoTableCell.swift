//
//  InfoTableCell.swift
//  KSPlayer-iOS
//
//  Created by Alanko5 on 03/03/2021.
//

import UIKit

@available(tvOS 13.0, *)
final class InfoTableCell: UITableViewCell {
    private let titleLabel: UILabel = UILabel()
    private let checkMarkImage: UIImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configureViews()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.configureViews()
    }
    
    func set(title:String, isSelected:Bool) {
        self.titleLabel.text = title
        self.checkMarkImage.isHidden = !isSelected
        self.isSelected = isSelected
        self.updateFont()
    }
    
    private func configureViews() {
        self.addSubview(self.titleLabel)
        self.titleLabel.frame = self.frame
        self.titleLabel.textColor = .darkGray
        self.titleLabel.font = UIFont.systemFont(ofSize: 31, weight: .regular)
        
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.titleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.titleLabel.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        
        self.addSubview(self.checkMarkImage)
        self.checkMarkImage.translatesAutoresizingMaskIntoConstraints = false
        self.checkMarkImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.checkMarkImage.rightAnchor.constraint(equalTo: self.titleLabel.leftAnchor).isActive = true
        self.checkMarkImage.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        self.checkMarkImage.widthAnchor.constraint(equalToConstant: 30).isActive = true
        self.checkMarkImage.heightAnchor.constraint(equalToConstant: 30).isActive = true
        self.checkMarkImage.image = UIImage(systemName: "checkmark")
        self.checkMarkImage.tintColor = .darkGray
    }
    
    private func updateFont() {
        if self.isSelected {
            self.titleLabel.font = UIFont.systemFont(ofSize: 31, weight: .semibold)
        } else {
            self.titleLabel.font = UIFont.systemFont(ofSize: 31, weight: .regular)
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.titleLabel.textColor = .white
                self.checkMarkImage.tintColor = .white
                self.contentView.backgroundColor = .clear
                self.backgroundColor = .clear
            }, completion: nil)
        }
        else {
            coordinator.addCoordinatedAnimations({
                self.titleLabel.textColor = .darkGray
                self.checkMarkImage.tintColor = .darkGray
                self.updateFont()
            }, completion: nil)
        }
    }
}
