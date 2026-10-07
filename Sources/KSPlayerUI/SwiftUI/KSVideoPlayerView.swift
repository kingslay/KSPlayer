//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import Combine
import KSPlayer
import MediaPlayer
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
@MainActor
public struct KSVideoPlayerView: View {
    @StateObject
    private var model: KSVideoPlayerModel
    private let subtitleDataSource: SubtitleDataSource?
    private let liftCycleBlock: ((KSVideoPlayer.Coordinator, Bool) -> Void)?
    @Environment(\.dismiss)
    private var dismiss
    /// 为了解决单击、双击全屏误触长按手势
    @State
    private var longPressSuccess = false

    public init(model: StateObject<KSVideoPlayerModel>, subtitleDataSource: SubtitleDataSource? = nil, liftCycleBlock: ((KSVideoPlayer.Coordinator, Bool) -> Void)? = nil) {
        _model = model
        self.subtitleDataSource = subtitleDataSource ?? model.wrappedValue
        self.liftCycleBlock = liftCycleBlock
    }

    public var body: some View {
        if let url = model.url {
            ZStack(alignment: .topLeading) {
                KSCorePlayerView(config: model.config, url: url, options: model.options, title: $model.title, subtitleDataSource: subtitleDataSource)
                    .onAppear {
                        if model.urls.count > 1 {
                            (model.config.playerLayer as? KSComplexPlayerLayer)?.set(urls: model.urls.map(\.url))
                        }
                        liftCycleBlock?(model.config, false)
                    }
                    .onDisappear {
                        liftCycleBlock?(model.config, true)
                    }
                    // onChange不会马上就回调，会少一些状态的回调。要用onReceive才不会有这个问题
                    .onReceive(model.config.$state) { state in
                        if state == .readyToPlay {
                            #if os(iOS)
                            if let playerLayer = model.config.playerLayer, playerLayer.player.naturalSize.isHorizonal == true, !UIApplication.isLandscape {
                                KSOptions.supportedInterfaceOrientations = .landscapeRight
                                UIViewController.attemptRotationToDeviceOrientation()
                            }
                            #endif
                        }
                    }
#if os(macOS) || os(iOS) || os(visionOS)
                    .onLongPressGesture(minimumDuration: 1) {
                        model.config.playbackRate = 2
                        longPressSuccess = true
                    } onPressingChanged: { flag in
                        if !flag, longPressSuccess {
                            longPressSuccess = false
                            model.config.playbackRate = 1
                        }
                    }
#endif
                if KSOptions.hudLog, let playerLayer = model.config.playerLayer {
                    HUDLogView(dynamicInfo: playerLayer.player.dynamicInfo)
                }
                // 需要放在这里才能生效
                #if canImport(UIKit)
                GestureView { direction in
                    switch direction {
                    case .left:
                        model.config.skip(interval: -15)
                    case .right:
                        model.config.skip(interval: 15)
                    default:
                        model.config.isMaskShow = true
                    }
                } pressAction: { direction in
                    if !model.config.isMaskShow {
                        switch direction {
                        case .left:
                            model.config.skip(interval: -15)
                        case .right:
                            model.config.skip(interval: 15)
                        case .up:
                            model.config.mask(show: true, autoHide: false)
                        case .down:
                            model.showVideoSetting = true
                        default:
                            break
                        }
                    }
                } toucheAction: {
                    model.config.mask(show: true, autoHide: false)
                }
                .isFocused($model.focusableView, equals: .play)
                .opacity(!model.config.isMaskShow ? 1 : 0)
                #endif
                controllerView
                    .sheet(isPresented: $model.showVideoSetting) {
                        VideoSettingView(model: model)
                    }
            }
            // 要放在这里才可以生效
            .onTapGesture {
                model.config.isMaskShow.toggle()
            }
            .preferredColorScheme(.dark)
            .persistentSystemOverlays(.hidden)
            .toolbar(.hidden, for: .automatic)
            #if os(macOS)
            .toolbar(model.config.isMaskShow ? .visible : .hidden, for: .windowToolbar)
            // onHover在view里面移动光标，onHover不会在回调
            // 要放在最上面的view。这样才不会被controllerView盖住
            .onHover { new in
                if new {
                    model.config.isMaskShow = true
                } else {
                    let loc = NSEvent.mouseLocation
                    if let window = model.config.playerLayer?.player.view.window, window.frame.contains(loc) {
                        return // 还在窗口内，不隐藏
                    }
                    model.config.isMaskShow = false
                }
            }
            #else
            .toolbar(.hidden, for: .tabBar)
            #endif
            #if os(iOS)
            .statusBar(hidden: !model.config.isMaskShow)
            #endif
            .focusedObject(model.config)
            .onChange(of: model.config.isMaskShow) { newValue in
                if newValue {
                    model.focusableView = .controller
                } else {
                    model.focusableView = .play
                }
            }
            #if os(tvOS)
            // 要放在最上层才不会有焦点丢失问题
            .onPlayPauseCommand {
                if model.config.state.isPlaying {
                    model.config.playerLayer?.pause()
                } else {
                    model.config.playerLayer?.play()
                }
            }
            .onExitCommand {
                if model.config.isMaskShow {
                    model.config.isMaskShow = false
                } else {
                    switch model.focusableView {
                    case .play:
                        dismiss()
                    default:
                        model.focusableView = .play
                    }
                }
            }
            #endif
        } else {
            controllerView
        }
    }

