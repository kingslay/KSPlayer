#import <libavcodec/avcodec.h>
#import <libavutil/avutil.h>
#import <libavutil/display.h>
#import <libavutil/imgutils.h>
#import <libavformat/avformat.h>
#import <libswresample/swresample.h>
#import <libswscale/swscale.h>
#import <stdbool.h>

static __inline__ int AVERROR_CONVERT(int err) {
    return AVERROR(err);
}

static __inline__ bool IS_AVERROR_EOF(int err) {
    return err == AVERROR_EOF;
}

static __inline__ bool IS_AVERROR_INVALIDDATA(int err) {
    return err == AVERROR_INVALIDDATA;
}

static __inline__ bool AVFILTER_EOF(int ret) {
    return ret == AVERROR(EAGAIN) || IS_AVERROR_EOF(ret);
}

