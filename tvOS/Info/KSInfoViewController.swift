//
//  KSInfoViewController.swift
//  KSPlayer-iOS
//
//  Created by Alanko5 on 03/03/2021.
//

import Foundation

@available(tvOS 13.0, *)
final class KSInfoViewController: InfoController {
    private var coverImage: UIImageView = UIImageView()
    private var titleLabel: UILabel = UILabel()
    private var descLabel: UILabel = UILabel()
    private var stackView: UIStackView = UIStackView()
    
    
    override func configureView() {
        super.configureView()
        self.setupContoller()
        
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.descLabel)
        self.contentView.addSubview(self.stackView)
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        self.titleLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        self.titleLabel.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -40).isActive = true
        self.titleLabel.heightAnchor.constraint(equalToConstant: 28).isActive = true
        self.titleLabel.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 600).isActive = true
        
        self.stackView.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 4).isActive = true
        self.stackView.leftAnchor.constraint(equalTo: self.titleLabel.leftAnchor).isActive = true
        self.stackView.rightAnchor.constraint(lessThanOrEqualTo: self.titleLabel.rightAnchor).isActive = true
        self.stackView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        self.stackView.axis = .horizontal
        
        self.descLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 4).isActive = true
        self.descLabel.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -40).isActive = true
        self.descLabel.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 600).isActive = true
        self.descLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -20).isActive = true
        self.descLabel.numberOfLines = 0
        self.testStings()
        
        self.configureColors()
    }
    
    private func setupContoller() {
        self.title = "Info"
    }
    
    private func configureColors() {
        self.titleLabel.textColor = .darkGray
        self.titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        
        self.descLabel.textColor = .darkGray
        self.descLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
    }
    
    private func getLabel(with text:String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .darkGray
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        return label
    }
    
    private func testStings() {
        self.titleLabel.text = "Lorem ipsum dolor sit amet"
        self.descLabel.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam at mattis urna, ac efficitur ligula. Sed viverra eu turpis quis aliquet. In sed est scelerisque, ultricies leo pulvinar, mollis lacus. In egestas placerat elementum. In placerat tincidunt leo, vel porta leo tincidunt nec. Integer volutpat commodo risus, ut hendrerit erat feugiat sit amet. Mauris dictum sodales fringilla. Aliquam elementum augue sed tortor faucibus vestibulum. Ut tellus diam, dapibus at nibh eget, vehicula eleifend lacus. Interdum et malesuada fames ac ante ipsum primis in faucibus. Ut porttitor et enim vitae malesuada. Nulla sollicitudin fermentum lobortis."
        
        self.stackView.addArrangedSubview(self.getLabel(with: "15 min"))
        self.stackView.setCustomSpacing(8, after: self.stackView.arrangedSubviews.last!)
        self.stackView.addArrangedSubview(self.getLabel(with: "Comedy"))
        self.stackView.setCustomSpacing(8, after: self.stackView.arrangedSubviews.last!)
        self.stackView.addArrangedSubview(self.getLabel(with: "4K"))
        self.stackView.setCustomSpacing(8, after: self.stackView.arrangedSubviews.last!)
    }
    
    public func setInfoPanel(_ data:KSInfoPanelData) {
        
    }
}
