//
//  SubtitlePlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import CoreGraphics
import Foundation
import Libavformat
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
class SubtitleDecode: DecodeProtocol {
    private weak var delegate: DecodeResultDelegate?
    private let reg = AssParse.patternReg()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private let scale = VideoSwresample(dstFormat: AV_PIX_FMT_ARGB)
    private var subtitle = AVSubtitle()
    private var startTime = TimeInterval(0)
    private var preSubtitleFrame: SubtitleFrame?
    required init(assetTrack: FFmpegAssetTrack, options: KSOptions, delegate: DecodeResultDelegate) {
        self.delegate = delegate
        startTime = assetTrack.startTime
        do {
            codecContext = try assetTrack.ceateContext(options: options)
        } catch {
            KSLog(error as CustomStringConvertible)
        }
    }

    func decode() {
        preSubtitleFrame = nil
    }

    func doDecode(packet: Packet) throws {
        guard let codecContext else {
            delegate?.decodeResult(frame: nil)
            return
        }
        var gotsubtitle = Int32(0)
        _ = avcodec_decode_subtitle2(codecContext, &subtitle, &gotsubtitle, packet.corePacket)
        if gotsubtitle == 0 {
            return
        }
        let (origin, attributedString, image) = text(subtitle: subtitle)
        let position = packet.position
        var start = packet.assetTrack.timebase.cmtime(for: position).seconds + TimeInterval(subtitle.start_display_time) / 1000.0
        if start >= startTime {
            start -= startTime
        }
        var duration = TimeInterval(subtitle.end_display_time - subtitle.start_display_time) / 1000.0
        if duration == 0 {
            duration = packet.assetTrack.timebase.cmtime(for: packet.duration).seconds
        }
        let part = SubtitlePart(start, start + duration, attributedString: attributedString)
        part.image = image
        part.origin = origin
        let frame = SubtitleFrame(part: part, timebase: packet.assetTrack.timebase)
        frame.position = position
        if let preSubtitleFrame, preSubtitleFrame.part == part {
            if let attributedString {
                preSubtitleFrame.part.text?.append(NSAttributedString(string: "\n"))
                preSubtitleFrame.part.text?.append(attributedString)
            }
        } else {
            if let preSubtitleFrame, preSubtitleFrame.part.end == preSubtitleFrame.part.start {
                preSubtitleFrame.part.end = frame.part.start
            }
            preSubtitleFrame = frame
            delegate?.decodeResult(frame: frame)
        }
        avsubtitle_free(&subtitle)
    }

    func doFlushCodec() {
        preSubtitleFrame = nil
    }

    func shutdown() {
        scale.shutdown()
        avsubtitle_free(&subtitle)
        if let codecContext {
            avcodec_close(codecContext)
            avcodec_free_context(&self.codecContext)
        }
    }

    private func text(subtitle: AVSubtitle) -> (CGPoint, NSMutableAttributedString?, UIImage?) {
        var attributedString: NSMutableAttributedString?
        var images = [(CGRect, CGImage)]()
        var origin: CGPoint = .zero
        for i in 0 ..< Int(subtitle.num_rects) {
            guard let rect = subtitle.rects[i]?.pointee else {
                continue
            }
            if i == 0 {
                origin = CGPoint(x: Int(rect.x), y: Int(rect.y))
            }
            if let text = rect.text {
                if attributedString == nil {
                    attributedString = NSMutableAttributedString()
                }
                attributedString?.append(NSAttributedString(string: String(cString: text)))
            } else if let ass = rect.ass {
                let scanner = Scanner(string: String(cString: ass))
                if let group = AssParse.parse(scanner: scanner, reg: reg), let text = group.text {
                    if attributedString == nil {
                        attributedString = NSMutableAttributedString()
                    }
                    attributedString?.append(text)
                }
            } else if rect.type == SUBTITLE_BITMAP {
                if let image = scale.transfer(format: AV_PIX_FMT_PAL8, width: rect.w, height: rect.h, data: Array(tuple: rect.data), linesize: Array(tuple: rect.linesize))?.cgImage() {
                    images.append((CGRect(x: Int(rect.x), y: Int(rect.y), width: Int(rect.w), height: Int(rect.h)), image))
                }
            }
        }
        if images.count > 1 {
            origin = .zero
        }
        return (origin, attributedString, CGImage.combine(images: images)?.image(quality: 0.2))
    }
}
