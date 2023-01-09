import AVFoundation
import FFmpeg
@testable import KSPlayer
import XCTest
class AudioTest: XCTestCase {
    func testChannelLayout() {
        assert(tag: kAudioChannelLayoutTag_Mono, mask: swift_AV_CH_LAYOUT_MONO)
        assert(tag: kAudioChannelLayoutTag_Stereo, mask: swift_AV_CH_LAYOUT_STEREO)
        assert(tag: kAudioChannelLayoutTag_MPEG_3_0_A, mask: swift_AV_CH_LAYOUT_SURROUND)
        assert(tag: kAudioChannelLayoutTag_Logic_4_0_A, mask: swift_AV_CH_LAYOUT_4POINT0)
        assert(tag: kAudioChannelLayoutTag_Logic_Quadraphonic, mask: swift_AV_CH_LAYOUT_2_2)
        assert(tag: kAudioChannelLayoutTag_Logic_5_0_A, mask: swift_AV_CH_LAYOUT_5POINT0)
        assert(tag: kAudioChannelLayoutTag_Logic_5_1_A, mask: swift_AV_CH_LAYOUT_5POINT1)
        assert(tag: kAudioChannelLayoutTag_Logic_6_0_A, mask: swift_AV_CH_LAYOUT_6POINT0)
        assert(tag: kAudioChannelLayoutTag_Logic_6_1_C, mask: swift_AV_CH_LAYOUT_6POINT1)
        assert(tag: kAudioChannelLayoutTag_AAC_7_0, mask: swift_AV_CH_LAYOUT_7POINT0)
        assert(tag: kAudioChannelLayoutTag_Logic_7_1_A, mask: swift_AV_CH_LAYOUT_7POINT1)
        assert(tag: kAudioChannelLayoutTag_Logic_7_1_SDDS_A, mask: swift_AV_CH_LAYOUT_7POINT1_WIDE)
//        assert(tag: kAudioChannelLayoutTag_Logic_Atmos_5_1_2, mask: swift_AV_CH_LAYOUT_7POINT1_WIDE_BACK)
        assert(tag: kAudioChannelLayoutTag_AAC_Octagonal, mask: swift_AV_CH_LAYOUT_OCTAGONAL)
    }

    private func assert(tag: AudioChannelLayoutTag, mask: UInt64) {
        let channelLayout = AVAudioChannelLayout(layout: tag.channelLayout)
        XCTAssertEqual(channelLayout.channelLayout(channelCount: channelLayout.channelCount).u.mask == mask, true)
    }

    private func assert(bitmap: AudioChannelBitmap, mask: UInt64) {
        let channelLayout = AVAudioChannelLayout(layout: bitmap.channelLayout)
        XCTAssertEqual(channelLayout.channelLayout(channelCount: channelLayout.channelCount).u.mask == mask, true)
    }
}
