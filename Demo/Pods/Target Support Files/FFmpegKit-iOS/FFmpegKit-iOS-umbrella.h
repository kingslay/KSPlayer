#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "avcodec_shim.h"
#import "avdevice_shim.h"
#import "avfilter_shim.h"
#import "avformat_shim.h"
#import "avutil_shim.h"
#import "swresample_shim.h"
#import "swscale_shim.h"

FOUNDATION_EXPORT double FFmpegKitVersionNumber;
FOUNDATION_EXPORT const unsigned char FFmpegKitVersionString[];

