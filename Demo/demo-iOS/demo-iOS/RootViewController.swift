//
//  RootViewController.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import KSPlayer
import UIKit

private class TableViewCell: UITableViewCell {
    #if os(iOS)
    fileprivate let playerView = IOSVideoPlayerView()
    #else
    fileprivate let playerView = CustomVideoPlayerView()
    #endif
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.65),
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RootViewController: UIViewController {
    var tableView = UITableView()
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addURL)), animated: false)
        KSOptions.isAutoPlay = false
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.reloadData()
    }

    #if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        KSOptions.supportedInterfaceOrientations
    }
    #endif
    @objc func addURL() {
        let alert = UIAlertController(title: "Enter movie URL", message: nil, preferredStyle: .alert)

        alert.addTextField(configurationHandler: { testField in
            testField.placeholder = "URL"
            testField.text = "https://"
        })

        alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { [weak self] _ in
            guard let textFieldText = alert.textFields?.first?.text,
                  let url = URL(string: textFieldText)
            else {
                return
            }
            let resource = KSPlayerResource(url: url)
            let controller = DetailViewController()
            controller.resource = resource
            self?.navigationController?.pushViewController(controller, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension RootViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        testObjects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let cell = cell as? TableViewCell {
            let resource = testObjects[indexPath.row]
            if cell.playerView.resource != resource {
                cell.playerView.set(resource: resource)
            }
        }
        return cell
    }
}

extension RootViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? TableViewCell else {
            return
        }
        cell.playerView.play()
    }
}
