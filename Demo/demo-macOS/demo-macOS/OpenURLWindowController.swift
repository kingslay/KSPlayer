//
//  OpenURLWindowController.swift
//  iina
//
//  Created by Collider LI on 25/8/2018.
//  Copyright © 2018 lhc. All rights reserved.
//

import Cocoa

class OpenURLWindowController: NSWindowController, NSTextFieldDelegate, NSControlTextEditingDelegate {
    override var windowNibName: NSNib.Name {
        NSNib.Name("OpenURLWindowController")
    }

    @IBOutlet var urlStackView: NSStackView!
    @IBOutlet var httpPrefixTextField: NSTextField!
    @IBOutlet var urlField: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var passwordField: NSSecureTextField!
    @IBOutlet var rememberPasswordCheckBox: NSButton!
    @IBOutlet var errorMessageLabel: NSTextField!
    @IBOutlet var openButton: NSButton!

    var isAlternativeAction = false

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.isMovableByWindowBackground = true
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        urlStackView.setVisibilityPriority(.notVisible, for: httpPrefixTextField)
        urlField.delegate = self
        for item in [.closeButton, .miniaturizeButton, .zoomButton] as [NSWindow.ButtonType] {
            window?.standardWindowButton(item)?.isHidden = true
        }
    }

    override func cancelOperation(_: Any?) {
        window?.close()
    }

    func resetFields() {
        urlField.stringValue = ""
        usernameField.stringValue = ""
        passwordField.stringValue = ""
        rememberPasswordCheckBox.state = .on
        urlStackView.setVisibilityPriority(.notVisible, for: httpPrefixTextField)
        window?.makeFirstResponder(urlField)
    }

    @IBAction func cancelBtnAction(_: Any) {
        window?.close()
    }

    @IBAction func openBtnAction(_: Any) {
        if let url = getURL().url {
            if rememberPasswordCheckBox.state == .on, let host = url.host {
                try? KeychainAccess.write(username: usernameField.stringValue,
                                          password: passwordField.stringValue,
                                          forService: .httpAuth,
                                          server: host,
                                          port: url.port)
            }
            window?.close()
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                delegate.open(url: url)
            }
        } else {
            Utility.showAlert("wrong_url_format")
        }
    }

    private func getURL() -> (url: URL?, hasScheme: Bool) {
        guard !urlField.stringValue.isEmpty else { return (nil, false) }
        let username = usernameField.stringValue
        let password = passwordField.stringValue
        guard var urlValue = urlField.stringValue.addingPercentEncoding(withAllowedCharacters: .urlAllowed) else {
            return (nil, false)
        }
        var hasScheme = true
        if let url = URL(string: urlValue), url.scheme == nil {
            urlValue = "http://" + urlValue
            hasScheme = false
        }
        guard let nsurl = NSURL(string: urlValue)?.standardized, let urlComponents = NSURLComponents(url: nsurl, resolvingAgainstBaseURL: false) else { return (nil, false) }
        if !username.isEmpty {
            urlComponents.user = username
            if !password.isEmpty {
                urlComponents.password = password
            }
        }
        return (urlComponents.url, hasScheme)
    }

    // NSControlTextEditingDelegate

    func controlTextDidChange(_ obj: Notification) {
        if let textView = obj.userInfo?["NSFieldEditor"] as? NSTextView, let str = textView.textStorage?.string, str.isEmpty {
            errorMessageLabel.isHidden = true
            urlStackView.setVisibilityPriority(.notVisible, for: httpPrefixTextField)
            openButton.isEnabled = true
            return
        }
        let (url, hasScheme) = getURL()
        if let url, let host = url.host {
            errorMessageLabel.isHidden = true
            urlField.textColor = .labelColor
            openButton.isEnabled = true
            if hasScheme {
                urlStackView.setVisibilityPriority(.notVisible, for: httpPrefixTextField)
            } else {
                urlStackView.setVisibilityPriority(.mustHold, for: httpPrefixTextField)
            }
            // find saved password
            if let (username, password) = try? KeychainAccess.read(username: nil, forService: .httpAuth, server: host, port: url.port) {
                usernameField.stringValue = username
                passwordField.stringValue = password
            } else {
                usernameField.stringValue = ""
                passwordField.stringValue = ""
            }
        } else {
            urlField.textColor = .systemRed
            errorMessageLabel.isHidden = false
            urlStackView.setVisibilityPriority(.notVisible, for: httpPrefixTextField)
            openButton.isEnabled = false
        }
    }
}

