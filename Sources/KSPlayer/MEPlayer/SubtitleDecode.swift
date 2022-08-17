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
    required init(assetTrack: AssetTrack, options: KSOptions, delegate: DecodeResultDelegate) {
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
        guard let codecContext = codecContext else {
            delegate?.decodeResult(frame: nil)
            return
        }
        var pktSize = packet.corePacket.pointee.size
        var error: NSError?
        while pktSize > 0 {
            var gotsubtitle = Int32(0)
            let len = avcodec_decode_subtitle2(codecContext, &subtitle, &gotsubtitle, packet.corePacket)
            if len < 0 {
                error = .init(errorCode: .codecSubtitleSendPacket, ffmpegErrnum: len)
                KSLog(error!)
                break
            } else if len == 0 {
                break
            }
            let (attributedString, image) = text(subtitle: subtitle)
            let position = max(packet.corePacket.pointee.pts == Int64.min ? packet.corePacket.pointee.dts : packet.corePacket.pointee.pts, 0)
            let seconds = packet.assetTrack.timebase.cmtime(for: position).seconds
            var end = seconds
            if subtitle.end_display_time > 0, subtitle.end_display_time != UInt32.max {
                end += TimeInterval(subtitle.end_display_time) / 1000.0
            } else if packet.corePacket.pointee.duration > 0 {
                end += packet.assetTrack.timebase.cmtime(for: packet.corePacket.pointee.duration).seconds
            } else {
                end += 2
            }
            let part = SubtitlePart(seconds + TimeInterval(subtitle.start_display_time) / 1000.0, end, attributedString: attributedString)
            part.image = image
            let frame = SubtitleFrame(part: part, timebase: packet.assetTrack.timebase)
            frame.position = position
            if let preSubtitleFrame = preSubtitleFrame, preSubtitleFrame.part == part {
                if let attributedString = attributedString {
                    preSubtitleFrame.part.text?.append(NSAttributedString(string: "\n"))
                    preSubtitleFrame.part.text?.append(attributedString)
                }
            } else {
                preSubtitleFrame = frame
                delegate?.decodeResult(frame: frame)
            }
            pktSize -= len
        }
    }

    func doFlushCodec() {}

    func shutdown() {
        scale.shutdown()
        avsubtitle_free(&subtitle)
        if let codecContext = codecContext {
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
        return (attributedString, CGImage.combine(images: images)?.image())
    }
}

extension AVCodecContext {
    func parseASSEvents() -> Int {
        var subtitleASSEvents = 10
        if subtitle_header_size > 0, let events = String(data: Data(bytes: subtitle_header, count: Int(subtitle_header_size)), encoding: .ascii), let eventsRange = events.range(of: "[Events]") {
            var range = eventsRange.upperBound ..< events.endIndex
            if let eventsRange = events.range(of: "Format:", options: String.CompareOptions(rawValue: 0), range: range, locale: nil) {
                range = eventsRange.upperBound ..< events.endIndex
                if let eventsRange = events.rangeOfCharacter(from: CharacterSet.newlines, options: String.CompareOptions(rawValue: 0), range: range) {
                    range = range.lowerBound ..< eventsRange.upperBound
                    let format = events[range]
                    let fields = format.components(separatedBy: ",")
                    let text = fields.last
                    if let text = text, text.trimmingCharacters(in: .whitespacesAndNewlines) == "Text" {
                        subtitleASSEvents = fields.count
                    }
                }
            }
        }
        return subtitleASSEvents
    }
}
