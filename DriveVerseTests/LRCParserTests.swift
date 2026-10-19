import Testing
@testable import DriveVerse

@Suite struct LRCParserTests {
    @Test func basicLine() {
        let lines = LRCParser.parse("[00:12.34]Hello world")
        #expect(lines == [LRCLine(timeMs: 12_340, text: "Hello world")])
    }

    @Test func multipleTagsPerLine() {
        let lines = LRCParser.parse("""
        [00:10.00][00:45.00]Chorus line
        [00:20.00]Verse line
        """)
        #expect(lines == [
            LRCLine(timeMs: 10_000, text: "Chorus line"),
            LRCLine(timeMs: 20_000, text: "Verse line"),
            LRCLine(timeMs: 45_000, text: "Chorus line"),
        ])
    }

    @Test func positiveOffsetShiftsEarlier() {
        let lines = LRCParser.parse("""
        [offset:+1000]
        [00:10.00]Line
        """)
        #expect(lines == [LRCLine(timeMs: 9_000, text: "Line")])
    }

    @Test func negativeOffsetShiftsLater() {
        let lines = LRCParser.parse("""
        [offset:-500]
        [00:10.00]Line
        """)
        #expect(lines == [LRCLine(timeMs: 10_500, text: "Line")])
    }

    @Test func offsetClampsAtZero() {
        let lines = LRCParser.parse("""
        [offset:+5000]
        [00:03.00]Early line
        """)
        #expect(lines == [LRCLine(timeMs: 0, text: "Early line")])
    }

    @Test func outOfOrderTimestampsAreSorted() {
        let lines = LRCParser.parse("""
        [00:30.00]Third
        [00:10.00]First
        [00:20.00]Second
        """)
        #expect(lines.map(\.text) == ["First", "Second", "Third"])
        #expect(lines.map(\.timeMs) == [10_000, 20_000, 30_000])
    }

    @Test func metadataTagsIgnored() {
        let lines = LRCParser.parse("""
        [ar:Example Artist]
        [ti:Example Track]
        [al:Example Album]
        [length:05:55]
        [by:someone]
        [00:01.00]Metadata fixture line
        """)
        #expect(lines == [LRCLine(timeMs: 1_000, text: "Metadata fixture line")])
    }

    @Test func emptyTimedLinesMarkInstrumentalBreaks() {
        let lines = LRCParser.parse("""
        [00:05.00]
        [00:06.00]
        [00:07.00]Real text
        """)
        #expect(lines == [LRCLine(timeMs: 5_000, text: ""), LRCLine(timeMs: 6_000, text: ""), LRCLine(timeMs: 7_000, text: "Real text")])
    }

    @Test func fractionalDigitVariants() {
        #expect(LRCParser.parse("[01:02.5]X") == [LRCLine(timeMs: 62_500, text: "X")])
        #expect(LRCParser.parse("[01:02.50]X") == [LRCLine(timeMs: 62_500, text: "X")])
        #expect(LRCParser.parse("[01:02.500]X") == [LRCLine(timeMs: 62_500, text: "X")])
        #expect(LRCParser.parse("[01:02]X") == [LRCLine(timeMs: 62_000, text: "X")])
    }

    @Test func colonFractionSeparator() {
        #expect(LRCParser.parse("[00:10:50]X") == [LRCLine(timeMs: 10_500, text: "X")])
    }

    @Test func nonTaggedLinesIgnored() {
        let lines = LRCParser.parse("""
        Just some stray text
        [00:10.00]Actual lyric
        """)
        #expect(lines == [LRCLine(timeMs: 10_000, text: "Actual lyric")])
    }

    @Test func emptyInput() {
        #expect(LRCParser.parse("") == [])
        #expect(LRCParser.parse("[ar:Nobody]") == [])
    }
}
