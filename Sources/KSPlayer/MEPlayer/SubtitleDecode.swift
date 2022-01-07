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
    private let reg = AssParse.patternReg()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private let scale = VideoSwresample(dstFormat: AV_PIX_FMT_RGBA, forceTransfer: true)
    private var subtitle = AVSubtitle()
    private var preSubtitleFrame: SubtitleFrame?
    private let timebase: Timebase
    required init(assetTrack: TrackProtocol, options: KSOptions) {
        timebase = assetTrack.timebase
        do {
            codecContext = try assetTrack.stream.pointee.codecpar.pointee.ceateContext(options: options)
        } catch {
            KSLog(error as CustomStringConvertible)
        }
    }

    func decode() {}

    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws -> [MEFrame] {
        guard let codecContext = codecContext else { return [] }
        var pktSize = packet.pointee.size
        var error: NSError?
        var array = [MEFrame]()
        while pktSize > 0 {
            var gotsubtitle = Int32(0)
            let len = avcodec_decode_subtitle2(codecContext, &subtitle, &gotsubtitle, packet)
            if len < 0 {
                error = .init(errorCode: .codecSubtitleSendPacket, ffmpegErrnum: len)
                KSLog(error!)
                break
            }
            let (attributedString, image) = text(subtitle: subtitle)
            let position = max(packet.pointee.pts == Int64.min ? packet.pointee.dts : packet.pointee.pts, 0)
            let seconds = timebase.cmtime(for: position).seconds
            var end = seconds
            if subtitle.end_display_time > 0 {
                end += TimeInterval(subtitle.end_display_time) / 1000.0
            } else if packet.pointee.duration > 0 {
                end += timebase.cmtime(for: packet.pointee.duration).seconds
            }
            let part = SubtitlePart(seconds + TimeInterval(subtitle.start_display_time) / 1000.0, end, attributedString.string)
            part.image = image
            let frame = SubtitleFrame(part: part)
            frame.position = position
            frame.timebase = timebase
            if let preSubtitleFrame = preSubtitleFrame, preSubtitleFrame.part == part {
                preSubtitleFrame.part.text.append(NSAttributedString(string: "\n"))
                preSubtitleFrame.part.text.append(attributedString)
            } else {
                preSubtitleFrame = frame
                array.append(frame)
            }
            if len == 0 {
                break
            }
            pktSize -= len
        }
        return array
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

    private func text(subtitle: AVSubtitle) -> (NSMutableAttributedString, UIImage?) {
        let attributedString = NSMutableAttributedString()
        var image: CGImage?
        for i in 0 ..< Int(subtitle.num_rects) {
            guard let rect = subtitle.rects[i]?.pointee else {
                continue
            }
            if let text = rect.text {
                attributedString.append(NSAttributedString(string: String(cString: text)))
            } else if let ass = rect.ass {
                let scanner = Scanner(string: String(cString: ass))
                if let group = AssParse.parse(scanner: scanner, reg: reg) {
                    attributedString.append(group.text)
                }
            } else if rect.type == SUBTITLE_BITMAP {
                image = scale.transfer(format: AV_PIX_FMT_PAL8, width: rect.w, height: rect.h, data: Array(tuple: rect.data), linesize: Array(tuple: rect.linesize).map { Int($0) })
            }
        }
        return (attributedString, image.map { UIImage(cgImage: $0) })
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
