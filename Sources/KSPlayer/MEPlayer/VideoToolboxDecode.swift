//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import FFmpegKit
import Libavformat
import VideoToolbox
class VideoToolboxDecode: DecodeProtocol {
    private weak var delegate: DecodeResultDelegate?
    private var session: DecompressionSession?
    private let timebase: Timebase
    private let options: KSOptions
    private var startTime = Int64(0)
    private var lastPosition = Int64(0)
    private var error: NSError?
    required convenience init(assetTrack: FFmpegAssetTrack, options: KSOptions, delegate: DecodeResultDelegate) {
        self.init(assetTrack: assetTrack, options: options, session: DecompressionSession(codecpar: assetTrack.codecpar, options: options), delegate: delegate)
    }

    init(assetTrack: FFmpegAssetTrack, options: KSOptions, session: DecompressionSession?, delegate: DecodeResultDelegate) {
        timebase = assetTrack.timebase
        self.options = options
        self.session = session
        self.delegate = delegate
    }

    func doDecode(packet: Packet) throws {
        guard let corePacket = packet.corePacket?.pointee, let data = corePacket.data, let session else {
            delegate?.decodeResult(frame: nil)
            return
        }
        let sampleBuffer = try session.formatDescription.getSampleBuffer(isConvertNALSize: session.isConvertNALSize, data: data, size: Int(corePacket.size))
        let flags: VTDecodeFrameFlags = [
            ._EnableAsynchronousDecompression,
        ]
        var flagOut = VTDecodeInfoFlags.frameDropped
        let pts = corePacket.pts
        let packetFlags = corePacket.flags
        let duration = corePacket.duration
        let size = corePacket.size
        let status = VTDecompressionSessionDecodeFrame(session.decompressionSession, sampleBuffer: sampleBuffer, flags: flags, infoFlagsOut: &flagOut) { [weak self] status, infoFlags, imageBuffer, _, _ in
            guard let self, !infoFlags.contains(.frameDropped) else {
                return
            }
            guard status == noErr else {
                if status == kVTInvalidSessionErr || status == kVTVideoDecoderMalfunctionErr || status == kVTVideoDecoderBadDataErr {
                    if corePacket.flags & AV_PKT_FLAG_KEY == 1 {
                        self.error = NSError(errorCode: .codecVideoReceiveFrame, avErrorCode: status)
                    }
                }
                return
            }
            self.error = nil
            let frame = VideoVTBFrame()
            frame.corePixelBuffer = imageBuffer
            frame.timebase = self.timebase
            if packetFlags & AV_PKT_FLAG_KEY == 1, packetFlags & AV_PKT_FLAG_DISCARD != 0, self.lastPosition > 0 {
                self.startTime = self.lastPosition - pts
            }
            self.lastPosition = max(self.lastPosition, pts)
            frame.position = self.startTime + pts
            frame.duration = duration
            frame.size = size
            self.lastPosition += frame.duration
            self.delegate?.decodeResult(frame: frame)
        }
        if let error {
            throw error
        }
        if status == kVTInvalidSessionErr || status == kVTVideoDecoderMalfunctionErr || status == kVTVideoDecoderBadDataErr {
            if corePacket.flags & AV_PKT_FLAG_KEY == 1 {
                throw NSError(errorCode: .codecVideoReceiveFrame, avErrorCode: status)
            } else {
                // 解决从后台切换到前台，解码失败的问题
                doFlushCodec()
            }
        }
    }

    func doFlushCodec() {
        if let session {
            self.session = DecompressionSession(codecpar: session.codecpar, options: options)
        }
        lastPosition = 0
        startTime = 0
    }

    func shutdown() {
        session = nil
    }

    func decode() {
        lastPosition = 0
        startTime = 0
    }
}

class DecompressionSession {
    fileprivate let isConvertNALSize: Bool
    fileprivate let formatDescription: CMFormatDescription
    fileprivate let decompressionSession: VTDecompressionSession
    fileprivate var codecpar: AVCodecParameters
    init?(codecpar: AVCodecParameters, options: KSOptions) {
        self.codecpar = codecpar
        let isFullRangeVideo = codecpar.color_range == AVCOL_RANGE_JPEG
        let format = AVPixelFormat(codecpar.format)
        guard let pixelFormatType = format.osType(fullRange: isFullRangeVideo) else {
            return nil
        }
        let videoCodecType = codecpar.codec_id.mediaSubType.rawValue
        #if os(macOS)
        VTRegisterProfessionalVideoWorkflowVideoDecoders()
        if #available(macOS 11.0, *) {
            VTRegisterSupplementalVideoDecoderIfAvailable(videoCodecType)
        }
        #endif
        var extradataSize = Int32(0)
        var extradata = codecpar.extradata
        let atomsData: Data?
        if let extradata {
            extradataSize = codecpar.extradata_size
            if extradataSize >= 5, extradata[4] == 0xFE {
                extradata[4] = 0xFF
                isConvertNALSize = true
            } else {
                isConvertNALSize = false
            }
            atomsData = Data(bytes: extradata, count: Int(extradataSize))
        } else {
            if videoCodecType == kCMVideoCodecType_VP9 {
                // ff_videotoolbox_vpcc_extradata_create
                var ioContext: UnsafeMutablePointer<AVIOContext>?
                guard avio_open_dyn_buf(&ioContext) == 0 else {
                    return nil
                }
                ff_isom_write_vpcc(options.formatCtx, ioContext, &self.codecpar)
                extradataSize = avio_close_dyn_buf(ioContext, &extradata)
                guard let extradata else {
                    return nil
                }
                var data = Data()
                var array: [UInt8] = [1, 0, 0, 0]
                data.append(&array, count: 4)
                data.append(extradata, count: Int(extradataSize))
                atomsData = data
            } else {
                atomsData = nil
            }
            isConvertNALSize = false
        }
        let dic: NSMutableDictionary = [
            kCVImageBufferChromaLocationBottomFieldKey: kCVImageBufferChromaLocation_Left,
            kCVImageBufferChromaLocationTopFieldKey: kCVImageBufferChromaLocation_Left,
            kCMFormatDescriptionExtension_FullRangeVideo: isFullRangeVideo,
            videoCodecType == kCMVideoCodecType_HEVC ? "EnableHardwareAcceleratedVideoDecoder" : "RequireHardwareAcceleratedVideoDecoder": true,
        ]
        if let atomsData {
            dic[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] = [videoCodecType.avc: atomsData]
        }
        dic[kCVImageBufferPixelAspectRatioKey] = codecpar.sample_aspect_ratio.size.aspectRatio
        dic[kCVImageBufferColorPrimariesKey] = codecpar.color_primaries.colorPrimaries
        dic[kCVImageBufferTransferFunctionKey] = codecpar.color_trc.transferFunction
        dic[kCVImageBufferYCbCrMatrixKey] = codecpar.color_space.ycbcrMatrix
        // swiftlint:disable line_length
        var description: CMFormatDescription?
        var status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: videoCodecType, width: codecpar.width, height: codecpar.height, extensions: dic, formatDescriptionOut: &description)
        // swiftlint:enable line_length
        guard status == noErr, let formatDescription = description else {
            return nil
        }
        self.formatDescription = formatDescription
