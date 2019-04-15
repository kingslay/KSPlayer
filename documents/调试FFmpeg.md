# 调试FFmpeg源码

一、编译

```bash
cd FFmpeg
sh build-ffmpeg-macOS.sh debug
dwarfdump -F --debug-info FFmpeg-macOS/lib/libavcodec.a  | head -n 20
```

![6](http://git.code.oa.com/kintanwang/KSPlayer/raw/master/documents/6.png)

二、把文件加入到项目

拿到了路径,我们就把路径加入到项目里面。

![7](http://git.code.oa.com/kintanwang/KSPlayer/raw/master/documents/7.png)

![8](http://git.code.oa.com/kintanwang/KSPlayer/raw/master/documents/8.png)

