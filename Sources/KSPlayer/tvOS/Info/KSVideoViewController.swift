//
//  KSVideoViewController.swift
//  KSPlayer-iOS
//
//  Created by Alanko5 on 03/03/2021.
//

import UIKit

@available(tvOS 13.0, *)
final class KSVideoViewController: InfoController {
    
    override func configureView() {
        super.configureView()
        self.title = "Video"
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for subview in self.contentView.arrangedSubviews {
            self.contentView.removeArrangedSubview(subview)
        }
        
        self.addPlaybacSpeed()
        self.addDefinitionsView()
    }

    private func addPlaybacSpeed() {
        let options: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75]
        let rateSelector = InfoTableView(items: options, with: "speed") { [weak self] (cell, value) in
            let currentRate = self?.player?.playerLayer.player?.playbackRate ?? 1.0
            cell.set(title: "\(value)", isSelected: currentRate == value)
        } selectHandler: { [weak self] (newValue) in
            self?.player?.playerLayer.player?.playbackRate = newValue
        }

        self.contentView.addArrangedSubview(rateSelector)
        let preferedConstant = rateSelector.tableViewWidth(for: options.map({ "\($0)" }))
        self.setConstrains(for: rateSelector, with: preferedConstant)
    }
    
    private func addDefinitionsView() {
        guard let definitions = self.player?.resource?.definitions,
              definitions.count > 1 else { return }
        let title = "definition"
        let definitionsSelector = InfoTableView(items: definitions, with: title) { [weak self] (cell, value) in
            guard let current = self?.player?.selecetdDefionition else { return }
            cell.set(title: value.definition, isSelected: current == value)
        } selectHandler: { [weak self] (newValue) in
            self?.player?.selecetdDefionition = newValue
        }

        self.contentView.addArrangedSubview(definitionsSelector)
        var objects = definitions.map({ $0.definition })
        objects.append(title)
        let preferedConstant = definitionsSelector.tableViewWidth(for: objects)
        self.setConstrains(for: definitionsSelector, with: preferedConstant)
    }
}