//        VTDecompressionSessionCanAcceptFormatDescription(<#T##session: VTDecompressionSession##VTDecompressionSession#>, formatDescription: <#T##CMFormatDescription#>)
        let attributes: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferWidthKey: codecpar.width,
            kCVPixelBufferHeightKey: codecpar.height,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ]
        var session: VTDecompressionSession?
        // swiftlint:disable line_length
        status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: formatDescription, decoderSpecification: dic, imageBufferAttributes: attributes, outputCallback: nil, decompressionSessionOut: &session)
        // swiftlint:enable line_length
        guard status == noErr, let decompressionSession = session else {
            return nil
        }
        if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
            VTSessionSetProperty(decompressionSession, key: kVTDecompressionPropertyKey_PropagatePerFrameHDRDisplayMetadata,
                                 value: kCFBooleanTrue)
        }
        if let destinationDynamicRange = options.availableDynamicRange(nil) {
            let pixelTransferProperties = [kVTPixelTransferPropertyKey_DestinationColorPrimaries: destinationDynamicRange.colorPrimaries,
                                           kVTPixelTransferPropertyKey_DestinationTransferFunction: destinationDynamicRange.transferFunction,
                                           kVTPixelTransferPropertyKey_DestinationYCbCrMatrix: destinationDynamicRange.yCbCrMatrix]
            VTSessionSetProperty(decompressionSession,
                                 key: kVTDecompressionPropertyKey_PixelTransferProperties,
                                 value: pixelTransferProperties as CFDictionary)
        }
        self.decompressionSession = decompressionSession
    }

    deinit {
        VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession)
        VTDecompressionSessionInvalidate(decompressionSession)
    }
}

extension CMFormatDescription {
    fileprivate func getSampleBuffer(isConvertNALSize: Bool, data: UnsafeMutablePointer<UInt8>, size: Int) throws -> CMSampleBuffer {
        if isConvertNALSize {
            var ioContext: UnsafeMutablePointer<AVIOContext>?
            let status = avio_open_dyn_buf(&ioContext)
            if status == 0 {
                var nalSize: UInt32 = 0
                let end = data + size
                var nalStart = data
                while nalStart < end {
                    nalSize = UInt32(nalStart[0]) << 16 | UInt32(nalStart[1]) << 8 | UInt32(nalStart[2])
                    avio_wb32(ioContext, nalSize)
                    nalStart += 3
                    avio_write(ioContext, nalStart, Int32(nalSize))
                    nalStart += Int(nalSize)
                }
                var demuxBuffer: UnsafeMutablePointer<UInt8>?
                let demuxSze = avio_close_dyn_buf(ioContext, &demuxBuffer)
                return try createSampleBuffer(data: demuxBuffer, size: Int(demuxSze))
            } else {
                throw NSError(errorCode: .codecVideoReceiveFrame, avErrorCode: status)
            }
        } else {
            return try createSampleBuffer(data: data, size: size)
        }
    }

    private func createSampleBuffer(data: UnsafeMutablePointer<UInt8>?, size: Int) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        var sampleBuffer: CMSampleBuffer?
        // swiftlint:disable line_length
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: data, blockLength: size, blockAllocator: kCFAllocatorNull, customBlockSource: nil, offsetToData: 0, dataLength: size, flags: 0, blockBufferOut: &blockBuffer)
        if status == noErr {
            status = CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self, sampleCount: 1, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer)
            if let sampleBuffer {
                return sampleBuffer
            }
        }
        throw NSError(errorCode: .codecVideoReceiveFrame, avErrorCode: status)
        // swiftlint:enable line_length
    }
}

extension CMVideoCodecType {
    var avc: String {
        switch self {
        case kCMVideoCodecType_MPEG4Video:
            return "esds"
        case kCMVideoCodecType_H264:
            return "avcC"
        case kCMVideoCodecType_HEVC:
            return "hvcC"
        case kCMVideoCodecType_VP9:
            return "vpcC"
        default: return "avcC"
        }
    }
}
