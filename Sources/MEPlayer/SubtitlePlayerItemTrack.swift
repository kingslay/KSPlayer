//
//  SubtitlePlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/11.
//

import ffmpeg
import Foundation
final class SubtitlePlayerItemTrack: FFPlayerItemTrack<SubtitleFrame> {
    private let reg = try? NSRegularExpression(pattern: "\\{[^}]+\\}", options: .caseInsensitive)
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var subtitle = AVSubtitle()
    private var preSubtitleFrame: SubtitleFrame?
    let assetTrack: TrackProtocol
    required init(assetTrack: TrackProtocol, options: KSOptions) {
        self.assetTrack = assetTrack
        super.init(assetTrack: assetTrack, options: options)
        codecContext = assetTrack.stream.pointee.codecpar.ceateContext(options: options)
    }

    override func shutdown() {
        super.shutdown()
        avsubtitle_free(&subtitle)
        if let codecContext = self.codecContext {
            avcodec_close(codecContext)
            avcodec_free_context(&self.codecContext)
        }
    }

    override func getOutputRender(where predicate: ((MEFrame) -> Bool)?) -> MEFrame? {
        return outputRenderQueue.search(where: predicate ?? { _ in true })
    }

    // todo 无缝循环的话，无法处理字幕，导致字幕的内存一直增加。一个暴力的方法是判断数据里面有没有这个数据了
    override func putPacket(packet: Packet) {
        guard let codecContext = codecContext else { return }
        let corePacket = packet.corePacket
        var pktSize = corePacket.pointee.size
        var error: NSError?
        while pktSize > 0 {
            var gotsubtitle = Int32(0)
            let len = avcodec_decode_subtitle2(codecContext, &subtitle, &gotsubtitle, corePacket)
            if len < 0 {
                error = .init(result: len, errorCode: .codecSubtitleSendPacket)
                KSLog(error!)
                break
            }
            let attributedString = subtitle.text(reg: reg)
            let frame = SubtitleFrame()
            frame.timebase = packet.assetTrack.timebase
            frame.position = subtitle.pts
            if frame.position == Int64.min {
                frame.position = max(packet.position, 0)
            }
            let seconds = frame.seconds
            var end = seconds
            if subtitle.end_display_time > 0 {
                end += TimeInterval(subtitle.end_display_time) / 1000
            } else if packet.duration > 0 {
                end += frame.timebase.cmtime(for: packet.duration).seconds
            }
            let part = SubtitlePart(seconds + TimeInterval(subtitle.start_display_time) / 1000, end, attributedString.string)
            if let preSubtitleFrame = preSubtitleFrame, preSubtitleFrame.part == part {
                preSubtitleFrame.part?.text.append(NSAttributedString(string: "\n"))
                preSubtitleFrame.part?.text.append(attributedString)
            } else {
                frame.part = part
                preSubtitleFrame = frame
                outputRenderQueue.push(frame)
            }
            if len == 0 {
                break
            }
            pktSize -= len
        }
    }
}

extension AVSubtitle {
    func text(reg: NSRegularExpression?) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()
        for i in 0 ..< Int(num_rects) {
            guard let rect = rects[i] else {
                continue
            }
            if let text = rect.pointee.text {
                attributedString.append(NSAttributedString(string: String(cString: text)))
            } else if let ass = rect.pointee.ass {
                let scanner = Scanner(string: String(cString: ass))
                if let group = AssParse.parse(scanner: scanner, reg: reg) {
                    attributedString.append(group.text)
                }
            }
        }
        return attributedString
    }
}

extension AVCodecContext {
    func parseASSEvents() -> Int {
        var subtitleASSEvents = 10
        if subtitle_header_size > 0 {
            if let events = String(data: Data(bytes: subtitle_header, count: Int(subtitle_header_size)), encoding: .ascii) {
                if let eventsRange = events.range(of: "[Events]") {
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
            }
        }
        return subtitleASSEvents
    }
}
