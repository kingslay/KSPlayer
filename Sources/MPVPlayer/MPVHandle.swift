//
//  MPVHandle.swift
//
//
//  Created by kintan on 5/2/24.
//

import Foundation
import KSPlayer
import libmpv
import QuartzCore
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
public class MPVHandle: NSObject, @unchecked Sendable {
    var mpv: OpaquePointer? = mpv_create()
    let metalView: MetalView
    private let queue = DispatchQueue(label: "com.ksplayer.mpv", qos: .userInitiated)
    @MainActor
    public init(options: KSOptions) {
        metalView = MetalView()
        super.init()
        #if DEBUG
        check(status: mpv_request_log_messages(mpv, "debug"))
        #else
        check(status: mpv_request_log_messages(mpv, "no"))
        #endif
        setOption(name: MPVOption.Input.inputMediaKeys, value: "yes")
        var layer = metalView.layer
        check(status: mpv_set_option(mpv, MPVOption.Window.wid, MPV_FORMAT_INT64, &layer))
        setOption(name: "subs-match-os-language", value: "yes")
//        setOption(name: "subs-fallback", value: "yes")
//        setOption(name: MPVOption.Subtitles.subAssOverride, value: "no")
//        setOption(name: MPVOption.GPURendererOptions.targetColorspaceHint, value: "yes")
        setOption(name: MPVOption.Video.vo, value: "gpu-next")
        setOption(name: MPVOption.GPURendererOptions.gpuApi, value: "vulkan")
        setOption(name: MPVOption.GPURendererOptions.gpuContext, value: "moltenvk")
        setOption(name: MPVOption.Video.hwdec, value: "videotoolbox")
        if KSOptions.audioPlayerType == AudioRendererPlayer.self {
            setOption(name: MPVOption.Audio.ao, value: "avfoundation")
        }
        setOption(name: MPVOption.Cache.cacheSecs, value: String(Int(options.maxBufferDuration)))
        setOption(name: MPVOption.Cache.cachePauseWait, value: String(Int(options.preferredForwardBufferDuration)))
        setOption(name: MPVOption.Cache.cachePauseInitial, value: "yes")
        for (k, v) in observeProperties {
            mpv_observe_property(mpv, 0, k, v)
        }
        check(status: mpv_initialize(mpv))
        queue.async { [weak self] in
            guard let self else { return }
            mpv_set_wakeup_callback(mpv, { ctx in
                guard let ctx else {
                    return
                }
                let `self` = unsafeBitCast(ctx, to: MPVHandle.self)
                self.readEvents()
            }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        }
    }

    private func readEvents() {
        queue.async { [weak self] in
            while let self, let mpv, let event = mpv_wait_event(mpv, 0) {
                if event.pointee.event_id == MPV_EVENT_NONE {
                    break
                }
                handle(event: event.pointee)
                if event.pointee.event_id == MPV_EVENT_SHUTDOWN {
                    break
                }
            }
        }
    }

    open func handle(event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_SHUTDOWN:
            mpv_destroy(mpv)
            mpv_set_wakeup_callback(mpv, nil, nil)
            mpv = nil
            KSLog("event: shutdown\n")
        case MPV_EVENT_PROPERTY_CHANGE:
            let dataOpaquePtr = OpaquePointer(event.data)
            if let property = UnsafePointer<mpv_event_property>(dataOpaquePtr)?.pointee {
                let propertyName = String(cString: property.name)
                change(property: property, name: propertyName)
            }
        case MPV_EVENT_LOG_MESSAGE:
            if let msg = UnsafeMutablePointer<mpv_event_log_message>(OpaquePointer(event.data)) {
                KSLog("[\(String(cString: (msg.pointee.prefix)!))] \(String(cString: (msg.pointee.level)!))=\(String(cString: (msg.pointee.text)!))")
            }
        default:
            if let eventName = mpv_event_name(event.event_id) {
                KSLog("eventID \(event.event_id.rawValue) name=\(String(cString: eventName))")
            }
        }
    }

    open func change(property _: mpv_event_property, name _: String) {}
#if DEBUG
    deinit {
        KSLog("")
    }
#endif

    private let observeProperties: [String: mpv_format] = [
        MPVProperty.trackList: MPV_FORMAT_NONE,
        MPVProperty.vf: MPV_FORMAT_NONE,
        MPVProperty.af: MPV_FORMAT_NONE,
        MPVProperty.timePos: MPV_FORMAT_DOUBLE,
        MPVOption.TrackSelection.vid: MPV_FORMAT_INT64,
        MPVOption.TrackSelection.aid: MPV_FORMAT_INT64,
        MPVOption.TrackSelection.sid: MPV_FORMAT_INT64,
        MPVOption.Subtitles.secondarySid: MPV_FORMAT_INT64,
        MPVOption.PlaybackControl.pause: MPV_FORMAT_FLAG,
        MPVOption.PlaybackControl.loopPlaylist: MPV_FORMAT_STRING,
        MPVOption.PlaybackControl.loopFile: MPV_FORMAT_STRING,
        MPVProperty.chapter: MPV_FORMAT_INT64,
        MPVOption.Video.deinterlace: MPV_FORMAT_FLAG,
        MPVOption.Video.hwdec: MPV_FORMAT_STRING,
        MPVOption.Video.videoRotate: MPV_FORMAT_INT64,
        MPVOption.Audio.mute: MPV_FORMAT_FLAG,
        MPVOption.Audio.volume: MPV_FORMAT_DOUBLE,
        MPVOption.Audio.audioDelay: MPV_FORMAT_DOUBLE,
        MPVOption.PlaybackControl.speed: MPV_FORMAT_DOUBLE,
        MPVOption.Subtitles.subDelay: MPV_FORMAT_DOUBLE,
        MPVOption.Subtitles.subScale: MPV_FORMAT_DOUBLE,
        MPVOption.Subtitles.subPos: MPV_FORMAT_DOUBLE,
        MPVOption.Equalizer.contrast: MPV_FORMAT_INT64,
        MPVOption.Equalizer.brightness: MPV_FORMAT_INT64,
        MPVOption.Equalizer.gamma: MPV_FORMAT_INT64,
        MPVOption.Equalizer.hue: MPV_FORMAT_INT64,
        MPVOption.Equalizer.saturation: MPV_FORMAT_INT64,
        MPVOption.Window.fullscreen: MPV_FORMAT_FLAG,
        MPVOption.Window.ontop: MPV_FORMAT_FLAG,
        MPVOption.Window.windowScale: MPV_FORMAT_DOUBLE,
        MPVProperty.mediaTitle: MPV_FORMAT_STRING,
        MPVProperty.videoParamsRotate: MPV_FORMAT_INT64,
        MPVProperty.videoParamsPrimaries: MPV_FORMAT_STRING,
        MPVProperty.videoParamsGamma: MPV_FORMAT_STRING,
        MPVProperty.idleActive: MPV_FORMAT_FLAG,
        MPVProperty.pausedForCache: MPV_FORMAT_FLAG,
    ]
}

