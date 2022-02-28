//
//  KSAudioInfoViewController.swift
//  KSPlayer-tvOS
//
//  Created by Alanko5 on 02/03/2021.
//

import UIKit
import AVKit

@available(tvOS 13.0, *)
final class KSAudioInfoViewController: InfoController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for subview in self.contentView.arrangedSubviews {
            contentView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        self.showAudioSounds()
        self.showAudioTracks()
    }
    
    override func configureView() {
        super.configureView()
        self.title = "Audio"
        
    }
    
    func showAirplay() {
        let routePickerView = AVRoutePickerView(frame: CGRect(x: 200, y: 200, width: 100, height: 100))
        routePickerView.routePickerButtonStyle = .custom
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.delegate = self
        self.view.addSubview(routePickerView)
        
    }
    
    private var playerSupportLoundSounds: Bool {
        get {
            return self.player?.isKSMEPlayer ?? false
        }
    }
}

@available(tvOS 13.0, *)
extension KSAudioInfoViewController {
    private func showAudioTracks() {
        guard let player = self.player?.playerLayer.player else { return }

        let tracks = player.tracks(mediaType: .audio)
        let audioPicker = InfoTableView(items: tracks, with: "Audio") { (cell, value) in
            cell.set(title: value.title, isSelected: value.isEnabled)
        } selectHandler: { [weak self] (newValue) in
            self?.player?.playerLayer.player?.select(track: newValue)
        }
        let preferedConstant = audioPicker.tableViewWidth(for: tracks.map({ $0.title }))
        self.contentView.addArrangedSubview(audioPicker)
        self.setConstrains(for: audioPicker, with: preferedConstant)
    }
    
    private func showAudioSounds() {
        guard let player = self.player, player.isKSMEPlayer else { return }
        let options = SoundOptions.allCases
        
        let soundOptionSelect = InfoTableView(items: options, with: "Sound") { [weak self] (cell, value) in
            guard let self = self, let player = self.player else { return }
            cell.set(title: value.title, isSelected: player.soundOptions == value)
        } selectHandler: { [weak self] (newValue) in
            self?.player?.soundOptions = newValue
        }
        let preferedConstant = soundOptionSelect.tableViewWidth(for: options.map({ $0.title }))
        self.contentView.addArrangedSubview(soundOptionSelect)
        self.setConstrains(for: soundOptionSelect, with: preferedConstant)
    }
}

@available(tvOS 13.0, *)
extension KSAudioInfoViewController: AVRoutePickerViewDelegate {
    func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        print(routePickerView)
    }
    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        print(routePickerView)
    }
}


extension MediaPlayerTrack {
    var title:String {
        let codecName = self.codecType.string.uppercased().trimmingCharacters(in: .whitespaces)
        return self.name + "[ \(self.language ?? "") - \(codecName) ]"
    }
}
