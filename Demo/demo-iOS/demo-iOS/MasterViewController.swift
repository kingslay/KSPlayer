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
        navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addURL)), animated: false)
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
        tableView.rowHeight = 40
        #if !os(tvOS)
        tableView.separatorStyle = .singleLine
        #endif
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
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        testObjects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let cell = cell as? TableViewCell {
            cell.nameLabel.text = testObjects[indexPath.row].name
        }
        return cell
    }
}

extension MasterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        play(resource: testObjects[indexPath.row])
    }
}

// MARK: - Actions

extension MasterViewController {
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
            self?.play(resource: resource)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func play(resource: KSPlayerResource?) {
        if let split = splitViewController, let nav = split.viewControllers.last as? UINavigationController, let detail = nav.topViewController as? DetailProtocol {
            detail.resource = resource
            #if os(iOS)
            detail.navigationItem.leftBarButtonItem = split.displayModeButtonItem
            detail.navigationItem.leftItemsSupplementBackButton = true
            #endif
            split.preferredDisplayMode = .primaryHidden
            return
        }
        let controller = DetailViewController()
        controller.resource = resource
        navigationController?.pushViewController(controller, animated: true)
    }
}
