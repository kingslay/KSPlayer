//  FFmpegAssetTrackTest.swift
//  KSPlayerTests
//
//  Trap guard + regression tests for FFmpegAssetTrack.audioNominalFrameRate.
//

@testable import KSPlayer
import FFmpegKit
import XCTest

final class FFmpegAssetTrackTest: XCTestCase {
    /// `AVCodecParameters.frame_size == 0` (left at 0 by most audio demuxers —
    /// AAC/MP3/Opus/FLAC/Vorbis — until the first frame is decoded): the old
    /// inline arithmetic on `FFmpegAssetTrack.swift:100` derived a fallback
    /// from `timebase.den / timebase.num`, which integer-divides to `0`
    /// whenever `den < num` (a valid `AVRational{num:3,den:1}`), so
    /// `sample_rate / 0` trapped with `Fatal error: Division by zero`. The
    /// helper must never trap; with `frame_size` unset it now falls back to
    /// codec-aware constants instead of timebase arithmetic.
    func testAudioNominalFrameRateFallbackDoesNotTrap() {
        // Non-TRUEHD codec: fallback frame size 1000 -> 48000 / 1000 == 48.
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 0,
            codecID: AV_CODEC_ID_AAC
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }

    /// TRUEHD with `frame_size == 0` uses the codec-specific fallback 48
    /// (the maintainer's suggested constant): `48000 / 48 == 1000`.
    func testAudioNominalFrameRateTrueHDFallbackUses48() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 0,
            codecID: AV_CODEC_ID_TRUEHD
        )
        XCTAssertEqual(rate, 1000, accuracy: 0.001)
    }

    /// `sample_rate == 0` (also common pre-decode): must return the `48`
    /// floor rather than `0 / fallback`.
    func testAudioNominalFrameRateZeroSampleRate() {
        XCTAssertEqual(
            FFmpegAssetTrack.audioNominalFrameRate(sampleRate: 0, frameSize: 0, codecID: AV_CODEC_ID_AAC),
            48,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FFmpegAssetTrack.audioNominalFrameRate(sampleRate: 0, frameSize: 1024, codecID: AV_CODEC_ID_AAC),
            48,
            accuracy: 0.001
        )
    }

    /// Well-formed stream, unchanged from the pre-fix behaviour:
    /// `48000 / 1024 == 46` (Int32) -> `max(46, 48) == 48`. Regression guard.
    func testAudioNominalFrameRateWellFormedClampsToFloor() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 1024,
            codecID: AV_CODEC_ID_AAC
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }

    /// Well-formed stream whose true rate is above the floor, using a
    /// non-evenly-dividing pair so the assertion pins INTEGER division
    /// (`48000 / 700 == 68` via Int32 truncation; a `Float / Float` refactor
    /// would yield ~68.57 and fail this assertion). Exercises the non-floor
    /// path and proves the arithmetic is byte-for-byte preserved.
    func testAudioNominalFrameRateAboveFloor() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 700,
            codecID: AV_CODEC_ID_MP3
        )
        XCTAssertEqual(rate, 68, accuracy: 0.001)
    }

    /// A zero `frame_size` on an arbitrary codec uses the generic fallback
    /// 1000: `44100 / 1000 == 44` -> floor `48`.
    func testAudioNominalFrameRateGenericFallbackClampsToFloor() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 44100,
            frameSize: 0,
            codecID: AV_CODEC_ID_OPUS
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }

    /// Negative `sample_rate` (corrupt/garbage input) maps to the `48` floor.
    /// Locks the `sampleRate > 0` guard against a future simplification.
    func testAudioNominalFrameRateNegativeSampleRate() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: -48000,
            frameSize: 960,
            codecID: AV_CODEC_ID_AAC
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }
}
