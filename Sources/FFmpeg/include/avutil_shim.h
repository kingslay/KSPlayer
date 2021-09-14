#ifndef AVUTIL_SHIM_H
#define AVUTIL_SHIM_H

#import <Libavutil/avutil.h>
#import <Libavutil/display.h>
#import <Libavutil/channel_layout.h>
#import <Libavutil/opt.h>

static const int64_t swift_AV_NOPTS_VALUE = AV_NOPTS_VALUE;

/* Audio channel layout */
static const uint64_t swift_AV_CH_LAYOUT_NATIVE            = AV_CH_LAYOUT_NATIVE;
static const uint64_t swift_AV_CH_LAYOUT_MONO              = AV_CH_LAYOUT_MONO;
static const uint64_t swift_AV_CH_LAYOUT_STEREO            = AV_CH_LAYOUT_STEREO;
static const uint64_t swift_AV_CH_LAYOUT_2POINT1           = AV_CH_LAYOUT_2POINT1;
static const uint64_t swift_AV_CH_LAYOUT_2_1               = AV_CH_LAYOUT_2_1;
static const uint64_t swift_AV_CH_LAYOUT_SURROUND          = AV_CH_LAYOUT_SURROUND;
static const uint64_t swift_AV_CH_LAYOUT_3POINT1           = AV_CH_LAYOUT_3POINT1;
static const uint64_t swift_AV_CH_LAYOUT_4POINT0           = AV_CH_LAYOUT_4POINT0;
static const uint64_t swift_AV_CH_LAYOUT_4POINT1           = AV_CH_LAYOUT_4POINT1;
static const uint64_t swift_AV_CH_LAYOUT_2_2               = AV_CH_LAYOUT_2_2;
static const uint64_t swift_AV_CH_LAYOUT_QUAD              = AV_CH_LAYOUT_QUAD;
static const uint64_t swift_AV_CH_LAYOUT_5POINT0           = AV_CH_LAYOUT_5POINT0;
static const uint64_t swift_AV_CH_LAYOUT_5POINT1           = AV_CH_LAYOUT_5POINT1;
static const uint64_t swift_AV_CH_LAYOUT_5POINT0_BACK      = AV_CH_LAYOUT_5POINT0_BACK;
static const uint64_t swift_AV_CH_LAYOUT_5POINT1_BACK      = AV_CH_LAYOUT_5POINT1_BACK;
static const uint64_t swift_AV_CH_LAYOUT_6POINT0           = AV_CH_LAYOUT_6POINT0;
static const uint64_t swift_AV_CH_LAYOUT_6POINT0_FRONT     = AV_CH_LAYOUT_6POINT0_FRONT;
static const uint64_t swift_AV_CH_LAYOUT_HEXAGONAL         = AV_CH_LAYOUT_HEXAGONAL;
static const uint64_t swift_AV_CH_LAYOUT_6POINT1           = AV_CH_LAYOUT_6POINT1;
static const uint64_t swift_AV_CH_LAYOUT_6POINT1_BACK      = AV_CH_LAYOUT_6POINT1_BACK;
static const uint64_t swift_AV_CH_LAYOUT_6POINT1_FRONT     = AV_CH_LAYOUT_6POINT1_FRONT;
static const uint64_t swift_AV_CH_LAYOUT_7POINT0           = AV_CH_LAYOUT_7POINT0;
static const uint64_t swift_AV_CH_LAYOUT_7POINT0_FRONT     = AV_CH_LAYOUT_7POINT0_FRONT;
static const uint64_t swift_AV_CH_LAYOUT_7POINT1           = AV_CH_LAYOUT_7POINT1;
static const uint64_t swift_AV_CH_LAYOUT_7POINT1_WIDE      = AV_CH_LAYOUT_7POINT1_WIDE;
static const uint64_t swift_AV_CH_LAYOUT_7POINT1_WIDE_BACK = AV_CH_LAYOUT_7POINT1_WIDE_BACK;
static const uint64_t swift_AV_CH_LAYOUT_OCTAGONAL         = AV_CH_LAYOUT_OCTAGONAL;
static const uint64_t swift_AV_CH_LAYOUT_HEXADECAGONAL     = AV_CH_LAYOUT_HEXADECAGONAL;
static const uint64_t swift_AV_CH_LAYOUT_STEREO_DOWNMIX    = AV_CH_LAYOUT_STEREO_DOWNMIX;
static const uint64_t swift_AV_OPT_SEARCH_CHILDREN         = AV_OPT_SEARCH_CHILDREN;

