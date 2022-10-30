//
//  demo_SPMApp.swift
//  Shared
//
//  Created by kintan on 2021/5/3.
//

import AVFoundation
import AVKit
import KSPlayer
import SwiftUI
#if !canImport(UIKit)
typealias UIHostingController = NSHostingController
typealias UIApplication = NSApplication
#endif
@main
struct DemoApp: App {
    @State private var isImporting: Bool = false
    init() {
        KSOptions.canBackgroundPlay = true
        #if DEBUG
        KSOptions.logLevel = .debug
        #endif
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
//        KSOptions.isLoopPlay = true
        let arguments = ProcessInfo.processInfo.arguments.dropFirst()
        var dropNextArg = false
        var playerArgs = [String]()
        var filenames = [String]()
        for argument in arguments {
            if dropNextArg {
                dropNextArg = false
                continue
            }
            if argument.starts(with: "--") {
                playerArgs.append(argument)
            } else if argument.starts(with: "-") {
                dropNextArg = true
            } else {
                filenames.append(argument)
            }
        }
        if let urlString = filenames.first {
            newPlayerView(KSVideoPlayerView(url: URL(fileURLWithPath: urlString), options: MEOptions()))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.black)
                .onOpenURL { url in
                    open(url: url)
                }
            #if !os(tvOS)
                .onDrop(of: ["public.url", "public.file-url"], isTargeted: nil) { items -> Bool in
                    guard let item = items.first, let identifier = item.registeredTypeIdentifiers.first else {
                        return false
                    }
                    item.loadItem(forTypeIdentifier: identifier, options: nil) { urlData, _ in
                        if let urlData = urlData as? Data {
                            let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                            DispatchQueue.main.async {
                                open(url: url)
                            }
                        }
                    }
                    return true
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.movie, .audio, .data]) { result in
                    guard let url = try? result.get() else {
                        return
                    }
                    open(url: url)
                }
            #endif
//
//            VideoPlayer(player: AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!))
//            AVContentView()
        }
        #if !os(tvOS)
        .commands {
            #if os(macOS)
            CommandGroup(before: .newItem) {
                Button("Open") {
                    isImporting = true
                }.keyboardShortcut("o")
            }
            #endif
        }
        #endif
    }

    private func newPlayerView(_ view: KSVideoPlayerView) {
        let controller = UIHostingController(rootView: view)
        #if os(macOS)
        let win = UIWindow(contentViewController: controller)
        win.makeKeyAndOrderFront(nil)
        if let frame = win.screen?.frame {
            win.setFrame(frame, display: true)
        }
        win.title = view.url.lastPathComponent
        #else
        let win = UIWindow()
        win.rootViewController = controller
        win.makeKey()
        #endif
        win.backgroundColor = .black
    }

    private func open(url: URL) {
        #if os(macOS)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        #endif
        if url.isAudio || url.isMovie {
            newPlayerView(KSVideoPlayerView(url: url, options: MEOptions()))
        } else {
            let controllers = UIApplication.shared.windows.reversed().compactMap {
                #if os(macOS)
                $0.contentViewController as? UIHostingController<KSVideoPlayerView>
                #else
                $0.rootViewController as? UIHostingController<KSVideoPlayerView>
                #endif
            }
            if let hostingController = controllers.first {
                hostingController.becomeFirstResponder()
                hostingController.rootView.subtitleModel.selectedSubtitle = KSURLSubtitle(url: url)
            }
        }
    }
}

