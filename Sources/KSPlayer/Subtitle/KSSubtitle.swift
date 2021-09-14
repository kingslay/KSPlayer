//
//  KSSubtitle.swift
//  Pods
//
//  Created by kintan on 2017/4/2.
//
//
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import CoreFoundation
import CoreGraphics
import Foundation
public class SubtitlePart: CustomStringConvertible, NSMutableCopying {
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: NSMutableAttributedString
    public var image: UIImage?
    public var description: String {
        "Subtile Group ==========\nstart: \(start)\nend:\(end)\ntext:\(text)"
    }

    public convenience init(_ start: TimeInterval, _ end: TimeInterval, _ string: String) {
        var text = string
        text = text.trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: "\r", with: "")
        self.init(start, end, attributedString: NSMutableAttributedString(string: text))
    }

    public init(_ start: TimeInterval, _ end: TimeInterval, attributedString: NSMutableAttributedString) {
        self.start = start
        self.end = end
        text = attributedString
    }

    public func mutableCopy(with _: NSZone? = nil) -> Any {
        // swiftlint:disable force_cast
        SubtitlePart(start, end, attributedString: text.mutableCopy() as! NSMutableAttributedString)
        // swiftlint:enable force_cast
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

public protocol KSSubtitleProtocol: AnyObject {
    func search(for time: TimeInterval) -> SubtitlePart?
}

public func == (lhs: KSSubtitleProtocol, rhs: KSSubtitleProtocol) -> Bool {
    if let lhs = lhs as? KSURLSubtitle, let rhs = rhs as? KSURLSubtitle {
        return lhs.url == rhs.url
    }
    return lhs === rhs
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

public class KSURLSubtitle: KSSubtitle {
    public var url: URL?
    public var parses: [KSParseProtocol] = [SrtParse(), AssParse()]
    public convenience init(url: URL, encoding: String.Encoding? = nil) {
        self.init()
        self.url = url
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                try self.parse(url: url, encoding: encoding)
            } catch {
                NSLog("[Error] failed to load \(url.absoluteString) \(error.localizedDescription)")
            }
        }
    }

    public func parse(url: URL) throws {
        try parse(url: url, encoding: nil)
    }

    public func parse(url: URL, encoding: String.Encoding? = nil) throws {
        self.url = url
        do {
            var string: String?
            let srtData = try Data(contentsOf: url)
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
            let parse = parses.first { $0.canParse(subtitle: subtitle) }
            if let parse = parse {
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
}

extension KSSubtitle: KSSubtitleProtocol {
    /// Search for target group for time
    public func search(for time: TimeInterval) -> SubtitlePart? {
        var index = currentIndex
        if searchIndex(for: time) != nil {
            if currentIndex == index {
                // swiftlint:disable force_cast
                let copy = parts[currentIndex].mutableCopy() as! SubtitlePart
                // swiftlint:enable force_cast
                let text = copy.text
                index = currentIndex + 1
                while index < parts.count, parts[index] == time {
                    text.append(NSAttributedString(string: "\n"))
                    text.append(parts[index].text)
                    index += 1
                }
                return copy
            } else {
                return parts[currentIndex]
            }
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
            let count = group.text.length
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
