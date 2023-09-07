//
//  KSParseProtocol.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
#if !canImport(UIKit)
import AppKit
#else
import UIKit
#endif
public protocol KSParseProtocol {
    func canParse(subtitle: String) -> Bool
    func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart?
    func parse(subtitle: String) -> [SubtitlePart]
}

public extension KSOptions {
    static var subtitleParses: [KSParseProtocol] = [SrtParse(), AssParse(), VTTParse()]
}

extension String {
    /// 把字符串时间转为对应的秒
    /// - Parameter fromStr: srt 00:02:52,184 ass0:30:11.56 vtt:00:00.430
    /// - Returns: 秒
    func parseDuration() -> TimeInterval {
        let scanner = Scanner(string: self)

        var hour: Double = 0
        if split(separator: ":").count > 2 {
            hour = scanner.scanDouble() ?? 0.0
            _ = scanner.scanString(":")
        }

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

public extension KSParseProtocol {
    func parse(subtitle: String) -> [SubtitlePart] {
        let reg = try? NSRegularExpression(pattern: "\\{[^}]+\\}", options: .caseInsensitive)
        var groups = [SubtitlePart]()
        let subtitle = subtitle.replacingOccurrences(of: "\r\n\r\n", with: "\n\n")
        let scanner = Scanner(string: subtitle)
        while !scanner.isAtEnd {
            if let group = parse(scanner: scanner, reg: reg) {
                groups.append(group)
            }
        }
        // 归并排序才是稳定排序。系统默认是快排
        groups = groups.mergeSortBottomUp { $0 < $1 }
        // 有的中文字幕和英文字幕分为两个group，所以要合并下
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

public class AssParse: KSParseProtocol {
    private var styleMap = [String: [NSAttributedString.Key: Any]]()
    public func canParse(subtitle: String) -> Bool {
        subtitle.contains("[Script Info]")
    }

    // Dialogue: 0,0:12:37.73,0:12:38.83,Aki Default,,0,0,0,,{\be8}原来如此
    // 875,,Default,NTP,0000,0000,0000,!Effect,- 你们两个别冲这么快\\N- 我会取消所有行程尽快赶过去
    public func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart? {
        let isDialogue = scanner.scanString("Dialogue") != nil
        let start: TimeInterval
        let end: TimeInterval
        var attributes: [NSAttributedString.Key: Any]?
        if isDialogue {
            _ = scanner.scanUpToString(",")
            _ = scanner.scanString(",")
            let startString = scanner.scanUpToString(",")
            _ = scanner.scanString(",")
            let endString = scanner.scanUpToString(",")
            _ = scanner.scanString(",")
            if let style = scanner.scanUpToString(",") {
                _ = scanner.scanString(",")
                attributes = styleMap[style]
            }
            (0 ..< 5).forEach { _ in
                _ = scanner.scanUpToString(",")
                _ = scanner.scanString(",")
            }
            if let startString, let endString {
                start = startString.parseDuration()
                end = endString.parseDuration()
            } else {
                return nil
            }
        } else {
            if scanner.scanString("Format:") != nil {
                parseStyle(scanner: scanner)
            } else {
                _ = scanner.scanUpToCharacters(from: .newlines)
            }
            return nil
        }
        guard var text = scanner.scanUpToCharacters(from: .newlines) else {
            return nil
        }
        text = text.replacingOccurrences(of: "\\N", with: "\n")
        if let reg {
            text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
        }
        return SubtitlePart(start, end, attributedString: NSMutableAttributedString(string: text, attributes: attributes))
    }

    public func parseStyle(scanner: Scanner) {
        _ = scanner.scanString("Format: ")
        guard let keys = scanner.scanUpToCharacters(from: .newlines)?.components(separatedBy: ",") else {
            return
        }
        while scanner.scanString("Style:") != nil {
            _ = scanner.scanString("Format: ")
            guard let values = scanner.scanUpToCharacters(from: .newlines)?.components(separatedBy: ",") else {
                continue
            }
            var dic = [String: String]()
            for i in 1 ..< keys.count {
                dic[keys[i].trimmingCharacters(in: .whitespaces)] = values[i]
            }
            styleMap[values[0]] = dic.parseASSStyle()
        }
    }
}

public extension [String: String] {
    func parseASSStyle() -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let fontName = self["Fontname"], let fontSize = self["Fontsize"].flatMap(Double.init) {
            var fontDescriptor = UIFontDescriptor(name: fontName, size: fontSize)
            var fontTraits: UIFontDescriptor.SymbolicTraits = []
            if self["Bold"] == "1" {
                fontTraits.insert(.traitBold)
            }
            if self["Italic"] == "1" {
                fontTraits.insert(.traitItalic)
            }
            fontDescriptor = fontDescriptor.withSymbolicTraits(fontTraits) ?? fontDescriptor
            if let degrees = self["Angle"].flatMap(Double.init) {
                let radians = CGFloat(degrees * .pi / 180.0)
                #if !canImport(UIKit)
                let matrix = AffineTransform(rotationByRadians: radians)
                #else
                let matrix = CGAffineTransform(rotationAngle: radians)
                #endif
                fontDescriptor = fontDescriptor.withMatrix(matrix)
            }
            let font = UIFont(descriptor: fontDescriptor, size: fontSize)
            attributes[.font] = font
        }
        // 创建字体样式
        if let assColor = self["PrimaryColour"] {
            attributes[.foregroundColor] = UIColor(assColor: assColor)
        }
        if let assColor = self["OutlineColour"] {
            attributes[.strokeColor] = UIColor(assColor: assColor)
        }
        if let assColor = self["BackColour"] {
            attributes[.backgroundColor] = UIColor(assColor: assColor)
        }

        if self["Underline"] == "1" {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if self["StrikeOut"] == "1" {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let scaleX = self["ScaleX"].flatMap(Double.init) {
            attributes[.expansion] = scaleX / 100.0
        }
        if let scaleY = self["ScaleY"].flatMap(Double.init) {
            attributes[.baselineOffset] = scaleY - 100.0
        }

        if let spacing = self["Spacing"].flatMap(Double.init) {
            attributes[.kern] = CGFloat(spacing)
        }

        if self["BorderStyle"] == "1" {
            attributes[.strokeWidth] = -2.0
        }
        // 设置段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        switch self["Alignment"] {
        case "1":
            paragraphStyle.alignment = .center
        case "2":
            paragraphStyle.alignment = .right
        default:
            paragraphStyle.alignment = .left
        }
        if let marginL = self["MarginL"].flatMap(Double.init) {
            paragraphStyle.headIndent = CGFloat(marginL)
        }
        if let marginR = self["MarginR"].flatMap(Double.init) {
            paragraphStyle.tailIndent = CGFloat(marginR)
        }
        if let marginV = self["MarginV"].flatMap(Double.init) {
            paragraphStyle.paragraphSpacing = CGFloat(marginV)
        }
        attributes[.paragraphStyle] = paragraphStyle
        if let shadowOffset = self["Shadow"].flatMap(Double.init),
           let shadowBlur = self["Outline"].flatMap(Double.init),
           shadowOffset != 0.0 || shadowBlur != 0.0
        {
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(width: CGFloat(shadowOffset), height: CGFloat(shadowOffset))
            shadow.shadowBlurRadius = CGFloat(shadowBlur)
            attributes[.shadow] = shadow
        }
        return attributes
    }
}

public class VTTParse: KSParseProtocol {
    public func canParse(subtitle: String) -> Bool {
        subtitle.contains(" --> ") && subtitle.contains("WEBVTT")
    }

    /**
     00:00.430 --> 00:03.380
     简中封装 by Q66
     */
    public func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart? {
        _ = scanner.scanUpToString("\n\n")
        let startString = scanner.scanUpToString(" --> ")
        // skip spaces and newlines by default.
        _ = scanner.scanString("-->")
        if let startString,
           let endString = scanner.scanUpToCharacters(from: .newlines),
           var text = scanner.scanUpToString("\n\n")
        {
            if let reg {
                text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
            }
            return SubtitlePart(startString.parseDuration(), endString.parseDuration(), text)
        }
        return nil
    }
}

public class SrtParse: KSParseProtocol {
    public func canParse(subtitle: String) -> Bool {
        subtitle.contains(" --> ") && !subtitle.contains("WEBVTT")
    }

    /**
     45
     00:02:52,184 --> 00:02:53,617
     {\an4}慢慢来
     */
    public func parse(scanner: Scanner, reg: NSRegularExpression?) -> SubtitlePart? {
        _ = scanner.scanUpToCharacters(from: .newlines)
        let startString = scanner.scanUpToString(" --> ")
        // skip spaces and newlines by default.
        _ = scanner.scanString("-->")
        if let startString,
           let endString = scanner.scanUpToCharacters(from: .newlines),
           var text = scanner.scanUpToString("\n\n")
        {
            if let reg {
                text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
            }
            return SubtitlePart(startString.parseDuration(), endString.parseDuration(), text)
        }
        return nil
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
