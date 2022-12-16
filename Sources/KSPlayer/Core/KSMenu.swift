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

final public class KSMenuBuilder {
    static func definitionsMenu(from resource: KSPlayerResource?,
                                selected definition: Int,
                                completition handler: @escaping (KSAction) -> Void) -> KSMenuX? {
        guard #available(macOS 11.0, iOS 13.0, tvOS 14.0, *) else { return nil }
        guard let resource, resource.definitions.count > 1 else { return nil }

        var actions: [KSAction] = []
        resource.definitions.enumerated().forEach { index, currentDefinition in
            let definitionItem = KSAction.initialize(title: currentDefinition.definition,
                                                     tag: index,
                                                     completition: handler)
            if index == definition {
                definitionItem.state = .on
            }
            actions.append(definitionItem)
        }

        let menu = KSMenuX.initialize(title: NSLocalizedString("select video quality", comment: ""), items: actions)

        return menu
    }

    static func playbackRateMenu(_ currentRate: Double,
                                 speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0],
                                 completition handler: @escaping (Double) -> Void) -> KSMenuX? {
        guard #available(macOS 11.0, iOS 13.0, tvOS 14.0, *) else { return nil }

        var actions: [KSAction] = []
        speeds.enumerated().forEach { index, rate in
            let title = "\(rate) x"
            let rateItem = KSAction.initialize(title: title,
                                               tag: index) { action in
                guard speeds.count > action.tag  else { return }
                handler(speeds[action.tag])
            }
            if currentRate == rate {
                rateItem.state = .on
            }
            actions.append(rateItem)
        }
        let menu = KSMenuX.initialize(title: NSLocalizedString("speed", comment: ""), items: actions)
        return menu
    }

    static func audioVideoChangeMenu(_ currentTrack: MediaPlayerTrack?,
                                     availableTracks: [MediaPlayerTrack],
                                     completition handler: @escaping (KSAction) -> Void) -> KSMenuX? {
        guard availableTracks.count > 1,
                let currentTrack,
                #available(macOS 11.0, iOS 13.0, tvOS 14.0, *)
        else { return nil }
        let title = NSLocalizedString(currentTrack.mediaType == .audio ? "switch audio" : "switch video", comment: "")

        var actions: [KSAction] = []
        availableTracks.enumerated().forEach { index, track in
            var title = track.name
            if track.mediaType == .video {
                title += " \(track.naturalSize.width)x\(track.naturalSize.height)"
            }

            let tracksItem = KSAction.initialize(title: title,
                                                 tag: index,
                                                 completition: handler)

            if track.isEnabled {
                tracksItem.state = .on
            }
            actions.append(tracksItem)
        }
        let menu = KSMenuX.initialize(title: title, items: actions)
        return menu
    }

    static func srtChangeMenu(_ currentSub: SubtitleInfo?,
                              availableSubtitles: [SubtitleInfo],
                              completition handler: @escaping (SubtitleInfo?) -> Void) -> KSMenuX? {
        guard availableSubtitles.count > 0, #available(macOS 11.0, iOS 13.0, tvOS 14.0, *) else { return nil }
        var actions: [KSAction] = []

        let subtitleItem = KSAction.initialize(title: "Disabled",
                                               tag: -1) { _ in
            handler(nil)
        }
        if currentSub == nil {
            subtitleItem.state = .on
        }
        actions.append(subtitleItem)

        availableSubtitles.enumerated().forEach { index, srt in
            let subtitleItem = KSAction.initialize(title: srt.name,
                                                   tag: index) { _ in
                let selectedSrt = availableSubtitles[index]
                handler(selectedSrt)
            }
            if srt.subtitleID == currentSub?.subtitleID {
                subtitleItem.state = .on
            }
            actions.append(subtitleItem)
        }

        let menu = KSMenuX.initialize(title: NSLocalizedString("subtitle", comment: ""), items: actions)
        return menu
    }
}

#if canImport(UIKit)
final public class KSAction: UIAction {
    var tag: Int = 0

    @available(macOS 11.0, iOS 13.0, tvOS 14.0, *)
    static func initialize(title string: String,
                           keyEquivalent charCode: String = "",
                           state: KSMenuX.State = .off,
                           tag: Int = 0,
                           completition handler: @escaping (KSAction) -> Void) -> KSAction {

        let action = KSAction(title: string,
                              image: nil,
                              identifier: nil,
                              discoverabilityTitle: nil,
                              attributes: [],
                              state: state.value) { action in
            guard let action = action as? KSAction else { return }
            handler(action)
        }
        action.tag = tag

        return action
    }
}

final public class KSMenuX: UIMenu {
    @available(iOS 13.0, tvOS 14.0, *)
    static func initialize(title: String, items: [KSAction]) -> KSMenuX {
        return KSMenuX.init(title: title, children: items)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#else
final public class KSAction: NSMenuItem {
    var completition: ((KSAction) -> Void)?

    static func initialize(title string: String,
                           keyEquivalent charCode: String = "",
                           state: KSMenuX.State = .off,
                           tag: Int = 0,
                           completition: @escaping (KSAction) -> Void) -> KSAction {
        let menuItem = KSAction(title: string, action: #selector(menuPressed), keyEquivalent: charCode)
        menuItem.completition = completition
        menuItem.state = state.value
        menuItem.target = menuItem
        menuItem.tag = tag
        return menuItem
    }

    @objc internal func menuPressed() {
        completition?(self)
    }
}

final public class KSMenuX: NSMenu {
    static func initialize(title: String, items: [KSAction]) -> KSMenuX {
        let menu = KSMenuX(title: title)
        for item in items {
            menu.addItem(item)
        }
        return menu
    }
}
#endif

public extension KSMenuX {
    // swiftlint:disable identifier_name
    enum State: Int, @unchecked Sendable {
        case off = 0
        case on = 1
        case mixed = 2

    #if canImport(UIKit)
        var value: UIMenuElement.State {
            switch self {
            case .off:
                return .off
            case .on:
                return .on
            case .mixed:
                return .mixed
            }
        }
    #else
        var value: NSControl.StateValue {
            switch self {
            case .off:
                return .off
            case .on:
                return .on
            case .mixed:
                return .mixed
            }
        }
    #endif
    }
}
