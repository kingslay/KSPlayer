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
    private var bufferSrcContext: UnsafeMutablePointer<AVFilterContext>?
    private var bufferSinkContext: UnsafeMutablePointer<AVFilterContext>?
    private var filters: String?
    let timebase: Timebase
    private let isAudio: Bool
    private var params = AVBufferSrcParameters()
    private let nominalFrameRate: Float
    deinit {
        graph?.pointee.opaque = nil
        avfilter_graph_free(&graph)
    }

    public init(timebase: Timebase, isAudio: Bool, nominalFrameRate: Float, options: KSOptions) {
        graph = avfilter_graph_alloc()
        graph?.pointee.opaque = Unmanaged.passUnretained(options).toOpaque()
        self.timebase = timebase
        self.isAudio = isAudio
        self.nominalFrameRate = nominalFrameRate
    }

    private func setup(filters: String) -> Bool {
        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        var ret = avfilter_graph_parse2(graph, filters, &inputs, &outputs)
        guard ret >= 0, let graph, let inputs, let outputs else {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
            return false
        }
        let bufferSink = avfilter_get_by_name(isAudio ? "abuffersink" : "buffersink")
        ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, "out", nil, nil, graph)
        guard ret >= 0 else { return false }
        ret = avfilter_link(outputs.pointee.filter_ctx, UInt32(outputs.pointee.pad_idx), bufferSinkContext, 0)
        guard ret >= 0 else { return false }
        let buffer = avfilter_get_by_name(isAudio ? "abuffer" : "buffer")
        bufferSrcContext = avfilter_graph_alloc_filter(graph, buffer, "in")
        guard bufferSrcContext != nil else { return false }
        av_buffersrc_parameters_set(bufferSrcContext, &params)
        ret = avfilter_init_str(bufferSrcContext, nil)
        guard ret >= 0 else { return false }
        ret = avfilter_link(bufferSrcContext, 0, inputs.pointee.filter_ctx, UInt32(inputs.pointee.pad_idx))
        guard ret >= 0 else { return false }
        if let ctx = params.hw_frames_ctx {
            let framesCtxData = UnsafeMutableRawPointer(ctx.pointee.data).bindMemory(to: AVHWFramesContext.self, capacity: 1)
            inputs.pointee.filter_ctx.pointee.hw_device_ctx = framesCtxData.pointee.device_ref
//                    outputs.pointee.filter_ctx.pointee.hw_device_ctx = framesCtxData.pointee.device_ref
//                    bufferSrcContext?.pointee.hw_device_ctx = framesCtxData.pointee.device_ref
//                    bufferSinkContext?.pointee.hw_device_ctx = framesCtxData.pointee.device_ref
        }
        ret = avfilter_graph_config(graph, nil)
        guard ret >= 0 else { return false }
        return true
    }

    private func setup2(filters: String) -> Bool {
        guard let graph else {
            return false
        }
        let bufferName = isAudio ? "abuffer" : "buffer"
        let bufferSrc = avfilter_get_by_name(bufferName)
        var ret = avfilter_graph_create_filter(&bufferSrcContext, bufferSrc, "ksplayer_\(bufferName)", params.arg, nil, graph)
        av_buffersrc_parameters_set(bufferSrcContext, &params)
        let bufferSink = avfilter_get_by_name(bufferName + "sink")
        ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, "ksplayer_\(bufferName)sink", nil, nil, graph)
        guard ret >= 0 else { return false }
        //        av_opt_set_int_list(bufferSinkContext, "pix_fmts", [AV_PIX_FMT_GRAY8, AV_PIX_FMT_NONE] AV_PIX_FMT_NONE,AV_OPT_SEARCH_CHILDREN)
        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        outputs?.pointee.name = strdup("in")
        outputs?.pointee.filter_ctx = bufferSrcContext
        outputs?.pointee.pad_idx = 0
        outputs?.pointee.next = nil
        inputs?.pointee.name = strdup("out")
        inputs?.pointee.filter_ctx = bufferSinkContext
        inputs?.pointee.pad_idx = 0
        inputs?.pointee.next = nil
        let filterNb = Int(graph.pointee.nb_filters)
        ret = avfilter_graph_parse_ptr(graph, filters, &inputs, &outputs, nil)
        guard ret >= 0 else {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
            return false
        }
        for i in 0 ..< Int(graph.pointee.nb_filters) - filterNb {
            swap(&graph.pointee.filters[i], &graph.pointee.filters[i + filterNb])
        }
        ret = avfilter_graph_config(graph, nil)
        guard ret >= 0 else { return false }
        return true
    }

    public func filter(options: KSOptions, inputFrame: UnsafeMutablePointer<AVFrame>, completionHandler: (UnsafeMutablePointer<AVFrame>) -> Void) {
        let filters: String
        if isAudio {
            filters = options.audioFilters.joined(separator: ",")
        } else {
            if options.autoDeInterlace, !options.videoFilters.contains("idet") {
                options.videoFilters.append("idet")
            }
            filters = options.videoFilters.joined(separator: ",")
        }
        guard !filters.isEmpty else {
            completionHandler(inputFrame)
            return
        }
        var params = AVBufferSrcParameters()
        params.format = inputFrame.pointee.format
        params.time_base = timebase.rational
        params.width = inputFrame.pointee.width
        params.height = inputFrame.pointee.height
        params.sample_aspect_ratio = inputFrame.pointee.sample_aspect_ratio
        params.frame_rate = AVRational(num: 1, den: Int32(nominalFrameRate))
        if let ctx = inputFrame.pointee.hw_frames_ctx {
            params.hw_frames_ctx = av_buffer_ref(ctx)
        }
        params.sample_rate = inputFrame.pointee.sample_rate
        params.ch_layout = inputFrame.pointee.ch_layout
        if self.params != params || self.filters != filters {
            self.params = params
            self.filters = filters
            if !setup(filters: filters) {
                completionHandler(inputFrame)
                return
            }
        }
        if graph?.pointee.sink_links_count == 0 {
            completionHandler(inputFrame)
            return
        }
        let ret = av_buffersrc_add_frame_flags(bufferSrcContext, inputFrame, 0)
        if ret < 0 {
            return
        }
        while av_buffersink_get_frame_flags(bufferSinkContext, inputFrame, 0) >= 0 {
//                timebase = Timebase(av_buffersink_get_time_base(bufferSinkContext))
            completionHandler(inputFrame)
            // 一定要加av_frame_unref，不然会内存泄漏。
            av_frame_unref(inputFrame)
        }
    }
}
