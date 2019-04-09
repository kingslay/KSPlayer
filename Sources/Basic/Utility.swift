//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
#if os(OSX)
import AppKit
#else
import UIKit
#endif
#if canImport(MobileCoreServices)
import MobileCoreServices.UTType
#endif
open class LayerContainerView: UIView {
    #if os(OSX)
    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer = CAGradientLayer()
    }

    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #else
    open override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    #endif
    public var gradientLayer: CAGradientLayer {
        // swiftlint:disable force_cast
        return layer as! CAGradientLayer
        // swiftlint:enable force_cast
    }
}

public final class KSObservable<Element> {
    public var observer: ((_ oldValue: Element, _ newValue: Element) -> Void)? {
        didSet {
            observer?(value, value)
        }
    }

    public var value: Element {
        didSet {
            observer?(oldValue, value)
        }
    }

    public init(_ value: Element) {
        self.value = value
    }
}

public final class AsyncResult<T> {
    let progress: (Double) -> Void
    let completion: (T) -> Void
    let failure: (Error) -> Void
    public init(progress: @escaping (Double) -> Void, completion: @escaping (T) -> Void, failure: @escaping (Error) -> Void) {
        self.progress = progress
        self.completion = completion
        self.failure = failure
    }
}

class GIFCreator {
    private let destination: CGImageDestination
    private let frameProperties: CFDictionary
    private(set) var firstImage: UIImage?
    init(savePath: URL, imagesCount: Int) {
        do {
            try FileManager.default.removeItem(at: savePath)
        } catch {}
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

extension UIColor {
    public convenience init(hex: Int, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF)
        let green = CGFloat((hex >> 8) & 0xFF)
        let blue = CGFloat(hex & 0xFF)
        self.init(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
    }

    public func createImage(size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
        #else
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
        #endif
    }
}

public extension UIView {
    var widthConstraint: NSLayoutConstraint? {
        // 防止返回NSContentSizeLayoutConstraint
        return constraints.first { $0.isMember(of: NSLayoutConstraint.self) && $0.firstAttribute == .width }
    }

    var heightConstraint: NSLayoutConstraint? {
        // 防止返回NSContentSizeLayoutConstraint
        return constraints.first { $0.isMember(of: NSLayoutConstraint.self) && $0.firstAttribute == .height }
    }

    var rightConstraint: NSLayoutConstraint? {
        return superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .right }
    }

    var leftConstraint: NSLayoutConstraint? {
        return superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .left }
    }

    var topConstraint: NSLayoutConstraint? {
        return superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .top }
    }

    var bottomConstraint: NSLayoutConstraint? {
        return superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .bottom }
    }

    var centerXConstraint: NSLayoutConstraint? {
        return superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .centerX }
    }

    var centerYConstraint: NSLayoutConstraint? {
        return superview?.constraints.first { $0.firstItem === self && $0.firstAttribute == .centerY }
    }

    var safeTopAnchor: NSLayoutYAxisAnchor {
        #if os(macOS)
        return topAnchor
        #else
        if #available(iOS 11.0, tvOS 11.0, *) {
            return self.safeAreaLayoutGuide.topAnchor
        } else {
            return topAnchor
        }
        #endif
    }

    var safeLeftAnchor: NSLayoutXAxisAnchor {
        #if os(macOS)
        return leftAnchor

        #else
        if #available(iOS 11.0, tvOS 11.0, *) {
            return self.safeAreaLayoutGuide.leftAnchor
        } else {
            return leftAnchor
        }
        #endif
    }

    var safeRightAnchor: NSLayoutXAxisAnchor {
        #if os(macOS)
        return rightAnchor

        #else
        if #available(iOS 11.0, tvOS 11.0, *) {
            return self.safeAreaLayoutGuide.rightAnchor
        } else {
            return rightAnchor
        }
        #endif
    }

    var safeBottomAnchor: NSLayoutYAxisAnchor {
        #if os(macOS)
        return bottomAnchor
        #else
        if #available(iOS 11.0, tvOS 11.0, *) {
            return self.safeAreaLayoutGuide.bottomAnchor
        } else {
            return bottomAnchor
        }
        #endif
    }
}

extension CMTime {
    init(seconds: TimeInterval) {
        self.init(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC))
    }
}

extension CMTimeRange {
    init(start: TimeInterval, end: TimeInterval) {
        self.init(start: CMTime(seconds: start), end: CMTime(seconds: end))
    }
}

public extension NSObjectProtocol {
    func image(named: String, bundleName: String? = "KSResources") -> UIImage? {
        var bundle = Bundle(for: type(of: self))
        if let bundleName = bundleName, let resourceURL = bundle.resourceURL, let newBundle = Bundle(url: resourceURL.appendingPathComponent(bundleName + ".bundle")) {
            bundle = newBundle
        }
        #if os(OSX)
        let image = bundle.image(forResource: named)
        #else
        let image = UIImage(named: named, in: bundle, compatibleWith: nil)
        #endif
        return image
    }
}

extension CGSize {
    var reverse: CGSize {
        return CGSize(width: height, height: width)
    }

