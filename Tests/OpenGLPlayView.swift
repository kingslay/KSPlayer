@testable import KSPlayer
import XCTest
class OpenGLPlayView: XCTestCase {
    func testResize() {
        // 模拟竖屏
        var size = UIScreen.main.bounds.size
        XCTAssertEqual(size.resize(naturalSize: size, contentsGravity: .resizeAspect), size)
        var naturalSize = CGSize(width: 4, height: 3)
        XCTAssertEqual(size.resize(naturalSize: naturalSize, contentsGravity: .resizeAspect), CGSize(width: size.width, height: ceil(size.width * naturalSize.height / naturalSize.width)))

        // 模拟横屏
        size = size.reverse
        XCTAssertEqual(size.resize(naturalSize: naturalSize, contentsGravity: .resizeAspect), CGSize(width: ceil(size.height * naturalSize.width / naturalSize.height), height: size.height))
        naturalSize = UIScreen.main.bounds.size
        XCTAssertEqual(size.resize(naturalSize: naturalSize, contentsGravity: .resizeAspect), CGSize(width: ceil(size.height * naturalSize.width / naturalSize.height), height: size.height))
    }
}
