//
//  PlayerDefines.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
import CoreServices
import SwiftUI

#if canImport(UIKit)
import UIKit

public extension KSOptions {
    @MainActor
    static var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.first as? UIWindowScene
    }

    @MainActor
    static var sceneSize: CGSize {
        let window = windowScene?.windows.first
        return window?.bounds.size ?? .zero
    }
}
#else
import AppKit
import SwiftUI

public typealias UIView = NSView
public typealias UIPasteboard = NSPasteboard
public extension KSOptions {
    static var sceneSize: CGSize {
        NSScreen.main?.frame.size ?? .zero
    }
}
#endif

// extension MediaPlayerTrack {
//    static func == (lhs: Self, rhs: Self) -> Bool {
//        lhs.trackID == rhs.trackID
//    }
// }

public enum DynamicRange: Int32 {
    case sdr = 0
    case hdr10 = 2
    case hlg = 3
    case dolbyVision = 5

    #if canImport(UIKit)
    var hdrMode: AVPlayer.HDRMode {
        switch self {
        case .sdr:
            return AVPlayer.HDRMode(rawValue: 0)
        case .hdr10:
            return .hdr10
        case .hlg:
            return .hlg
        case .dolbyVision:
            return .dolbyVision
        }
    }
    #endif
}

extension DynamicRange: CustomStringConvertible {
    public var description: String {
        switch self {
        case .sdr:
            return "SDR"
        case .hdr10:
            return "HDR10"
        case .hlg:
            return "HDR"
        case .dolbyVision:
            return "Dolby Vision"
        }
    }
}

extension DynamicRange {
    var colorPrimaries: CFString {
        switch self {
        case .sdr:
            return kCVImageBufferColorPrimaries_ITU_R_709_2
        case .hdr10, .hlg, .dolbyVision:
            return kCVImageBufferColorPrimaries_ITU_R_2020
        }
    }

    var transferFunction: CFString {
        switch self {
        case .sdr:
            return kCVImageBufferTransferFunction_ITU_R_709_2
        case .hdr10:
            return kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ
        case .hlg, .dolbyVision:
            return kCVImageBufferTransferFunction_ITU_R_2100_HLG
        }
    }

    var yCbCrMatrix: CFString {
        switch self {
        case .sdr:
            return kCVImageBufferYCbCrMatrix_ITU_R_709_2
        case .hdr10, .hlg, .dolbyVision:
            return kCVImageBufferYCbCrMatrix_ITU_R_2020
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

@MainActor
public enum DisplayEnum {
    case plane
    // swiftlint:disable identifier_name
    case vr
    // swiftlint:enable identifier_name
    case vrBox
}

public struct VideoAdaptationState {
    public struct BitRateState {
        let bitRate: Int64
        let time: TimeInterval
    }

    public let bitRates: [Int64]
    public let duration: TimeInterval
    public internal(set) var fps: Float
    public internal(set) var bitRateStates: [BitRateState]
    public internal(set) var currentPlaybackTime: TimeInterval = 0
    public internal(set) var isPlayable: Bool = false
    public internal(set) var loadedCount: Int = 0
}

public enum ClockProcessType {
    case remain
    case next
    case dropNextFrame
    case dropNextPacket
    case dropGOPPacket
    case flush
    case seek
}

// 缓冲情况
public protocol CapacityProtocol {
    var fps: Float { get }
    var packetCount: Int { get }
    var frameCount: Int { get }
    var frameMaxCount: Int { get }
    var isEndOfFile: Bool { get }
    var mediaType: AVFoundation.AVMediaType { get }
}

extension CapacityProtocol {
    var loadedTime: TimeInterval {
        TimeInterval(packetCount + frameCount) / TimeInterval(fps)
    }
}

public struct LoadingState {
    public let loadedTime: TimeInterval
    public let progress: TimeInterval
    public let packetCount: Int
    public let frameCount: Int
    public let isEndOfFile: Bool
    public let isPlayable: Bool
    public let isFirst: Bool
    public let isSeek: Bool
}

public let KSPlayerErrorDomain = "KSPlayerErrorDomain"

public enum KSPlayerErrorCode: Int {
    case unknown
    case formatCreate
    case formatOpenInput
    case formatOutputCreate
    case formatWriteHeader
    case formatFindStreamInfo
    case readFrame
    case codecContextCreate
    case codecContextSetParam
    case codecContextFindDecoder
    case codesContextOpen
    case codecVideoSendPacket
    case codecAudioSendPacket
    case codecVideoReceiveFrame
    case codecAudioReceiveFrame
    case auidoSwrInit
    case codecSubtitleSendPacket
    case videoTracksUnplayable
    case subtitleUnEncoding
    case subtitleUnParse
    case subtitleFormatUnSupport
    case subtitleParamsEmpty
}

extension KSPlayerErrorCode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .formatCreate:
            return "avformat_alloc_context return nil"
        case .formatOpenInput:
            return "avformat can't open input"
        case .formatOutputCreate:
            return "avformat_alloc_output_context2 fail"
        case .formatWriteHeader:
            return "avformat_write_header fail"
        case .formatFindStreamInfo:
            return "avformat_find_stream_info return nil"
        case .codecContextCreate:
            return "avcodec_alloc_context3 return nil"
        case .codecContextSetParam:
            return "avcodec can't set parameters to context"
        case .codesContextOpen:
            return "codesContext can't Open"
        case .codecVideoReceiveFrame:
            return "avcodec can't receive video frame"
        case .codecAudioReceiveFrame:
            return "avcodec can't receive audio frame"
        case .videoTracksUnplayable:
            return "VideoTracks are not even playable."
        case .codecSubtitleSendPacket:
            return "avcodec can't decode subtitle"
        case .subtitleUnEncoding:
            return "Subtitle encoding format is not supported."
        case .subtitleUnParse:
            return "Subtitle parsing error"
        case .subtitleFormatUnSupport:
            return "Current subtitle format is not supported"
        case .subtitleParamsEmpty:
            return "Subtitle Params is empty"
        case .auidoSwrInit:
            return "swr_init swrContext fail"
        default:
            return "unknown"
        }
    }
}

