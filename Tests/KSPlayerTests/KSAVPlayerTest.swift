@testable import KSPlayer
import XCTest
class KSAVPlayerTest: XCTestCase {
    private var readyToPlayExpectation: XCTestExpectation?
    func testPlayer() {
        if let path = Bundle(for: type(of: self)).path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "MP4") {
            set(path: path)
        }
        //        if let path = Bundle(for: type(of: self)).path(forResource: "google-help-vr", ofType: "mp4") {
        //            set(path: path)
        //        }
        if let path = Bundle(for: type(of: self)).path(forResource: "Polonaise", ofType: "flac") {
            set(path: path)
        }
        if let path = Bundle(for: type(of: self)).path(forResource: "video-h265", ofType: "mkv") {
            set(path: path)
        }
    }

    func set(path: String) {
        let play = KSAVPlayer(url: URL(fileURLWithPath: path), options: KSOptions())
        play.delegate = self
        play.prepareToPlay()
        readyToPlayExpectation = expectation(description: "openVideo")
        waitForExpectations(timeout: 10) { _ in
            if play.isPreparedToPlay {
                play.play()
            }
            play.shutdown()
        }
    }
}

extension KSAVPlayerTest: MediaPlayerDelegate {
    func preparedToPlay(player _: MediaPlayerProtocol) {
        readyToPlayExpectation?.fulfill()
    }

    func changeLoadState(player _: MediaPlayerProtocol) {}

    func changeBuffering(player _: MediaPlayerProtocol, progress _: Int) {}

    func playBack(player _: MediaPlayerProtocol, loopCount _: Int) {}

    func finish(player _: MediaPlayerProtocol, error: Error?) {
        if error != nil {
            readyToPlayExpectation?.fulfill()
        }
    }
}
