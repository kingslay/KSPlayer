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
    var videoView = UIView()
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        nameLabel = UILabel()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameLabel)
        contentView.addSubview(videoView)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        videoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            videoView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 50),
            videoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        _ = videoView.subviews.compactMap { $0.removeFromSuperview() }
    }
}

class RootViewController: UIViewController {
    var tableView = UITableView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UIScreen.main.bounds.width * 0.65 + 50
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.reloadData()
        DispatchQueue.main.async {
            self._scrollViewDidStopScroll(self.tableView)
        }
    }

    #if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        !playerView.isMaskShow
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        KSOptions.supportedInterfaceOrientations
    }

    private let playerView = IOSVideoPlayerView()
    #else
    private let playerView = CustomVideoPlayerView()
    #endif
}

extension RootViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        objects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let cell = cell as? TableViewCell {
            let resource = objects[indexPath.row]
            cell.nameLabel.text = resource.name
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
        if playerView.resource != objects[indexPath.row] {
            playerView.set(resource: objects[indexPath.row])
        }
        cell.videoView.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: cell.videoView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: cell.videoView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: cell.videoView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: cell.videoView.bottomAnchor),
        ])
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating {
            _scrollViewDidStopScroll(scrollView)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating {
                _scrollViewDidStopScroll(scrollView)
            }
        }
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        _scrollViewDidStopScroll(scrollView)
    }

    private func _scrollViewDidStopScroll(_ scrollView: UIScrollView) {
        let index = tableView.indexPathsForVisibleRows?.first { index in
            guard let cell = tableView.cellForRow(at: index) else {
                return false
            }
            let rect = cell.convert(cell.frame, to: scrollView.superview)
            let topSpacing = rect.minY - scrollView.frame.minY - cell.frame.minY
            let bottomSpacing = scrollView.frame.maxY - rect.maxY + cell.frame.minY
            let spacing = -(1 - 0.6) * rect.height
            if topSpacing > spacing, bottomSpacing > spacing {
                return true
            }
            return false
        }
        guard let index, let cell = tableView.cellForRow(at: index) as? TableViewCell else {
            return
        }
        if playerView.resource != objects[index.row] {
            playerView.set(resource: objects[index.row])
        }
        cell.videoView.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: cell.videoView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: cell.videoView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: cell.videoView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: cell.videoView.bottomAnchor),
        ])
    }
}
