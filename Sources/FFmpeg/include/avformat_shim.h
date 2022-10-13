#ifndef AVFORMAT_SHIM_H
#define AVFORMAT_SHIM_H

#import <Libavformat/avformat.h>
#import <Libavformat/avio.h>
int ff_isom_write_vpcc(AVFormatContext *s, AVIOContext *pb, AVCodecParameters *par);
int ff_isom_write_avcc(AVIOContext *pb, const uint8_t *data, int len);
int ff_isom_write_hvcc(AVIOContext *pb, const uint8_t *data, int size, int ps_array_completeness);
int ff_isom_write_av1c(AVIOContext *pb, const uint8_t *buf, int size, int write_seq_header);
#endif /* AVFORMAT_SHIM_H */
