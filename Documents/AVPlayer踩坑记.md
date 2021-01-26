# AVPlayer踩坑记

AVPlayer是苹果平台上常用的视频播放器组件。使用简单，性能好。

## 一、缓冲状态判断

有以下三个属性判断视频能否进行播放

```swift
isPlaybackBufferEmpty  // 缓冲空了
isPlaybackLikelyToKeepUp // 可以进行播放
isPlaybackBufferFull // 缓冲满了
```

一开始的写法是:

```swift
if playerItem.isPlaybackLikelyToKeepUp {
    self.loadState = .playable
}
if playerItem.isPlaybackBufferEmpty {
    self.loadState = .loading
}
```

后来发现有些高码率的视频，会出现一直加载，无法播放的情况。后来发现是因为缓存满了`isPlaybackBufferFull`的值为true, 但是`isPlaybackLikelyToKeepUp`的值还是为false。

所以改成是下面的写法:

```swift
if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
    self.loadState = .playable
}
if playerItem.isPlaybackBufferEmpty {
    self.loadState = .loading
} 
```

最后发现有些视频会频繁的切换状态，分析了之后。发现 `isPlaybackBufferFull`， `isPlaybackBufferEmpty`会同时为true。从字面上理解这两个值应该是要互斥的，但是结果是相反。

所以最后正确的写法应该是：

```swift
if playerItem.isPlaybackBufferEmpty {
    self.loadState = .loading
} else if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
    self.loadState = .playable
}
```

## 二、视频播放黑屏

有些mp4视频在AVPlayer播放有声音，但是画面黑屏。但是放在自研播放器`MEPlayer`就可以有声音又有画面了。所以解决方案就是能判断异常视频，并自动切换到`MEPlayer`。

通过分析视频流发现帧率是25，视频帧的格式是yuv444p。猜测应该是无法硬解yuv444p。所以导致视频帧无法显示，后来通过增加AVPlayerItemOutput，发现确实没有输出视频帧。

通过对每个属性进行尝试，发现可以通过assetTrack的isPlayable属性来判断是否能输出视频帧

代码如下：

```swift
let videoTrack = item.tracks.first { $0.assetTrack?.mediaType.rawValue == AVMediaType.video.rawValue }
if let videoTrack = videoTrack, videoTrack.assetTrack?.isPlayable == false {
    error = NSError(domain: AVFoundationErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "can't player"])
    return
}
```



## 三、多音轨

AVPlayer播放多音轨的时候。默认所有的音轨都会打开的。所以要改成只打开一个音轨

代码如下：

```swift
// 默认选择第一个声道
item.tracks.filter { $0.assetTrack?.mediaType.rawValue == AVMediaType.audio.rawValue }.dropFirst().forEach { $0.isEnabled = false }
```



## 四、AVQueuePlayer

AVQueuePlayer是AVPlayer的子类，主要是用来实现视频顺序播放。也可以搭配AVPlayerLooper实现视频循环播放。

AVQueuePlayer默认是播放完一个视频，就会自动切换到下个视频了。

这样就会导致一个问题，如果只是播放单个资源的话。那视频播放播放完之后，你就无法从头开始播放了。因为`currentItem`这个属性被重置为nil了。

这时你可以通过修改属性`actionAtItemEnd`的值。来改变视频播放完之后的行为。默认是`.advance`。直接改成是.`pause`或是`.none`就可以了

## 五、广告时间

以上所说的坑都已经在 [KSPlayer](https://git.code.oa.com/kintanwang/KSPlayer) 填了。KSPlayer是一款基于 AVPlayer, FFmpeg 纯Swift的音视频播放器，支持所有视频格式和全景视频，支持苹果全平台。实现高可用，高性能的音视频播放能力。它包含UI控件模块、字幕模块、播放器内核模块。这些模块都是解耦的，可以通过pod按需接入。欢迎大家试用。

# 