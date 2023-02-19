# KSPlayer 原理详解

KSPlayer 是一款基于 AVPlayer、FFmpeg 的媒体资源播放器框架。支持RTMP、RTSP 等直播流；同时支持 iOS、macOS、tvOS 三个平台。扩张性强，支持自定义播放器内核和UI界面 。本文将采用图解+说明的方式把关键模块的实现原理介绍给大家。


## 一、整体架构

![1](https://github.com/kingslay/KSPlayer/raw/develop/Documents/1.png)

上图展示了 KSPlayer 的主要组件，一共分为四层。每一个层都是解耦的，都可以单独拿出来使用。下面简单介绍图中各组件的分工

### PlayerView

PlayerView 是播放器UI控件。目前有VideoPlayerView，AudioPlayerView两个子类。

VideoPlayerView根据平台特色又有IOSVideoPlayerView，MacVideoPlayerView这两个子类

### KSPlayerLayer 

KSPlayerLayer 是播放内核的封装，主要工作是根据配置参数切换播放器内核，管理播放状态，

### MediaPlayerProtocol

MediaPlayerProtocol是播放器内核接口。只要遵守MediaPlayerProtocol协议的播放器内核就可以在KSPlayer使用。默认提供了两种播放器内核：KSAVPlayer、KSMEPlayer

1、KSAVPlayer 是基于 AVPlayer 封装而成，支持H.264、H.265、MPEG-4格式。

2、KSMEPlayer是自研播放器内核，支持所有的主流视频格式。支持硬解和软解。 

### 小结

了解了各组件的功能，重新梳理一下完整的播放过程

- PlayerView 收到播放请求。
- 由 KSPlayerLayer 根据配置参数分发给 KSAVPlayer 或 KSMEPlayer 进行播放。
- 如果使用 KSAVPlayer 播放，将视频画面输出给 KSAVPlayerView 中的 AVPlayerLayer 。
- 如果使用 KSMEPlayer 播放，将视频画面输出给 MetalPlayView，音频输出至 AudioEnginePlayer。

通过抽象的 MediaPlayerProtocol  将真正负责播放的 KSAVPlayer 、 KSMEPlayer 屏蔽起来，这样可以保证无论资源是何种类型，对外仅暴露一套统一的接口和回调，将播放内核间的差异内部消化，尽可能降低使用成本。如果需要接入别的的播放器内核的话，如ijkplayer。那只要为ijkplayer实现MediaPlayerProtocol接口即可。

## 二、KSMEPlayer组织结构

![1](https://github.com/kingslay/KSPlayer/raw/develop/Documents/2.png)

上图展示了 KSMEPlayer 的主要组件，下面简单介绍图中各组件的分工

### MEPlayerItem

视频控制的上下文,负责创建视频流，读取数据包。

### PlayerItemTrackProtocol 

解码处理，负责把数据包解码成数据帧。支持硬解，软解。使用VideoToolbox进行视频硬解，FFmpeg进行视频软硬解、音频软解、字幕软解

### AudioEnginePlayer

AudioEnginePlayer 负责声音的播放和音频事件的处理。内部使用 AVAudioEngine 做了一层混音，通过混音可以设置声音的输出音量大小和播放倍数

### MetalPlayView

 MetalPlayView是视频画面绘制实现类，里面会更加参数参数来决定是使用AVSampleBufferDisplayLayer还是Metal来进行绘制。Metal支持全景视频，AVSampleBufferDisplayLayer支持HDR。

## 三、KSMEPlayer 运作流程

![1](https://github.com/kingslay/KSPlayer/raw/develop/Documents/3.png)

上图展示了 KSMEPlayer 的协作流程图，下面简单介绍图中各组件

### 线程模型

KSMEPlayer 中共有5个线程。与图中5个蓝色圆圈对应。

- 数据读取 - Read Packet Loop
- 视频解码 - Video Decode Loop
- 音频解码 - Audio Decode Loop
- 视频绘制 - Video Display Loop
- 音频播放 - Audio Playback Loop

这五个线程采用生产者-消费者模式。通过ObjectQueue中的数据个数来作为线程的控制条件

### PlayerItemTrackProtocol

解码处理，目前一共有两个实现类
| 类名                    | 同步/异步 | 备注 |
| ----------------------- | -------- | ---- |
| SyncPlayerItemTrack     |   同步      |主要用于字幕，如果是纯音频的话，也是可以用同步 |
| AsyncPlayerItemTrack     | 异步      |  |


#### 备注：

1、视频、音频采用异步的解码方式。是因为视频、音频解码的时间比较久，除了这个还有更重要的原因：视频、音频解码后的数据帧比数据包大了好几倍，为了节约内存，要控制数据帧的大小。

2、异步解码过程：解码器收到数据包存入数据包队列，当独立的解码线程取出数据包并完成解码后，再存入数据帧队列 

3、同步解码过程：解码器收到数据包后立即解码，并存入数据帧队列。

4、优先使用视频硬解，当视频无法软解或硬解失败的话，就自动切换到软解

### DecodeProtocol 

解码器接口，目前一共有三个实现类

| 类名                    | 解码类型 | 同步/异步 | 备注 |
| ----------------------- | -------- | --------- | ---- |
| FFmpegDecode     | 音视频     | 同步      | 软硬解 |
| VideoToolboxDecode    | 视频     | 异步      | 硬解 |
| SubtitleDecode | 字幕     | 同步      | 软解 |

### CircularBuffer 数据队列

 CircularBuffer是环形队列
数据队列提供`push` 、`pop(wait, where)` `search(where)` 三个方法


| 操作             | 行为                                                         |
| ---------------- | ------------------------------------------------------------ |
| `put`  | 队列满了，有两个处理方式：1.没有现在队列长度，那会双倍扩展队列长度，如果限制了，那会阻塞当前线程，直到队列只剩下1/2的数据，线程才会通过`NSCondition`被唤醒。避免频繁的进行锁操作 |
| `pop(wait, where)`  | 如果参数wait为true，那当队列中没有数据时，会阻塞当前线程，直到向队列中添加新元素时，线程才会通过`NSCondition`被唤醒，如果wait为false，那就会直接返回空 |
| `search(where)` | 只是访问队列里面的数据，不会对队列的游标产生影响 ，一般是用于文字字幕                          |

CircularBuffer还支持排序，因为视频有可能不是按顺序解码。所以一定要排序下，不然画面会来回抖动

### 音视频同步

常用的同步当时有3种

1. 音频时钟
2. 视频时钟
3. 自制时钟

在 KSMEPlayer 中，优先使用音频时钟，当视频中没有音轨时，或是音轨数据都播放完了，会使用视频时钟进行同步。音视频同步的接口是OutputRenderSourceDelegate， 具体实现类是MEPlayerItem。

### 小结

了解了各组件的功能，重新梳理一下整个流程

- 数据读取线程读取到数据包，根据数据包类型分发给音频解码器、视频解码器、字幕解码器。
- 如果是字幕包，字幕解码器收到字幕包的同时进行解码，并将解码后的字幕帧存入字幕帧队列。
- 音视频解码器收到音视频包存入音视频包队列，当独立的解码线程取出音视频包并完成解码后，再存入音视频帧队列 
- 音频播放线程循环从音频帧队列中取出音频帧并播放。
- 视频展示线程循环从视频帧队列中取出视频帧并绘制。
- 字幕控件根据时间戳到字幕帧队列查找对应的字幕帧并展示，不会把字幕帧从字幕队列删除。

## 四、总结

关于 KSPlayer 的原理就阐述到这里，由于本文以理论为主，所以并没有贴代码。感兴趣的同学可以在 [GitHub](https://github.com/kingslay/KSPlayer.git) 上找到全部的代码实现。希望对大家能有所帮助。
