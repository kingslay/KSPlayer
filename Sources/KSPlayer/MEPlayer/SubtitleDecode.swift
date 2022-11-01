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
    private var preSubtitleFrame: SubtitleFrame?
    required init(assetTrack: FFmpegAssetTrack, options: KSOptions, delegate: DecodeResultDelegate) {
        self.delegate = delegate
        assetTrack.setIsEnabled(!assetTrack.isImageSubtitle)
        do {
            codecContext = try assetTrack.stream.pointee.codecpar.pointee.ceateContext(options: options)
        } catch {
            KSLog(error as CustomStringConvertible)
        }
    }

    func decode() {}

    func doDecode(packet: Packet) throws {
        guard let codecContext else {
            delegate?.decodeResult(frame: nil)
            return
        }
        var gotsubtitle = Int32(0)
        let len = avcodec_decode_subtitle2(codecContext, &subtitle, &gotsubtitle, packet.corePacket)
        if len <= 0 {
            return
        }
        let (attributedString, image) = text(subtitle: subtitle)
        let position = packet.position
        let seconds = packet.assetTrack.timebase.cmtime(for: position).seconds - packet.assetTrack.startTime
        var end = seconds
        if subtitle.end_display_time == UInt32.max {
            end = Double(UInt32.max)
        } else if subtitle.end_display_time > 0 {
            end += TimeInterval(subtitle.end_display_time) / 1000.0
        } else if packet.duration > 0 {
            end += packet.assetTrack.timebase.cmtime(for: packet.duration).seconds
        }
        let part = SubtitlePart(seconds + TimeInterval(subtitle.start_display_time) / 1000.0, end, attributedString: attributedString)
        part.image = image
        let frame = SubtitleFrame(part: part, timebase: packet.assetTrack.timebase)
        frame.position = position
        if let preSubtitleFrame, preSubtitleFrame.part.end == Double(UInt32.max) {
            preSubtitleFrame.part.end = frame.part.start
        }
        if let preSubtitleFrame, preSubtitleFrame.part == part {
            if let attributedString {
                preSubtitleFrame.part.text?.append(NSAttributedString(string: "\n"))
                preSubtitleFrame.part.text?.append(attributedString)
            }
        } else {
            preSubtitleFrame = frame
            delegate?.decodeResult(frame: frame)
        }
        if gotsubtitle > 0 {
            avsubtitle_free(&subtitle)
        }
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

    private func text(subtitle: AVSubtitle) -> (NSMutableAttributedString?, UIImage?) {
        var attributedString: NSMutableAttributedString?
        var images = [(CGRect, CGImage)]()
        for i in 0 ..< Int(subtitle.num_rects) {
            guard let rect = subtitle.rects[i]?.pointee else {
                continue
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
        return (attributedString, CGImage.combine(images: images)?.image(quality: 0.2))
    }
}
