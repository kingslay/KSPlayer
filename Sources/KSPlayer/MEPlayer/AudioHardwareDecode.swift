//
//  AudioHardwareDecode.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import AudioToolbox
import Libavcodec

final class AudioHardwareDecode: DecodeProtocol {
    private let timebase: Timebase
    private var converter: AudioConverterRef?
    private var outAudioBufferList = AudioBufferList()
    required init(assetTrack: TrackProtocol, options _: KSOptions) {
        let codecpar = assetTrack.stream.pointee.codecpar.pointee
        timebase = assetTrack.timebase
        var inputFormat = codecpar.inputFormat
        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mFormatID = kAudioFormatLinearPCM
        outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        outputFormat.mFramesPerPacket = 1
        let sampleFmt = codecpar.bits_per_raw_sample == 32 ? AV_SAMPLE_FMT_S32 : AV_SAMPLE_FMT_S16
        outputFormat.mBitsPerChannel = UInt32(av_get_bytes_per_sample(sampleFmt) * 8)
        outputFormat.mSampleRate = inputFormat.mSampleRate
        outputFormat.mChannelsPerFrame = inputFormat.mChannelsPerFrame
        outAudioBufferList.mNumberBuffers = 1
        outAudioBufferList.mBuffers.mNumberChannels = UInt32(codecpar.channels)
        let bufferSize = outputFormat.mBitsPerChannel * UInt32(codecpar.channels * codecpar.frame_size)
        outAudioBufferList.mBuffers.mDataByteSize = bufferSize
        outAudioBufferList.mBuffers.mData = malloc(Int(bufferSize))
        AudioConverterNew(&inputFormat, &outputFormat, &converter)
    }

    func decode() {}

    func doDecode(packet: UnsafeMutablePointer<AVPacket>) throws -> [MEFrame] {
        guard let converter = converter else {
            return []
        }
        let inputDataProc: AudioConverterComplexInputDataProc = { _, ioPacketCount, audioBufferList, packetDesc, userData -> OSStatus in
            guard let packet = UnsafePointer<AVPacket>(OpaquePointer(userData)), let data = packet.pointee.data else {
                ioPacketCount.pointee = 0
                return 1
            }
            audioBufferList.pointee.mNumberBuffers = 1
            audioBufferList.pointee.mBuffers.mNumberChannels = 1
            audioBufferList.pointee.mBuffers.mData = UnsafeMutableRawPointer(data)
            audioBufferList.pointee.mBuffers.mDataByteSize = UInt32(packet.pointee.size)
            ioPacketCount.pointee = 1
            if let packetDesc = packetDesc {
                var description = AudioStreamPacketDescription()
                description.mStartOffset = 0
                description.mVariableFramesInPacket = 0
                description.mDataByteSize = audioBufferList.pointee.mBuffers.mDataByteSize
                withUnsafeMutablePointer(to: &description) {
                    packetDesc.pointee = $0
                }
            }
            return noErr
        }
        var ioOutputDataPacketSize = UInt32(0)
        let status = AudioConverterFillComplexBuffer(converter, inputDataProc, packet, &ioOutputDataPacketSize, &outAudioBufferList, nil)
        if status == noErr {
            let frame = AudioFrame(bufferSize: Int32(outAudioBufferList.mNumberBuffers), channels: Int32(outAudioBufferList.mBuffers.mNumberChannels))
            frame.timebase = timebase
            frame.position = packet.pointee.pts
            if frame.position == Int64.min || frame.position < 0 {
                frame.position = max(packet.pointee.dts, 0)
            }
            frame.duration = packet.pointee.duration
            frame.size = Int64(packet.pointee.size)
            return [frame]
        }
        return []
    }

    func doFlushCodec() {}

    func shutdown() {
        if let converter = converter {
            AudioConverterDispose(converter)
        }
        converter = nil
    }
}

extension AVCodecID {
    var mFormatID: UInt32 {
        switch self {
        case AV_CODEC_ID_AAC:
            return kAudioFormatMPEG4AAC
        case AV_CODEC_ID_AC3:
            return kAudioFormatAC3
        case AV_CODEC_ID_ADPCM_IMA_QT:
            return kAudioFormatAppleIMA4
        case AV_CODEC_ID_ALAC:
            return kAudioFormatAppleLossless
        case AV_CODEC_ID_AMR_NB:
            return kAudioFormatAMR
        case AV_CODEC_ID_EAC3:
            return kAudioFormatEnhancedAC3
        case AV_CODEC_ID_GSM_MS:
            return kAudioFormatMicrosoftGSM
        case AV_CODEC_ID_ILBC:
            return kAudioFormatiLBC
        case AV_CODEC_ID_MP1:
            return kAudioFormatMPEGLayer1
        case AV_CODEC_ID_MP2:
            return kAudioFormatMPEGLayer2
        case AV_CODEC_ID_MP3:
            return kAudioFormatMPEGLayer3
        case AV_CODEC_ID_PCM_ALAW:
            return kAudioFormatALaw
        case AV_CODEC_ID_PCM_MULAW:
            return kAudioFormatULaw
        case AV_CODEC_ID_QDMC:
            return kAudioFormatQDesign
        case AV_CODEC_ID_QDM2:
            return kAudioFormatQDesign2
        default:
            return 0
        }
    }
}

extension AVCodecParameters {
    var inputFormat: AudioStreamBasicDescription {
        var inputFormat = AudioStreamBasicDescription()
        inputFormat.mFormatID = codec_id.mFormatID
        inputFormat.mBytesPerPacket = UInt32(codec_id == AV_CODEC_ID_ILBC ? block_align : 0)
//        if extradata_size > 0, codec_id == AV_CODEC_ID_ALAC || codec_id == AV_CODEC_ID_QDM2 || codec_id == AV_CODEC_ID_QDMC || codec_id == AV_CODEC_ID_AAC {
//            if codec_id == AV_CODEC_ID_AAC {
//
//            }
//            AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, UInt32(extradata_size), extradata, nil, &inputFormat)
//        } else {
//        }
        inputFormat.mSampleRate = Float64(sample_rate)
        inputFormat.mChannelsPerFrame = UInt32(channels)
        if codec_id == AV_CODEC_ID_ADPCM_IMA_QT {
            inputFormat.mFramesPerPacket = 64
        }
        return inputFormat
    }
}
