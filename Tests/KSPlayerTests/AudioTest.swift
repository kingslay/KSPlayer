import AVFoundation
import FFmpeg
@testable import KSPlayer
import XCTest
class AudioTest: XCTestCase {
    func testChannelLayout() {
        layoutMapTuple.forEach { tag, mask in
            assert(tag: tag, mask: mask)
        }
    }

    private func assert(tag: AudioChannelLayoutTag, mask: UInt64) {
        let channelLayout = AVAudioChannelLayout(layout: tag.channelLayout)
        XCTAssertEqual(channelLayout.channelLayout().u.mask == mask, true)
    }

    private func assert(bitmap: AudioChannelBitmap, mask: UInt64) {
        let channelLayout = AVAudioChannelLayout(layout: bitmap.channelLayout)
        XCTAssertEqual(channelLayout.channelLayout().u.mask == mask, true)
    }
}
