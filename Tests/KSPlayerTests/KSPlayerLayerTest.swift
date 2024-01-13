@testable import KSPlayer
import XCTest

class KSPlayerLayerTest: XCTestCase {
    private var readyToPlayExpectation: XCTestExpectation?
    override func setUp() {
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isSecondOpen = true
        KSOptions.isAccurateSeek = true
    }

    func testPlayerLayer() {
        if let path = Bundle(for: type(of: self)).path(forResource: "h264", ofType: "MP4") {
            set(path: path)
        }
//        if let path = Bundle(for: type(of: self)).path(forResource: "google-help-vr", ofType: "mp4") {
//            set(path: path)
//        }
        if let path = Bundle(for: type(of: self)).path(forResource: "mjpeg", ofType: "flac") {
            set(path: path)
        }
        if let path = Bundle(for: type(of: self)).path(forResource: "hevc", ofType: "mkv") {
            set(path: path)
        }
    }

    func set(path: String) {
        let options = KSOptions()
        let playerLayer = KSPlayerLayer(url: URL(fileURLWithPath: path), options: options)
        playerLayer.delegate = self
        XCTAssertEqual(playerLayer.state, .prepareToPlay)
        readyToPlayExpectation = expectation(description: "openVideo")
        waitForExpectations(timeout: 2) { _ in
            XCTAssert(playerLayer.player.isReadyToPlay == true)
            XCTAssertEqual(playerLayer.state, .readyToPlay)
            playerLayer.play()
            XCTAssert(options.isAutoPlay)
            playerLayer.pause()
            XCTAssert(!options.isAutoPlay)
            XCTAssertEqual(playerLayer.state, .paused)
            let seekExpectation = self.expectation(description: "seek")
            playerLayer.seek(time: 2, autoPlay: true) { _ in
                XCTAssert(options.isAutoPlay)
                seekExpectation.fulfill()
            }
            XCTAssertEqual(playerLayer.state, .buffering)
            self.waitForExpectations(timeout: 1000) { _ in
                playerLayer.finish(player: playerLayer.player, error: nil)
                XCTAssertEqual(playerLayer.state, .playedToTheEnd)
                playerLayer.resetPlayer()
                XCTAssertEqual(playerLayer.state, .prepareToPlay)
            }
        }
    }
}

extension KSPlayerLayerTest: KSPlayerLayerDelegate {
    func player(layer _: KSPlayerLayer, state: KSPlayerState) {
        if state == .readyToPlay {
            readyToPlayExpectation?.fulfill()
        }
    }

    func player(layer _: KSPlayerLayer, currentTime _: TimeInterval, totalTime _: TimeInterval) {}

    func player(layer _: KSPlayerLayer, finish _: Error?) {}
    func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime _: TimeInterval) {
        if bufferedCount > 0 {
            XCTFail()
        }
    }
}
