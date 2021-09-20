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
    deinit {
        avfilter_graph_free(&graph)
        av_frame_free(&outputFrame)
    }

    public init?(filters: String, args: String, isAudio: Bool) {
        graph = avfilter_graph_alloc()
        if !setup(filters: filters, args: args, isAudio: isAudio) {
            return nil
        }
    }

    private func setup(filters: String, args: String, isAudio: Bool) -> Bool {
        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        defer {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
        }
        let buffer = avfilter_get_by_name(isAudio ? "abuffer" : "buffer")
        /// create buffer filter necessary parameter
        var ret = avfilter_graph_create_filter(&bufferContext, buffer, buffer?.pointee.name, args, nil, graph)
        guard ret >= 0, bufferContext != nil else { return false }
        let bufferSink = avfilter_get_by_name(isAudio ? "abuffersink" : "buffersink")
        ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, buffer?.pointee.name, nil, nil, graph)
        guard ret >= 0, bufferSinkContext != nil else { return false }
        inputs?.pointee.name = av_strdup("in")
        inputs?.pointee.filter_ctx = bufferContext
        inputs?.pointee.pad_idx = 0

        outputs?.pointee.name = av_strdup("out")
        outputs?.pointee.filter_ctx = bufferSinkContext
        outputs?.pointee.pad_idx = 0
        outputs?.pointee.next = nil
        inputs?.pointee.next = nil

        ret = avfilter_graph_parse_ptr(graph, filters, &outputs, &inputs, nil)
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

    public func filter(inputFrame: UnsafeMutablePointer<AVFrame>) -> UnsafeMutablePointer<AVFrame>? {
        var ret = av_buffersrc_add_frame_flags(bufferContext, inputFrame, Int32(AV_BUFFERSRC_FLAG_KEEP_REF))
        guard ret == 0 else { return nil }
        av_frame_unref(outputFrame)
        ret = av_buffersink_get_frame(bufferSinkContext, outputFrame)
        guard ret == 0 else { return nil }
        return outputFrame
    }
}
