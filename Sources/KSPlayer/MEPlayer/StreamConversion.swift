//
//  StreamConversion.swift
//
//
//  Created by kintan on 4/5/24.
//

import AVFoundation
import Foundation
import Libavcodec
import Libavdevice
import Libavformat

public class StreamConversion: ObservableObject {
    private var formatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var packet: UnsafeMutablePointer<AVPacket>?
    private var outputPacket: UnsafeMutablePointer<AVPacket>?
    public init(url: String, options: [String: Any], outputURL: String, inFormat: String? = nil, outFormat: String? = nil) throws {
        avdevice_register_all()
        formatCtx = avformat_alloc_context()
        var avOptions = options.avOptions
        let inputFormat: UnsafePointer<AVInputFormat>?
        if let inFormat {
            inputFormat = av_find_input_format(inFormat)
        } else {
            inputFormat = nil
        }
        var result = avformat_open_input(&formatCtx, url, inputFormat, &avOptions)
        av_dict_free(&avOptions)
        guard result == 0, let formatCtx else {
            throw NSError(errorCode: .formatOpenInput, avErrorCode: result)
        }
        result = avformat_find_stream_info(formatCtx, nil)
        guard result == 0 else {
            throw NSError(errorCode: .formatFindStreamInfo, avErrorCode: result)
        }
        var ret = avformat_alloc_output_context2(&outputFormatCtx, nil, outFormat, outputURL)
        guard let outputFormatCtx else {
            throw NSError(errorCode: .formatOutputCreate, avErrorCode: ret)
        }
        let formatName = outputFormatCtx.pointee.oformat.pointee.name.flatMap { String(cString: $0) }
        for i in 0 ..< Int(formatCtx.pointee.nb_streams) {
            if let inputStream = formatCtx.pointee.streams[i] {
                let codecType = inputStream.pointee.codecpar.pointee.codec_type
                if [AVMEDIA_TYPE_AUDIO, AVMEDIA_TYPE_VIDEO, AVMEDIA_TYPE_SUBTITLE].contains(codecType) {
                    if let outStream = avformat_new_stream(outputFormatCtx, nil) {
                        avcodec_parameters_copy(outStream.pointee.codecpar, inputStream.pointee.codecpar)
                    }
                }
            }
        }
        avio_open(&outputFormatCtx.pointee.pb, outputURL, AVIO_FLAG_WRITE)
        ret = avformat_write_header(outputFormatCtx, nil)
        guard ret >= 0 else {
            avformat_close_input(&self.outputFormatCtx)
            throw NSError(errorCode: .formatWriteHeader, avErrorCode: ret)
        }
    }

    public func start() {
        guard let formatCtx, let outputFormatCtx else {
            return
        }
        packet = av_packet_alloc()
        outputPacket = av_packet_alloc()
        guard var packet, var outputPacket else {
            return
        }
        while av_read_frame(formatCtx, self.packet) >= 0 {
            let index = Int(packet.pointee.stream_index)
            if let inputTb = formatCtx.pointee.streams[index]?.pointee.time_base,
               let outputTb = outputFormatCtx.pointee.streams[index]?.pointee.time_base
            {
                av_packet_ref(outputPacket, packet)
                outputPacket.pointee.stream_index = Int32(index)
                av_packet_rescale_ts(outputPacket, inputTb, outputTb)
                outputPacket.pointee.pos = -1
                let ret = av_interleaved_write_frame(outputFormatCtx, outputPacket)
                if ret < 0 {
                    KSLog("can not av_interleaved_write_frame")
                }
            }
        }
    }

    public func stop() {
        av_packet_free(&packet)
        av_packet_free(&outputPacket)
        av_write_trailer(outputFormatCtx)
        avformat_close_input(&formatCtx)
        avformat_close_input(&outputFormatCtx)
    }
}
