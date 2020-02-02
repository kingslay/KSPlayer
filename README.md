# KSPlayer

## 一、介绍
KSPlayer是一款基于 AVPlayer, FFmpeg  纯Swift的音视频播放器，支持所有视频格式和全景视频，支持苹果全平台。实现高可用，高性能的音视频播放能力。它包含UI控件模块、字幕模块、播放器内核模块。这些模块都是解耦的，可以通过pod按需接入。

 [原理详解](https://github.com/kingslay/KSPlayer/blob/master/documents/KSPlayer原理详解.md) 

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
- iOS 10 +,  macOS 10.12 +, tvOS 10.2 +
- Xcode 11
- Swift 5.1

## 四、安装
### CocoaPods

确保使用最新版本 **cocoapods 1.9**, 可以使用命令 ` brew install cocoapods` 来安装

```ruby
target 'ProjectName' do
    use_frameworks!
    pod 'KSPlayer',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'master'
    pod 'Openssl',:git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'master'
end
```

#### Carthage

```
git "https://github.com/kingslay/KSPlayer.git" "master"
```

### Demo

进Demo目录打开Demo.xcworkspace。

## 五、使用

### 初始化

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

- 设置KSPlayerManager 、KSOptions里面的属性

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
      public static var logLevel = AV_LOG_WARNING
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


## 七、效果:

![gif](https://github.com/kingslay/KSPlayer/raw/master/Demo/demo.gif)

## 八、参考：
本项目参考了 [ZFPlayer](https://github.com/renzifeng/ZFPlayer)、**[SGPlayer](https://github.com/libobjc/SGPlayer)**