    var toPoint: CGPoint {
        return CGPoint(x: width, y: height)
    }
}

extension Array {
    init(tuple: (Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7])
    }
}

func * (left: CGSize, right: CGFloat) -> CGSize {
    return CGSize(width: left.width * right, height: left.height * right)
}

func * (left: CGPoint, right: CGFloat) -> CGPoint {
    return CGPoint(x: left.x * right, y: left.y * right)
}

func * (left: CGRect, right: CGFloat) -> CGRect {
    return CGRect(origin: left.origin * right, size: left.size * right)
}

func - (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width - right.width, height: left.height - right.height)
}

public func runInMainqueue(block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

extension AVAsset {
    public func ceateImageGenerator() -> AVAssetImageGenerator {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        return imageGenerator
    }

    public func thumbnailImage(currentTime: CMTime) -> UIImage? {
        let imageGenerator = ceateImageGenerator()
        var cgImage: CGImage?
        do {
            cgImage = try imageGenerator.copyCGImage(at: currentTime, actualTime: nil)
        } catch {
            imageGenerator.requestedTimeToleranceBefore = .positiveInfinity
            imageGenerator.requestedTimeToleranceAfter = .positiveInfinity
            do {
                cgImage = try imageGenerator.copyCGImage(at: currentTime, actualTime: nil)
            } catch {}
        }
        if let cgImage = cgImage {
            return UIImage(cgImage: cgImage)
        } else {
            return nil
        }
    }

    public func generateGIF(beginTime: TimeInterval, endTime: TimeInterval, interval: Double = 0.2, savePath: URL, blockResult: AsyncResult<Bool>) {
        let count = Int(ceil((endTime - beginTime) / interval))
        let timesM = (0 ..< count).map { NSValue(time: CMTime(seconds: beginTime + Double($0) * interval)) }
        let imageGenerator = ceateImageGenerator()
        let gifCreator = GIFCreator(savePath: savePath, imagesCount: count)
        var i = 0
        imageGenerator.generateCGImagesAsynchronously(forTimes: timesM) { _, imageRef, _, result, error in
            switch result {
            case .succeeded:
                guard let imageRef = imageRef else { return }
                i += 1
                gifCreator.add(image: imageRef)
                blockResult.progress(Double(i) / Double(count))
                guard i == count else { return }
                let result = gifCreator.finalize()
                if result {
                    let error = NSError(domain: AVFoundationErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Generate Gif Failed!"])
                    blockResult.failure(error)
                } else {
                    blockResult.completion(result)
                }
            case .failed:
                if let error = error {
                    blockResult.failure(error)
                }
            case .cancelled:
                break
            @unknown default:
                break
            }
        }
    }

    private func ceateComposition(beginTime: TimeInterval, endTime: TimeInterval) throws -> AVMutableComposition {
        let compositionM = AVMutableComposition()
        let audioTrackM = compositionM.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrackM = compositionM.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let cutRange = CMTimeRange(start: beginTime, end: endTime)
        if let assetAudioTrack = tracks(withMediaType: .audio).first {
            try audioTrackM?.insertTimeRange(cutRange, of: assetAudioTrack, at: .zero)
        }
        if let assetVideoTrack = tracks(withMediaType: .video).first {
            try videoTrackM?.insertTimeRange(cutRange, of: assetVideoTrack, at: .zero)
        }
        return compositionM
    }

    func ceateExportSession(beginTime: TimeInterval, endTime: TimeInterval) throws -> AVAssetExportSession? {
        let compositionM = try ceateComposition(beginTime: beginTime, endTime: endTime)
        guard let exportSession = AVAssetExportSession(asset: compositionM, presetName: "") else {
            return nil
        }
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputFileType = .mp4
        return exportSession
    }

    func exportMp4(beginTime: TimeInterval, endTime: TimeInterval, outputURL: URL, blockResult: AsyncResult<URL>) throws {
        try FileManager.default.removeItem(at: outputURL)
        guard let exportSession = try ceateExportSession(beginTime: beginTime, endTime: endTime) else { return }
        exportSession.outputURL = outputURL
        exportSession.exportAsynchronously { [weak exportSession] in
            guard let exportSession = exportSession else {
                return
            }
            switch exportSession.status {
            case .exporting:
                blockResult.progress(Double(exportSession.progress))
            case .completed:
                blockResult.progress(1)
                blockResult.completion(outputURL)
                exportSession.cancelExport()
            case .failed:
                if let error = exportSession.error {
                    blockResult.failure(error)
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

    func exportMp4(beginTime: TimeInterval, endTime: TimeInterval, blockResult: AsyncResult<URL>) throws {
        guard var exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        exportURL = exportURL.appendingPathExtension("Export.mp4")
        try exportMp4(beginTime: beginTime, endTime: endTime, outputURL: exportURL, blockResult: blockResult)
    }
}

extension UIImageView {
    func image(url: URL?) {
        guard let url = url else { return }
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let data = try? Data(contentsOf: url)
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.image = image
            }
        }
    }
}
