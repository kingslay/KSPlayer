//
//  KSSubtitle.swift
//  Pods
//
//  Created by kintan on 2017/4/2.
//
//

import CoreFoundation
import CoreGraphics
import Foundation
import SwiftUI

public class SubtitlePart: CustomStringConvertible, NSMutableCopying {
    public let start: TimeInterval
    public var end: TimeInterval
    public var origin: CGPoint = .zero
    public let text: NSMutableAttributedString?
    public var image: UIImage?
    public var description: String {
        "Subtile Group ==========\nstart: \(start)\nend:\(end)\ntext:\(String(describing: text))"
    }

    public convenience init(_ start: TimeInterval, _ end: TimeInterval, _ string: String) {
        var text = string
        text = text.trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: "\r", with: "")
        self.init(start, end, attributedString: NSMutableAttributedString(string: text))
    }

    public init(_ start: TimeInterval, _ end: TimeInterval, attributedString: NSMutableAttributedString?) {
        self.start = start
        self.end = end
        text = attributedString
    }

    public func mutableCopy(with _: NSZone? = nil) -> Any {
        SubtitlePart(start, end, attributedString: text?.mutableCopy() as? NSMutableAttributedString)
    }
}

extension SubtitlePart: Comparable {
    public static func == (left: SubtitlePart, right: SubtitlePart) -> Bool {
        if left.start == right.start, left.end == right.end {
            return true
        } else {
            return false
        }
    }

    public static func < (left: SubtitlePart, right: SubtitlePart) -> Bool {
        if left.start < right.start {
            return true
        } else {
            return false
        }
    }
}

extension SubtitlePart: NumericComparable {
    public typealias Compare = TimeInterval
    public static func == (left: SubtitlePart, right: TimeInterval) -> Bool {
        left.start <= right && left.end >= right
    }

    public static func < (left: SubtitlePart, right: TimeInterval) -> Bool {
        left.end < right
    }
}

public protocol KSSubtitleProtocol {
    func search(for time: TimeInterval) -> SubtitlePart?
}

public protocol SubtitleInfo: KSSubtitleProtocol, AnyObject, Hashable, Identifiable {
    var subtitleID: String { get }
    var name: String { get }
    var delay: TimeInterval { get set }
    //    var userInfo: NSMutableDictionary? { get set }
    //    var subtitleDataSouce: SubtitleDataSouce? { get set }
//    var comment: String? { get }
    func subtitle(isEnabled: Bool)
}

public extension SubtitleInfo {
    var id: String { subtitleID }
    func hash(into hasher: inout Hasher) {
        hasher.combine(subtitleID)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.subtitleID == rhs.subtitleID
    }
}

public class KSSubtitle {
    public var parts: [SubtitlePart] = []
    public private(set) var currentIndex = 0 {
        didSet {
            if oldValue != currentIndex {
                isChangeIndex = true
            }
        }
    }

    private var isFirstSearch = true
    public var isChangeIndex = true
    public var currentPart: SubtitlePart {
        parts[currentIndex]
    }

    public var partsCount: Int {
        parts.count
    }

    public init() {}
}

extension KSSubtitle: KSSubtitleProtocol {
    /// Search for target group for time
    public func search(for time: TimeInterval) -> SubtitlePart? {
        var index = currentIndex
        if searchIndex(for: time) != nil {
            if currentIndex == index {
                index = currentIndex + 1
                if index < parts.count, parts[index] == time {
                    // swiftlint:disable force_cast
                    let copy = parts[currentIndex].mutableCopy() as! SubtitlePart
                    // swiftlint:enable force_cast
                    repeat {
                        if let otherText = parts[index].text {
                            copy.text?.append(NSAttributedString(string: "\n"))
                            copy.text?.append(otherText)
                        }
                        copy.end = parts[index].end
                        index += 1
                    } while index < parts.count && parts[index] == time
                    return copy
                }
            }
            return parts[currentIndex]
        } else {
            return nil
        }
    }

    public func searchIndex(for time: TimeInterval) -> Int? {
        guard currentIndex < partsCount else {
            return nil
        }
        let group = parts[currentIndex]
        if group == time {
            if isFirstSearch {
                isChangeIndex = true
                isFirstSearch = false
            } else {
                isChangeIndex = false
            }
            return currentIndex
        } else if group < time, currentIndex + 1 < parts.count {
            let group = parts[currentIndex + 1]
            if group == time {
                currentIndex += 1
                return currentIndex
            }
        }
        if let firstIndex = parts.binarySearch(key: time) {
            currentIndex = firstIndex
            return currentIndex
        }
        return nil
    }

    public func searchIndex(filter: (SubtitlePart, Int) -> Bool) -> NSRange? {
        var length = 0
        for (index, group) in parts.enumerated() {
            let count = group.text?.length ?? 0
            if filter(group, length + count) {
                if currentIndex != index {
                    currentIndex = index
                } else {
                    if isFirstSearch {
                        isChangeIndex = true
                        isFirstSearch = false
                    } else {
                        isChangeIndex = false
                    }
                }
                return NSRange(location: length, length: count)
            } else {
                length += count
            }
        }
        return nil
    }
}

