//
//  FFmpeg.c
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//
#import "FFmpegError.h"
#import "libavutil/common.h"
#import "libavutil/error.h"
int AVERROR_CONVERT(int err) {
    return AVERROR(err);
}
bool IS_AVERROR_EOF(int err) {
    return err == AVERROR_EOF;
}
bool IS_AVERROR_INVALIDDATA(int err) {
    return err == AVERROR_INVALIDDATA;
}
bool IS_AVERROR_EAGAIN(int err) {
    return err == AVERROR(EAGAIN);
}
bool AVFILTER_EOF(int ret) {
    return IS_AVERROR_EAGAIN(ret) || IS_AVERROR_EOF(ret);
}
