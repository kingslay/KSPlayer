# KSPlayer

## 一、介绍
KSPlayer是一款基于 AVPlayer, FFmpeg  纯Swift的音视频播放器，支持所有视频格式和全景视频，支持苹果全平台。实现高可用，高性能的音视频播放能力。它包含UI控件模块、字幕模块、播放器内核模块。这些模块都是解耦的，可以通过pod按需接入。

 [原理详解](./Documents/KSPlayer原理详解.md) 

## 二、功能
- [x] 首屏秒开
- [x] 无缝循环播放
- [x] 精确seek
- [x] 支持外挂字幕、内挂字幕
- [x] 倍速播放
- [x] 支持iOS、macOS、tvOS
- [x] 支持360°全景视频
- [x] 使用Metal进行渲染
- [x] 支持所有媒体格式(自动切换KSAVPlayer和KSMEPlayer)
- [x] 支持横竖屏切换，支持自动旋转屏幕
- [x] 右侧 1/2 位置上下滑动调节屏幕亮度（模拟器调不了亮度，请在真机调试）
- [x] 左侧 1/2 位置上下滑动调节音量（模拟器调不了音量，请在真机调试）
- [x] 左右滑动调节播放进度
- [x] 清晰度切换
- [x] H.264 H.265 硬件解码（VideoToolBox）
- [x] 首屏耗时，缓冲次数，缓冲时长监控
- [x] AirPlay
- [x] Bitcode

## 三、要求
- iOS 13 +,  macOS 10.15 +, tvOS 13 +


## 四、安装
### CocoaPods

确保使用最新版本 **cocoapods 1.10.1+, 可以使用命令 ` brew install cocoapods` 来安装

```ruby
target 'ProjectName' do
    use_frameworks!
    pod 'KSPlayer',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'develop'
    pod 'FFmpegKit',:git => 'https://github.com/kingslay/FFmpegKit.git', :branch => 'main'
    pod 'OpenSSL',:git => 'https://github.com/kingslay/FFmpegKit.git', :branch => 'main'
end
```

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/kingslay/KSPlayer.git", .branch("develop"))
]
```

### Demo

进Demo目录打开Demo.xcworkspace。

## License
KSPlayer默认采用 GPL 协议(需开源自己的项目代码)，希望大家能自觉尊重 KSPlayer 项目的授权协议。另外有一个付费版本是采用LGPL协议。(联系我们)

如果由于商业原因，不希望遵守 GPL 协议或 LGPL 协议，那你可以联系我们，经过我们的授权，你可以拥有更加宽松的授权协议。

## 五、使用

### 初始化

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

### 设置普通视频

```swift
playerView.set(url:URL(string: "http://baobab.wdjcdn.com/14525705791193.mp4")!)
playerView.set(resource: KSPlayerResource(url: url, name: name!, cover: URL(string: "http://img.wdjimg.com/image/video/447f973848167ee5e44b67c8d4df9839_0_0.jpeg"), subtitle: nil))
```

### 多清晰度，带封面视频

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
### 设置 HTTP header

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

### 监听状态变化
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



## 六、进阶用法
- 继承 PlayerView 自定义播放逻辑和UI。

- 设置KSOptions 里面的属性

  ```swift
  open class KSOptions {
    //    public static let shared = KSOptions()
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
    public var seekFlags = Int32(1)
    // ffmpeg only cache http
    public var cache = false
    public var outputURL: URL?
    public var display = DisplayEnum.plane
    public var videoDelay = 0.0 // s
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
  }
  ```


## 七、效果:

![gif](./Demo/demo.gif)

## 八、参考：
本项目参考了 [ZFPlayer](https://github.com/renzifeng/ZFPlayer)、**[SGPlayer](https://github.com/libobjc/SGPlayer)**

