//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import AudioToolbox
import ffmpeg

final class ATBPlayerItemTrack: AsyncPlayerItemTrack<AudioFrame> {
    // 刷新Session的话，后续的解码还是会失败，直到遇到I帧
    private var converter: AudioConverterRef?
    override func open() -> Bool {
        if super.open() {
            var outputFormat = KSDefaultParameter.outputFormat()
            var inputFormat = codecpar.pointee.inputFormat
            return AudioConverterNew(&inputFormat, &outputFormat, &converter) == 0
        }
        return false
    }

    override func doDecode(packet: Packet) throws -> [AudioFrame] {
        guard let corePacket = packet.corePacket, let converter = converter else {
            return []
        }
        let inputDataProc: AudioConverterComplexInputDataProc
        inputDataProc = { (_, ioPacketCount, audioBufferList, _, userData) -> OSStatus in
            let packet = UnsafePointer<AVPacket>(OpaquePointer(userData!))
            var bufferList = AudioBufferList()
            bufferList.mNumberBuffers = 1
            bufferList.mBuffers.mData = UnsafeMutableRawPointer(OpaquePointer(packet.pointee.data))
            bufferList.mBuffers.mDataByteSize = UInt32(packet.pointee.size)
            bufferList.mBuffers.mNumberChannels = 1
            audioBufferList.initialize(to: bufferList)
            ioPacketCount.pointee = UInt32(packet.pointee.size)
            return 0
        }
        var outAudioBufferList = AudioBufferList()
        var ioOutputDataPacketSize: UInt32 = 1
        AudioConverterFillComplexBuffer(converter, inputDataProc, corePacket, &ioOutputDataPacketSize, &outAudioBufferList, nil)
        let frame = AudioFrame()
        frame.timebase = timebase
        frame.position = corePacket.pointee.pts
        if frame.position == Int64.min || frame.position < 0 {
            frame.position = max(corePacket.pointee.dts, 0)
        }
        frame.duration = corePacket.pointee.duration
        frame.size = Int64(corePacket.pointee.size)
//        frame.bufferSize = outAudioBufferList.mNumberBuffers
        return [frame]
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
        inputFormat.mSampleRate = Float64(sample_rate)
        inputFormat.mChannelsPerFrame = UInt32(channels)
        inputFormat.mBytesPerPacket = UInt32(codec_id == AV_CODEC_ID_ILBC ? block_align : 0)
        if codec_id == AV_CODEC_ID_ADPCM_IMA_QT {
            inputFormat.mFramesPerPacket = 64
        }
        return inputFormat
    }
}