extension MPVHandle {
    // MARK: - Command & property

    private func makeCArgs(_ command: MPVCommand, _ args: [String?]) -> [String?] {
        if args.count > 0, args.last == nil {
            KSLog("Command do not need a nil suffix")
        }
        var strArgs = args
        strArgs.insert(command.rawValue, at: 0)
        strArgs.append(nil)
        return strArgs
    }

    /// Send arbitrary mpv command.
    func command(_ command: MPVCommand, args: [String?] = [], checkError: Bool = true) -> Int32 {
        guard let mpv else { return 0 }
        var cargs = makeCArgs(command, args).map { $0.flatMap { UnsafePointer<CChar>(strdup($0)) } }
        defer {
            for ptr in cargs {
                if ptr != nil {
                    free(UnsafeMutablePointer(mutating: ptr!))
                }
            }
        }
        let returnValue = mpv_command(mpv, &cargs)
        if checkError {
            check(status: returnValue)
        }
        return returnValue
    }

    func command(rawString: String) -> Int32 {
        mpv_command_string(mpv, rawString)
    }

    func asyncCommand(_ command: MPVCommand, args: [String?] = [], checkError: Bool = true, replyUserdata: UInt64) {
        guard let mpv else { return }
        var cargs = makeCArgs(command, args).map { $0.flatMap { UnsafePointer<CChar>(strdup($0)) } }
        defer {
            for ptr in cargs {
                if ptr != nil {
                    free(UnsafeMutablePointer(mutating: ptr!))
                }
            }
        }
        let returnValue = mpv_command_async(mpv, replyUserdata, &cargs)
        if checkError {
            check(status: returnValue)
        }
    }

    func observe(property: String, format: mpv_format = MPV_FORMAT_DOUBLE) {
        mpv_observe_property(mpv, 0, property, format)
    }

    /// Set property
    func setFlag(_ name: String, _ flag: Bool) {
        guard let mpv else { return }
        var data: Int = flag ? 1 : 0
        mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &data)
    }

    func setInt(_ name: String, _ value: Int) {
        guard let mpv else { return }
        var data = Int64(value)
        mpv_set_property(mpv, name, MPV_FORMAT_INT64, &data)
    }

    func setDouble(_ name: String, _ value: Double) {
        guard let mpv else { return }
        var data = value
        mpv_set_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
    }

    func setFlagAsync(_ name: String, _ flag: Bool) {
        guard let mpv else { return }
        var data: Int = flag ? 1 : 0
        mpv_set_property_async(mpv, 0, name, MPV_FORMAT_FLAG, &data)
    }

    func setIntAsync(_ name: String, _ value: Int) {
        guard let mpv else { return }
        var data = Int64(value)
        mpv_set_property_async(mpv, 0, name, MPV_FORMAT_INT64, &data)
    }

    func setDoubleAsync(_ name: String, _ value: Double) {
        guard let mpv else { return }
        var data = value
        mpv_set_property_async(mpv, 0, name, MPV_FORMAT_DOUBLE, &data)
    }

    func setString(_ name: String, _ value: String) {
        guard let mpv else { return }
        mpv_set_property_string(mpv, name, value)
    }

    func getInt(_ name: String) -> Int {
        var data = Int64()
        mpv_get_property(mpv, name, MPV_FORMAT_INT64, &data)
        return Int(data)
    }

    func getDouble(_ name: String) -> Double {
        guard let mpv else { return 0.0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }

    func getFlag(_ name: String) -> Bool {
        guard let mpv else { return false }
        var data = Int64()
        mpv_get_property(mpv, name, MPV_FORMAT_FLAG, &data)
        return data > 0
    }

    func getString(_ name: String) -> String? {
        let cstr = mpv_get_property_string(mpv, name)
        let str: String? = cstr == nil ? nil : String(cString: cstr!)
        mpv_free(cstr)
        return str
    }

    func setOption(name: String, value: String) {
        guard let mpv else { return }
        check(status: mpv_set_option_string(mpv, name, value))
    }

    func check(status: CInt) {
        if status < 0 {
            KSLog("MPV API error=\(String(cString: mpv_error_string(status))), Return value=\(status).")
        }
    }
}
