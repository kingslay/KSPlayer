//
//  Filter.swift
//  KSPlayer
//
//  Created by kintan on 2021/8/7.
//

import Foundation
import Libavfilter
import Libavutil
class MEFilter {
    private var graph: UnsafeMutablePointer<AVFilterGraph>?
    private var bufferContext: UnsafeMutablePointer<AVFilterContext>?
    private var bufferSinkContext: UnsafeMutablePointer<AVFilterContext>?
    private var outputFrame = av_frame_alloc()
    private var filters: String?
    private let timebase: Timebase
    private let isAudio: Bool
    private var args: String?

    deinit {
        avfilter_graph_free(&graph)
        av_frame_free(&outputFrame)
    }

    public init(timebase: Timebase, isAudio: Bool, options: KSOptions) {
        graph = avfilter_graph_alloc()
        graph?.pointee.opaque = Unmanaged.passUnretained(options).toOpaque()
        self.timebase = timebase
        self.isAudio = isAudio
    }

    private func setup(filters: String, args: String, hwDeviceCtx _: UnsafeMutablePointer<AVBufferRef>?) -> Bool {
        let buffer = avfilter_get_by_name(isAudio ? "abuffer" : "buffer")
        /// create buffer filter necessary parameter
        var ret = avfilter_graph_create_filter(&bufferContext, buffer, "in", args, nil, graph)
        guard ret >= 0, bufferContext != nil else { return false }
        let bufferSink = avfilter_get_by_name(isAudio ? "abuffersink" : "buffersink")
        ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, "out", nil, nil, graph)
        guard ret >= 0, bufferSinkContext != nil else { return false }
        // can not add hw_device_ctx
//        bufferContext?.pointee.hw_device_ctx = hwDeviceCtx
//        bufferSinkContext?.pointee.hw_device_ctx = hwDeviceCtx
//        ret = av_opt_set_int_list(bufferSinkContext, "pix_fmts", pix_fmts, AV_PIX_FMT_NONE, AV_OPT_SEARCH_CHILDREN)
//        ret = av_opt_set_int_list(bufferSinkContext, "sample_fmts", out_sample_fmts, -1,
//                                  AV_OPT_SEARCH_CHILDREN);
//        ret = av_opt_set(bufferSinkContext, "ch_layouts", "mono",
//                                  AV_OPT_SEARCH_CHILDREN);
//        ret = av_opt_set_int_list(bufferSinkContext, "sample_rates", out_sample_rates, -1,
//                                  AV_OPT_SEARCH_CHILDREN);
        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        defer {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
        }
        outputs?.pointee.name = av_strdup("in")
        outputs?.pointee.filter_ctx = bufferContext
        outputs?.pointee.pad_idx = 0
        outputs?.pointee.next = nil

        inputs?.pointee.name = av_strdup("out")
        inputs?.pointee.filter_ctx = bufferSinkContext
        inputs?.pointee.pad_idx = 0
        inputs?.pointee.next = nil
        ret = avfilter_graph_parse_ptr(graph, filters, &inputs, &outputs, nil)
        guard ret >= 0 else { return false }
//        let filterContexts = filters.map { str -> UnsafeMutablePointer<AVFilterContext>? in
//            let name: String
//            let args: String?
//            if let index = str.firstIndex(of: "=") {
//                name = String(str.prefix(upTo: index))
//                args = String(str.suffix(from: index))
//            } else {
//                name = str
//                args = nil
//            }
//            let filter = avfilter_get_by_name(name)
//            var filterContext: UnsafeMutablePointer<AVFilterContext>?
//            _ = avfilter_graph_create_filter(&filterContext, filter, name, args, nil, graph)
//            return filterContext
//        }
//        avfilter_link(bufferContext, 0, filterContexts[0], 0)
//        for i in 0..<filterContexts.count-1 {
//            avfilter_link(filterContexts[i], 0, filterContexts[i+1], 0)
//        }
//        avfilter_link(filterContexts[filterContexts.count - 1], 0, bufferSinkContext, 0)
        ret = avfilter_graph_config(graph, nil)
        guard ret >= 0 else { return false }
        return true
    }

    public func filter(options: KSOptions, inputFrame: UnsafeMutablePointer<AVFrame>, hwDeviceCtx: UnsafeMutablePointer<AVBufferRef>?) -> UnsafeMutablePointer<AVFrame> {
        var filters: String?
        if isAudio {
            filters = options.audioFilters
        } else {
            filters = options.videoFilters
            if options.autoDeInterlace {
                if var filters {
                    filters = "idet," + filters
                } else {
                    filters = "idet"
                }
            }
        }
        guard let filters else {
            return inputFrame
        }
        let args: String
        if isAudio {
            let fmt = String(cString: av_get_sample_fmt_name(AVSampleFormat(rawValue: inputFrame.pointee.format)))
            var str = [Int8](repeating: 0, count: 64)
            _ = av_channel_layout_describe(&inputFrame.pointee.ch_layout, &str, str.count)
            args = "sample_rate=\(inputFrame.pointee.sample_rate):sample_fmt=\(fmt):time_base=\(timebase.num)/\(timebase.den):channels=\(inputFrame.pointee.ch_layout.nb_channels):channel_layout=\(String(cString: str))"
        } else {
            let ratio = inputFrame.pointee.sample_aspect_ratio
            args = "video_size=\(inputFrame.pointee.width)x\(inputFrame.pointee.height):pix_fmt=\(inputFrame.pointee.format):time_base=\(timebase.num)/\(timebase.den):pixel_aspect=\(ratio.num)/\(ratio.den)"
        }
        if self.args != args || self.filters != filters {
            if setup(filters: filters, args: args, hwDeviceCtx: hwDeviceCtx) {
                self.args = args
                self.filters = filters
            } else {
                return inputFrame
            }
        }
        var ret = av_buffersrc_add_frame_flags(bufferContext, inputFrame, Int32(AV_BUFFERSRC_FLAG_KEEP_REF))
        guard ret == 0 else { return inputFrame }
        av_frame_unref(outputFrame)
        ret = av_buffersink_get_frame(bufferSinkContext, outputFrame)
        guard ret == 0 else { return inputFrame }
        return outputFrame ?? inputFrame
    }
}
