#import <stdbool.h>
#import "libavutil/samplefmt.h"
#import "libavcodec/avcodec.h"
#import "libavutil/pixdesc.h"
#import "libavutil/error.h"
#import "libavutil/common.h"
#import "libavutil/dict.h"
#import "libavutil/time.h"
#import "libavutil/display.h"
#import "libavutil/imgutils.h"
//#import "libavdevice/avdevice.h"
//#import "libavfilter/avfilter.h"
#import "libavformat/avformat.h"
#import "libavutil/avutil.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"

int AVERROR_CONVERT(int err) {
    return AVERROR(err);
}

bool IS_AVERROR_EOF(int err) {
    return err == AVERROR_EOF;
}

bool IS_AVERROR_INVALIDDATA(int err) {
    return err == AVERROR_INVALIDDATA;
}

bool AVFILTER_EOF(int ret) {
    return ret == AVERROR(EAGAIN) || IS_AVERROR_EOF(ret);
}

