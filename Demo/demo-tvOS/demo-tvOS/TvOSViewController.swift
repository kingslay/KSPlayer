//
//  TvOSViewController.swift
//  demo-tvOS
//
//  Created by Alanko5 on 07/01/2022.
//  Copyright © 2022 kintan. All rights reserved.
//

import UIKit
import KSPlayer
final class TvOSViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    func showPlayer(media:KSPlayerResource) {
        if #available(tvOS 13.0, *) {
            let vc = KSPlayerViewController()
            vc.set(media)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func getURL() {
        let alertController = UIAlertController(title: "", message: "", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "URL"
        }
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let text = alertController.textFields?.first?.text,
                  text.contains("http"),
                  let url = URL(string: text)
            else { return }
            self?.showPlayer(media: KSPlayerResource(url: url))
        }
        alertController.addAction(confirmAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true) {
            alertController.textFields?.first?.becomeFirstResponder()
        }
    }
}

extension TvOSViewController {
    override func numberOfSections(in _: UITableView) -> Int {
        2
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return objects.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if indexPath.section == 0 {
            cell.textLabel?.text = "From URL"
        } else {
            cell.textLabel?.text = objects[indexPath.row].name
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            getURL()
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            let resource = objects[indexPath.row]
            showPlayer(media: resource)
        }
    }
}