class KeychainAccess {
    enum KeychainError: Error {
        case noResult
        case unhandledError(message: String)
        case unexpectedData
    }

    struct ServiceName: RawRepresentable {
        typealias RawValue = String
        var rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ rawValue: String) {
            self.init(rawValue: rawValue)
        }

        static let openSubAccount = ServiceName(rawValue: "IINA OpenSubtitles Account")
        static let httpAuth = ServiceName(rawValue: "IINA Saved HTTP Password")
    }

    static func write(username: String, password: String, forService serviceName: ServiceName, server: String? = nil, port: Int? = nil) throws {
        let status: OSStatus

        if let _ = try? read(username: username, forService: serviceName, server: nil, port: nil) {
            // if password exists, try to update the password
            var query: [String: Any] = [kSecAttrService as String: serviceName.rawValue]
            if let server { query[kSecAttrServer as String] = server }
            if let port { query[kSecAttrPort as String] = port }
            query[kSecClass as String] = server == nil && port == nil ? kSecClassGenericPassword : kSecClassInternetPassword

            // create attributes for updating
            let passwordData = password.data(using: String.Encoding.utf8)!
            let attributes: [String: Any] = [kSecAttrAccount as String: username,
                                             kSecValueData as String: passwordData]
            // update
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        } else {
            // try to write the password
            var query: [String: Any] = [kSecAttrService as String: serviceName.rawValue,
                                        kSecAttrLabel as String: serviceName.rawValue,
                                        kSecAttrAccount as String: username,
                                        kSecValueData as String: password]
            if let server { query[kSecAttrServer as String] = server }
            if let port { query[kSecAttrPort as String] = port }
            query[kSecClass as String] = server == nil && port == nil ? kSecClassGenericPassword : kSecClassInternetPassword

            status = SecItemAdd(query as CFDictionary, nil)
        }

        // check result
        guard status != errSecItemNotFound else { throw KeychainError.noResult }
        guard status == errSecSuccess else {
            let message = (SecCopyErrorMessageString(status, nil) as String?) ?? ""
            throw KeychainError.unhandledError(message: message)
        }
    }

    static func read(username: String?, forService serviceName: ServiceName, server: String? = nil, port: Int? = nil) throws -> (username: String, password: String) {
        var query: [String: Any] = [kSecAttrService as String: serviceName.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        if let username { query[kSecAttrAccount as String] = username }
        if let server { query[kSecAttrServer as String] = server }
        if let port { query[kSecAttrPort as String] = port }

        query[kSecClass as String] = server == nil && port == nil ? kSecClassGenericPassword : kSecClassInternetPassword

        // initiate the search
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw KeychainError.noResult }
        guard status == errSecSuccess else {
            let message = (SecCopyErrorMessageString(status, nil) as String?) ?? ""
            throw KeychainError.unhandledError(message: message)
        }

        // get data
        guard let existingItem = item as? [String: Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: String.Encoding.utf8),
              let account = existingItem[kSecAttrAccount as String] as? String
        else {
            throw KeychainError.unexpectedData
        }
        return (account, password)
    }
}

enum Utility {
    static func showAlert(_ key: String, comment: String? = nil, arguments: [CVarArg]? = nil, style: NSAlert.Style = .critical, sheetWindow: NSWindow? = nil) {
        let alert = NSAlert()
        switch style {
        case .critical:
            alert.messageText = NSLocalizedString("alert.title_error", comment: "Error")
        case .informational:
            alert.messageText = NSLocalizedString("alert.title_info", comment: "Information")
        case .warning:
            alert.messageText = NSLocalizedString("alert.title_warning", comment: "Warning")
        @unknown default:
            break
        }

        var format: String
        if let stringComment = comment {
            format = NSLocalizedString("alert." + key, comment: stringComment)
        } else {
            format = NSLocalizedString("alert." + key, comment: key)
        }

        if let stringArguments = arguments {
            alert.informativeText = String(format: format, arguments: stringArguments)
        } else {
            alert.informativeText = String(format: format)
        }

        alert.alertStyle = style
        if let sheetWindow {
            alert.beginSheetModal(for: sheetWindow)
        } else {
            alert.runModal()
        }
    }
}

extension CharacterSet {
    static let urlAllowed: CharacterSet = {
        var set = CharacterSet.urlHostAllowed
            .union(.urlUserAllowed)
            .union(.urlPasswordAllowed)
            .union(.urlPathAllowed)
            .union(.urlQueryAllowed)
            .union(.urlFragmentAllowed)
        set.insert(charactersIn: "%")
        return set
    }()
}
