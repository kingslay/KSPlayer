//
//  File.swift
//
//
//  Created by kintan on 2023/1/9.
//

import AVFoundation
import FFmpeg
import Libavutil

extension OSType {
    func planeCount() -> UInt8 {
        switch self {
        case
            kCVPixelFormatType_48RGB,
            kCVPixelFormatType_32ABGR,
            kCVPixelFormatType_32ARGB,
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_32RGBA,
            kCVPixelFormatType_24BGR,
            kCVPixelFormatType_24RGB,
            kCVPixelFormatType_16BE555,
            kCVPixelFormatType_16LE555,
            kCVPixelFormatType_16BE565,
            kCVPixelFormatType_16LE565,
            kCVPixelFormatType_16BE555,
            kCVPixelFormatType_OneComponent8,
            kCVPixelFormatType_1Monochrome:
            return 1
        case
            kCVPixelFormatType_444YpCbCr8,
            kCVPixelFormatType_4444YpCbCrA8R,
            kCVPixelFormatType_444YpCbCr10,
            kCVPixelFormatType_4444AYpCbCr16,
            kCVPixelFormatType_422YpCbCr8,
            kCVPixelFormatType_422YpCbCr8_yuvs,
            kCVPixelFormatType_422YpCbCr10,
            kCVPixelFormatType_422YpCbCr16,
            kCVPixelFormatType_420YpCbCr8Planar,
            kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            return 3
        default: return 2
        }
    }
}

extension CVPixelBufferPool {
    static func ceate(width: Int32, height: Int32, bytesPerRowAlignment: Int32, pixelFormatType: OSType, bufferCount: Int = 24) -> CVPixelBufferPool? {
        let sourcePixelBufferOptions: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferBytesPerRowAlignmentKey: bytesPerRowAlignment.alignment(value: 64),
            kCVPixelBufferMetalCompatibilityKey: true,
            //            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()
        ]
        var outputPool: CVPixelBufferPool?
        let pixelBufferPoolOptions: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: bufferCount]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferPoolOptions, sourcePixelBufferOptions, &outputPool)
        return outputPool
    }
}

extension AudioUnit {
    var channelLayout: UnsafeMutablePointer<AudioChannelLayout> {
        var size = UInt32(0)
        AudioUnitGetPropertyInfo(self, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Output, 0, &size, nil)
        let data = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<Int8>.alignment)
        AudioUnitGetProperty(self, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Output, 0, data, &size)
        let layout = data.bindMemory(to: AudioChannelLayout.self, capacity: 1)
        let tag = layout.pointee.mChannelLayoutTag
        KSLog("audio unit channelLayout tag: \(tag)")
        if tag == kAudioChannelLayoutTag_UseChannelDescriptions {
            KSLog("audio unit channelLayout channelDescriptions: \(layout.channelDescriptions)")
            return layout
        }
        if tag == kAudioChannelLayoutTag_UseChannelBitmap {
            return layout.pointee.mChannelBitmap.channelLayout
        } else {
            let layout = tag.channelLayout
            KSLog("audio unit channelLayout channelDescriptions: \(layout.channelDescriptions)")
            return layout
        }
    }
}

extension AudioChannelLayoutTag {
    var channelLayout: UnsafeMutablePointer<AudioChannelLayout> {
        var tag = self
        var size = UInt32(0)
        AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutForTag, UInt32(MemoryLayout<AudioChannelLayoutTag>.size), &tag, &size)
        let data = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<Int8>.alignment)
        AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag, UInt32(MemoryLayout<AudioChannelLayoutTag>.size), &tag, &size, data)
        let newLayout = data.bindMemory(to: AudioChannelLayout.self, capacity: 1)
        newLayout.pointee.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions
        return newLayout
    }
}

extension AudioChannelBitmap {
    var channelLayout: UnsafeMutablePointer<AudioChannelLayout> {
        var mChannelBitmap = self
        var size = UInt32(0)
        AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutForBitmap, UInt32(MemoryLayout<AudioChannelBitmap>.size), &mChannelBitmap, &size)
        let data = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<Int8>.alignment)
        AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForBitmap, UInt32(MemoryLayout<AudioChannelBitmap>.size), &mChannelBitmap, &size, data)
        let newLayout = data.bindMemory(to: AudioChannelLayout.self, capacity: 1)
        newLayout.pointee.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions
        return newLayout
    }
}

