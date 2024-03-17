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

public class SubtitlePart: CustomStringConvertible, Identifiable {
    public var start: TimeInterval
    public var end: TimeInterval
    public var origin: CGPoint = .zero
    public let text: NSAttributedString?
    public var image: UIImage?
    public var textPosition: TextPosition?
    public var description: String {
        "Subtile Group ==========\nstart: \(start)\nend:\(end)\ntext:\(String(describing: text))"
    }

    public convenience init(_ start: TimeInterval, _ end: TimeInterval, _ string: String) {
        var text = string
        text = text.trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: "\r", with: "")
        self.init(start, end, attributedString: NSAttributedString(string: text))
    }

    public init(_ start: TimeInterval, _ end: TimeInterval, attributedString: NSAttributedString?) {
        self.start = start
        self.end = end
        text = attributedString
    }
}

public struct TextPosition {
    public var verticalAlign: VerticalAlignment = .bottom
    public var horizontalAlign: HorizontalAlignment = .center
    public var leftMargin: CGFloat = 0
    public var rightMargin: CGFloat = 0
    public var verticalMargin: CGFloat = 10
    public var edgeInsets: EdgeInsets {
        var edgeInsets = EdgeInsets()
        if verticalAlign == .bottom {
            edgeInsets.bottom = verticalMargin
        } else if verticalAlign == .top {
            edgeInsets.top = verticalMargin
        }
        if horizontalAlign == .leading {
            edgeInsets.leading = leftMargin
        }
        if horizontalAlign == .trailing {
            edgeInsets.trailing = rightMargin
        }
        return edgeInsets
    }

    public mutating func ass(alignment: String?) {
        switch alignment {
        case "1":
            verticalAlign = .bottom
            horizontalAlign = .leading
        case "2":
            verticalAlign = .bottom
            horizontalAlign = .center
        case "3":
            verticalAlign = .bottom
            horizontalAlign = .trailing
        case "4":
            verticalAlign = .center
            horizontalAlign = .leading
        case "5":
            verticalAlign = .center
            horizontalAlign = .center
        case "6":
            verticalAlign = .center
            horizontalAlign = .trailing
        case "7":
            verticalAlign = .top
            horizontalAlign = .leading
        case "8":
            verticalAlign = .top
            horizontalAlign = .center
        case "9":
            verticalAlign = .top
            horizontalAlign = .trailing
        default:
            break
        }
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
    func search(for time: TimeInterval) -> [SubtitlePart]
}

public protocol SubtitleInfo: KSSubtitleProtocol, AnyObject, Hashable, Identifiable {
    var subtitleID: String { get }
    var name: String { get }
    var delay: TimeInterval { get set }
    //    var userInfo: NSMutableDictionary? { get set }
    //    var subtitleDataSouce: SubtitleDataSouce? { get set }
//    var comment: String? { get }
    var isEnabled: Bool { get set }
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
    public init() {}
}

extension KSSubtitle: KSSubtitleProtocol {
    /// Search for target group for time
    public func search(for time: TimeInterval) -> [SubtitlePart] {
        var result = [SubtitlePart]()
        for part in parts {
            if part == time {
                result.append(part)
            } else if part.start > time {
                break
            }
        }
        return result
    }
}

public extension KSSubtitle {
    func parse(url: URL, userAgent: String? = nil, encoding: String.Encoding? = nil) async throws {
        let data = try await url.data(userAgent: userAgent)
        try parse(data: data, encoding: encoding)
    }

