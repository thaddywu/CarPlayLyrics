import Foundation

/// At most two additional lookups, started within five seconds of detection.
/// An in-flight lookup may finish after the window; it is never cut off at 5s.
enum LyricsRetryPolicy {
    static let window: TimeInterval = 5
    static func delay(retries: Int, elapsed: TimeInterval) -> TimeInterval? {
        let delays: [TimeInterval] = [1, 2]
        guard delays.indices.contains(retries), elapsed >= 0,
              elapsed + delays[retries] < window else { return nil }
        return delays[retries]
    }
}

/// Cache-first lookup with a bounded retry window for misses and network errors.
final class LyricsService {
    private let client: LRCLIBClient
    private let cache: LyricsCache
    private let now: () -> TimeInterval
    private let sleep: (TimeInterval) async throws -> Void

    init(client: LRCLIBClient = LRCLIBClient(), cache: LyricsCache = LyricsCache(),
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         sleep: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.client = client
        self.cache = cache
        self.now = now
        self.sleep = sleep
    }

    func lyrics(for state: NowPlayingState, refresh: Bool = false) async throws -> LyricsFetchResult {
        let signature = "artist-alias-v3|" + LyricsMatcher.signature(
            title: state.title, artist: state.artist, durationMs: state.durationMs, album: state.album
        )
        let startedAt = now()
        var retries = 0
        var useCache = !refresh
        while true {
            try Task.checkCancellation()
            let outcome: Result<LyricsFetchResult, Error>
            do {
                let result: LyricsFetchResult
                if useCache, let hit = cache.lookup(signature: signature) {
                    result = hit
                } else {
                    result = try await client.fetchLyrics(
                        title: state.title, artist: state.artist,
                        album: state.album, durationMs: state.durationMs
                    )
                    try Task.checkCancellation()
                    cache.store(result, signature: signature)
                }
                // Timed, plain-text and instrumental results are complete.
                guard result == .notFound else { return result }
                outcome = .success(result)
            } catch {
                if Task.isCancelled || error is CancellationError { throw CancellationError() }
                outcome = .failure(error)
            }
            guard let delay = LyricsRetryPolicy.delay(retries: retries, elapsed: now() - startedAt) else {
                return try outcome.get()
            }
            try await sleep(delay)
            try Task.checkCancellation()
            // App suspension can make a short sleep resume far beyond its deadline.
            guard now() - startedAt < LyricsRetryPolicy.window else { return try outcome.get() }
            retries += 1
            useCache = false // Never retry a cached negative result.
        }
    }

    func clearCache() { cache.clear() }
}