extension UnsafePointer<AudioChannelLayout> {
    var channelDescriptions: [AudioChannelDescription] {
        return UnsafeMutablePointer(mutating: self).channelDescriptions
    }
}

extension UnsafeMutablePointer<AudioChannelLayout> {
    var channelDescriptions: [AudioChannelDescription] {
        let n = pointee.mNumberChannelDescriptions
        return withUnsafeMutablePointer(to: &pointee.mChannelDescriptions) { start in
            let buffers = UnsafeBufferPointer<AudioChannelDescription>(start: start, count: Int(n))
            return (0 ..< Int(n)).map {
                buffers[$0]
            }
        }
    }
}

extension AVAudioChannelLayout {
    func channelLayout(channelCount: AVAudioChannelCount) -> AVChannelLayout {
        KSLog("KSOptions channelLayout: \(layout.pointee)")
        switch layoutTag {
        case kAudioChannelLayoutTag_Mono: return .init(nb: 1, mask: swift_AV_CH_LAYOUT_MONO)
        case kAudioChannelLayoutTag_Stereo: return .init(nb: 2, mask: swift_AV_CH_LAYOUT_STEREO)
        case kAudioChannelLayoutTag_AAC_3_0: return .init(nb: 3, mask: swift_AV_CH_LAYOUT_SURROUND)
        case kAudioChannelLayoutTag_AAC_4_0: return .init(nb: 4, mask: swift_AV_CH_LAYOUT_4POINT0)
        case kAudioChannelLayoutTag_AAC_Quadraphonic: return .init(nb: 4, mask: swift_AV_CH_LAYOUT_2_2)
        case kAudioChannelLayoutTag_AAC_5_0: return .init(nb: 5, mask: swift_AV_CH_LAYOUT_5POINT0)
        case kAudioChannelLayoutTag_AAC_5_1: return .init(nb: 6, mask: swift_AV_CH_LAYOUT_5POINT1)
        case kAudioChannelLayoutTag_AAC_6_0: return .init(nb: 6, mask: swift_AV_CH_LAYOUT_6POINT0)
        case kAudioChannelLayoutTag_AAC_6_1: return .init(nb: 7, mask: swift_AV_CH_LAYOUT_6POINT1)
        case kAudioChannelLayoutTag_AAC_7_0: return .init(nb: 7, mask: swift_AV_CH_LAYOUT_7POINT0)
        case kAudioChannelLayoutTag_AAC_7_1: return .init(nb: 8, mask: swift_AV_CH_LAYOUT_7POINT1_WIDE)
        case kAudioChannelLayoutTag_MPEG_7_1_C: return .init(nb: 8, mask: swift_AV_CH_LAYOUT_7POINT1)
        case kAudioChannelLayoutTag_AAC_Octagonal: return .init(nb: 8, mask: swift_AV_CH_LAYOUT_OCTAGONAL)
        case kAudioChannelLayoutTag_UseChannelDescriptions:
            var mask = UInt64(0)
            layout.channelDescriptions.forEach { description in
                let label = description.mChannelLabel
                KSLog("KSOptions channelLayout label: \(label)")
                let channel = label.avChannel.rawValue
                KSLog("KSOptions channelLayout avChannel: \(channel)")
                if channel >= 0 {
                    mask |= 1 << channel
                }
            }
            var outChannel = AVChannelLayout()
            // 不能用AV_CHANNEL_ORDER_CUSTOM
            av_channel_layout_from_mask(&outChannel, mask)
            KSLog("out channelLayout mask: \(outChannel.u.mask) nb_channels: \(outChannel.nb_channels)")
            return outChannel
        default:
            var outChannel = AVChannelLayout()
            av_channel_layout_default(&outChannel, Int32(channelCount))
            return outChannel
        }
    }
}

