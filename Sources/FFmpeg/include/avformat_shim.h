#ifndef AVFORMAT_SHIM_H
#define AVFORMAT_SHIM_H

#import <Libavformat/avformat.h>
#import <Libavformat/avio.h>

int ff_isom_write_vpcc(AVFormatContext *s, AVIOContext *pb, AVCodecParameters *par);
int ff_isom_write_avcc(AVIOContext *pb, const uint8_t *data, int len);
int ff_isom_write_hvcc(AVIOContext *pb, const uint8_t *data, int size, int ps_array_completeness);
int ff_isom_write_av1c(AVIOContext *pb, const uint8_t *buf, int size, int write_seq_header);
extern AVClass ffurl_context_class;

typedef struct URLContext {
    const AVClass *av_class;    /**< information for av_log(). Set by url_open(). */
    const struct URLProtocol *prot;
    void *priv_data;
    char *filename;             /**< specified URL */
    int flags;
    int max_packet_size;        /**< if non zero, the stream is packetized with this max packet size */
    int is_streamed;            /**< true if streamed (no seek possible), default = false */
    int is_connected;
    AVIOInterruptCB interrupt_callback;
    int64_t rw_timeout;         /**< maximum time to wait for (network) read/write operation completion, in mcs */
    const char *protocol_whitelist;
    const char *protocol_blacklist;
    int min_packet_size;        /**< if non zero, the stream is packetized with this min packet size */
} URLContext;


#endif /* AVFORMAT_SHIM_H */
