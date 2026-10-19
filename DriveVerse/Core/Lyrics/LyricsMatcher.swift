import Foundation

/// Title/artist normalization for querying LRCLIB and for cache keys.
enum LyricsMatcher {
    /// Preserve version labels so live/remix editions cannot silently collide.
    static func normalizeTitle(_ raw: String) -> String {
        collapseWhitespace(raw.lowercased())
    }

    /// "Rihanna feat. JAY-Z" → "rihanna"
    static func normalizeArtist(_ raw: String) -> String {
        var s = raw.lowercased()
        s = stripBracketed(s)
        s = stripFeatClause(s)
        return collapseWhitespace(s)
    }

    /// Exact duration and album keep different editions in separate caches.
    static func signature(title: String, artist: String, durationMs: Int?, album: String? = nil) -> String {
        let bucket = durationMs ?? -1
        return "\(normalizeTitle(title))|\(normalizeArtist(artist))|\(bucket)|\(album ?? "")"
    }

    /// Picks the `/api/search` result whose normalized title matches and whose
    /// duration is within ±3 s (when we know ours); prefers synced lyrics.
    static func bestMatch(from candidates: [LRCLIBResponse], title: String, durationMs: Int?, artist: String? = nil) -> LRCLIBResponse? {
        let wantedTitle = comparisonKey(normalizeTitle(title))
        let matches = candidates.filter { candidate in
            guard comparisonKey(normalizeTitle(candidate.trackName ?? "")) == wantedTitle else { return false }
            if let artist {
                guard let candidateArtist = candidate.artistName,
                      canonicalArtist(candidateArtist) == canonicalArtist(artist) else { return false }
            }
            guard let durationMs else { return true }
            guard let duration = candidate.duration else { return false }
            return abs(duration * 1000 - Double(durationMs)) <= 3000
        }
        return matches.first { $0.syncedLyrics?.isEmpty == false } ?? matches.first
    }

    /// Exact, curated identities. No nickname or fuzzy-name inference.
    private static let artistGroups: [[String]] = [
        ["陶喆", "david tao", "tao, david"],
        ["李荣浩", "ronghao li", "li, ronghao"],
        ["the weeknd", "weeknd", "abel tesfaye", "abel makkonen tesfaye"],
        ["周杰伦", "jay chou"],
        ["林俊杰", "jj lin", "j.j. lin"],
        ["陈奕迅", "eason chan"],
        ["邓紫棋", "g.e.m.", "g.e.m.邓紫棋", "gem邓紫棋"],
        ["张信哲", "jeff chang"],
        ["黄丽玲", "a-lin", "a-lin 黄丽玲"],
        ["薛之谦", "joker xue"],
        ["萧敬腾", "jam hsiao"],
        ["杨宗纬", "aska yang"],
        ["孙燕姿", "stefanie sun"],
        ["蔡依林", "jolin tsai"],
        ["张惠妹", "a-mei", "amei"],
        ["莫文蔚", "karen mok"],
        ["王力宏", "leehom wang", "wang leehom"],
        ["王菲", "faye wong"],
        ["刘德华", "andy lau"],
        ["张学友", "jacky cheung"],
        ["张国荣", "leslie cheung"],
        ["梁静茹", "fish leong"],
        ["梁咏琪", "gigi leung"],
        ["容祖儿", "joey yung"],
        ["杨千嬅", "miriam yeung"],
        ["许茹芸", "valen hsu"],
        ["林宥嘉", "yoga lin"],
        ["刘若英", "rene liu"],
        ["王心凌", "cyndi wang"],
        ["田馥甄", "hebe tien"],
        ["杨丞琳", "rainie yang"],
        ["周兴哲", "eric chou"],
        ["bruno mars", "peter gene hernandez"],
        ["lady gaga", "stefani germanotta", "stefani joanne angelina germanotta"],
        ["post malone", "austin post", "austin richard post"],
        ["lana del rey", "elizabeth grant", "elizabeth woolridge grant"],
    ]

    // Build once, rather than repeatedly running ICU over every artist in each
    // search result. Simplified/traditional and casing share the same key.
    private static let artistGroupsByName: [String: [String]] = {
        var index: [String: [String]] = [:]
        for group in artistGroups {
            let normalized = group.map(normalizeArtist)
            for alias in normalized { index[comparisonKey(alias)] = normalized }
        }
        return index
    }()

    static func artistSearchNames(_ artist: String) -> [String] {
        let original = normalizeArtist(artist)
        let group = artistGroupsByName[comparisonKey(original)] ?? []
        var seen = Set<String>()
        return ([original] + group).filter { seen.insert($0).inserted }
    }

    private static func canonicalArtist(_ artist: String) -> String {
        let key = comparisonKey(normalizeArtist(artist))
        guard let canonical = artistGroupsByName[key]?.first else { return key }
        return comparisonKey(canonical)
    }

    private static func comparisonKey(_ text: String) -> String {
        let simplified = text.applyingTransform(StringTransform(rawValue: "Traditional-Simplified"), reverse: false) ?? text
        let folded = simplified.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        // Chinese catalogues vary in spaces and commas inside otherwise identical titles.
        // Keep version words, so a live/remix edition still differs from the original.
        if folded.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return folded.replacingOccurrences(of: "[\\s\\p{P}]+", with: "", options: .regularExpression)
        }
        return folded
    }

    // MARK: - Helpers

    /// Removes every `(…)` and `[…]` segment.
    private static func stripBracketed(_ s: String) -> String {
        var out = ""
        var depth = 0
        for ch in s {
            if ch == "(" || ch == "[" {
                depth += 1
            } else if ch == ")" || ch == "]" {
                if depth > 0 { depth -= 1 }
            } else if depth == 0 {
                out.append(ch)
            }
        }
        return out
    }

    private static let featMarkers = [" feat. ", " feat ", " featuring ", " ft. ", " ft "]

    private static func stripFeatClause(_ s: String) -> String {
        var s = s
        for marker in featMarkers {
            if let r = s.range(of: marker) {
                s = String(s[..<r.lowerBound])
            }
        }
        return s
    }

    private static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
