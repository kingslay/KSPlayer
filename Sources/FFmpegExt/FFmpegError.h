//
//  FFmpeg.h
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//
#include <stdbool.h>
int AVERROR_CONVERT(int err);
bool IS_AVERROR_EOF(int err);
bool IS_AVERROR_EAGAIN(int err);
bool AVFILTER_EOF(int ret);
bool IS_AVERROR_INVALIDDATA(int err);