extension NSError {
    convenience init(errorCode: KSPlayerErrorCode, userInfo: [String: Any] = [:]) {
        var userInfo = userInfo
        userInfo[NSLocalizedDescriptionKey] = errorCode.description
        self.init(domain: KSPlayerErrorDomain, code: errorCode.rawValue, userInfo: userInfo)
    }

    convenience init(description: String) {
        var userInfo = [String: Any]()
        userInfo[NSLocalizedDescriptionKey] = description
        self.init(domain: KSPlayerErrorDomain, code: 0, userInfo: userInfo)
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
        var entrys = [(String, URL, [String: String])]()
        guard let symbol = scanner.scanUpToCharacters(from: .newlines), symbol.contains("#EXTM3U") else {
            return []
        }
        while !scanner.isAtEnd {
            if let entry = scanner.parseM3U() {
                entrys.append(entry)
            }
        }
        return entrys
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

#if !SWIFT_PACKAGE
extension Bundle {
    static let module = Bundle(for: KSPlayerLayer.self).path(forResource: "KSPlayer_KSPlayer", ofType: "bundle").flatMap { Bundle(path: $0) } ?? Bundle.main
}
#endif

public enum TimeType {
    case min
    case hour
    case minOrHour
    case millisecond
}

public extension TimeInterval {
    func toString(for type: TimeType) -> String {
        Int(ceil(self)).toString(for: type)
    }
}

public extension Int {
    func toString(for type: TimeType) -> String {
        var second = self
        var min = second / 60
        second -= min * 60
        switch type {
        case .min:
            return String(format: "%02d:%02d", min, second)
        case .hour:
            let hour = min / 60
            min -= hour * 60
            return String(format: "%d:%02d:%02d", hour, min, second)
        case .minOrHour:
            let hour = min / 60
            if hour > 0 {
                min -= hour * 60
                return String(format: "%d:%02d:%02d", hour, min, second)
            } else {
                return String(format: "%02d:%02d", min, second)
            }
        case .millisecond:
            var time = self * 100
            let millisecond = time % 100
            time /= 100
            let sec = time % 60
            time /= 60
            let min = time % 60
            time /= 60
            let hour = time % 60
            if hour > 0 {
                return String(format: "%d:%02d:%02d.%02d", hour, min, sec, millisecond)
            } else {
                return String(format: "%02d:%02d.%02d", min, sec, millisecond)
            }
        }
    }
}

public extension FixedWidthInteger {
    var kmFormatted: String {
        Double(self).kmFormatted
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
