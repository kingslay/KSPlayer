![Build Status](https://img.shields.io/badge/build-%20passing%20-brightgreen.svg)
![Platform](https://img.shields.io/badge/Platform-%20iOS%20macOS%20tvOS%20-blue.svg)

# KSPlayer 

- KSPlayer is a powerful media play framework foriOS, tvOS, macOS,Mac Catalyst, SwiftUI,  Apple Silicon M1 .

## Based On

- FFmpeg
- Metal
- AudioUnit

## Features

- iOS, tvOS, macOS,Mac Catalyst,  Apple Silicon M1, SwiftUI.
- 360° panorama video.
- Background playback.
- RTMP/RTSP/Dash/HLS streaming.
- Setting playback speed.
- Multiple audio/video tracks.
- H.264/H.265 hardware accelerator.
- HDR
- dvb_subtitle
- Picture in Picture

## Requirements

- iOS 11 +,  macOS 10.13 +, tvOS 11 +
- Xcode 13
- Swift 5.5

## Demo

- Open Demo/Demo.xcworkspace with Xcode.

## Quick Start

#### CocoaPods

Make sure to use the latest version **cocoapods 1.10.1**, which can be installed using the command `brew install cocoapods`

```ruby
target 'ProjectName' do
    use_frameworks!
    pod 'KSPlayer',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
    pod 'FFmpeg',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
    pod 'Openssl',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
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
KSPlayerManager.secondPlayerType = KSMEPlayer.self
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
let header = ["User-Agent":"KSPlayer"]
let options = KSOptions()
options.avOptions = ["AVURLAssetHTTPHeaderFieldsKey":header]

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

- ### Set the properties in KSPlayerManager and KSOptions.

  ```swift
  public struct KSPlayerManager {
       /// 顶部返回、标题、AirPlay按钮 显示选项，默认.Always，可选.HorizantalOnly、.None
      public static var topBarShowInCase = KSPlayerTopBarShowCase.always
      /// 自动隐藏操作栏的时间间隔 默认5秒
      public static var animateDelayTimeInterval = TimeInterval(5)
      /// 开启亮度手势 默认true
      public static var enableBrightnessGestures = true
      /// 开启音量手势 默认true
      public static var enableVolumeGestures = true
      /// 开启进度滑动手势 默认true
      public static var enablePlaytimeGestures = true
      /// 竖屏是否开启手势控制 默认false
      public static var enablePortraitGestures = false
      /// 播放内核选择策略 先使用firstPlayer，失败了自动切换到secondPlayer，播放内核有KSAVPlayer、KSMEPlayer两个选项
      public static var firstPlayerType: MediaPlayerProtocol.Type = KSAVPlayer.self
      public static var secondPlayerType: MediaPlayerProtocol.Type?
      /// 是否能后台播放视频
      public static var canBackgroundPlay = false
      /// 日志输出方式
      public static var logFunctionPoint: (String) -> Void = {
          print($0)
      }
      /// 开启VR模式的陀飞轮
      public static var enableSensor = true
      /// 日志级别
      public static var logLevel = LogLevel.warning
      public static var stackSize = 16384
      public static var audioPlayerMaximumFramesPerSlice = AVAudioFrameCount(4096)
  }
  public class KSOptions {
      /// 视频颜色编码方式 支持kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange kCVPixelFormatType_420YpCbCr8BiPlanarFullRange kCVPixelFormatType_32BGRA kCVPixelFormatType_420YpCbCr8Planar
      public static var bufferPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
      public static var hardwareDecodeH264 = true
      public static var hardwareDecodeH265 = true
      /// 最低缓存视频时间
      public static var preferredForwardBufferDuration = 3.0
      /// 最大缓存视频时间
      public static var maxBufferDuration = 30.0
      /// 是否开启秒开
      public static var isSecondOpen = false
      /// 开启精确seek
      public static var isAccurateSeek = true
      /// 开启无缝循环播放
      public static var isLoopPlay = false
      /// 是否自动播放，默认false
      public static var isAutoPlay = false
      /// seek完是否自动播放
      public static var isSeekedAutoPlay = true
  }
  
  ```


## Effect

![gif](https://github.com/kingslay/KSPlayer/raw/master/Demo/demo.gif)

## Debug FFmpeg

```bash
swift run Script debug
dwarfdump -F --debug-info ../Sources/libavformat.xcframework/macos-arm64_x86_64/Libavformat.framework/Libavformat | head -n 20
```

run demo-macOS

![6](https://github.com/kingslay/KSPlayer/blob/develop/Documents/6.png?raw=true)

## Developments and Tests

Any contributing and pull requests are warmly welcome. However, before you plan to implement some features or try to fix an uncertain issue, it is recommended to open a discussion first. It would be appreciated if your pull requests could build and with all tests green. :)

## Communication

- Email : kingslay@icloud.com

## Reference

This item references the  [ZFPlayer](https://github.com/renzifeng/ZFPlayer)、**[SGPlayer](https://github.com/libobjc/SGPlayer)**