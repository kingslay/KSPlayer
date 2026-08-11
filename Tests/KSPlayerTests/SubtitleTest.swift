@testable import KSPlayer
import XCTest

class SubtitleTest: XCTestCase {
    func testSrt() {
        let string = """
        1
        00:00:00,050 --> 00:00:11,000
        <font color="#4096d1">本字幕仅供学习交流，严禁用于商业用途</font>

        2
        00:00:13,000 --> 00:00:18,000
        <font color=#4096d1>-=破烂熊字幕组=-
        翻译:风铃
        校对&时间轴:小白</font>

        3
        00:01:00,840 --> 00:01:02,435
        你现在必须走了吗?

        4
        00:01:02,680 --> 00:01:04,318
        我说过我会去找他的

        5
        00:01:07,194 --> 00:01:08,239
        - 很多事情我们都说过
        - 我承诺过他

        907
        00:59:47,520 --> 00:59:49,720
        有两个人在我们镇上
        There were two men in my hometown

        908
        00:59:51,370 --> 00:59:55,170
        被判4F不合格，他们就自杀了，因为不能服役
        Declared 4-F unfit, they killed themselves cause they couldn't serve.

        909
        00:59:55,750 --> 00:59:58,360
        注：4-F，二战服役有关的物理，心理，或道德标准。
        https://en.wikipedia.org/wiki/Selective_Service_System

         http://www.apd.army.mil/pdffiles/r40_501.pdf

        910
        00:59:59,220 --> 01:00:01,140
        为何？我在国防工厂有份工作
        Why, I had a job in a defense plant.

        """
        let scanner = Scanner(string: string)
        let parse = SrtParse()
        XCTAssertEqual(parse.canParse(scanner: scanner), true)
        let parts = parse.parse(scanner: scanner)
        XCTAssertEqual(parts.count, 9)
        XCTAssertEqual(parts[8].end, 3601.14)
    }

    /// An SRT cue whose trailing content is not a numeric sequence line used to put
    /// `SrtParse.parsePart` into an infinite loop: the sequence-number scan repeats
    /// `scanUpToCharacters(from: .newlines)` / `scanCharacters(from: .newlines)` and,
    /// once the scanner reaches a non-numeric line at end of input, neither call
    /// advances the position nor returns an `Int`, so the loop span forever. The fix
    /// adds `!scanner.isAtEnd` to the loop guard. This test would hang (never return)
    /// without it.
    func testSrtTrailingJunkDoesNotHang() {
        let string = """
        1
        00:00:01,000 --> 00:00:02,000
        Hello

        SOME JUNK WITHOUT A SEQUENCE NUMBER
        """
        let scanner = Scanner(string: string)
        let parse = SrtParse()
        XCTAssertTrue(parse.canParse(scanner: scanner))
        // Must terminate: the lone valid cue is parsed, the trailing junk is skipped.
        let parts = parse.parse(scanner: scanner)
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].start, 1.0)
        XCTAssertEqual(parts[0].end, 2.0)
    }

    func testVtt() {
        let string = """
        WEBVTT
        1
        00:00:00,050 --> 00:00:11,000
        <font color="#4096d1">本字幕仅供学习交流，严禁用于商业用途</font>

        2
        00:00:13,000 --> 00:00:18,000
        <font color=#4096d1>-=破烂熊字幕组=-
        翻译:风铃
        校对&时间轴:小白</font>

        3
        00:01:00,840 --> 00:01:02,435
        你现在必须走了吗?

        4
        00:01:02,680 --> 00:01:04,318
        我说过我会去找他的

        5
        00:01:07,194 --> 00:01:08,239
        - 很多事情我们都说过
        - 我承诺过他

        6
        00:01:08,280 --> 00:01:10,661
        我希望你明白

        7
        00:01:12,814 --> 00:01:14,702
        等等! 你是不可能活着回来的!

        """
        let scanner = Scanner(string: string)
        let parse = VTTParse()
        XCTAssertEqual(parse.canParse(scanner: scanner), true)
        let parts = parse.parse(scanner: scanner)
        XCTAssertEqual(parts.count, 7)
    }

    /// An ASS file whose `[Script Info]` section has no `Format:` line (a truncated
    /// header, or one whose `[V4+ Styles]` section was stripped) used to put
    /// `AssParse.canParse` into an infinite loop. The `while scanString("Format:") == nil`
    /// line-skip calls `scanUpToCharacters(from: .newlines)`, which returns `nil`
    /// without advancing once the scanner reaches EOF, so the loop span forever. The
    /// fix bails out with `return false` when the scanner is at end. Without the fix
    /// this test would hang (never return).
    func testAssWithoutFormatLineDoesNotHang() {
        let malformed = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 1920
        PlayResY: 1080
        Title: header only, styles section missing
        """
        XCTAssertFalse(AssParse().canParse(scanner: Scanner(string: malformed)))

        // Happy path is unaffected: a header that does contain a `Format:` line still parses.
        let valid = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour
        """
        XCTAssertTrue(AssParse().canParse(scanner: Scanner(string: valid)))
    }
}
