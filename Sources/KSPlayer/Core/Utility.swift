//
//  Utility.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
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

extension String {
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