    @MainActor
    public func openURL(_ url: URL, options: KSOptions? = nil) {
        if url.isSubtitle {
            let info = URLSubtitleInfo(url: url)
            model.config.playerLayer?.select(subtitleInfo: info)
        } else {
            if let options {
                model.options = options
            }
            model.url = url
            model.title = url.lastPathComponent
        }
    }

    private var controllerView: some View {
        VideoControllerView(model: model)
        #if !os(tvOS)
        // 要放在最上面才能修改url
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                if let data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                    Task { @MainActor in
                        openURL(url)
                    }
                }
            }
            return true
        }
        #endif
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
public extension KSVideoPlayerView {
    init(url: URL, options: KSOptions, title: String? = nil, liftCycleBlock: ((KSVideoPlayer.Coordinator, Bool) -> Void)? = nil) {
        self.init(url: url, options: options, title: title, subtitleDataSource: nil, liftCycleBlock: liftCycleBlock)
    }

    /// xcode 15.2还不支持对MainActor参数设置默认值
    init(coordinator: KSVideoPlayer.Coordinator? = nil, url: URL, options: KSOptions, title: String? = nil, subtitleDataSource: SubtitleDataSource? = nil, liftCycleBlock: ((KSVideoPlayer.Coordinator, Bool) -> Void)? = nil) {
        self.init(model: StateObject(wrappedValue: KSVideoPlayerModel(title: title ?? url.lastPathComponent, config: coordinator, options: options, url: url)),
                  subtitleDataSource: subtitleDataSource,
                  liftCycleBlock: liftCycleBlock)
    }

    init(playerLayer: KSPlayerLayer) {
        self.init(model: StateObject(wrappedValue: KSVideoPlayerModel(playerLayer: playerLayer)))
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
open class KSVideoPlayerModel: ObservableObject, URLSubtitleDataSource, @unchecked Sendable {
    @Published
    public var title: String
    public var config: KSVideoPlayer.Coordinator
    public var options: KSOptions
    public var urls = [FileObject]()
    public var extensionInfos = [String: String]()
    @Published
    public var url: URL? {
        didSet {
            if url != oldValue, let url {
                if let first = urls.first(where: { $0.url == url }) {
                    set(file: first)
                } else {
                    title = url.lastPathComponent
                    subtitleURLs = []
                    extensionInfos = [:]
                }
                #if os(macOS)
                runOnMainThread {
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                }
                #endif
            }
        }
    }

    public private(set) var subtitleURLs: [URLSubtitleInfo]

    @Published
    var focusableView: KSVideoPlayerModel.FocusableView?
    enum FocusableView {
        case play, controller, slider
    }

    @Published
    var showVideoSetting = false
    private var cancellables = Set<AnyCancellable>()
    @MainActor
    public init(title: String, config: KSVideoPlayer.Coordinator?, options: KSOptions, url: URL? = nil, subtitleURLs: [URLSubtitleInfo] = []) {
        self.title = title
        self.config = config ?? KSVideoPlayer.Coordinator()
        // url不要放在最后面这样才不会调用didSet
        self.url = url
        self.options = options
        self.subtitleURLs = subtitleURLs
        // 嵌套属性无法触发UI更新，所以需要进行绑定，手动触发。
        self.config.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        self.config.onURLChanged = { [weak self] _, url in
            self?.url = url
        }

        #if os(macOS)
        if let url {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }
        #endif
    }

    @MainActor
    public convenience init(playerLayer: KSPlayerLayer) {
        self.init(title: playerLayer.url.lastPathComponent, config: KSVideoPlayer.Coordinator(playerLayer: playerLayer), options: playerLayer.options, url: playerLayer.url)
    }

    open func set(file: FileObject) {
        title = file.name
        subtitleURLs = file.subtitleURLs
    }

    @MainActor
    public func next() {
        (config.playerLayer as? KSComplexPlayerLayer)?.playNextURL()
    }

    @MainActor
    public func previous() {
        (config.playerLayer as? KSComplexPlayerLayer)?.playPreviousURL()
    }

    public func searchSubtitle(fileURL: URL) async throws -> [URLSubtitleInfo] {
        fileURL == url ? subtitleURLs : []
    }
}

#if DEBUG
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let url = URL(string: "https://raw.githubusercontent.com/kingslay/TestVideo/main/subrip.mkv")!
        KSVideoPlayerView(url: url, options: KSOptions())
    }
}

// struct AVContentView: View {
//    var body: some View {
//        StructAVPlayerView().frame(width: UIScene.main.bounds.width, height: 400, alignment: .center)
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
#endif
