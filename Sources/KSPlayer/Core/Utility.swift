//
//  Utility.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CryptoKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
#if canImport(MobileCoreServices)
import MobileCoreServices.UTType
#endif
open class LayerContainerView: UIView {
    #if canImport(UIKit)
    override open class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    #else
    override public init(frame: CGRect) {
        super.init(frame: frame)
        layer = CAGradientLayer()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    public var gradientLayer: CAGradientLayer {
        // swiftlint:disable force_cast
        layer as! CAGradientLayer
        // swiftlint:enable force_cast
    }
}

class GIFCreator {
    private let destination: CGImageDestination
    private let frameProperties: CFDictionary
    private(set) var firstImage: UIImage?
    init(savePath: URL, imagesCount: Int) {
        try? FileManager.default.removeItem(at: savePath)
        frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.25]] as CFDictionary
        destination = CGImageDestinationCreateWithURL(savePath as CFURL, kUTTypeGIF, imagesCount, nil)!
        let fileProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
    }

    func add(image: CGImage) {
        if firstImage == nil {
            firstImage = UIImage(cgImage: image)
        }
        CGImageDestinationAddImage(destination, image, frameProperties)
    }

    func finalize() -> Bool {
        let result = CGImageDestinationFinalize(destination)
        return result
    }
}

public extension String {
    static func systemClockTime(second: Bool = false) -> String {
        let date = Date()
        let calendar = Calendar.current
        let component = calendar.dateComponents([.hour, .minute, .second], from: date)
        if second {
            return String(format: "%02i:%02i:%02i", component.hour!, component.minute!, component.second!)
        } else {
            return String(format: "%02i:%02i", component.hour!, component.minute!)
        }
    }

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

    func md5() -> String {
        Data(utf8).md5()
    }
}

public extension UIColor {
    convenience init?(assColor: String) {
        var colorString = assColor
        // 移除颜色字符串中的前缀 &H 和后缀 &
        if colorString.hasPrefix("&H") {
            colorString = String(colorString.dropFirst(2))
        }
        if colorString.hasSuffix("&") {
            colorString = String(colorString.dropLast())
        }
        if let hex = Scanner(string: colorString).scanInt(representation: .hexadecimal) {
            self.init(abgr: hex)
        } else {
            return nil
        }
    }

