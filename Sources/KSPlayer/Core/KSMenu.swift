//
//  KSMenu.swift
//  KSPlayer
//
//  Created by Alanko5 on 15/12/2022.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@available(tvOS 15.0, *)
public enum KSMenuBuilder {
    static func definitionsMenu(from resource: KSPlayerResource?,
                                selected definition: Int,
                                completition handler: @escaping (Int) -> Void) -> UIMenu?
    {
        guard let resource, resource.definitions.count > 1 else {
            return nil
        }
        var actions = [UIAction]()
        resource.definitions.enumerated().forEach { index, currentDefinition in
            let definitionItem = UIAction(title: currentDefinition.definition) { item in
                handler(index)
                actions.forEach { action in
                    action.state = item.title == action.title ? .on : .off
                }
            }
            if index == definition {
                definitionItem.state = .on
            }
            actions.append(definitionItem)
        }
        return UIMenu(title: NSLocalizedString("select video quality", comment: ""), children: actions)
    }

    static func playbackRateMenu(_ currentRate: Double,
                                 speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0],
                                 completition handler: @escaping (Double) -> Void) -> UIMenu
    {
        var actions = [UIAction]()
        speeds.forEach { rate in
            let title = "\(rate) x"
            let rateItem = UIAction(title: title) { item in
                handler(rate)
                actions.forEach { action in
                    action.state = item.title == action.title ? .on : .off
                }
            }
            if currentRate == rate {
                rateItem.state = .on
            }
            actions.append(rateItem)
        }
        return UIMenu(title: NSLocalizedString("speed", comment: ""), children: actions)
    }

    static func audioVideoChangeMenu(_ currentTrack: MediaPlayerTrack?,
                                     availableTracks: [MediaPlayerTrack],
                                     completition handler: @escaping (MediaPlayerTrack) -> Void) -> UIMenu?
    {
        guard let currentTrack, availableTracks.count > 1 else {
            return nil
        }
        let title = NSLocalizedString(currentTrack.mediaType == .audio ? "switch audio" : "switch video", comment: "")
        var actions = [UIAction]()
        availableTracks.forEach { track in
            var title = track.name
            if track.mediaType == .video {
                title += " \(track.naturalSize.width)x\(track.naturalSize.height)"
            }

            let tracksItem = UIAction(title: title) { item in
                handler(track)
                actions.forEach { action in
                    action.state = item.title == action.title ? .on : .off
                }
            }

            if track.isEnabled {
                tracksItem.state = .on
            }
            actions.append(tracksItem)
        }
        return UIMenu(title: title, children: actions)
    }

    static func srtChangeMenu(_ currentSub: (any SubtitleInfo)?,
                              availableSubtitles: [any SubtitleInfo],
                              completition handler: @escaping ((any SubtitleInfo)?) -> Void) -> UIMenu?
    {
        guard availableSubtitles.count > 0 else { return nil }
        var actions = [UIAction]()
        let subtitleItem = UIAction(title: "Disabled") { item in
            handler(nil)
            actions.forEach { action in
                action.state = item.title == action.title ? .on : .off
            }
        }
        if currentSub == nil {
            subtitleItem.state = .on
        }

        actions.append(subtitleItem)
        availableSubtitles.forEach { srt in
            let subtitleItem = UIAction(title: srt.name) { item in
                handler(srt)
                actions.forEach { action in
                    action.state = item.title == action.title ? .on : .off
                }
            }
            if srt.subtitleID == currentSub?.subtitleID {
                subtitleItem.state = .on
            }
            actions.append(subtitleItem)
        }

        return UIMenu(title: NSLocalizedString("subtitle", comment: ""), children: actions)
    }
}

#if canImport(UIKit)

#else
public typealias UIMenu = NSMenu

public final class UIAction: NSMenuItem {
    private let handler: (UIAction) -> Void
    init(title: String, handler: @escaping (UIAction) -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(menuPressed), keyEquivalent: "")
        state = .off
        target = self
    }

    @objc private func menuPressed() {
        handler(self)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIMenu {
    convenience init(title: String, children: [UIAction]) {
        self.init(title: title)
        for item in children {
            addItem(item)
        }
    }
}
#endif
