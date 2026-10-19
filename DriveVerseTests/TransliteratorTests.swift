import Testing
@testable import DriveVerse

@Suite struct TransliteratorTests {
    @Test func englishPassesThroughUntouched() {
        #expect(Transliterator.latinized("Hello, world! (feat. Someone)") == "Hello, world! (feat. Someone)")
        // Latin-script diacritics are the artist's choice — keep them.
        #expect(Transliterator.latinized("café Motörhead") == "café Motörhead")
    }

    @Test func devanagariBecomesLatin() {
        let out = Transliterator.latinized("तुम ही हो")
        #expect(!Transliterator.needsLatinization(out))
        #expect(out.lowercased().contains("tum"))
        #expect(out.lowercased().contains("ho"))
    }

    @Test func cyrillicBecomesLatin() {
        let out = Transliterator.latinized("Привет")
        #expect(!Transliterator.needsLatinization(out))
        #expect(out.lowercased().hasPrefix("privet"))
    }

    @Test func mixedLineKeepsLatinPartsAndConvertsTheRest() {
        let out = Transliterator.latinized("Baby मेरी jaan")
        #expect(out.contains("Baby"))
        #expect(out.contains("jaan"))
        #expect(!Transliterator.needsLatinization(out))
    }

    @Test func emptyAndSymbolLinesUnchanged() {
        #expect(Transliterator.latinized("") == "")
        #expect(Transliterator.latinized("♪") == "♪")
    }
}

@Suite struct SimplifiedChineseDisplayTests {
    @Test func traditionalLyricsBecomeSimplified() {
        #expect(Transliterator.simplifiedChinese("愛 請問怎麼走，讓音樂陪著你") == "爱 请问怎么走，让音乐陪着你")
    }
    @Test func mixedLyricsKeepEnglishAndLineBoundaries() {
        #expect(Transliterator.simplifiedChinese("愛你\nHello, world! 123") == "爱你\nHello, world! 123")
    }
}