    convenience init(abgr hex: Int) {
        let alpha = 1 - (CGFloat(hex >> 24 & 0xFF) / 255)
        let blue = CGFloat((hex >> 16) & 0xFF)
        let green = CGFloat((hex >> 8) & 0xFF)
        let red = CGFloat(hex & 0xFF)
        self.init(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
    }

    convenience init(rgb hex: Int, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF)
        let green = CGFloat((hex >> 8) & 0xFF)
        let blue = CGFloat(hex & 0xFF)
        self.init(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
    }

    func createImage(size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        #if canImport(UIKit)
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
        #else
        let image = NSImage(size: size)
        image.lockFocus()
        drawSwatch(in: CGRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
        #endif
    }
}

extension AVAsset {
    public func generateGIF(beginTime: TimeInterval, endTime: TimeInterval, interval: Double = 0.2, savePath: URL, progress: @escaping (Double) -> Void, completion: @escaping (Error?) -> Void) {
        let count = Int(ceil((endTime - beginTime) / interval))
        let timesM = (0 ..< count).map { NSValue(time: CMTime(seconds: beginTime + Double($0) * interval)) }
        let imageGenerator = ceateImageGenerator()
        let gifCreator = GIFCreator(savePath: savePath, imagesCount: count)
        var i = 0
        imageGenerator.generateCGImagesAsynchronously(forTimes: timesM) { _, imageRef, _, result, error in
            switch result {
            case .succeeded:
                guard let imageRef else { return }
                i += 1
                gifCreator.add(image: imageRef)
                progress(Double(i) / Double(count))
                guard i == count else { return }
                if gifCreator.finalize() {
                    completion(nil)
                } else {
                    let error = NSError(domain: AVFoundationErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Generate Gif Failed!"])
                    completion(error)
                }
            case .failed:
                if let error {
                    completion(error)
                }
            case .cancelled:
                break
            @unknown default:
                break
            }
        }
    }

    private func ceateComposition(beginTime: TimeInterval, endTime: TimeInterval) async throws -> AVMutableComposition {
        let compositionM = AVMutableComposition()
        let audioTrackM = compositionM.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrackM = compositionM.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let cutRange = CMTimeRange(start: beginTime, end: endTime)
        #if os(xrOS)
        if let assetAudioTrack = try await loadTracks(withMediaType: .audio).first {
            try audioTrackM?.insertTimeRange(cutRange, of: assetAudioTrack, at: .zero)
        }
        if let assetVideoTrack = try await loadTracks(withMediaType: .video).first {
            try videoTrackM?.insertTimeRange(cutRange, of: assetVideoTrack, at: .zero)
        }
        #else
        if let assetAudioTrack = tracks(withMediaType: .audio).first {
            try audioTrackM?.insertTimeRange(cutRange, of: assetAudioTrack, at: .zero)
        }
        if let assetVideoTrack = tracks(withMediaType: .video).first {
            try videoTrackM?.insertTimeRange(cutRange, of: assetVideoTrack, at: .zero)
        }
        #endif
        return compositionM
    }

    func ceateExportSession(beginTime: TimeInterval, endTime: TimeInterval) async throws -> AVAssetExportSession? {
        let compositionM = try await ceateComposition(beginTime: beginTime, endTime: endTime)
        guard let exportSession = AVAssetExportSession(asset: compositionM, presetName: "") else {
            return nil
        }
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputFileType = .mp4
        return exportSession
    }

    func exportMp4(beginTime: TimeInterval, endTime: TimeInterval, outputURL: URL, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) throws {
        try FileManager.default.removeItem(at: outputURL)
        Task {
            guard let exportSession = try await ceateExportSession(beginTime: beginTime, endTime: endTime) else { return }
            exportSession.outputURL = outputURL
            await exportSession.export()
            switch exportSession.status {
            case .exporting:
                progress(Double(exportSession.progress))
            case .completed:
                progress(1)
                completion(.success(outputURL))
                exportSession.cancelExport()
            case .failed:
                if let error = exportSession.error {
                    completion(.failure(error))
                }
                exportSession.cancelExport()
            case .cancelled:
                exportSession.cancelExport()
            case .unknown, .waiting:
                break
            @unknown default:
                break
            }
        }
    }

    func exportMp4(beginTime: TimeInterval, endTime: TimeInterval, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) throws {
        guard var exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        exportURL = exportURL.appendingPathExtension("Export.mp4")
        try exportMp4(beginTime: beginTime, endTime: endTime, outputURL: exportURL, progress: progress, completion: completion)
    }
}

extension UIImageView {
    func image(url: URL?) {
        guard let url else { return }
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let data = try? Data(contentsOf: url)
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.image = image
            }
        }
    }
}

#if canImport(UIKit)
extension AVPlayer.HDRMode {
    var dynamicRange: DynamicRange {
        if contains(.dolbyVision) {
            return .dolbyVision
        } else if contains(.hlg) {
            return .hlg
        } else if contains(.hdr10) {
            return .hdr10
        } else {
            return .sdr
        }
    }
}
#endif

public extension FourCharCode {
    var string: String {
        let cString: [CChar] = [
            CChar(self >> 24 & 0xFF),
            CChar(self >> 16 & 0xFF),
            CChar(self >> 8 & 0xFF),
            CChar(self & 0xFF),
            0,
        ]
        return String(cString: cString)
    }
}

extension CMTime {
    init(seconds: TimeInterval) {
        self.init(seconds: seconds, preferredTimescale: Int32(USEC_PER_SEC))
    }
}

extension CMTimeRange {
    init(start: TimeInterval, end: TimeInterval) {
        self.init(start: CMTime(seconds: start), end: CMTime(seconds: end))
    }
}

extension CGPoint {
    var reverse: CGPoint {
        CGPoint(x: y, y: x)
    }
}

extension CGSize {
    var reverse: CGSize {
        CGSize(width: height, height: width)
    }

    var toPoint: CGPoint {
        CGPoint(x: width, y: height)
    }

