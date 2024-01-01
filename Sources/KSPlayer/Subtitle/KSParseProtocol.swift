//
//  KSParseProtocol.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
import SwiftUI
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
    static var subtitleParses: [KSParseProtocol] = [AssParse(), VTTParse(), SrtParse()]
}

public extension String {
    /// 把字符串时间转为对应的秒
    /// - Parameter fromStr: srt 00:02:52,184 ass 0:30:11.56 vtt 00:00.430
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
        return groups
    }
}

public class AssParse: KSParseProtocol {
    private var styleMap = [String: ASSStyle]()
    private var eventKeys = ["Layer", "Start", "End", "Style", "Name", "MarginL", "MarginR", "MarginV", "Effect", "Text"]
    private var playResX = Float(0.0)
    private var playResY = Float(0.0)
    public func canParse(scanner: Scanner) -> Bool {
        guard scanner.scanString("[Script Info]") != nil else {
            return false
        }
        while scanner.scanString("Format:") == nil {
            if scanner.scanString("PlayResX:") != nil {
                playResX = scanner.scanFloat() ?? 0
            } else if scanner.scanString("PlayResY:") != nil {
                playResY = scanner.scanFloat() ?? 0
            } else {
                _ = scanner.scanUpToCharacters(from: .newlines)
            }
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
        var textPosition: TextPosition
        if let style = dic["Style"], let assStyle = styleMap[style] {
            attributes = assStyle.attrs
            textPosition = assStyle.textPosition
            if let marginL = dic["MarginL"].flatMap(Double.init), marginL != 0 {
                textPosition.leftMargin = CGFloat(marginL)
            }
            if let marginR = dic["MarginR"].flatMap(Double.init), marginR != 0 {
                textPosition.rightMargin = CGFloat(marginR)
            }
            if let marginV = dic["MarginV"].flatMap(Double.init), marginV != 0 {
                textPosition.verticalMargin = CGFloat(marginV)
            }
        } else {
            textPosition = TextPosition()
        }
        guard var text = dic["Text"] else {
            return nil
        }
        text = text.replacingOccurrences(of: "\\N", with: "\n")
        text = text.replacingOccurrences(of: "\\n", with: "\n")
        let part = SubtitlePart(start, end, attributedString: text.build(textPosition: &textPosition, attributed: attributes))
        part.textPosition = textPosition
        return part
    }
}

public struct ASSStyle {
    let attrs: [NSAttributedString.Key: Any]
    let textPosition: TextPosition
}

// swiftlint:disable cyclomatic_complexity
extension String {
    func build(textPosition: inout TextPosition, attributed: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
        let lineCodes = splitStyle()
        let attributedStr = NSMutableAttributedString()
        var attributed = attributed ?? [:]
        for lineCode in lineCodes {
            attributedStr.append(lineCode.0.parseStyle(attributes: &attributed, style: lineCode.1, textPosition: &textPosition))
        }
        return attributedStr
    }

    func splitStyle() -> [(String, String?)] {
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil
        var result = [(String, String?)]()
        var sytle: String?
        while !scanner.isAtEnd {
            if scanner.scanString("{") != nil {
                sytle = scanner.scanUpToString("}")
                _ = scanner.scanString("}")
            } else if let text = scanner.scanUpToString("{") {
                result.append((text, sytle))
            } else if let text = scanner.scanUpToCharacters(from: .newlines) {
                result.append((text, sytle))
            }
        }
        return result
    }

