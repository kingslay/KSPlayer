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
            // Tightened: assert a concrete extinf value, not only the entry count.
            // A dropped/empty attribute dict would still satisfy count == 2.
            XCTAssertEqual(result.first?.2["tvg-id"], "2365", "first entry extinf: \(result.first?.2 ?? [:])")
        }
    }

    /// Golden: a fully-quoted EXTINF must keep parsing byte-for-byte. Must never regress.
    /// Includes a quoted value that itself contains `=` and `,` (a real `catchup-source`
    /// URL) to prove the quoted branch is never truncated at an inner `=`/`,`.
    func testParseAllQuotedExtInf() {
        let data = """
        #EXTM3U
        #EXTINF:-1 tvg-id="cctv1" tvg-name="CCTV-1" catchup-source="http://x/?a=1,b=2",CCTV 1
        http://stream/1
        """.data(using: .utf8)!
        let result = data.parsePlaylist()
        XCTAssertEqual(result.count, 1)
        let extinf = result.first?.2 ?? [:]
        XCTAssertEqual(extinf["tvg-id"], "cctv1", "extinf: \(extinf)")
        XCTAssertEqual(extinf["tvg-name"], "CCTV-1", "extinf: \(extinf)")
        XCTAssertEqual(extinf["catchup-source"], "http://x/?a=1,b=2", "extinf: \(extinf)")
        XCTAssertEqual(result.first?.0, "CCTV 1")
        XCTAssertEqual(result.first?.1.absoluteString, "http://stream/1")
    }

    /// Red→green core case: an UNQUOTED attribute value. Proves the scanner no longer runs
    /// past the end of the line / into the next entry to find a closing quote.
    func testUnquotedExtInfSingleValue() {
        let data = """
        #EXTM3U
        #EXTINF:-1 tvg-id=cctv1 tvg-name="CCTV-1",CCTV 1
        http://stream/1
        """.data(using: .utf8)!
        let result = data.parsePlaylist()
        XCTAssertEqual(result.count, 1)
        let extinf = result.first?.2 ?? [:]
        XCTAssertEqual(extinf["tvg-id"], "cctv1", "extinf: \(extinf)")
        XCTAssertEqual(extinf["tvg-name"], "CCTV-1", "extinf: \(extinf)")
        XCTAssertEqual(result.first?.0, "CCTV 1")
        XCTAssertEqual(result.first?.1.absoluteString, "http://stream/1")
    }

    /// Entry 1 carries an unquoted attribute; entry 2 is fully quoted. Both must parse with
    /// no cross-entry bleed — the scanner must not escape entry 1 into entry 2's quotes.
    func testUnquotedExtInfBleedsAcrossEntries() {
        let data = """
        #EXTM3U
        #EXTINF:-1 tvg-id=chan1 tvg-name="Channel One",Channel One
        http://stream/1
        #EXTINF:-1 tvg-id="chan2" tvg-name="Channel Two",Channel Two
        http://stream/2
        """.data(using: .utf8)!
        let result = data.parsePlaylist()
        XCTAssertEqual(result.count, 2, "got \(result.count) entries: \(result.map { $0.1.absoluteString })")
        XCTAssertEqual(result[0].2["tvg-id"], "chan1", "entry0 extinf: \(result[0].2)")
        XCTAssertEqual(result[0].2["tvg-name"], "Channel One", "entry0 extinf: \(result[0].2)")
        XCTAssertEqual(result[0].0, "Channel One")
        XCTAssertEqual(result[0].1.absoluteString, "http://stream/1")
        XCTAssertEqual(result[1].2["tvg-id"], "chan2", "entry1 extinf: \(result[1].2)")
        XCTAssertEqual(result[1].2["tvg-name"], "Channel Two", "entry1 extinf: \(result[1].2)")
        XCTAssertEqual(result[1].0, "Channel Two")
        XCTAssertEqual(result[1].1.absoluteString, "http://stream/2")
    }

    func testURLParse() async {
//        let url = Bundle(for: M3UParseTest.self).url(forResource: "test.m3u", withExtension: nil)!
//        if let result = try? await url.parsePlaylist() {
//            XCTAssertEqual(result.count > 0, true)
//        }
    }
}