    var isHorizonal: Bool {
        width > height
    }
}

func * (left: CGSize, right: CGFloat) -> CGSize {
    CGSize(width: left.width * right, height: left.height * right)
}

func * (left: CGPoint, right: CGFloat) -> CGPoint {
    CGPoint(x: left.x * right, y: left.y * right)
}

func * (left: CGRect, right: CGFloat) -> CGRect {
    CGRect(origin: left.origin * right, size: left.size * right)
}

func - (left: CGSize, right: CGSize) -> CGSize {
    CGSize(width: left.width - right.width, height: left.height - right.height)
}

@inline(__always)
@preconcurrency
// @MainActor
public func runOnMainThread(block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        Task {
            await MainActor.run(body: block)
        }
    }
}

public extension URL {
    var isMovie: Bool {
        if let typeID = try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier as CFString? {
            return UTTypeConformsTo(typeID, kUTTypeMovie)
        }
        return false
    }

    var isAudio: Bool {
        if let typeID = try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier as CFString? {
            return UTTypeConformsTo(typeID, kUTTypeAudio)
        }
        return false
    }

    var isSubtitle: Bool {
        ["ass", "srt", "ssa", "vtt"].contains(pathExtension.lowercased())
    }

    var isPlaylist: Bool {
        ["cue", "m3u", "pls"].contains(pathExtension.lowercased())
    }

    func parsePlaylist() async throws -> [(String, URL, [String: String])] {
        let data = try await data()
        var entrys = data.parsePlaylist()
        for i in 0 ..< entrys.count {
            var entry = entrys[i]
            if entry.1.path.hasPrefix("./") {
                entry.1 = deletingLastPathComponent().appendingPathComponent(entry.1.path).standardized
                entrys[i] = entry
            }
        }
        return entrys
    }

