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
    func canParse(scanner: Scanner) -> Bool
    func parsePart(scanner: Scanner) -> SubtitlePart?
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
    func parse(scanner: Scanner) -> [SubtitlePart] {
        var groups = [SubtitlePart]()

        while !scanner.isAtEnd {
            if let group = parsePart(scanner: scanner) {
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
    private let reg = try? NSRegularExpression(pattern: "\\{[^}]+\\}", options: .caseInsensitive)
    private var styleMap = [String: [NSAttributedString.Key: Any]]()
    private var eventKeys = ["Layer", "Start", "End", "Style", "Name", "MarginL", "MarginR", "MarginV", "Effect", "Text"]
    public func canParse(scanner: Scanner) -> Bool {
        guard scanner.scanString("[Script Info]") != nil else {
            return false
        }
        while scanner.scanString("Format:") == nil {
            _ = scanner.scanUpToCharacters(from: .newlines)
        }
        guard var keys = scanner.scanUpToCharacters(from: .newlines)?.components(separatedBy: ",") else {
            return false
        }
        keys = keys.map { $0.trimmingCharacters(in: .whitespaces) }
        while scanner.scanString("Style:") != nil {
            _ = scanner.scanString("Format: ")
            guard let values = scanner.scanUpToCharacters(from: .newlines)?.components(separatedBy: ",") else {
                continue
            }
            var dic = [String: String]()
            for i in 1 ..< keys.count {
                dic[keys[i]] = values[i]
            }
            styleMap[values[0]] = dic.parseASSStyle()
        }
        _ = scanner.scanString("[Events]")
        if scanner.scanString("Format: ") != nil {
            guard let keys = scanner.scanUpToCharacters(from: .newlines)?.components(separatedBy: ",") else {
                return false
            }
            eventKeys = keys.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return true
    }

    // Dialogue: 0,0:12:37.73,0:12:38.83,Aki Default,,0,0,0,,{\be8}原来如此
    // ffmpeg 软解的字幕
    // 875,,Default,NTP,0000,0000,0000,!Effect,- 你们两个别冲这么快\\N- 我会取消所有行程尽快赶过去
    public func parsePart(scanner: Scanner) -> SubtitlePart? {
        let isDialogue = scanner.scanString("Dialogue") != nil
        var dic = [String: String]()
        for i in 0 ..< eventKeys.count {
            if !isDialogue, i == 1 {
                continue
            }
            if i == eventKeys.count - 1 {
                dic[eventKeys[i]] = scanner.scanUpToCharacters(from: .newlines)
            } else {
                dic[eventKeys[i]] = scanner.scanUpToString(",")
                _ = scanner.scanString(",")
            }
        }
        let start: TimeInterval
        let end: TimeInterval
        if let startString = dic["Start"], let endString = dic["End"] {
            start = startString.parseDuration()
            end = endString.parseDuration()
        } else {
            if isDialogue {
                return nil
            } else {
                start = 0
                end = 0
            }
        }
        var attributes: [NSAttributedString.Key: Any]?
        if let style = dic["Style"] {
            attributes = styleMap[style]
        }
        guard var text = dic["Text"] else {
            return nil
        }
        text = text.replacingOccurrences(of: "\\N", with: "\n")
        if let reg {
            text = reg.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: "")
        }
        return SubtitlePart(start, end, attributedString: NSMutableAttributedString(string: text, attributes: attributes))
    }
}

public extension [String: String] {
    func parseASSStyle() -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let fontName = self["Fontname"], let fontSize = self["Fontsize"].flatMap(Double.init) {
            var fontDescriptor = UIFontDescriptor(name: fontName, size: fontSize)
            var fontTraits: UIFontDescriptor.SymbolicTraits = []
            if self["Bold"] == "-1" {
                fontTraits.insert(.traitBold)
            }
            if self["Italic"] == "-1" {
                fontTraits.insert(.traitItalic)
            }
            fontDescriptor = fontDescriptor.withSymbolicTraits(fontTraits) ?? fontDescriptor
            if let degrees = self["Angle"].flatMap(Double.init), degrees != 0 {
                let radians = CGFloat(degrees * .pi / 180.0)
                #if !canImport(UIKit)
                let matrix = AffineTransform(rotationByRadians: radians)
                #else
                let matrix = CGAffineTransform(rotationAngle: radians)
                #endif
                fontDescriptor = fontDescriptor.withMatrix(matrix)
            }
            let font = UIFont(descriptor: fontDescriptor, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            attributes[.font] = font
        }
        // 创建字体样式
        if let assColor = self["PrimaryColour"] {
            attributes[.foregroundColor] = UIColor(assColor: assColor)
        }
        if let assColor = self["OutlineColour"] {
            attributes[.strokeColor] = UIColor(assColor: assColor)
        }

        if self["Underline"] == "-1" {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if self["StrikeOut"] == "-1" {
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
            paragraphStyle.alignment = .left
        case "2":
            paragraphStyle.alignment = .center
        case "3":
            paragraphStyle.alignment = .right
        case "4":
            paragraphStyle.alignment = .left
        case "5":
            paragraphStyle.alignment = .center
        case "6":
            paragraphStyle.alignment = .right
        case "7":
            paragraphStyle.alignment = .left
        case "8":
            paragraphStyle.alignment = .center
        case "9":
            paragraphStyle.alignment = .right
        default:
            paragraphStyle.alignment = .center
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

        if let assColor = self["BackColour"],
           let shadowOffset = self["Shadow"].flatMap(Double.init),
           let shadowBlur = self["Outline"].flatMap(Double.init),
           shadowOffset != 0.0 || shadowBlur != 0.0
        {
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(width: CGFloat(shadowOffset), height: CGFloat(shadowOffset))
            shadow.shadowBlurRadius = CGFloat(shadowBlur)
            shadow.shadowColor = UIColor(assColor: assColor)
            attributes[.shadow] = shadow
        }
        return attributes
    }
}

public class VTTParse: KSParseProtocol {
    private let reg = try? NSRegularExpression(pattern: "\\{[^}]+\\}", options: .caseInsensitive)
    public func canParse(scanner: Scanner) -> Bool {
        scanner.scanString("WEBVTT") != nil
    }

    /**
     00:00.430 --> 00:03.380
     简中封装 by Q66
     */
    public func parsePart(scanner: Scanner) -> SubtitlePart? {
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
    private let reg = try? NSRegularExpression(pattern: "\\{[^}]+\\}", options: .caseInsensitive)
    public func canParse(scanner: Scanner) -> Bool {
        scanner.scanString("WEBVTT") == nil && scanner.string.contains(" --> ")
    }

    /**
     45
     00:02:52,184 --> 00:02:53,617
     {\an4}慢慢来
     */
    public func parsePart(scanner: Scanner) -> SubtitlePart? {
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
