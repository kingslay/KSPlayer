@testable import KSPlayer
import XCTest

final class DisplayMatrixRotationTest: XCTestCase {
    /// Identity 3×3 display matrix in FFmpeg's 16.16 fixed point (1 << 16 on the
    /// diagonal) — the well-formed 36-byte allocation FFmpeg normally emits.
    private static let identityMatrix: [Int32] = {
        var matrix = [Int32](repeating: 0, count: 9)
        matrix[0] = 1 << 16
        matrix[4] = 1 << 16
        matrix[8] = 1 << 16
        return matrix
    }()

    func testRejectsTruncatedDisplayMatrixSideData() {
        Self.identityMatrix.withUnsafeBufferPointer { buffer in
            guard let matrix = buffer.baseAddress else {
                XCTFail("could not obtain a matrix pointer")
                return
            }
            // A full 36-byte matrix is read and yields the identity rotation (0°),
            // unchanged from the previous unguarded behaviour for well-formed input.
            let rotation = FFmpegAssetTrack.displayRotation(sideDataSize: 36, matrix: matrix)
            XCTAssertNotNil(rotation, "a full 36-byte matrix should yield a rotation")
            if let rotation {
                XCTAssertEqual(rotation, 0.0, "an identity matrix encodes a 0° rotation")
            }
            // Truncated allocations must be rejected before av_display_rotation_get
            // dereferences the 3×3 matrix, so adjacent heap is never over-read.
            // The buffer backing these calls is valid 36 bytes — only the reported
            // side-data length is short, proving the guard (not the buffer) protects us.
            XCTAssertNil(FFmpegAssetTrack.displayRotation(sideDataSize: 35, matrix: matrix))
            XCTAssertNil(FFmpegAssetTrack.displayRotation(sideDataSize: 0, matrix: matrix))
        }
    }

    func testReadsRotationForFullDisplayMatrix() {
        // A 90° rotation matrix (what av_display_rotation_set(matrix, 90) produces):
        // the 2×2 block [0, 1; -1, 0] in 16.16 fixed point, with matrix[8] = 1 << 16.
        var matrix = [Int32](repeating: 0, count: 9)
        matrix[1] = 1 << 16
        matrix[3] = -(1 << 16)
        matrix[8] = 1 << 16
        matrix.withUnsafeBufferPointer { buffer in
            guard let matrix = buffer.baseAddress else {
                XCTFail("could not obtain a matrix pointer")
                return
            }
            // A full 36-byte matrix delegates to av_display_rotation_get and applies
            // the leading negation: get returns -90° for this matrix, so the helper
            // returns +90°. Proves the read path is wired through, not stubbed.
            guard let rotation = FFmpegAssetTrack.displayRotation(sideDataSize: 36, matrix: matrix) else {
                XCTFail("a full 36-byte matrix should yield a rotation")
                return
            }
            XCTAssertEqual(rotation, 90.0, "this matrix should decode to a +90° raw rotation")
        }
    }
}
