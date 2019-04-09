//
//  FFmpeg.h
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//
#include <stdbool.h>
//#define AV_NOPTS_VALUE          ((int64_t)UINT64_C(0x8000000000000000))
int AVERROR_CONVERT(int err);
bool IS_AVERROR_EOF(int err);
bool IS_AVERROR_EAGAIN(int err);
bool AVFILTER_EOF(int ret);
bool IS_AVERROR_INVALIDDATA(int err);
