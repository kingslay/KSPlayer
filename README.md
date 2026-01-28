![Build Status](https://img.shields.io/badge/build-%20passing%20-blue.svg)
![Platform](https://img.shields.io/badge/Platform-%20iOS%20macOS%20tvOS%20visionOS%20-blue.svg)
![License](https://img.shields.io/badge/license-GPL-blue.svg)
# KSPlayer

KSPlayer is a powerful media play framework for iOS, tvOS, macOS, xrOS, visionOS, Mac Catalyst. based on AVPlayer and FFmpeg, support AppKit/UIKit/SwiftUI.

English | [简体中文](./README_CN.md)

## Communication

If you have a commercial project that requires a custom player, or would like to receive a paid consultation, please email me.

- Email : kingslay@icloud.com

## License
KSPlayer defaults to the GPL license (requires open-sourcing your own project code), and we hope everyone will consciously respect the licensing agreement of the KSPlayer project. Additionally, there is a paid version that adopts the LGPL license (contact us).

If due to commercial reasons, you prefer not to adhere to the GPL license  or the LGPL license, you can contact us. Through our authorization, you can obtain a more flexible licensing agreement.

## Features
Functional differences between GPL version and LGPL version.
Some features of the LGPL version require a one-time payment, which I have used 💰 to mark them out.

To experience the powerful features of the LGPL version, you can download the app from the App Store. [App Store Link](https://apps.apple.com/app/tracyplayer/id6450770064)


| Feature     | LGPL      | GPL    |
| ----------- | --------- | ------ |
|Dolby AC-4|✅|❌|
|Swift Concurrency|✅|❌|
|AV1 hardware decoding|✅|❌|
|Word-by-word subtitles|✅|❌|
|All demuxers, All decoders|✅|❌|
|Use System Caption Appearance|✅|❌|
|Record video clips at any time|✅|❌|
|Smoothly Play 8K or 120 FPS Video|✅|❌|
|Video download and format conversion|✅|❌|
|External image subtitles, such as SUP|✅|❌|
|Main subtitles and Secondary subtitles|✅|❌|
|Picture in Picture supports subtitle display|✅|❌|
|Annex-B async hardware decoding(Live Stream)|✅|❌|
|Use the fonts in the video to render subtitles|✅|❌|
|Use memory cache for fast seek in short time range|✅|❌|
|Full display of ass subtitles effect(Render as image using libass)|✅|❌|
|FFmpeg version|8.0.1|6.1.0|
|Video upscaling |💰|❌|
|Precache data to Hard Drive|💰|❌|
|Video switching with zero delay|💰|❌|
|Dovi P5 displays HDR (not overheating)|💰|❌|
|Live streaming supports rewind viewing|💰|❌|
|ISO Blu-ray disc playback on all Apple platforms|💰|❌|
|Simultaneous playback of separate audio and video URLs|💰|❌|
|Offline AI real-time subtitle generation and translation|💰|❌|
|Play videos in a small window in the App (resumable, supports macOS、iOS and tvOS)|💰|❌|
|Record video|✅|✅|
|360° panorama video|✅|✅|
|Picture in Picture|✅|✅|
|Hardware accelerator|✅|✅|
|Seamless loop playback|✅|✅|
|De-interlace auto detect|✅|✅|
|Multichannel Audio/Spatial Audio|✅|✅|
|4k/HDR/HDR10/HDR10+/Dolby Vision|✅|✅|
|Custom url protocols such as nfs/smb/UPnP |✅|✅|
|Text subtitle/Image subtitle/Closed Captions|✅|✅|
|Search Online Subtitles(shooter/assrt/opensubtitles)|✅|✅|
|Low latency 4K live video streaming (less than 200ms on LAN)|✅|✅|
|Automatically switch to multi-bitrate streams based on network|✅|✅|


## Requirements

- iOS 13+, macOS 10.15+, tvOS 13+, xrOS 1+

## The list of App using this SDK
| App Store Link | Logo |
| -------------- | ---- |
|[APTV](https://apps.apple.com/app/aptv/id1630403500)||
|[homeTV IPTV Player](https://apps.apple.com/app/hometv-iptv-player/id1636701357)||
|[IPTV +](https://apps.apple.com/app/iptv-my-smart-iptv-player/id1525121231)||
|[LillyPlayer Video Player](https://apps.apple.com/app/lillyplayer-video-player/id1446967273)||
|[SenPlayer](https://apps.apple.com/app/senplayer-hdr-media-player/id6443975850)||
|[Smart IPTV](https://apps.apple.com/app/smart-iptv-tv-and-movies-ott/id1492738910)||
|[Snappier IPTV](https://apps.apple.com/app/snappier-iptv/id1579702567)||
|[Spatial Video Studio](https://apps.apple.com/app/id6523429904)||
|[SWIPTV - IPTV Smart Player](https://apps.apple.com/app/swiptv-iptv-smart-player/id1658538188)||
|[TracyPlayer](https://apps.apple.com/app/tracyplayer/id6450770064)||
|[UHF - Love your IPTV](https://apps.apple.com/app/uhf-love-your-iptv/id6443751726)|![logo](https://uhf-web.vercel.app/uhfsponsor.png)|
|[Zen IPTV](https://apps.apple.com/fr/app/zen-iptv/id6458223193)||


## Demo

```bash
cd Demo
pod install
```
- Open Demo/Demo.xcworkspace with Xcode.

## Quick Start

#### CocoaPods

Make sure to use the latest version **cocoapods 1.10.1+**, which can be installed using the command `brew install cocoapods`

```ruby
target 'ProjectName' do
    use_frameworks!
    pod 'KSPlayer',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'main'
    pod 'DisplayCriteria',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'main'
    pod 'FFmpegKit',:git => 'https://github.com/kingslay/FFmpegKit.git', :branch => 'main'
    pod 'Libass',:git => 'https://github.com/kingslay/FFmpegKit.git', :branch => 'main'
end
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/kingslay/KSPlayer.git", .branch("main"))
]
```

## Usage

#### Initialization

```swift
KSOptions.secondPlayerType = KSMEPlayer.self
playerView = IOSVideoPlayerView()
view.addSubview(playerView)
playerView.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    playerView.topAnchor.constraint(equalTo: view.readableContentGuide.topAnchor),
    playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
    playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
    playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
])
playerView.backBlock = { [unowned self] in
    if UIApplication.shared.statusBarOrientation.isLandscape {
        self.playerView.updateUI(isLandscape: false)
    } else {
        self.navigationController?.popViewController(animated: true)
    }
}
```

#### Setting up a regular video

```swift
playerView.set(url:URL(string: "http://baobab.wdjcdn.com/14525705791193.mp4")!)
playerView.set(resource: KSPlayerResource(url: url, name: name!, cover: URL(string: "http://img.wdjimg.com/image/video/447f973848167ee5e44b67c8d4df9839_0_0.jpeg"), subtitleURL: URL(string: "http://example.ksplay.subtitle")))
```

#### Multi-definition, with cover video

```swift
let res0 = KSPlayerResourceDefinition(url: URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!,
                                      definition: "高清")
let res1 = KSPlayerResourceDefinition(url: URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!,
                                      definition: "标清")

let asset = KSPlayerResource(name: "Big Buck Bunny",
                             definitions: [res0, res1],
                             cover: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/848px-Big_buck_bunny_poster_big.jpg"))
playerView.set(resource: asset)
```

#### Setting up an HTTP header

```swift
let options = KSOptions()
options.appendHeader(["Referer":"https:www.xxx.com"])
let definition = KSPlayerResourceDefinition(url: URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!,
                                            definition: "高清",
                                            options: options)
let asset = KSPlayerResource(name: "Video Name",
                             definitions: [definition])
playerView.set(resource: asset)
```

#### Listening status change

```swift
// Listen to play time change
playerView.playTimeDidChange = { (currentTime: TimeInterval, totalTime: TimeInterval) in
    print("playTimeDidChange currentTime: \(currentTime) totalTime: \(totalTime)")
}

// Delegates
public protocol PlayerControllerDelegate: class {
    func playerController(state: KSPlayerState)
    func playerController(currentTime: TimeInterval, totalTime: TimeInterval)
    func playerController(finish error: Error?)
    func playerController(maskShow: Bool)
    func playerController(action: PlayerButtonType)
    // `bufferedCount: 0` indicates first time loading
    func playerController(bufferedCount: Int, consumeTime: TimeInterval)
}
```

## Advanced Usage

- ### Inherits PlayerView's custom play logic and UI.

  ```swift
  class CustomVideoPlayerView: IOSVideoPlayerView {
      override func updateUI(isLandscape: Bool) {
          super.updateUI(isLandscape: isLandscape)
          toolBar.playbackRateButton.isHidden = true
      }

      override func onButtonPressed(type: PlayerButtonType, button: UIButton) {
          if type == .landscape {
              // Your own button press behaviour here
          } else {
              super.onButtonPressed(type: type, button: button)
          }
      }
  }
  ```



- ### Selecting Tracks

  ```swift
     override open func player(layer: KSPlayerLayer, state: KSPlayerState) {
          super.player(layer: layer, state: state)
          if state == .readyToPlay, let player = layer.player {
              let tracks = player.tracks(mediaType: .audio)
              let track = tracks[1]
              /// the name of the track
              let name = track.name
              /// the language of the track
              let language = track.language
              /// selecting the one
              player.select(track: track)
          }
     }
  ```

- ### Set the properties in KSOptions

  ```swift
  open class KSOptions {
    /// 最低缓存视频时间
    @Published
    public var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration
    /// 最大缓存视频时间
    public var maxBufferDuration = KSOptions.maxBufferDuration
    /// 是否开启秒开
    public var isSecondOpen = KSOptions.isSecondOpen
    /// 开启精确seek
    public var isAccurateSeek = KSOptions.isAccurateSeek
    /// Applies to short videos only
    public var isLoopPlay = KSOptions.isLoopPlay
    /// 是否自动播放，默认false
    public var isAutoPlay = KSOptions.isAutoPlay
    /// seek完是否自动播放
    public var isSeekedAutoPlay = KSOptions.isSeekedAutoPlay
    /*
     AVSEEK_FLAG_BACKWARD: 1
     AVSEEK_FLAG_BYTE: 2
     AVSEEK_FLAG_ANY: 4
     AVSEEK_FLAG_FRAME: 8
     */
    public var seekFlags = Int32(0)
    // ffmpeg only cache http
    public var cache = false
    public var outputURL: URL?
    public var display = DisplayEnum.plane
    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var decoderOptions = [String: Any]()
    public var probesize: Int64?
    public var maxAnalyzeDuration: Int64?
    public var lowres = UInt8(0)
    public var startPlayTime: TimeInterval = 0
    public var startPlayRate: Float = 1.0
    public var registerRemoteControll: Bool = true // 默认支持来自系统控制中心的控制
    public var referer: String?
    public var userAgent: String?
      // audio
    public var audioFilters = [String]()
    public var syncDecodeAudio = false
    // sutile
    public var autoSelectEmbedSubtitle = true
    public var subtitleDisable = false
    public var isSeekImageSubtitle = false
    // video
    public var videoDelay = 0.0 // s
    public var autoDeInterlace = false
    public var autoRotate = true
    public var destinationDynamicRange: DynamicRange?
    public var videoAdaptable = true
    public var videoFilters = [String]()
    public var syncDecodeVideo = false
    public var hardwareDecode = KSOptions.hardwareDecode
    public var asynchronousDecompression = true
    public var videoDisable = false
    public var canStartPictureInPictureAutomaticallyFromInline = true
  }

  ```


## Effect

![gif](./Demo/demo.gif)

## Developments and Tests

Any contributing and pull requests are warmly welcome. However, before you plan to implement some features or try to fix an uncertain issue, it is recommended to open a discussion first. It would be appreciated if your pull requests could build and with all tests green. :)


## Backers & Sponsors

Open-source projects cannot live long without your help. If you find KSPlayer to be useful, please consider supporting this
project by becoming a sponsor.

Become a sponsor through [GitHub Sponsors](https://github.com/sponsors/kingslay/). :heart:

Your user icon or company logo shows up this with a link to your home page.
|Name| App name | App Logo |
| ----------- | ----------- |----------- |
|[UnknownCoder807](https://github.com/UnknownCoder807)|[Snappier](https://apps.apple.com/app/snappier-iptv/id1579702567)||
|[skrew](https://github.com/skrew)||
|[Kimentanm](https://github.com/Kimentanm)||
|[nakiostudio](https://github.com/nakiostudio)|[UHF](https://apps.apple.com/app/uhf-love-your-iptv/id6443751726)||
|[CodingByJerez](https://github.com/CodingByJerez)||
|[andrefmsilva](https://github.com/andrefmsilva)||
|[romaingyh](https://github.com/romaingyh)|[Zen IPTV](https://apps.apple.com/fr/app/zen-iptv/id6458223193)||
|[FantasyKingdom](https://github.com/FantasyKingdom)|[Senplayer](https://apps.apple.com/us/app/senplayer-hdr-media-player/id6443975850)||
|[aart-rainey](https://github.com/aart-rainey)||
|[nihalahmed](https://github.com/nihalahmed)||
|[johnil](https://github.com/johnil)||
|[MeloDreek](https://github.com/MeloDreek)||
|[nsplay1990](https://github.com/nsplay1990)||
|[AppleChillVibez](https://github.com/AppleChillVibez)||
|[stekc](https://github.com/stekc)||
|[AstroChivs](https://github.com/AstroChivs)||
|[bmob222](https://github.com/bmob222)||
|[pateltejas](https://github.com/pateltejas)||
|[ewanl2001](https://github.com/ewanl2001)||
|[themisterholliday](https://github.com/themisterholliday)||
|[JulienDev](https://github.com/JulienDev)||
|[Sheinices](https://github.com/Sheinices)||
|[Etheirystech](https://github.com/Etheirystech)||
|[loicleser](https://github.com/loicleser)||


Thanks to [nightfall708](https://github.com/nightfall708) for sponsoring a mac mini

Thanks to [cdguy](https://github.com/cdguy) [UnknownCoder807](https://github.com/UnknownCoder807) [skrew](https://github.com/skrew) and LillyPlayer community for sponsoring a LG S95QR Sound Bar

Thanks to [skrew](https://github.com/skrew) and LillyPlayer community for sponsoring a 2022 Apple TV 4K

Thanks to [bgoncal](https://github.com/bgoncal) for sponsoring a HomePod mini

![1](./Documents/Sponsors.jpg)
