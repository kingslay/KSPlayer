//
//  MasterViewController.swift
//  Demo
//
//  Created by kintan on 2018/4/15.
//  Copyright © 2018年 kintan. All rights reserved.
//

import KSPlayer
import UIKit
class TableViewCell: UITableViewCell {
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

class MasterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var objects = [KSPlayerResource]()
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
        if let path = Bundle.main.path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "mp4") {
            let options = KSOptions()
            options.videoFilters = "hflip,vflip"
            options.hardwareDecodeH264 = false
            objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地视频"))
        }
        if let path = Bundle.main.path(forResource: "google-help-vr", ofType: "mp4") {
            let options = KSOptions()
            options.display = .vr
            objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地全景视频"))
        }
        if let path = Bundle.main.path(forResource: "Polonaise", ofType: "flac") {
            objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "本地音频"))
        }
        if let path = Bundle.main.path(forResource: "video-h265", ofType: "mkv") {
            objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "h265视频"))
        }
        if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
            let res0 = KSPlayerResourceDefinition(url: url, definition: "高清")
            let res1 = KSPlayerResourceDefinition(url: URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!, definition: "标清")
            let asset = KSPlayerResource(name: "http视频", definitions: [res0, res1], cover: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/848px-Big_buck_bunny_poster_big.jpg"))
            objects.append(asset)
        }

        if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
            objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "m3u8视频"))
        }

        if let url = URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8") {
            objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "fmp4"))
        }

        if let url = URL(string: "http://116.199.5.51:8114/00000000/hls/index.m3u8?Fsv_chan_hls_se_idx=188&FvSeid=1&Fsv_ctype=LIVES&Fsv_otype=1&Provider_id=&Pcontent_id=.m3u8") {
            objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "tvb视频"))
        }

        if let url = URL(string: "http://dash.edgesuite.net/akamai/bbb_30fps/bbb_30fps.mpd") {
            objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "dash视频"))
        }
        if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2019/244gmopitz5ezs2kkq/244/hls_vod_mvp.m3u8") {
            let options = KSOptions()
            options.formatContextOptions["timeout"] = 0
            objects.append(KSPlayerResource(url: url, options: options, name: "https视频"))
        }

        if let url = URL(string: "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov") {
            let options = KSOptions()
            options.formatContextOptions["timeout"] = 0
            objects.append(KSPlayerResource(url: url, options: options, name: "rtsp video"))
        }

        if let path = Bundle.main.path(forResource: "Polonaise", ofType: "flac") {
            objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "音乐播放器界面"))
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
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        objects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let cell = cell as? TableViewCell {
            cell.nameLabel.text = objects[indexPath.row].name
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let split = splitViewController, let nav = split.viewControllers.last as? UINavigationController, let detail = nav.topViewController as? DetailProtocol {
            detail.resource = objects[indexPath.row]
            #if os(iOS)
            detail.navigationItem.leftBarButtonItem = split.displayModeButtonItem
            detail.navigationItem.leftItemsSupplementBackButton = true
            #endif
            split.preferredDisplayMode = .primaryHidden
            return
        }
        let controller: DetailProtocol
        if indexPath.row == objects.count - 1 {
            controller = AudioViewController()
        } else {
            controller = DetailViewController()
        }
        controller.resource = objects[indexPath.row]
        navigationController?.pushViewController(controller, animated: true)
    }
}