public class KSURLSubtitle: KSSubtitle {
    public func parse(url: URL, encoding: String.Encoding? = nil) async throws {
        do {
            var string: String?
            let srtData = try await url.data()
            let encodes = [encoding ?? String.Encoding.utf8,
                           String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),
                           String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
                           String.Encoding.unicode]
            for encode in encodes {
                string = String(data: srtData, encoding: encode)
                if string != nil {
                    break
                }
            }
            guard let subtitle = string else {
                throw NSError(errorCode: .subtitleUnEncoding, userInfo: ["url": url.absoluteString])
            }
            let parse = KSOptions.subtitleParses.first { $0.canParse(subtitle: subtitle) }
            if let parse {
                parts = parse.parse(subtitle: subtitle)
                if partsCount == 0 {
                    throw NSError(errorCode: .subtitleUnParse, userInfo: ["url": url.absoluteString])
                }
            } else {
                throw NSError(errorCode: .subtitleFormatUnSupport, userInfo: ["url": url.absoluteString])
            }
        } catch {
            throw NSError(errorCode: .subtitleUnEncoding, userInfo: ["url": url.absoluteString])
        }
    }

//    public static func == (lhs: KSURLSubtitle, rhs: KSURLSubtitle) -> Bool {
//        lhs.url == rhs.url
//    }
}

public protocol NumericComparable {
    associatedtype Compare
    static func < (lhs: Self, rhs: Compare) -> Bool
    static func == (lhs: Self, rhs: Compare) -> Bool
}

extension Collection where Element: NumericComparable {
    func binarySearch(key: Element.Compare) -> Self.Index? {
        var lowerBound = startIndex
        var upperBound = endIndex
        while lowerBound < upperBound {
            let midIndex = index(lowerBound, offsetBy: distance(from: lowerBound, to: upperBound) / 2)
            if self[midIndex] == key {
                return midIndex
            } else if self[midIndex] < key {
                lowerBound = index(lowerBound, offsetBy: 1)
            } else {
                upperBound = midIndex
            }
        }
        return nil
    }
}

open class SubtitleModel: ObservableObject {
    public enum Size {
        case smaller
        case standard
        case large
        public var rawValue: CGFloat {
            switch self {
            case .smaller:
                #if os(tvOS)
                return 30
                #elseif os(macOS)
                return 20
                #else
                return 12
                #endif
            case .standard:
                #if os(tvOS)
                return 36
                #elseif os(macOS)
                return 26
                #else
                return 16
                #endif
            case .large:
                #if os(tvOS)
                return 42
                #elseif os(macOS)
                return 32
                #else
                return 20
                #endif
            }
        }
    }

    public static var textColor: Color = .white
    public static var textBackgroundColor: Color = .clear
    public static var textFont: UIFont {
        textBold ? .boldSystemFont(ofSize: textFontSize) : .systemFont(ofSize: textFontSize)
    }

    public static var textFontSize = SubtitleModel.Size.standard.rawValue
    public static var textBold = false
    public static var textItalic = false
    public static var textXAlign: TextAlignment = .center
    public static var textYAlign: VerticalAlignment = .bottom
    public static var textXMargin: Int = 0
    public static var textYMargin: Int = 10
    public static var edgeInsets: EdgeInsets {
        var edgeInsets = EdgeInsets()
        if SubtitleModel.textYAlign == .bottom {
            edgeInsets.bottom = CGFloat(SubtitleModel.textYMargin)
        } else if SubtitleModel.textYAlign == .top {
            edgeInsets.top = CGFloat(SubtitleModel.textYMargin)
        }
        if SubtitleModel.textXAlign == .leading {
            edgeInsets.leading = CGFloat(SubtitleModel.textXMargin)
        } else if SubtitleModel.textXAlign == .trailing {
            edgeInsets.trailing = CGFloat(SubtitleModel.textXMargin)
        }
        return edgeInsets
    }

    private var subtitleDataSouces: [SubtitleDataSouce] = KSOptions.subtitleDataSouces
    public private(set) var subtitleInfos = [any SubtitleInfo]()
    @Published public private(set) var part: SubtitlePart?
    public var subtitleDelay = 0.0 // s
    public var url: URL? {
        didSet {
            subtitleInfos.removeAll()
            subtitleDataSouces.forEach { datasouce in
                addSubtitle(dataSouce: datasouce)
            }
        }
    }

    @Published public var selectedSubtitleInfo: (any SubtitleInfo)? {
        didSet {
            oldValue?.subtitle(isEnabled: false)
            if let selectedSubtitleInfo {
                addSubtitle(info: selectedSubtitleInfo)
                selectedSubtitleInfo.subtitle(isEnabled: true)
            }
        }
    }

    public init() {}

    private func addSubtitle(info: any SubtitleInfo) {
        if subtitleInfos.first(where: { $0.subtitleID == info.subtitleID }) == nil {
            subtitleInfos.append(info)
        }
    }

    public func subtitle(currentTime: TimeInterval) -> Bool {
        let newPart: SubtitlePart?
        if let subtile = selectedSubtitleInfo {
            let currentTime = currentTime - subtile.delay + subtitleDelay
            if let part = subtile.search(for: currentTime) {
                newPart = part
            } else {
                if let part, part.end > part.start, !(part == currentTime) {
                    newPart = nil
                } else {
                    newPart = part
                }
            }
        } else {
            newPart = nil
        }
        // swiftUI不会判断是否相等。所以需要这边判断下。
        if newPart != part {
            part = newPart
            return true
        } else {
            return false
        }
    }

    public func addSubtitle(dataSouce: SubtitleDataSouce) {
        if let dataSouce = dataSouce as? SearchSubtitleDataSouce {
            if let url {
                Task {
                    try? await dataSouce.searchSubtitle(url: url)
                    dataSouce.infos.forEach { info in
                        addSubtitle(info: info)
                    }
                }
            }
        } else {
            dataSouce.infos.forEach { info in
                addSubtitle(info: info)
            }
        }
    }
}