// swiftlint:enable identifier_name
// Some channel abbreviations used below:
// Ts - top surround
// Ltm - left top middle
// Rtm - right top middle
// Lss - left side surround
// Rss - right side surround
// Lb - left bottom
// Rb - Right bottom
// Cb - Center bottom
// Lts - Left top surround
// Rts - Right top surround
// Leos - Left edge of screen
// Reos - Right edge of screen
// Lbs - Left back surround
// Rbs - Right back surround
// Lt - left matrix total. for matrix encoded stereo.
// Rt - right matrix total. for matrix encoded stereo.
extension AudioChannelLabel {
    var avChannel: AVChannel {
        switch self {
        case kAudioChannelLabel_Left:
            // L - left
            return AV_CHAN_FRONT_LEFT
        case kAudioChannelLabel_Right:
            // R - right
            return AV_CHAN_FRONT_RIGHT
        case kAudioChannelLabel_Center:
            // C - center
            return AV_CHAN_FRONT_CENTER
        case kAudioChannelLabel_LFEScreen:
            // Lfe
            return AV_CHAN_LOW_FREQUENCY
        case kAudioChannelLabel_LeftSurround:
            // Ls - left surround
            return AV_CHAN_SIDE_LEFT
        case kAudioChannelLabel_RightSurround:
            // Rs - right surround
            return AV_CHAN_SIDE_RIGHT
        case kAudioChannelLabel_LeftCenter:
            // Lc - left center
            return AV_CHAN_FRONT_LEFT_OF_CENTER
        case kAudioChannelLabel_RightCenter:
            // Rc - right center
            return AV_CHAN_FRONT_RIGHT_OF_CENTER
        case kAudioChannelLabel_CenterSurround:
            // Cs - center surround "Back Center" or plain "Rear Surround"
            return AV_CHAN_BACK_CENTER
        case kAudioChannelLabel_LeftSurroundDirect:
            // Lsd - left surround direct
            return AV_CHAN_SURROUND_DIRECT_LEFT
        case kAudioChannelLabel_RightSurroundDirect:
            // Rsd - right surround direct
            return AV_CHAN_SURROUND_DIRECT_RIGHT
        case kAudioChannelLabel_TopCenterSurround:
            // TS
            return AV_CHAN_TOP_CENTER
        case kAudioChannelLabel_VerticalHeightLeft:
            // Vhl - vertical height left Top Front Left
            return AV_CHAN_TOP_FRONT_LEFT
        case kAudioChannelLabel_VerticalHeightCenter:
            // Vhc - vertical height center Top Front Center
            return AV_CHAN_TOP_FRONT_CENTER
        case kAudioChannelLabel_VerticalHeightRight:
            // Vhr - vertical height right Top Front right
            return AV_CHAN_TOP_FRONT_RIGHT
        case kAudioChannelLabel_TopBackLeft:
            // Ltr - left top rear
            return AV_CHAN_TOP_BACK_LEFT
        case kAudioChannelLabel_TopBackCenter:
            // Ctr - center top rear
            return AV_CHAN_TOP_BACK_CENTER
        case kAudioChannelLabel_TopBackRight:
            // Rtr - right top rear
            return AV_CHAN_TOP_BACK_RIGHT
        case kAudioChannelLabel_RearSurroundLeft:
            // Rls - rear left surround
            return AV_CHAN_BACK_LEFT
        case kAudioChannelLabel_RearSurroundRight:
            // Rrs - rear right surround
            return AV_CHAN_BACK_RIGHT
        case kAudioChannelLabel_LeftWide:
            // Lw - left wide
            return AV_CHAN_WIDE_LEFT
        case kAudioChannelLabel_RightWide:
            // Rw - right wide
            return AV_CHAN_WIDE_RIGHT
        case kAudioChannelLabel_LFE2:
            // LFE2
            return AV_CHAN_LOW_FREQUENCY_2
        case kAudioChannelLabel_Mono:
            // C - center
            return AV_CHAN_FRONT_CENTER
        case kAudioChannelLabel_HeadphonesLeft:
            return AV_CHAN_STEREO_LEFT
        case kAudioChannelLabel_HeadphonesRight:
            return AV_CHAN_STEREO_RIGHT
        default:
            return AV_CHAN_NONE
        }
    }
}
