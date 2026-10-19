import Testing
@testable import DriveVerse

@Suite struct LyricsMatcherTests {
    @Test func featuredTitleRetainsVersionInformation() {
        #expect(LyricsMatcher.normalizeTitle("Song (feat. X) - Remix") == "song (feat. x) - remix")
    }

    @Test func remasteredSuffixPreserved() {
        #expect(LyricsMatcher.normalizeTitle("Bohemian Rhapsody (Remastered 2011)") == "bohemian rhapsody (remastered 2011)")
    }

    @Test func dashVersionsPreserved() {
        #expect(LyricsMatcher.normalizeTitle("Track - Radio Edit") == "track - radio edit")
        #expect(LyricsMatcher.normalizeTitle("Heroes - 2017 Remaster") == "heroes - 2017 remaster")
    }

    @Test func featuredTitlePreserved() {
        #expect(LyricsMatcher.normalizeTitle("Umbrella feat. Jay-Z") == "umbrella feat. jay-z")
        #expect(LyricsMatcher.normalizeTitle("Umbrella ft. Jay-Z") == "umbrella ft. jay-z")
        #expect(LyricsMatcher.normalizeTitle("Umbrella featuring Jay-Z") == "umbrella featuring jay-z")
    }

    @Test func liveVenuePreserved() {
        #expect(LyricsMatcher.normalizeTitle("Song [Live at Wembley]") == "song [live at wembley]")
    }

    @Test func plainTitleUntouched() {
        #expect(LyricsMatcher.normalizeTitle("Yesterday") == "yesterday")
    }

    @Test func wordContainingFtNotMangled() {
        // "soft" contains "ft" — markers require surrounding spaces.
        #expect(LyricsMatcher.normalizeTitle("Soft Spot") == "soft spot")
    }

    @Test func artistFeatStripped() {
        #expect(LyricsMatcher.normalizeArtist("Rihanna feat. JAY-Z") == "rihanna")
        #expect(LyricsMatcher.normalizeArtist("Calvin Harris (with Dua Lipa)") == "calvin harris")
    }

    @Test func signatureSeparatesDifferentEditions() {
        let a = LyricsMatcher.signature(title: "Song (Remastered)", artist: "Artist", durationMs: 200_000)
        let b = LyricsMatcher.signature(title: "Song", artist: "Artist", durationMs: 201_000)
        #expect(a != b)
    }

    @Test func signatureDiffersByDuration() {
        let a = LyricsMatcher.signature(title: "Song", artist: "Artist", durationMs: 200_000)
        let b = LyricsMatcher.signature(title: "Song", artist: "Artist", durationMs: 260_000)
        #expect(a != b)
    }

    @Test func signatureWithoutDuration() {
        let s = LyricsMatcher.signature(title: "Song", artist: "Artist", durationMs: nil)
        #expect(s == "song|artist|-1|")
    }
    @Test func verifiedArtistNamesExpandWithoutGuessingOtherArtists() {
        #expect(LyricsMatcher.artistSearchNames("李荣浩").contains("ronghao li"))
        #expect(LyricsMatcher.artistSearchNames("Weeknd").contains("the weeknd"))
        #expect(LyricsMatcher.artistSearchNames("Unrelated Artist") == ["unrelated artist"])
    }

    @Test func ronghaoAliasAcceptsTraditionalTitle() {
        let record = LRCLIBResponse(id: 1, trackName: "烏梅子醬", artistName: "Li, Ronghao", albumName: "縱橫四海", duration: 257, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.00]原创测试")
        #expect(LyricsMatcher.bestMatch(from: [record], title: "乌梅子酱", durationMs: 257_000, artist: "李荣浩")?.id == 1)
    }

    @Test func weekndAliasCannotSelectShorterRemixRecording() {
        let remix = LRCLIBResponse(id: 1, trackName: "Save Your Tears", artistName: "The Weeknd", albumName: "Remix", duration: 191, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.00]Wrong version")
        let studio = LRCLIBResponse(id: 2, trackName: "Save Your Tears", artistName: "The Weeknd", albumName: "After Hours", duration: 216, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.00]Original test")
        #expect(LyricsMatcher.bestMatch(from: [remix, studio], title: "Save Your Tears", durationMs: 215_667, artist: "Weeknd")?.id == 2)
    }

    @Test func commonAliasesMatchInBothDirections() {
        let pairs = [
            ["周杰倫", "Jay Chou"], ["林俊傑", "JJ Lin"], ["陳奕迅", "Eason Chan"],
            ["鄧紫棋", "G.E.M."], ["張信哲", "Jeff Chang"], ["黃麗玲", "A-Lin"],
            ["薛之謙", "Joker Xue"], ["蕭敬騰", "Jam Hsiao"], ["楊宗緯", "Aska Yang"],
            ["孫燕姿", "Stefanie Sun"], ["蔡依林", "Jolin Tsai"], ["張惠妹", "aMEI"],
            ["莫文蔚", "Karen Mok"], ["王力宏", "Leehom Wang"], ["王菲", "Faye Wong"],
            ["劉德華", "Andy Lau"], ["張學友", "Jacky Cheung"], ["張國榮", "Leslie Cheung"],
            ["梁靜茹", "Fish Leong"], ["梁詠琪", "Gigi Leung"], ["容祖兒", "Joey Yung"],
            ["楊千嬅", "Miriam Yeung"], ["許茹芸", "Valen Hsu"], ["林宥嘉", "Yoga Lin"],
            ["劉若英", "Rene Liu"], ["王心凌", "Cyndi Wang"], ["田馥甄", "Hebe Tien"],
            ["楊丞琳", "Rainie Yang"], ["周興哲", "Eric Chou"],
            ["Bruno Mars", "Peter Gene Hernandez"], ["Lady Gaga", "Stefani Germanotta"],
            ["Post Malone", "Austin Richard Post"], ["Lana Del Rey", "Elizabeth Grant"],
        ]
        for pair in pairs {
            for names in [pair, pair.reversed().map { $0 }] {
                let record = LRCLIBResponse(id: 1, trackName: "Original Test", artistName: names[0], albumName: nil, duration: 200, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.00]Test")
                #expect(LyricsMatcher.bestMatch(from: [record], title: "Original Test", durationMs: 200_000, artist: names[1])?.id == 1)
            }
        }
    }

    @Test func compositeChineseArtistNamesHaveKnownIdentity() {
        for name in ["G.E.M. 鄧紫棋", "GEM邓紫棋", "A-Lin 黃麗玲"] {
            let expected = name.hasPrefix("A-Lin") ? "A-Lin" : "G.E.M."
            let record = LRCLIBResponse(id: 1, trackName: "Test", artistName: expected, albumName: nil, duration: 200, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.00]Test")
            #expect(LyricsMatcher.bestMatch(from: [record], title: "Test", durationMs: 200_000, artist: name)?.id == 1)
        }
    }

    @Test func shortNicknamesAndUnrelatedArtistsAreNotMerged() {
        for pair in [["Jay", "周杰伦"], ["JJ", "林俊杰"], ["GEM", "邓紫棋"], ["陈奕迅", "陈小春"], ["王心凌", "王菲"], ["Ashin", "Mayday"]] {
            let record = LRCLIBResponse(id: 1, trackName: "Same Title", artistName: pair[0], albumName: nil, duration: 200, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.00]Test")
            #expect(LyricsMatcher.bestMatch(from: [record], title: "Same Title", durationMs: 200_000, artist: pair[1]) == nil)
        }
    }

}
