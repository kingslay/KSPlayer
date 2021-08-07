//
//  KSParseProtocol.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
public protocol KSParseProtocol {
    func canParse(subtitle: String) -> Bool
    func parse(subtitle: String) -> [SubtitlePart]
}

public extension KSParseProtocol {
    static func patternReg() -> NSRegularExpression? {
        try? NSRegularExpression(pattern: "\\{[^}]+\\}", options: .caseInsensitive)
    }

    static func parseDuration(_ fromStr: String) -> TimeInterval {
        var hour: TimeInterval = 0.0, min: TimeInterval = 0.0, sec: TimeInterval = 0.0, millisecond: TimeInterval = 0.0
        let scanner = Scanner(string: fromStr)
        scanner.scanDouble(&hour)
        scanner.scanString(":", into: nil)
        scanner.scanDouble(&min)
        scanner.scanString(":", into: nil)
        scanner.scanDouble(&sec)
        if !scanner.scanString(",", into: nil) {
            scanner.scanString(".", into: nil)
        }
        scanner.scanDouble(&millisecond)
        return (hour * 3600.0) + (min * 60.0) + sec + (millisecond / 1000.0)
    }
}

public class AssParse: KSParseProtocol {
    public func canParse(subtitle: String) -> Bool {
        subtitle.contains("[Script Info]")
    }

    // Dialogue: 0,0:12:37.73,0:12:38.83,Aki Default,,0,0,0,,{\be8}原来如此
    public class func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart? {
        guard scanner.scanString("Dialogue:", into: nil) else {
            scanner.scanUpToCharacters(from: .newlines, into: nil)
            return nil
        }
        scanner.scanUpTo(",", into: nil)
        scanner.scanString(",", into: nil)
        var startString: NSString?
        scanner.scanUpTo(",", into: &startString)
        scanner.scanString(",", into: nil)
        var endString: NSString?
        scanner.scanUpTo(",", into: &endString)
        scanner.scanString(",", into: nil)
        (0 ..< 6).forEach { _ in
            scanner.scanUpTo(",", into: nil)
            scanner.scanString(",", into: nil)
        }
        var textString: NSString?
        scanner.scanUpToCharacters(from: .newlines, into: &textString)
        guard var text = textString as String? else {
            return nil
        }
        text = text.replacingOccurrences(of: "\\N", with: "\n")
        if let reg = reg {
            text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
        }
        if let startString = startString as String?, let endString = endString as String? {
            let start = parseDuration(startString)
            let end = parseDuration(endString)
            return SubtitlePart(start, end, text)
        }
        return nil
    }

    public func parse(subtitle: String) -> [SubtitlePart] {
        let reg = AssParse.patternReg()
        var groups = [SubtitlePart]()
        let scanner = Scanner(string: subtitle)
        while !scanner.isAtEnd {
            if let group = AssParse.parse(scanner: scanner, reg: reg) {
                groups.append(group)
            }
        }
        // 归并排序才是稳定排序。系统默认是快排
        groups = groups.mergeSortBottomUp { $0 < $1 }
        if var preGroup = groups.first {
            var newGroups = [SubtitlePart]()
            for i in 1 ..< groups.count {
                let group = groups[i]
                if preGroup == group {
                    preGroup.text.append(NSAttributedString(string: "\n"))
                    preGroup.text.append(group.text)
                } else {
                    newGroups.append(preGroup)
                    preGroup = group
                }
            }
            newGroups.append(preGroup)
            groups = newGroups
        }
        return groups
    }
}

public class SrtParse: KSParseProtocol {
    public func canParse(subtitle: String) -> Bool {
        subtitle.contains(" --> ")
    }

    /**
     45
     00:02:52,184 --> 00:02:53,617
     {\an4}慢慢来
     */
    public class func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart? {
        scanner.scanUpToCharacters(from: .newlines, into: nil)
        var startString: NSString?
        scanner.scanUpTo(" --> ", into: &startString)
        // skip spaces and newlines by default.
        scanner.scanString("-->", into: nil)
        var endString: NSString?
        scanner.scanUpToCharacters(from: .newlines, into: &endString)
        var textString: NSString?
        scanner.scanUpTo("\r\n\r\n", into: &textString)
        if let startString = startString as String?, let endString = endString as String?, var text = textString as String? {
            if let reg = reg {
                text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
            }
            return SubtitlePart(AssParse.parseDuration(startString), AssParse.parseDuration(endString), text)
        }
        return nil
    }

    public func parse(subtitle: String) -> [SubtitlePart] {
        let reg = AssParse.patternReg()
        var groups = [SubtitlePart]()
        let scanner = Scanner(string: subtitle)
        while !scanner.isAtEnd {
            if let group = SrtParse.parse(scanner: scanner, reg: reg) {
                groups.append(group)
            }
        }
        return groups
    }
}

private extension Array {
    func mergeSortBottomUp(isOrderedBefore: (Element, Element) -> Bool) -> [Element] {
        let n = count
        var z = [self, self] // the two working arrays
        var d = 0 // z[d] is used for reading, z[1 - d] for writing
        var width = 1
        while width < n {
            var i = 0
            while i < n {
                var j = i
                var l = i
                var r = i + width

                let lmax = Swift.min(l + width, n)
                let rmax = Swift.min(r + width, n)

                while l < lmax, r < rmax {
                    if isOrderedBefore(z[d][l], z[d][r]) {
                        z[1 - d][j] = z[d][l]
                        l += 1
                    } else {
                        z[1 - d][j] = z[d][r]
                        r += 1
                    }
                    j += 1
                }
                while l < lmax {
                    z[1 - d][j] = z[d][l]
                    j += 1
                    l += 1
                }
                while r < rmax {
                    z[1 - d][j] = z[d][r]
                    j += 1
                    r += 1
                }

                i += width * 2
            }

            width *= 2 // in each step, the subarray to merge becomes larger
            d = 1 - d // swap active array
        }
        return z[d]
    }
}
