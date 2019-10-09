//
//  MasterViewController.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import UIKit
struct Model {
    var name: String
    var url: URL
    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

class TableViewCell: UITableViewCell {
    var nameLabel: UILabel
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        nameLabel = UILabel()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            nameLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10),
            nameLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MasterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var objects = [Model]()
    var tableView = UITableView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.delegate = self
        tableView.dataSource = self
        if let path = Bundle.main.path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "MP4") {
            objects.append(Model(name: "本地视频", url: URL(fileURLWithPath: path)))
        }
        if let path = Bundle.main.path(forResource: "google-help-vr", ofType: "mp4") {
            objects.append(Model(name: "本地全景视频", url: URL(fileURLWithPath: path)))
        }
        if let path = Bundle.main.path(forResource: "video-h265", ofType: "mkv") {
            objects.append(Model(name: "h265视频", url: URL(fileURLWithPath: path)))
        }
        if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
            objects.append(Model(name: "http视频", url: url))
        }
        if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/tutorials/20170912/602x28bbwk8lp/metal_on_iphone_x_overview/hls_vod_mvp.m3u8") {
            objects.append(Model(name: "https视频", url: url))
        }

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

    // MARK: - Table View

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return objects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
        cell.nameLabel.text = objects[indexPath.row].name
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = DetailViewController()
        controller.name = objects[indexPath.row].name
        controller.detailItem = objects[indexPath.row].url
        navigationController?.pushViewController(controller, animated: true)
    }
}
