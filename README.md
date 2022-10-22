![Build Status](https://img.shields.io/badge/build-%20passing%20-blue.svg)
![Platform](https://img.shields.io/badge/Platform-%20iOS%20macOS%20tvOS%20-blue.svg)
![License](https://img.shields.io/badge/license-GPL-blue.svg)
# KSPlayer 

KSPlayer is a powerful media play framework foriOS, tvOS, macOS,Mac Catalyst, SwiftUI, Apple Silicon M1 .

English | [简体中文](./README_CN.md)

## Based On

- FFmpeg
- Metal
- AVAudioEngine

## Features

- iOS, tvOS, macOS,Mac Catalyst, Apple Silicon M1, SwiftUI.
- Multiple audio/video tracks.
- H.264/H.265 hardware accelerator.
- 4k/HDR
- text subtitle/image subtitle(dvbsub/dvdsub/pgssub)
- Picture in Picture
- Record video
- De-interlace auto detect
- 360° panorama video.

## Requirements

- iOS 13 +,  macOS 10.15 +, tvOS 13 +

## Demo

- Open Demo/Demo.xcworkspace with Xcode.

## Quick Start

#### CocoaPods

Make sure to use the latest version **cocoapods 1.10.1+**, which can be installed using the command `brew install cocoapods`

```ruby
target 'ProjectName' do
    use_frameworks!
    pod 'KSPlayer',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
    pod 'FFmpeg',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
    pod 'OpenSSL',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
end
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/kingslay/KSPlayer.git", .branch("develop"))
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
//Listen to when the play time changes
playerView.playTimeDidChange = { (currentTime: TimeInterval, totalTime: TimeInterval) in
    print("playTimeDidChange currentTime: \(currentTime) totalTime: \(totalTime)")
}
///协议方式
public protocol PlayerControllerDelegate: class {
    func playerController(state: KSPlayerState)
    func playerController(currentTime: TimeInterval, totalTime: TimeInterval)
    func playerController(finish error: Error?)
    func playerController(maskShow: Bool)
    func playerController(action: PlayerButtonType)
    // bufferedCount: 0代表首次加载
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
              // xx
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
    //    public static let shared = KSOptions()
    /// 最低缓存视频时间
    @Published public var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration
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
    public var seekFlags = Int32(1)
    // ffmpeg only cache http
    public var cache = false
    public var outputURL: URL?
    public var display = DisplayEnum.plane
    public var audioDelay = 0.0 // s
    public var subtitleDelay = 0.0 // s
    public var videoDisable = false
    public var audioFilters: String?
    public var videoFilters: String?
    public var subtitleDisable = false
    public var videoAdaptable = true
    public var syncDecodeAudio = false
    public var syncDecodeVideo = false
    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var hardwareDecode = true
    public var decoderOptions = [String: Any]()
    public var probesize: Int64?
    public var maxAnalyzeDuration: Int64?
    public var lowres = UInt8(0)
    public var autoSelectEmbedSubtitle = true
    public var asynchronousDecompression = false
    public var autoDeInterlace = false
    @Published var preferredFramesPerSecond = Float(60)
  }

  ```


## Effect

![gif](./Demo/demo.gif)

## Custom FFmpeg
edit BuildFFmpeg.swift And run
```bash
swift run build-FFmpeg enable-openssl
```

## Debug FFmpeg

```bash
swift run build-FFmpeg enable-debug
```

run target TracyPlayer  


![6](./Documents/6.png?raw=true)

## Developments and Tests

Any contributing and pull requests are warmly welcome. However, before you plan to implement some features or try to fix an uncertain issue, it is recommended to open a discussion first. It would be appreciated if your pull requests could build and with all tests green. :)


## Backers & Sponsors

Open-source projects cannot live long without your help. If you find KSPlayer to be useful, please consider supporting this 
project by becoming a sponsor. 

Become a sponsor through [GitHub Sponsors](https://github.com/sponsors/kingslay/). :heart:

Your user icon or company logo shows up this with a link to your home page. 

[UnknownCoder807](https://github.com/UnknownCoder807)

[skrew](https://github.com/skrew)

## Communication

- Email : kingslay@icloud.com