// struct AVContentView: View {
//    var body: some View {
//        StructAVPlayerView().frame(width: UIScreen.main.bounds.width, height: 400, alignment: .center)
//    }
// }
//
// struct StructAVPlayerView: UIViewRepresentable {
//    let playerVC = AVPlayerViewController()
//    typealias UIViewType = UIView
//    func makeUIView(context _: Context) -> UIView {
//        playerVC.view
//    }
//
//    func updateUIView(_: UIView, context _: Context) {
//        playerVC.player = AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!)
//    }
// }
var objects: [KSPlayerResource] = {
    var objects = [KSPlayerResource]()
    if let path = Bundle.main.path(forResource: "h264", ofType: "mp4") {
        let options = MEOptions()
        options.videoFilters = "hflip,vflip"
        options.hardwareDecode = false
        options.startPlayTime = 30
        #if os(macOS)
        let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        options.outputURL = moviesDirectory?.appendingPathComponent("recording.mov")
        #endif
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地视频"))
    }
    if let path = Bundle.main.path(forResource: "subrip", ofType: "mkv") {
        let options = KSOptions()
        options.asynchronousDecompression = false
        options.videoFilters = "yadif_videotoolbox=mode=0:parity=auto:deint=1"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "文字字幕"))
    }
    if let path = Bundle.main.path(forResource: "dvd_subtitle", ofType: "mkv") {
        let options = KSOptions()
//        options.videoFilters = "hflip,vflip"
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "图片字幕"))
    }
    if let path = Bundle.main.path(forResource: "vr", ofType: "mp4") {
        let options = KSOptions()
        options.display = .vr
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地全景视频"))
    }
    if let path = Bundle.main.path(forResource: "mjpeg", ofType: "flac") {
        let options = MEOptions()
        options.videoDisable = true
        options.syncDecodeAudio = true
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), options: options, name: "本地音频"))
    }
    if let path = Bundle.main.path(forResource: "hevc", ofType: "mkv") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "h265视频"))
    }

    if let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4") {
        let options = MEOptions()
        options.startPlayTime = 25
        objects.append(KSPlayerResource(url: url, options: options, name: "mp4视频"))
    }

    if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
        let options = MEOptions()
        #if os(macOS)
        let moviesDirectory = try? FileManager.default.url(for: .moviesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        options.outputURL = moviesDirectory?.appendingPathComponent("recording.mp4")
        #endif
        objects.append(KSPlayerResource(url: url, options: options, name: "m3u8视频"))
    }

    if let url = URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "fmp4"))
    }

    if let url = URL(string: "http://116.199.5.51:8114/00000000/hls/index.m3u8?Fsv_chan_hls_se_idx=188&FvSeid=1&Fsv_ctype=LIVES&Fsv_otype=1&Provider_id=&Pcontent_id=.m3u8") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "tvb视频"))
    }

    if let url = URL(string: "http://dash.edgesuite.net/akamai/bbb_30fps/bbb_30fps.mpd") {
        objects.append(KSPlayerResource(url: url, options: KSOptions(), name: "dash视频"))
    }
    if let url = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2019/244gmopitz5ezs2kkq/244/hls_vod_mvp.m3u8") {
        let options = KSOptions()
        objects.append(KSPlayerResource(url: url, options: options, name: "https视频"))
    }

    if let url = URL(string: "rtsp://rtsp.stream/pattern") {
        let options = KSOptions()
        objects.append(KSPlayerResource(url: url, options: options, name: "rtsp video"))
    }

    if let path = Bundle.main.path(forResource: "raw", ofType: "h264") {
        objects.append(KSPlayerResource(url: URL(fileURLWithPath: path), name: "raw h264"))
    }
    return objects
}()

class MEOptions: KSOptions {
    override func process(assetTrack: MediaPlayerTrack) {
        if assetTrack.mediaType == .video {
            if [FFmpegFieldOrder.bb, .bt, .tt, .tb].contains(assetTrack.fieldOrder) {
                videoFilters = "yadif=mode=0:parity=auto:deint=0"
                hardwareDecode = false
            }
        }
    }

    #if os(tvOS)
    override open func preferredDisplayCriteria(refreshRate: Float, videoDynamicRange: Int32) -> AVDisplayCriteria? {
        AVDisplayCriteria(refreshRate: refreshRate, videoDynamicRange: videoDynamicRange)
    }
    #endif
}
