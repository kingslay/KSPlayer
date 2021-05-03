//#import <libavcodec/avcodec.h>
//#import <libavutil/avutil.h>
//#import <libavutil/imgutils.h>
//#import <libavformat/avformat.h>
//#import <libswresample/swresample.h>
//#import <libswscale/swscale.h>
#import <libavutil/display.h>
#import <stdbool.h>

static inline int swift_AVERROR(int errnum) {
    return AVERROR(errnum);
}
static const int swift_AVERROR_EOF                = AVERROR_EOF; ///< End of file
static const int swift_AVERROR_INVALIDDATA        = AVERROR_INVALIDDATA; ///< Invalid data found when processing input