    func data(userAgent: String? = nil) async throws -> Data {
        if isFileURL {
            return try Data(contentsOf: self)
        } else {
            var request = URLRequest(url: self)
            if let userAgent {
                request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        }
    }

    func download(userAgent: String? = nil, completion: @escaping ((String, URL) -> Void)) {
        var request = URLRequest(url: self)
        if let userAgent {
            request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        let task = URLSession.shared.downloadTask(with: request) { url, response, _ in
            guard let url, let response else {
                return
            }
            // 下载的临时文件要马上就用。不然可能会马上被清空
            completion(response.suggestedFilename ?? url.lastPathComponent, url)
        }
        task.resume()
    }
}

public extension Data {
    func parsePlaylist() -> [(String, URL, [String: String])] {
        guard let string = String(data: self, encoding: .utf8) else {
            return []
        }
        let scanner = Scanner(string: string)
        guard let symbol = scanner.scanUpToCharacters(from: .newlines) else {
            return []
        }
        if symbol.contains("#EXTM3U") {
            var entrys = [(String, URL, [String: String])]()
            while !scanner.isAtEnd {
                if let entry = scanner.parseM3U() {
                    entrys.append(entry)
                }
            }
            return entrys
        }
        if symbol.contains("[playlist]") {
            return scanner.parsePls()
        }
        return []
    }

    func md5() -> String {
        let digestData = Insecure.MD5.hash(data: self)
        return String(digestData.map { String(format: "%02hhx", $0) }.joined().prefix(32))
    }
}

extension Scanner {
    /*
     #EXTINF:-1 tvg-id="ExampleTV.ua" tvg-logo="https://image.com" group-title="test test", Example TV (720p) [Not 24/7]
     #EXTVLCOPT:http-referrer=http://example.com/
     #EXTVLCOPT:http-user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64)
     http://example.com/stream.m3u8
     */
    func parseM3U() -> (String, URL, [String: String])? {
        if scanString("#EXTINF:") == nil {
            _ = scanUpToCharacters(from: .newlines)
            return nil
        }
        var extinf = [String: String]()
        if let duration = scanDouble() {
            extinf["duration"] = String(duration)
        }
        while scanString(",") == nil {
            let key = scanUpToString("=")
            _ = scanString("=\"")
            let value = scanUpToString("\"")
            _ = scanString("\"")
            if let key, let value {
                extinf[key] = value
            }
        }
        let title = scanUpToCharacters(from: .newlines)
        while scanString("#EXT") != nil {
            if scanString("VLCOPT:") != nil {
                let key = scanUpToString("=")
                _ = scanString("=")
                let value = scanUpToCharacters(from: .newlines)
                if let key, let value {
                    extinf[key] = value
                }
            } else {
                let key = scanUpToString(":")
                _ = scanString(":")
                let value = scanUpToCharacters(from: .newlines)
                if let key, let value {
                    extinf[key] = value
                }
            }
        }
        let urlString = scanUpToCharacters(from: .newlines)
        if let urlString, let url = URL(string: urlString) {
            return (title ?? url.lastPathComponent, url, extinf)
        }
        return nil
    }

    /*
     [playlist]

     File1=https://e20.yesstreaming.net:8279/
     Length1=-1

     File2=example2.mp3
     Title2=Just some local audio that is 2mins long
     Length2=120

     File3=F:\Music\whatever.m4a
     Title3=absolute path on Windows

     File4=%UserProfile%\Music\short.ogg
     Title4=example for an Environment variable
     Length4=5

     NumberOfEntries=4
     Version=2
     */
    func parsePls() -> [(String, URL, [String: String])] {
        var entrys = [(String, URL, [String: String])]()
        var urlMap = [Int: URL]()
        var titleMap = [Int: String]()
        var durationMap = [Int: String]()
        while !isAtEnd {
            if scanString("File") != nil {
                if let key = scanInt(), scanString("=") != nil, let value = scanUpToCharacters(from: .newlines), let url = URL(string: value) {
                    urlMap[key] = url
                }
            } else if scanString("Title") != nil {
                if let key = scanInt(), scanString("=") != nil, let value = scanUpToCharacters(from: .newlines) {
                    titleMap[key] = value
                }
            } else if scanString("Length") != nil {
                if let key = scanInt(), scanString("=") != nil, let value = scanUpToCharacters(from: .newlines) {
                    durationMap[key] = value
                }
            } else if scanString("NumberOfEntries") != nil || scanString("Version") != nil {
                break
            }
        }
        return urlMap.keys.sorted().compactMap { key in
            if let url = urlMap[key] {
                let title = titleMap[key]
                var extinf = [String: String]()
                extinf["duration"] = durationMap[key]
                return (title ?? url.lastPathComponent, url, extinf)
            } else {
                return nil
            }
        }
    }
}

extension HTTPURLResponse {
    var filename: String? {
        let httpFileName = "attachment; filename="
        if var disposition = value(forHTTPHeaderField: "Content-Disposition"), disposition.hasPrefix(httpFileName) {
            disposition.removeFirst(httpFileName.count)
            return disposition
        }
        return nil
    }
}

public extension Double {
    var kmFormatted: String {
        //        return .formatted(.number.notation(.compactName))
        if self >= 1_000_000 {
            return String(format: "%.1fM", locale: Locale.current, self / 1_000_000)
            //                .replacingOccurrences(of: ".0", with: "")
        } else if self >= 10000, self <= 999_999 {
            return String(format: "%.1fK", locale: Locale.current, self / 1000)
            //                .replacingOccurrences(of: ".0", with: "")
        } else {
            return String(format: "%.0f", locale: Locale.current, self)
        }
    }
}

extension TextAlignment: RawRepresentable {
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        if rawValue == "Leading" {
            self = .leading
        } else if rawValue == "Center" {
            self = .center
        } else if rawValue == "Trailing" {
            self = .trailing
        } else {
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .leading:
            return "Leading"
        case .center:
            return "Center"
        case .trailing:
            return "Trailing"
        }
    }
}

extension TextAlignment: Identifiable {
    public var id: Self { self }
}

extension HorizontalAlignment: Hashable, RawRepresentable {
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        if rawValue == "Leading" {
            self = .leading
        } else if rawValue == "Center" {
            self = .center
        } else if rawValue == "Trailing" {
            self = .trailing
        } else {
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .leading:
            return "Leading"
        case .center:
            return "Center"
        case .trailing:
            return "Trailing"
        default:
            return ""
        }
    }
}

extension HorizontalAlignment: Identifiable {
    public var id: Self { self }
}