    func parse(data: Data, encoding: String.Encoding? = nil) throws {
        var string: String?
        let encodes = [encoding ?? String.Encoding.utf8,
                       String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),
                       String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
                       String.Encoding.unicode]
        for encode in encodes {
            string = String(data: data, encoding: encode)
            if string != nil {
                break
            }
        }
        guard let subtitle = string else {
            throw NSError(errorCode: .subtitleUnEncoding)
        }
        let scanner = Scanner(string: subtitle)
        _ = scanner.scanCharacters(from: .controlCharacters)
        let parse = KSOptions.subtitleParses.first { $0.canParse(scanner: scanner) }
        if let parse {
            parts = parse.parse(scanner: scanner)
            if parts.count == 0 {
                throw NSError(errorCode: .subtitleUnParse)
            }
        } else {
            throw NSError(errorCode: .subtitleFormatUnSupport)
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
                #if os(tvOS) || os(xrOS)
                return 48
                #elseif os(macOS)
                return 20
                #else
                return 12
                #endif
            case .standard:
                #if os(tvOS) || os(xrOS)
                return 58
                #elseif os(macOS)
                return 26
                #else
                return 16
                #endif
            case .large:
                #if os(tvOS) || os(xrOS)
                return 68
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
    public static var textPosition = TextPosition()
    private var subtitleDataSouces: [SubtitleDataSouce] = KSOptions.subtitleDataSouces
    @Published
    public private(set) var subtitleInfos = [any SubtitleInfo]()
    @Published
    public private(set) var parts = [SubtitlePart]()
    public var subtitleDelay = 0.0 // s
    public var url: URL? {
        didSet {
            subtitleInfos.removeAll()
            searchSubtitle(query: nil, languages: [])
            for datasouce in subtitleDataSouces {
                addSubtitle(dataSouce: datasouce)
            }
            // 要用async，不能在更新UI的时候，修改Publishe变量
            DispatchQueue.main.async { [weak self] in
                self?.parts = []
                self?.selectedSubtitleInfo = nil
            }
        }
    }

    @Published
    public var selectedSubtitleInfo: (any SubtitleInfo)? {
        didSet {
            oldValue?.isEnabled = false
            selectedSubtitleInfo?.isEnabled = true
            if let url, let info = selectedSubtitleInfo as? URLSubtitleInfo, !info.downloadURL.isFileURL, let cache = subtitleDataSouces.first(where: { $0 is CacheSubtitleDataSouce }) as? CacheSubtitleDataSouce {
                cache.addCache(fileURL: url, downloadURL: info.downloadURL)
            }
        }
    }

    public init() {}

    public func addSubtitle(info: any SubtitleInfo) {
        if subtitleInfos.first(where: { $0.subtitleID == info.subtitleID }) == nil {
            subtitleInfos.append(info)
        }
    }

    public func subtitle(currentTime: TimeInterval) -> Bool {
        var newParts = [SubtitlePart]()
        if let subtile = selectedSubtitleInfo {
            let currentTime = currentTime - subtile.delay - subtitleDelay
            newParts = subtile.search(for: currentTime)
            if newParts.isEmpty {
                newParts = parts.filter { part in
                    part.end <= part.start || part == currentTime
                }
            }
        }
        // swiftUI不会判断是否相等。所以需要这边判断下。
        if newParts != parts {
            for part in newParts {
                if let text = part.text as? NSMutableAttributedString {
                    text.addAttributes([.font: SubtitleModel.textFont],
                                       range: NSRange(location: 0, length: text.length))
                }
            }
            parts = newParts
            return true
        } else {
            return false
        }
    }

    public func searchSubtitle(query: String?, languages: [String]) {
        for dataSouce in subtitleDataSouces {
            if let dataSouce = dataSouce as? SearchSubtitleDataSouce {
                subtitleInfos.removeAll { info in
                    dataSouce.infos.contains {
                        $0 === info
                    }
                }
                Task { @MainActor in
                    try? await dataSouce.searchSubtitle(query: query, languages: languages)
                    subtitleInfos.append(contentsOf: dataSouce.infos)
                }
            }
        }
    }

    public func addSubtitle(dataSouce: SubtitleDataSouce) {
        if let dataSouce = dataSouce as? FileURLSubtitleDataSouce {
            Task { @MainActor in
                try? await dataSouce.searchSubtitle(fileURL: url)
                subtitleInfos.append(contentsOf: dataSouce.infos)
            }
        } else {
            subtitleInfos.append(contentsOf: dataSouce.infos)
        }
    }
}
