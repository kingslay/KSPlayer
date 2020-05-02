# 调试FFmpeg源码

一、编译

```bash
brew install pkg-config
cd FFmpeg
sh build-openssl.sh
sh build-ffmpeg.sh debug
dwarfdump -F --debug-info FFmpeg.xcframework/ios-arm64/FFmpeg.framework/FFmpeg | head -n 20
```

![6](https://github.com/kingslay/KSPlayer/blob/develop/documents/6.png?raw=true)

二、把文件加入到项目

拿到了路径,我们就把路径加入到项目里面。

![7](https://github.com/kingslay/KSPlayer/blob/develop/documents/7.png?raw=true)

![8](https://github.com/kingslay/KSPlayer/blob/develop/documents/8.png?raw=true)

