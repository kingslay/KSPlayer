//  FFmpegAssetTrackTest.swift
//  KSPlayerTests
//
//  Trap guard + regression tests for FFmpegAssetTrack.audioNominalFrameRate.
//

@testable import KSPlayer
import XCTest

final class FFmpegAssetTrackTest: XCTestCase {
    /// `AVCodecParameters.frame_size == 0` (left at 0 by most audio demuxers —
    /// AAC/MP3/Opus/FLAC/Vorbis — until the first frame is decoded) combined
    /// with a valid `AVRational{num:3,den:1}`: the `timebase.den / timebase.num`
    /// fallback integer-divides to `0`, so the old inline arithmetic on
    /// `FFmpegAssetTrack.swift:100` did `sample_rate / 0` and trapped with
    /// `Fatal error: Division by zero`. The helper must return the `48` floor.
    func testAudioNominalFrameRateFallbackDividesToZero() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 0,
            timebase: Timebase(num: 3, den: 1)
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }

    /// `sample_rate == 0` (also common pre-decode). Two sub-cases:
    /// - a usable fallback (`den >= num`): historically `0 / 1000 == 0` -> 48;
    /// - a zero fallback (`den < num`): historically `0 / 0` -> trap.
    /// Both must now return the `48` floor.
    func testAudioNominalFrameRateZeroSampleRate() {
        XCTAssertEqual(
            FFmpegAssetTrack.audioNominalFrameRate(sampleRate: 0, frameSize: 0, timebase: Timebase(num: 1, den: 1000)),
            48,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FFmpegAssetTrack.audioNominalFrameRate(sampleRate: 0, frameSize: 0, timebase: Timebase(num: 3, den: 1)),
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
            timebase: Timebase(num: 1, den: 1)
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
            timebase: Timebase(num: 1, den: 1)
        )
        XCTAssertEqual(rate, 68, accuracy: 0.001)
    }

    /// `frame_size == 0` but the `time_base` fallback is usable (`den >= num`):
    /// `den / num == 1000`, then `48000 / 1000 == 48` -> floor `48`.
    func testAudioNominalFrameRateUsesTimebaseFallback() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 0,
            timebase: Timebase(num: 1, den: 1000)
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }

    /// `timebase.num == 0`: the helper's `den / num` fallback must be skipped
    /// (it would divide by zero) and the `48` floor returned. The production
    /// caller pre-guards `num > 0`, but the helper is exercised directly here,
    /// so pin that it can never trap on its own.
    func testAudioNominalFrameRateZeroTimebaseNumDoesNotTrap() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: 48000,
            frameSize: 0,
            timebase: Timebase(num: 0, den: 1000)
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }

    /// Negative `sample_rate` (corrupt/garbage input) maps to the `48` floor.
    /// Locks the `sampleRate > 0` guard against a future simplification.
    func testAudioNominalFrameRateNegativeSampleRate() {
        let rate = FFmpegAssetTrack.audioNominalFrameRate(
            sampleRate: -48000,
            frameSize: 960,
            timebase: Timebase(num: 1, den: 1)
        )
        XCTAssertEqual(rate, 48, accuracy: 0.001)
    }
}