/* error handling */
static inline int swift_AVERROR(int errnum) {
  return AVERROR(errnum);
}

static inline int swift_AVUNERROR(int errnum) {
  return AVUNERROR(errnum);
}

static const int swift_AVERROR_BSF_NOT_FOUND      = AVERROR_BSF_NOT_FOUND; ///< Bitstream filter not found
static const int swift_AVERROR_BUG                = AVERROR_BUG; ///< Internal bug, also see AVERROR_BUG2
static const int swift_AVERROR_BUFFER_TOO_SMALL   = AVERROR_BUFFER_TOO_SMALL; ///< Buffer too small
static const int swift_AVERROR_DECODER_NOT_FOUND  = AVERROR_DECODER_NOT_FOUND; ///< Decoder not found
static const int swift_AVERROR_DEMUXER_NOT_FOUND  = AVERROR_DEMUXER_NOT_FOUND; ///< Demuxer not found
static const int swift_AVERROR_ENCODER_NOT_FOUND  = AVERROR_ENCODER_NOT_FOUND; ///< Encoder not found
static const int swift_AVERROR_EOF                = AVERROR_EOF; ///< End of file
static const int swift_AVERROR_EXIT               = AVERROR_EXIT; ///< Immediate exit was requested; the called function should not be restarted
static const int swift_AVERROR_EXTERNAL           = AVERROR_EXTERNAL; ///< Generic error in an external library
static const int swift_AVERROR_FILTER_NOT_FOUND   = AVERROR_FILTER_NOT_FOUND; ///< Filter not found
static const int swift_AVERROR_INVALIDDATA        = AVERROR_INVALIDDATA; ///< Invalid data found when processing input
static const int swift_AVERROR_MUXER_NOT_FOUND    = AVERROR_MUXER_NOT_FOUND; ///< Muxer not found
static const int swift_AVERROR_OPTION_NOT_FOUND   = AVERROR_OPTION_NOT_FOUND; ///< Option not found
static const int swift_AVERROR_PATCHWELCOME       = AVERROR_PATCHWELCOME; ///< Not yet implemented in FFmpeg, patches welcome
static const int swift_AVERROR_PROTOCOL_NOT_FOUND = AVERROR_PROTOCOL_NOT_FOUND; ///< Protocol not found

static const int swift_AVERROR_STREAM_NOT_FOUND   = AVERROR_STREAM_NOT_FOUND; ///< Stream not found
/**
 * This is semantically identical to AVERROR_BUG
 * it has been introduced in Libav after our AVERROR_BUG and with a modified value.
 */
static const int swift_AVERROR_BUG2               = AVERROR_BUG2;
static const int swift_AVERROR_UNKNOWN            = AVERROR_UNKNOWN; ///< Unknown error, typically from an external library
static const int swift_AVERROR_EXPERIMENTAL       = AVERROR_EXPERIMENTAL; ///< Requested feature is flagged experimental. Set strict_std_compliance if you really want to use it.
static const int swift_AVERROR_INPUT_CHANGED      = AVERROR_INPUT_CHANGED; ///< Input changed between calls. Reconfiguration is required. (can be OR-ed with AVERROR_OUTPUT_CHANGED)
static const int swift_AVERROR_OUTPUT_CHANGED     = AVERROR_OUTPUT_CHANGED; ///< Output changed between calls. Reconfiguration is required. (can be OR-ed with AVERROR_INPUT_CHANGED)
/* HTTP & RTSP errors */
static const int swift_AVERROR_HTTP_BAD_REQUEST   = AVERROR_HTTP_BAD_REQUEST;
static const int swift_AVERROR_HTTP_UNAUTHORIZED  = AVERROR_HTTP_UNAUTHORIZED;
static const int swift_AVERROR_HTTP_FORBIDDEN     = AVERROR_HTTP_FORBIDDEN;
static const int swift_AVERROR_HTTP_NOT_FOUND     = AVERROR_HTTP_NOT_FOUND;
static const int swift_AVERROR_HTTP_OTHER_4XX     = AVERROR_HTTP_OTHER_4XX;
static const int swift_AVERROR_HTTP_SERVER_ERROR  = AVERROR_HTTP_SERVER_ERROR;

#endif /* AVUTIL_SHIM_H */
