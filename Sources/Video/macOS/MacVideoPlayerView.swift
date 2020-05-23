//
//  MacVideoPlayerView.swift
//  Pods
//
//  Created by kintan on 2018/10/31.
//

import AppKit
import AVFoundation
extension NSPasteboard.PasteboardType {
    public static let nsURL = NSPasteboard.PasteboardType("NSURL")
    public static let nsFilenames = NSPasteboard.PasteboardType("NSFilenamesPboardType")
}

extension NSDraggingInfo {
    public func getUrl() -> URL? {
        guard let types = draggingPasteboard.types else { return nil }

        if types.contains(.nsFilenames) {
            guard let paths = draggingPasteboard.propertyList(forType: .nsFilenames) as? [String] else { return nil }
            let urls = paths.map { URL(fileURLWithPath: $0) }
            return urls.first
        }
        return nil
    }
}

open class MacVideoPlayerView: VideoPlayerView {
    static let supportedFileExt: [AVMediaType: [String]] = [
        .video: ["mkv", "mp4", "avi", "m4v", "mov", "3gp", "ts", "mts", "m2ts", "wmv", "flv", "f4v", "asf", "webm", "rm", "rmvb", "qt", "dv", "mpg", "mpeg", "mxf", "vob", "gif"],
        .audio: ["mp3", "aac", "mka", "dts", "flac", "ogg", "oga", "mogg", "m4a", "ac3", "opus", "wav", "wv", "aiff", "ape", "tta", "tak"],
        .subtitle: ["utf", "utf8", "utf-8", "idx", "sub", "srt", "smi", "rt", "ssa", "aqt", "jss", "js", "ass", "mks", "vtt", "sup", "scc"],
    ]

    static let playableFileExt = supportedFileExt[.video]! + supportedFileExt[.audio]!

    /// 滑动方向
    private var scrollDirection = KSPanDirection.horizontal
    private var tmpPanValue: Float = 1
    override open func customizeUIComponents() {
        super.customizeUIComponents()
        registerForDraggedTypes([.nsFilenames, .nsURL, .string])
    }

    override open func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        if state == .readyToPlay {
            if let naturalSize = layer.player?.naturalSize {
                window?.aspectRatio = naturalSize
            }
        }
    }
}

extension MacVideoPlayerView {
    override open func updateTrackingAreas() {
        trackingAreas.forEach {
            removeTrackingArea($0)
        }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override open func mouseEntered(with _: NSEvent) {
        isMaskShow = true
    }

    override open func mouseMoved(with _: NSEvent) {
        isMaskShow = true
    }

    override open func mouseExited(with _: NSEvent) {
        isMaskShow = false
    }

    override open func scrollWheel(with event: NSEvent) {
        if event.phase.contains(.began) {
            if event.scrollingDeltaX != 0 {
                scrollDirection = .horizontal
                tmpPanValue = toolBar.timeSlider.value
            } else if event.scrollingDeltaY != 0 {
                scrollDirection = .vertical
                tmpPanValue = 1
            }
        } else if event.phase.contains(.changed) {
            let delta = scrollDirection == .horizontal ? event.scrollingDeltaX : event.scrollingDeltaY
            if scrollDirection == .horizontal {
                tmpPanValue += Float(delta / 10000) * Float(totalTime)
                showSeekToView(second: Double(tmpPanValue), isAdd: delta > 0)
            } else {
                if KSPlayerManager.enableVolumeGestures {
                    tmpPanValue -= Float(delta / 1000)
                    tmpPanValue = max(min(tmpPanValue, 1), 0)
                }
            }
        } else if event.phase.contains(.ended) {
            if scrollDirection == .horizontal {
                slider(value: Double(tmpPanValue), event: .touchUpInside)
                hideSeekToView()
            } else {
                if KSPlayerManager.enableVolumeGestures {
                    playerLayer.player?.playbackVolume = tmpPanValue
                }
            }
        }
    }

    override open var acceptsFirstResponder: Bool {
        true
    }

    override open func keyDown(with event: NSEvent) {
        if let specialKey = event.specialKey {
            if specialKey == .rightArrow {
                slider(value: Double(toolBar.timeSlider.value) + 0.01 * totalTime, event: .touchUpInside)
            } else if specialKey == .leftArrow {
                slider(value: Double(toolBar.timeSlider.value) - 0.01 * totalTime, event: .touchUpInside)
            }
        } else if let character = event.characters?.first {
            if character == " " {
                onButtonPressed(toolBar.playButton)
            }
        }
    }

    override open func draggingEntered(_: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override open func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let url = sender.getUrl() {
            if let set = MacVideoPlayerView.supportedFileExt[.subtitle],
                set.contains(url.pathExtension.lowercased()) {
                resource?.subtitle = KSURLSubtitle(url: url)
                return true
            } else if MacVideoPlayerView.playableFileExt.contains(url.pathExtension.lowercased()) {
                set(resource: KSPlayerResource(url: url, options: KSOptions()))
                return true
            }
        }
        return false
    }
}

class UIActivityIndicatorView: UIView {
    private var loadingView = NSView()
    private var progressLabel = UILabel()
    public var progress: Double = 0 {
        didSet {
            print("new progress: \(progress)")
            progressLabel.stringValue = "\(Int(progress * 100))%"
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backingLayer?.backgroundColor = UIColor(white: 0, alpha: 0.2).cgColor
        setupLoadingView()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLoadingView() {
        loadingView.wantsLayer = true
        addSubview(loadingView)
        let imageView = NSImageView()
        imageView.image = UIImage(ksName: "loading")
        loadingView.addSubview(imageView)
        imageView.imageScaling = .scaleAxesIndependently
        imageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 110),
            heightAnchor.constraint(equalToConstant: 110),
            loadingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingView.widthAnchor.constraint(equalTo: widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: heightAnchor),
            imageView.bottomAnchor.constraint(equalTo: loadingView.bottomAnchor),
            imageView.leftAnchor.constraint(equalTo: loadingView.leftAnchor),
            imageView.heightAnchor.constraint(equalTo: widthAnchor),
            imageView.widthAnchor.constraint(equalTo: heightAnchor),
        ])
        progressLabel.alignment = .center
        progressLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        addSubview(progressLabel)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: loadingView.bottomAnchor, constant: 20),
            progressLabel.widthAnchor.constraint(equalToConstant: 100),
            progressLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
        startAnimating()
    }
}

extension UIActivityIndicatorView: LoadingIndector {
    func startAnimating() {
        loadingView.backingLayer?.position = CGPoint(x: loadingView.layer!.frame.midX, y: loadingView.layer!.frame.midY)
        loadingView.backingLayer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.duration = 1.0
        rotationAnimation.repeatCount = MAXFLOAT
        rotationAnimation.fromValue = 0.0
        rotationAnimation.toValue = Float.pi * -2
        loadingView.backingLayer?.add(rotationAnimation, forKey: "loading")
    }

    func stopAnimating() {
        loadingView.backingLayer?.removeAnimation(forKey: "loading")
    }
}
