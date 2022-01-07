//
//  KSPanelViewController.swift
//  KSPlayer
//
//  Created by Alanko5 on 02/02/2021.
//

import UIKit
import AVKit

struct KSInfoPanelData {
    var title: String?
    var description: String?
    var duration: String?
    var resolution: String?
    var generes: [String]
    var posterImage: UIImage?
}
@available(tvOS 13.0, *)
class InfoController: UIViewController {
    var heightConstraint: NSLayoutConstraint?
    var contentView: UIStackView = UIStackView()
    var player: TVPlayerView?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.configureView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.configureView()
    }
    
    open func configureView() {
        self.view.addSubview(self.contentView)
        self.contentView.translatesAutoresizingMaskIntoConstraints = false

        self.contentView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 150).isActive = true
        self.contentView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        self.heightConstraint = self.contentView.heightAnchor.constraint(equalToConstant: 290)
        self.heightConstraint?.isActive = true
    }
    
    func setConstrains(for view:UIView, with width:CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = true
        view.heightAnchor.constraint(equalTo: self.contentView.heightAnchor).isActive = true
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        view.translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - infoViewController
@available(tvOS 13.0, *)
final class KSPanelViewController: UITabBarController {
    private var contentView: UIView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    private var separator: UIView = UIView()
    private var heightConstraint: NSLayoutConstraint?
    
    var player:TVPlayerView?

    override var preferredUserInterfaceStyle: UIUserInterfaceStyle {
        return .light
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func start(with player:TVPlayerView?) {
        self.player = player
        var controllers:[UIViewController] = []
        let infoController = KSInfoViewController()
        infoController.player = self.player
        controllers.append(infoController)
        
        let audioController = KSAudioInfoViewController()
        audioController.player = self.player
        controllers.append(audioController)
        
        if self.player?.srtControl.filterInfos({ _ in true }).count ?? 0 > 0 {
            let strController = KSSrtViewController()
            strController.player = self.player
            controllers.append(strController)
        }
        
        let videoControll = KSVideoViewController()
        videoControll.player = self.player
        controllers.append(videoControll)
        
        self.setViewControllers(controllers, animated: false)
        self.configureTabBarController()
    }

    private func configureTabBarController() {
        let appearance = self.tabBar.standardAppearance.copy()
        appearance.backgroundImage = UIImage()
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear
        appearance.backgroundEffect = nil
        self.tabBar.standardAppearance = appearance
        
        self.view.backgroundColor = .clear
        
        self.delegate = self
    }
    
    private func configureView() {
        self.view.addSubview(self.contentView)
        self.view.sendSubviewToBack(self.contentView)
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.contentView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 20).isActive = true
        self.contentView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -80).isActive = true
        self.contentView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 80).isActive = true

        self.heightConstraint = self.contentView.heightAnchor.constraint(equalToConstant: 440)
        
        self.heightConstraint?.isActive = true
        
        self.contentView.layer.cornerRadius = 32
        self.contentView.clipsToBounds = true
        
        self.view.addSubview(self.separator)
        self.separator.translatesAutoresizingMaskIntoConstraints = false
        
        self.separator.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 140).isActive = true
        self.separator.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -140).isActive = true
        self.separator.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 140).isActive = true
        self.separator.heightAnchor.constraint(equalToConstant: 2).isActive = true
        self.separator.backgroundColor = UIColor.separator
    }
}

@available(tvOS 13.0, *)
extension KSPanelViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
//        if let viewController = viewController as? InfoController, viewController.contentView.frame.height != 0 {
//            UIView.animate(withDuration: 0.5) {
//                self.heightConstraint?.constant = viewController.contentView.frame.height
//            }
//        }
    }
    
    
}
