//
//  LiveTextImage.swift
//  KSPlayer
//
//  Created by kintan on 2023/5/4.
//

import SwiftUI
#if canImport(VisionKit)
import VisionKit

@available(iOS 16.0, macOS 13.0, macCatalyst 17.0, *)
@MainActor
public struct LiveTextImage: UIViewRepresentable {
    public let uiImage: UIImage
    private let analyzer = ImageAnalyzer()
    #if canImport(UIKit)
    public typealias UIViewType = UIImageView
    private let interaction = ImageAnalysisInteraction()
    public init(uiImage: UIImage) {
        self.uiImage = uiImage
    }

    public func makeUIView(context _: Context) -> UIViewType {
        let imageView = LiveTextImageView()
        imageView.addInteraction(interaction)
        return imageView
    }

    public func updateUIView(_ view: UIViewType, context _: Context) {
        updateView(view)
    }
    #else
    public typealias NSViewType = UIImageView
    @MainActor
    private let interaction = ImageAnalysisOverlayView()
    public func makeNSView(context _: Context) -> NSViewType {
        let imageView = LiveTextImageView()
        interaction.autoresizingMask = [.width, .height]
        interaction.frame = imageView.bounds
        interaction.trackingImageView = imageView
        imageView.addSubview(interaction)
        return imageView
    }

    public func updateNSView(_ view: NSViewType, context _: Context) {
        updateView(view)
    }
    #endif
    @MainActor
    private func updateView(_ view: UIImageView) {
        view.image = uiImage
        view.sizeToFit()
        let image = uiImage
        Task { @MainActor in
            do {
                let configuration = ImageAnalyzer.Configuration([.text])
                let analysis = try await analyzer.analyze(image, orientation: .up, configuration: configuration)
                interaction.preferredInteractionTypes = .textSelection
                interaction.analysis = analysis
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
#endif

#if os(macOS)
public extension Image {
    init(uiImage: UIImage) {
        self.init(nsImage: uiImage)
    }
}
#endif

public extension UIImage {
    func fitRect(_ fitSize: CGSize) -> CGRect {
        let hZoom = fitSize.width / size.width
        let vZoom = fitSize.height / size.height
        let zoom = min(min(hZoom, vZoom), 1)
        let newSize = size * zoom
        return CGRect(origin: CGPoint(x: (fitSize.width - newSize.width) / 2, y: fitSize.height - newSize.height), size: newSize)
    }
}

class LiveTextImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}
