//
//  InfoTableView.swift
//  KSPlayer-iOS
//
//  Created by Alanko5 on 03/03/2021.
//

import UIKit

@available(tvOS 13.0, *)
final class InfoTableView<T, Cell: InfoTableCell>: UITableView, UITableViewDelegate, UITableViewDataSource {
    var items: [T] = [] {
        didSet {
            self.reloadData()
        }
    }
    var selectHandler: ((T) -> Void)?
    var configure: ((Cell, T) -> Void)?
    var title:String?
    private var selectedIndex: IndexPath?

    init(items: [T], with title:String?, configure: @escaping (Cell, T) -> Void,  selectHandler: @escaping (T) -> Void) {
        self.items = items
        self.selectHandler = selectHandler
        self.configure = configure
        self.title = title
        super.init(frame: .zero, style: .plain)
        self.delegate = self
        self.dataSource = self
        self.register(Cell.self, forCellReuseIdentifier: "Cell")
    }

    init() {
        super.init(frame: .zero, style: .plain)
        self.delegate = self
        self.dataSource = self
        self.register(Cell.self, forCellReuseIdentifier: "Cell")
    }

    func set(items: [T], with title:String?, configure: @escaping (Cell, T) -> Void, header: ((UILabel) -> Void)?, selectHandler: @escaping (T) -> Void) {
        self.items = items
        self.configure = configure
        self.selectHandler = selectHandler
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func scrollToSelectedIndex(animated: Bool = false) {
        if let selectedIndex = self.selectedIndex {
            self.scrollToRow(at: selectedIndex, at: .middle, animated: animated)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? Cell else { return UITableViewCell()}
        let item = items[indexPath.row]
        self.configure?(cell, item)
        if cell.isSelected {
            self.selectedIndex = indexPath
        }
        cell.focusStyle = .custom
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.title
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.title == nil ? 0 : 24
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label =  UILabel(frame: .zero)
        label.text = self.title
        label.textColor = .darkGray
        label.font = UIFont.systemFont(ofSize: 19, weight: .regular)
        return label
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        self.selectHandler?(item)
        self.reloadData()
    }
    
    public func tableViewWidth(for array:[String]) -> CGFloat {
        if let max = array.max(by: {$1.count > $0.count}) {
            let textWidth = max.width(withConstrainedHeight: 28, font: UIFont.systemFont(ofSize: 31, weight: .semibold))
            return textWidth + 50
        }
        return 400
    }
    
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if context.nextFocusedIndexPath == nil {
            scrollToSelectedIndex(animated: true)
        }
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
    
        return ceil(boundingBox.height)
    }

    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)

        return ceil(boundingBox.width)
    }
}
