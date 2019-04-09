//
//  PanoramaPlayer.swift
//  KSPlayer-0677b3ec
//
//  Created by kintan on 2018/7/11.
//
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
public class KSVRPlayer: KSMEPlayer {
    open override var renderViewType: (PixelRenderView & UIView).Type {
        #if arch(arm64) || os(macOS)
        return PanoramaView.self
        #else
        return OpenGLVRPlayView.self
        #endif
    }

    public override var pixelFormatType: OSType {
        #if arch(arm64) || os(macOS)
        return kCVPixelFormatType_32BGRA
        #else
        return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        #endif
    }
}
