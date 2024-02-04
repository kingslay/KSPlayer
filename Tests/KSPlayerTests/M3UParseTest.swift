@testable import KSPlayer
import XCTest

class M3UParseTest: XCTestCase {
    func testParsePlaylist() {
        let data = """
        #EXTM3U url-tvg="http://epg.tvfor.pro/epgtv.xml"
        #EXTINF:-1 tvg-id="2365" tvg-name="Первый канал" tvg-logo="http://tvfor.pro/img/images/Chanels/perviy_k.png" group-title="Базовые" catchup="default" catchup-source="http://vandijk.tvfor.pro/ORT/TOKEN?utc=${start}" catchup-days="5" timeshift="5",Первый канал
        #EXTGRP:Базовые
        http://vandijk.tvfor.pro/Perviykanal/TOKEN
        #EXTINF:-1 tvg-id="2379" tvg-name="Первый канал HD" tvg-logo="http://tvfor.pro/img/images/Chanels/1tv_hd.png" group-title="Базовые" catchup="default" catchup-source="http://vandijk.tvfor.pro/CupLeTaWkn/TOKEN?utc=${start}" catchup-days="3" timeshift="3",Первый канал HD
        #EXTGRP:Базовые
        http://vandijk.tvfor.pro/CupLeTaWkn/TOKEN
        """.data(using: .utf8)
        if let data {
            let result = data.parsePlaylist()
            XCTAssertEqual(result.count == 2, true)
        }
    }

    func testURLParse() async {
//        let url = Bundle(for: M3UParseTest.self).url(forResource: "test.m3u", withExtension: nil)!
//        if let result = try? await url.parsePlaylist() {
//            XCTAssertEqual(result.count > 0, true)
//        }
    }
}
