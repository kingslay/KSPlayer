#include <stdbool.h>
#include "libavutil/error.h"
#include "libavutil/samplefmt.h"
#include "libavcodec/avcodec.h"
#include "libavutil/pixdesc.h"
#include "libavutil/common.h"
#include "libavutil/dict.h"
#include "libavutil/time.h"
#include "libavutil/display.h"
#include "libavutil/imgutils.h"
// #include "libavdevice/avdevice.h"
// #include "libavfilter/avfilter.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"


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

