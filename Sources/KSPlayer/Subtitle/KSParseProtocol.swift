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

    /// 把字符串时间转为对应的秒
    /// - Parameter fromStr: srt 00:02:52,184 ass0:30:11.56
    /// - Returns: 秒
    static func parseDuration(_ fromStr: String) -> TimeInterval {
        let scanner = Scanner(string: fromStr)
        let hour = scanner.scanDouble() ?? 0.0
        _ = scanner.scanString(":")
        let min = scanner.scanDouble() ?? 0.0
        _ = scanner.scanString(":")
        let sec = scanner.scanDouble() ?? 0.0
        if scanner.scanString(",") == nil {
            _ = scanner.scanString(".")
        }
        let millisecond = scanner.scanDouble() ?? 0.0
        return (hour * 3600.0) + (min * 60.0) + sec + (millisecond / 1000.0)
    }
}

public class AssParse: KSParseProtocol {
    public func canParse(subtitle: String) -> Bool {
        subtitle.contains("[Script Info]")
    }

    // Dialogue: 0,0:12:37.73,0:12:38.83,Aki Default,,0,0,0,,{\be8}原来如此
    // 875,,Default,NTP,0000,0000,0000,!Effect,- 你们两个别冲这么快\\N- 我会取消所有行程尽快赶过去
    public class func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart? {
        let isDialogue = scanner.scanString("Dialogue") != nil
        let start: TimeInterval
        let end: TimeInterval
        if isDialogue {
            _ = scanner.scanUpToString(",")
            _ = scanner.scanString(",")
            let startString = scanner.scanUpToString(",")
            _ = scanner.scanString(",")
            let endString = scanner.scanUpToString(",")
            _ = scanner.scanString(",")
            (0 ..< 6).forEach { _ in
                _ = scanner.scanUpToString(",")
                _ = scanner.scanString(",")
            }
            if let startString, let endString {
                start = parseDuration(startString)
                end = parseDuration(endString)
            } else {
                return nil
            }
        } else {
            start = 0
            end = 0
            (0 ..< 8).forEach { _ in
                _ = scanner.scanUpToString(",")
                _ = scanner.scanString(",")
            }
        }
        guard var text = scanner.scanUpToCharacters(from: .newlines) else {
            return nil
        }
        text = text.replacingOccurrences(of: "\\N", with: "\n")
        if let reg {
            text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
        }
        return SubtitlePart(start, end, text)
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
                    if let text = group.text {
                        preGroup.text?.append(NSAttributedString(string: "\n"))
                        preGroup.text?.append(text)
                    }
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
        _ = scanner.scanUpToCharacters(from: .newlines)
        let startString = scanner.scanUpToString(" --> ")
        // skip spaces and newlines by default.
        _ = scanner.scanString("-->")
        if let startString,
           let endString = scanner.scanUpToCharacters(from: .newlines),
           var text = scanner.scanUpToString("\r\n\r\n")
        {
            if let reg {
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
