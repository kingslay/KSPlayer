//
//  MasterViewController.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import KSPlayer
import UIKit
private class TableViewCell: UITableViewCell {
    var nameLabel: UILabel
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        nameLabel = UILabel()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MasterViewController: UIViewController {
    var tableView = UITableView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 50
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension MasterViewController: UITableViewDataSource {
    // MARK: - Table View

    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return objects.count
        }
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let cell = cell as? TableViewCell {
            if indexPath.section == 1 {
                cell.nameLabel.text = objects[indexPath.row].name
            } else {
                cell.nameLabel.text = "Enter self URL"
            }
        }
        return cell
    }
}

extension MasterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            play(from: indexPath)
        } else {
            showAlertForEnterURL()
        }
    }
}

// MARK: - Actions

extension MasterViewController {
    func showAlertForEnterURL(_ message: String? = nil) {
        let alert = UIAlertController(title: "Enter movie URL", message: message, preferredStyle: .alert)

        alert.addTextField(configurationHandler: { testField in
            testField.placeholder = "URL"
            testField.text = "https://"
        })

        alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { [weak self] _ in
            guard let textFieldText = alert.textFields?.first?.text,
                  let mURL = URL(string: textFieldText)
            else {
                self?.showAlertForEnterURL("Please enter valid URL")
                return
            }

            let resource = KSPlayerResource(url: mURL)
            self?.play(from: IndexPath(row: 0, section: 0), or: resource)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    func play(from indexPath: IndexPath, or resource: KSPlayerResource? = nil) {
        if let split = splitViewController, let nav = split.viewControllers.last as? UINavigationController, let detail = nav.topViewController as? DetailProtocol {
            if let resource {
                detail.resource = resource
            } else {
                detail.resource = objects[indexPath.row]
            }
            #if os(iOS)
            detail.navigationItem.leftBarButtonItem = split.displayModeButtonItem
            detail.navigationItem.leftItemsSupplementBackButton = true
            #endif
            split.preferredDisplayMode = .primaryHidden
            return
        }
        let controller: DetailProtocol
        if indexPath.row == objects.count - 1, resource == nil {
            controller = AudioViewController()
        } else {
            controller = DetailViewController()
        }
        controller.resource = objects[indexPath.row]
        navigationController?.pushViewController(controller, animated: true)
    }
}
