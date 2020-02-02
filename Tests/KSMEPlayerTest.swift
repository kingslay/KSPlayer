@testable import KSPlayer
import XCTest
class KSMEPlayerTest: XCTestCase {
    func testPlaying() {
        if let path = Bundle(for: type(of: self)).path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "mp4") {
            let options = KSOptions()
            let player = KSMEPlayer(url: URL(fileURLWithPath: path), options: options)
            options.isAutoPlay = false
            player.delegate = self
            XCTAssertEqual(player.isPlaying, false)
            player.play()
            XCTAssertEqual(player.isPlaying, true)
            player.pause()
            XCTAssertEqual(player.isPlaying, false)
        }
    }

    func testAutoPlay() {
        if let path = Bundle(for: type(of: self)).path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "mp4") {
            let options = KSOptions()
            let player = KSMEPlayer(url: URL(fileURLWithPath: path), options: options)
            options.isAutoPlay = true
            player.delegate = self
            XCTAssertEqual(player.isPlaying, false)
            player.play()
            XCTAssertEqual(player.isPlaying, true)
            player.pause()
            XCTAssertEqual(player.isPlaying, false)
        }
    }
}

extension KSMEPlayerTest: MediaPlayerDelegate {
    func preparedToPlay(player _: MediaPlayerProtocol) {}

    func changeLoadState(player _: MediaPlayerProtocol) {}

    func changeBuffering(player _: MediaPlayerProtocol, progress _: Int) {}

    func playBack(player _: MediaPlayerProtocol, loopCount _: Int) {}

    func finish(player _: MediaPlayerProtocol, error _: Error?) {}
}