extension VerticalAlignment: Hashable, RawRepresentable {
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        if rawValue == "Top" {
            self = .top
        } else if rawValue == "Center" {
            self = .center
        } else if rawValue == "Bottom" {
            self = .bottom
        } else {
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .top:
            return "Top"
        case .center:
            return "Center"
        case .bottom:
            return "Bottom"
        default:
            return ""
        }
    }
}

extension VerticalAlignment: Identifiable {
    public var id: Self { self }
}

extension Color: RawRepresentable {
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        guard let data = Data(base64Encoded: rawValue) else {
            self = .black
            return
        }

        do {
            let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) ?? .black
            self = Color(color)
        } catch {
            self = .black
        }
    }

    public var rawValue: RawValue {
        do {
            if #available(macOS 11.0, iOS 14, tvOS 14, *) {
                let data = try NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false) as Data
                return data.base64EncodedString()
            } else {
                return ""
            }
        } catch {
            return ""
        }
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension Date: RawRepresentable {
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8),
              let date = try? JSONDecoder().decode(Date.self, from: data)
        else {
            return nil
        }
        self = date
    }

    public var rawValue: RawValue {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return result
    }
}

extension CGImage {
    static func combine(images: [(CGRect, CGImage)]) -> CGImage? {
        if images.isEmpty {
            return nil
        }
        if images.count == 1 {
            return images[0].1
        }
        var width = 0
        var height = 0
        for (rect, _) in images {
            width = max(width, Int(rect.maxX))
            height = max(height, Int(rect.maxY))
        }
        let bitsPerComponent = 8
        // RGBA(的bytes) * bitsPerComponent *width
        let bytesPerRow = 4 * 8 * bitsPerComponent * width
        return autoreleasepool {
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let context else {
                return nil
            }
            //            context.clear(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
            for (rect, cgImage) in images {
                context.draw(cgImage, in: CGRect(x: rect.origin.x, y: CGFloat(height) - rect.maxY, width: rect.width, height: rect.height))
            }
            let cgImage = context.makeImage()
            return cgImage
        }
    }

    func data(type: AVFileType, quality: CGFloat) -> Data? {
        autoreleasepool {
            guard let mutableData = CFDataCreateMutable(nil, 0),
                  let destination = CGImageDestinationCreateWithData(mutableData, type.rawValue as CFString, 1, nil)
            else {
                return nil
            }
            CGImageDestinationAddImage(destination, self, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                return nil
            }
            return mutableData as Data
        }
    }

    static func make(rgbData: UnsafePointer<UInt8>, linesize: Int, width: Int, height: Int, isAlpha: Bool = false) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = isAlpha ? CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue) : CGBitmapInfo.byteOrderMask
        guard let data = CFDataCreate(kCFAllocatorDefault, rgbData, linesize * height), let provider = CGDataProvider(data: data) else {
            return nil
        }
        // swiftlint:disable line_length
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: isAlpha ? 32 : 24, bytesPerRow: linesize, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        // swiftlint:enable line_length
    }
}

public extension AVFileType {
    static let png = AVFileType(kUTTypePNG as String)
    static let jpeg2000 = AVFileType(kUTTypeJPEG2000 as String)
}

extension URL: Identifiable {
    public var id: Self { self }
}

extension String: Identifiable {
    public var id: Self { self }
}

extension Float: Identifiable {
    public var id: Self { self }
}

public enum Either<Left, Right> {
    case left(Left), right(Right)
}

public extension Either {
    init(_ left: Left, or _: Right.Type) { self = .left(left) }
    init(_ left: Left) { self = .left(left) }
    init(_ right: Right) { self = .right(right) }
}

/// Allows to "box" another value.
final class Box<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

extension Array {
    init(tuple: (Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7])
    }

    init(tuple: (Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3])
    }

    var tuple8: (Element, Element, Element, Element, Element, Element, Element, Element) {
        (self[0], self[1], self[2], self[3], self[4], self[5], self[6], self[7])
    }

    var tuple4: (Element, Element, Element, Element) {
        (self[0], self[1], self[2], self[3])
    }

    // 归并排序才是稳定排序。系统默认是快排
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