    func parseStyle(attributes: inout [NSAttributedString.Key: Any], style: String?, textPosition: inout TextPosition) -> NSAttributedString {
        guard let style else {
            return NSAttributedString(string: self, attributes: attributes)
        }
        var fontName: String?
        var fontSize: Float?
        let subStyleArr = style.components(separatedBy: "\\")
        var shadow = attributes[.shadow] as? NSShadow
        for item in subStyleArr {
            let itemStr = item.replacingOccurrences(of: " ", with: "")
            let scanner = Scanner(string: itemStr)
            let char = scanner.scanCharacter()
            switch char {
            case "a":
                let char = scanner.scanCharacter()
                if char == "n" {
                    textPosition.ass(alignment: scanner.scanUpToCharacters(from: .newlines))
                }
            case "b":
                attributes[.expansion] = scanner.scanFloat()
            case "c":
                attributes[.foregroundColor] = scanner.scanUpToCharacters(from: .newlines).flatMap(UIColor.init(assColor:))
            case "f":
                let char = scanner.scanCharacter()
                if char == "n" {
                    fontName = scanner.scanUpToCharacters(from: .newlines)
                } else if char == "s" {
                    fontSize = scanner.scanFloat()
                }
            case "i":
                attributes[.obliqueness] = scanner.scanFloat()
            case "s":
                if scanner.scanString("had") != nil {
                    if let size = scanner.scanFloat() {
                        shadow = shadow ?? NSShadow()
                        shadow?.shadowOffset = CGSize(width: CGFloat(size), height: CGFloat(size))
                        shadow?.shadowBlurRadius = CGFloat(size)
                    }
                    attributes[.shadow] = shadow
                } else {
                    attributes[.strikethroughStyle] = scanner.scanInt()
                }
            case "u":
                attributes[.underlineStyle] = scanner.scanInt()
            case "1", "2", "3", "4":
                let twoChar = scanner.scanCharacter()
                if twoChar == "c" {
                    let color = scanner.scanUpToCharacters(from: .newlines).flatMap(UIColor.init(assColor:))
                    if char == "1" {
                        attributes[.foregroundColor] = color
                    } else if char == "2" {
                        // 还不知道这个要设置到什么颜色上
//                        attributes[.backgroundColor] = color
                    } else if char == "3" {
                        attributes[.strokeColor] = color
                    } else if char == "4" {
                        shadow = shadow ?? NSShadow()
                        shadow?.shadowColor = color
                        attributes[.shadow] = shadow
                    }
                }
            default:
                break
            }
        }
        // Apply font attributes if available
        if let fontName, let fontSize {
            let font = UIFont(name: fontName, size: CGFloat(fontSize)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
            attributes[.font] = font
        }
        return NSAttributedString(string: self, attributes: attributes)
    }
}

public extension [String: String] {
    func parseASSStyle() -> ASSStyle {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let fontName = self["Fontname"], let fontSize = self["Fontsize"].flatMap(Double.init) {
            var font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            if let degrees = self["Angle"].flatMap(Double.init), degrees != 0 {
                let radians = CGFloat(degrees * .pi / 180.0)
                #if !canImport(UIKit)
                let matrix = AffineTransform(rotationByRadians: radians)
                #else
                let matrix = CGAffineTransform(rotationAngle: radians)
                #endif
                let fontDescriptor = UIFontDescriptor(name: fontName, matrix: matrix)
                font = UIFont(descriptor: fontDescriptor, size: fontSize) ?? font
            }
            attributes[.font] = font
        }
        // 创建字体样式
        if let assColor = self["PrimaryColour"] {
            attributes[.foregroundColor] = UIColor(assColor: assColor)
        }
        // 还不知道这个要设置到什么颜色上
        if let assColor = self["SecondaryColour"] {
//            attributes[.backgroundColor] = UIColor(assColor: assColor)
        }
        if self["Bold"] == "1" {
            attributes[.expansion] = 1
        }
        if self["Italic"] == "1" {
            attributes[.obliqueness] = 1
        }
        if self["Underline"] == "1" {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if self["StrikeOut"] == "1" {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

//        if let scaleX = self["ScaleX"].flatMap(Double.init), scaleX != 100 {
//            attributes[.expansion] = scaleX / 100.0
//        }
//        if let scaleY = self["ScaleY"].flatMap(Double.init), scaleY != 100 {
//            attributes[.baselineOffset] = scaleY - 100.0
//        }

//        if let spacing = self["Spacing"].flatMap(Double.init) {
//            attributes[.kern] = CGFloat(spacing)
//        }

        if self["BorderStyle"] == "1" {
            if let strokeWidth = self["Outline"].flatMap(Double.init), strokeWidth > 0 {
                attributes[.strokeWidth] = -strokeWidth
                if let assColor = self["OutlineColour"] {
                    attributes[.strokeColor] = UIColor(assColor: assColor)
                }
            }
            if let assColor = self["BackColour"],
               let shadowOffset = self["Shadow"].flatMap(Double.init),
               shadowOffset > 0
            {
                let shadow = NSShadow()
                shadow.shadowOffset = CGSize(width: CGFloat(shadowOffset), height: CGFloat(shadowOffset))
                shadow.shadowBlurRadius = shadowOffset
                shadow.shadowColor = UIColor(assColor: assColor)
                attributes[.shadow] = shadow
            }
        }
        var textPosition = TextPosition()
        textPosition.ass(alignment: self["Alignment"])
        if let marginL = self["MarginL"].flatMap(Double.init) {
            textPosition.leftMargin = CGFloat(marginL)
        }
        if let marginR = self["MarginR"].flatMap(Double.init) {
            textPosition.rightMargin = CGFloat(marginR)
        }
        if let marginV = self["MarginV"].flatMap(Double.init) {
            textPosition.verticalMargin = CGFloat(marginV)
        }
        return ASSStyle(attrs: attributes, textPosition: textPosition)
    }
    // swiftlint:enable cyclomatic_complexity
}

public class VTTParse: KSParseProtocol {
    public func canParse(scanner: Scanner) -> Bool {
        let result = scanner.scanString("WEBVTT")
        if result != nil {
            scanner.charactersToBeSkipped = nil
            return true
        } else {
            return false
        }
    }

    /**
     00:00.430 --> 00:03.380
     简中封装 by Q66
     */
    public func parsePart(scanner: Scanner) -> SubtitlePart? {
        var decimal: String?
        repeat {
            decimal = scanner.scanUpToCharacters(from: .newlines)
            _ = scanner.scanCharacters(from: .newlines)
        } while decimal.flatMap(Int.init) == nil
        let startString = scanner.scanUpToString("-->")
        // skip spaces and newlines by default.
        _ = scanner.scanString("-->")
        if let startString,
           let endString = scanner.scanUpToCharacters(from: .newlines)
        {
            _ = scanner.scanCharacters(from: .newlines)
            var text = ""
            var newLine: String? = nil
            repeat {
                if let str = scanner.scanUpToCharacters(from: .newlines) {
                    text += str
                }
                newLine = scanner.scanCharacters(from: .newlines)
                if newLine == "\n" || newLine == "\r\n" {
                    text += "\n"
                }
            } while newLine == "\n" || newLine == "\r\n"
            var textPosition = TextPosition()
            return SubtitlePart(startString.parseDuration(), endString.parseDuration(), attributedString: text.build(textPosition: &textPosition))
        }
        return nil
    }
}

public class SrtParse: KSParseProtocol {
    public func canParse(scanner: Scanner) -> Bool {
        let result = scanner.string.contains(" --> ")
        if result {
            scanner.charactersToBeSkipped = nil
        }
        return result
    }

    /**
     45
     00:02:52,184 --> 00:02:53,617
     {\an4}慢慢来
     */
    public func parsePart(scanner: Scanner) -> SubtitlePart? {
        var decimal: String?
        repeat {
            decimal = scanner.scanUpToCharacters(from: .newlines)
            _ = scanner.scanCharacters(from: .newlines)
        } while decimal.flatMap(Int.init) == nil
        let startString = scanner.scanUpToString("-->")
        // skip spaces and newlines by default.
        _ = scanner.scanString("-->")
        if let startString,
           let endString = scanner.scanUpToCharacters(from: .newlines)
        {
            _ = scanner.scanCharacters(from: .newlines)
            var text = ""
            var newLine: String? = nil
            repeat {
                if let str = scanner.scanUpToCharacters(from: .newlines) {
                    text += str
                }
                newLine = scanner.scanCharacters(from: .newlines)
                if newLine == "\n" || newLine == "\r\n" {
                    text += "\n"
                }
            } while newLine == "\n" || newLine == "\r\n"
            var textPosition = TextPosition()
            return SubtitlePart(startString.parseDuration(), endString.parseDuration(), attributedString: text.build(textPosition: &textPosition))
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
