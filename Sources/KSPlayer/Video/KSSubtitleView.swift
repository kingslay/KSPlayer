//
//  File.swift
//  KSSubtitles
//
//  Created by kintan on 2018/8/3.
//
import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public class KSSubtitleView: UIControl, SubtitleViewProtocol {
    private var infos = [SubtitleInfo]()
    private let closeInfo = URLSubtitleInfo(subtitleID: "", name: NSLocalizedString("no show subtitle", comment: ""))
    private let tableView = UITableView()
    private let tableWidth = CGFloat(360)
    private var tableViewTrailingConstraint: NSLayoutConstraint!
    public let selectedInfo: KSObservable<SubtitleInfo>
    override public var isHidden: Bool {
        didSet {
            if isHidden {
                UIView.animate(withDuration: 0.25) {
                    self.tableViewTrailingConstraint.constant = self.tableWidth
                    self.layoutIfNeeded()
                }
                #if canImport(UIKit)
                isUserInteractionEnabled = false
                #endif
            } else {
                tableView.reloadData()
                UIView.animate(withDuration: 0.25) {
                    self.tableViewTrailingConstraint.constant = 0
                    self.layoutIfNeeded()
                }
                #if canImport(UIKit)
                isUserInteractionEnabled = true
                #endif
            }
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override public init(frame: CGRect) {
        selectedInfo = KSObservable(wrappedValue: closeInfo)
        super.init(frame: frame)
        tableView.rowHeight = 52
        tableView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewTrailingConstraint = tableView.trailingAnchor.constraint(equalTo: trailingAnchor)
        #if canImport(UIKit)
        #if !os(tvOS)
        tableView.separatorColor = UIColor(white: 1, alpha: 0.15)
        #endif
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SrtListCell.self, forCellReuseIdentifier: "SrtListCell")
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.widthAnchor.constraint(equalToConstant: tableWidth),
            tableViewTrailingConstraint,
        ])
        #else
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
//          tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.widthAnchor.constraint(equalToConstant: tableWidth),
            tableViewTrailingConstraint,
        ])
        #endif

        setupDatas(infos: infos)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupDatas(infos: [SubtitleInfo]) {
        var arrays: [SubtitleInfo] = [closeInfo]
        arrays.append(contentsOf: infos)
        self.infos = arrays
        tableView.reloadData()
    }

    #if canImport(UIKit)
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        isHidden = true
    }
    #endif
}

#if canImport(UIKit)
extension KSSubtitleView: UITableViewDelegate {
    public func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedInfo.wrappedValue = infos[indexPath.row]
    }
}

extension KSSubtitleView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SrtListCell", for: indexPath)
        if let srtCell = cell as? SrtListCell {
            let info = infos[indexPath.row]
            srtCell.titleLabel.text = info.name
            if let comment = info.comment {
                srtCell.localIconView.setTitle(comment, for: .normal)
                srtCell.localIconViewWidth.constant = 34
                srtCell.localIconView.isHidden = false
            } else {
                srtCell.localIconViewWidth.constant = 0
                srtCell.localIconView.isHidden = true
            }
            srtCell.checked(info === selectedInfo.wrappedValue)
        }
        return cell
    }

    public func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        infos.count
    }
}

public class SrtListCell: UITableViewCell {
    private let checkView = UIImageView()
    fileprivate let localIconViewWidth: NSLayoutConstraint
    fileprivate let titleLabel = UILabel()
    fileprivate let localIconView = UIButton()
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        localIconViewWidth = localIconView.widthAnchor.constraint(equalToConstant: 34)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.numberOfLines = 2
        contentView.addSubview(titleLabel)
        localIconView.isUserInteractionEnabled = false
        localIconView.titleLabel?.font = .systemFont(ofSize: 12)
        localIconView.setBackgroundImage(KSPlayerManager.image(named: "ic_subtitle_local"), for: .normal)
        localIconView.setBackgroundImage(KSPlayerManager.image(named: "ic_subtitle_selected"), for: .selected)
        localIconView.setTitleColor(.white, for: .normal)
        localIconView.setTitleColor(UIColor(red: 0x29 / 255.0, green: 0x80 / 255.0, blue: 1.0, alpha: 1.0), for: .selected)
        contentView.addSubview(localIconView)
        checkView.image = KSPlayerManager.image(named: "ic_check")
        checkView.contentMode = .right
        contentView.addSubview(checkView)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        localIconView.translatesAutoresizingMaskIntoConstraints = false
        checkView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: localIconView.leadingAnchor, constant: -12),
            localIconViewWidth,
            localIconView.heightAnchor.constraint(equalToConstant: 20),
            localIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            localIconView.trailingAnchor.constraint(equalTo: checkView.leadingAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 20),
            checkView.heightAnchor.constraint(equalToConstant: 20),
            checkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
        ])
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func checked(_ checked: Bool) {
        titleLabel.textColor = checked ? UIColor(red: 0x29 / 255.0, green: 0x80 / 255.0, blue: 1.0, alpha: 1.0) : .white
        checkView.isHidden = !checked
        localIconView.isSelected = checked
    }
}
#endif
