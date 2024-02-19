![Build Status](https://img.shields.io/badge/build-%20passing%20-blue.svg)
![Platform](https://img.shields.io/badge/Platform-%20iOS%20macOS%20tvOS%20visionOS%20-blue.svg)
![License](https://img.shields.io/badge/license-GPL-blue.svg)
# KSPlayer 

KSPlayer is a powerful media play framework for iOS, tvOS, macOS, xrOS, visionOS, Mac Catalyst, SwiftUI, Apple Silicon M1 .

English | [简体中文](./README_CN.md)

## Based On

- FFmpeg
- Metal
- AVAudioEngine

## Features

- [x] iOS, tvOS, macOS, visionOS, Mac Catalyst, Apple Silicon M1, SwiftUI.
- [x] Multiple audio/video tracks.
- [x] hardware accelerator.
- [x] 4k/HDR/HDR10/HDR10+/Dolby Vision
- [x] show local and online subtitles(shooter/assrt/opensubtitles).
- [x] text subtitle(srt/vtt/ass)/Closed Captions/image subtitle(dvbsub/dvdsub/pgssub)
- [x] Picture in Picture
- [x] Record video
- [x] De-interlace auto detect
- [x] Dolby Atmos/Spatial Audio 
- [x] 360° panorama video.
- [x] libsmbclient protocol

## Requirements

- iOS 13 +,  macOS 10.15 +, tvOS 13 +, xrOS 1 +

## Demo

```bash
cd Demo
pod install
```
- Open Demo/Demo.xcworkspace with Xcode.


## TestFlight

[APPStore](https://apps.apple.com/app/tracyplayer/id6450770064)

[TestFlight](https://testflight.apple.com/join/eNmYbmZN)

## License
KSPlayer defaults to the GPL license (requires open-sourcing your own project code), and we hope everyone will consciously respect the licensing agreement of the KSPlayer project. Additionally, there is a paid version that adopts the LGPL license (contact us). 

If due to commercial reasons, you prefer not to adhere to the GPL license  or the LGPL license, you can contact us. Through our authorization, you can obtain a more flexible licensing agreement.


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

#### initialize

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

[UnknownCoder807](https://github.com/UnknownCoder807)
[skrew](https://github.com/skrew)   
[Kimentanm](https://github.com/Kimentanm)
[nakiostudio](https://github.com/nakiostudio)
[andrefmsilva](https://github.com/andrefmsilva)
[CodingByJerez](https://github.com/CodingByJerez)

Thanks to [nightfall708](https://github.com/nightfall708) for sponsoring a mac mini

Thanks to [cdguy](https://github.com/cdguy) [UnknownCoder807](https://github.com/UnknownCoder807) [skrew](https://github.com/skrew) and LillyPlayer community for sponsoring a LG S95QR Sound Bar 

Thanks to [skrew](https://github.com/skrew) and LillyPlayer community for sponsoring a 2022 Apple TV 4K

## Communication

If you have a business cooperation project or want to initiate a paid consultation, you can contact me via email

- Email : kingslay@icloud.com

![1](https://github.com/kingslay/KSPlayer/raw/develop/Documents/Sponsors.jpg)

