import Testing
import Foundation
@testable import DriveVerse

/// Serialization umbrella: every suite that touches StubURLProtocol's static
/// state must be nested in here (via extension), because `.serialized` only
/// orders tests within one suite tree — sibling suites run in parallel.
@Suite(.serialized) enum HTTPStubbedTests {}

/// Records every request and answers from a per-run handler.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (status: Int, body: Data))?
    nonisolated(unsafe) static var headers: [String: String]?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset(headers: [String: String]? = nil, handler: @escaping (URLRequest) -> (status: Int, body: Data)) {
        self.handler = handler
        self.headers = headers
        self.requests = []
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let (status, body) = Self.handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: Self.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func json(_ s: String) -> Data { Data(s.utf8) }

private let syncedHit = json("""
{"id": 1, "trackName": "song", "artistName": "artist", "albumName": "album",
 "duration": 200.0, "instrumental": false,
 "plainLyrics": "Hello world", "syncedLyrics": "[00:01.00]Hello world"}
""")

private func queryValue(_ request: URLRequest, _ name: String) -> String? {
    URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
        .queryItems?.first { $0.name == name }?.value
}

extension HTTPStubbedTests {
@Suite struct LRCLIBClientTests {
    private var client: LRCLIBClient { LRCLIBClient(session: StubURLProtocol.makeSession()) }

    @Test func directHitReturnsSynced() async throws {
        StubURLProtocol.reset { _ in (200, syncedHit) }

        let result = try await client.fetchLyrics(
            title: "Song (Remastered 2011)", artist: "Artist feat. Other",
            album: "Album (Deluxe)", durationMs: 200_000
        )
        #expect(result == .synced("[00:01.00]Hello world"))
        #expect(StubURLProtocol.requests.count == 1)

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.url?.path == "/api/get")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Along/1.0 (https://github.com/thaddywu/CarPlayLyrics; based on DriveVerse)")
        // Queries are sent normalized, with duration in seconds.
        #expect(queryValue(request, "track_name") == "song (remastered 2011)")
        #expect(queryValue(request, "artist_name") == "artist")
        #expect(queryValue(request, "album_name") == "album (deluxe)")
        #expect(queryValue(request, "duration") == "200")
    }

    @Test func fallbackChainGetGetSearch() async throws {
        StubURLProtocol.reset { request in
            let path = request.url!.path
            if path == "/api/get" { return (404, Data()) }
            // /api/search: one wrong-duration candidate, one match without
            // synced lyrics, one match with — the last should win.
            return (200, json("""
            [
              {"id": 1, "trackName": "song", "artistName": "artist", "duration": 300.0, "syncedLyrics": "[00:01.00]Wrong"},
              {"id": 2, "trackName": "song", "artistName": "artist", "duration": 201.0, "plainLyrics": "Plain only"},
              {"id": 3, "trackName": "song", "artistName": "artist", "duration": 199.0, "syncedLyrics": "[00:01.00]Right"}
            ]
            """))
        }

        let result = try await client.fetchLyrics(
            title: "Song", artist: "Artist", album: "Album", durationMs: 200_000
        )
        #expect(result == .synced("[00:01.00]Right"))

        let paths = StubURLProtocol.requests.map { $0.url!.path }
        #expect(paths == ["/api/get", "/api/get", "/api/search"])
        // First get carries the album, the retry drops it.
        #expect(queryValue(StubURLProtocol.requests[0], "album_name") == "album")
        #expect(queryValue(StubURLProtocol.requests[1], "album_name") == nil)
    }

    @Test func instrumentalTrack() async throws {
        StubURLProtocol.reset { _ in
            (200, json("""
            {"id": 9, "trackName": "song", "instrumental": true,
             "plainLyrics": null, "syncedLyrics": null}
            """))
        }
        let result = try await client.fetchLyrics(title: "Song", artist: "Artist", album: nil, durationMs: 100_000)
        #expect(result == .instrumental)
    }

    @Test func plainLyricsFallback() async throws {
        StubURLProtocol.reset { request in
            if request.url?.path == "/api/search" { return (200, json("[]")) }
            return (200, json("""
            {"id": 9, "trackName": "song", "instrumental": false,
             "plainLyrics": "Just words", "syncedLyrics": null}
            """))
        }
        let result = try await client.fetchLyrics(title: "Song", artist: "Artist", album: nil, durationMs: nil)
        #expect(result == .plain("Just words"))
    }

    @Test func nothingFoundAnywhere() async throws {
        StubURLProtocol.reset { request in
            request.url!.path == "/api/search" ? (200, json("[]")) : (404, Data())
        }
        let result = try await client.fetchLyrics(title: "Song", artist: "Artist", album: "Album", durationMs: 100_000)
        #expect(result == .notFound)
        #expect(StubURLProtocol.requests.count == 3)
    }

    @Test func noAlbumSkipsSecondGet() async throws {
        StubURLProtocol.reset { request in
            request.url!.path == "/api/search" ? (200, json("[]")) : (404, Data())
        }
        _ = try await client.fetchLyrics(title: "Song", artist: "Artist", album: nil, durationMs: 100_000)
        let paths = StubURLProtocol.requests.map { $0.url!.path }
        #expect(paths == ["/api/get", "/api/search"])
    }

    @Test func serverErrorThrows() async {
        StubURLProtocol.reset { _ in (500, Data()) }
        await #expect(throws: LRCLIBClient.ClientError.badStatus(500)) {
            _ = try await client.fetchLyrics(title: "Song", artist: "Artist", album: nil, durationMs: nil)
        }
    }

    @Test func plainAlbumHitDoesNotHideSyncedRelease() async throws {
        StubURLProtocol.reset { request in
            if request.url?.path == "/api/search" {
                return (200, json("""
                [{"trackName":"爱你没错","artistName":"张信哲","duration":255.29,"syncedLyrics":"[00:01.00]原创测试"},
                 {"trackName":"爱你没错","artistName":"张信哲","duration":249,"syncedLyrics":"[00:01.00]Wrong edition"}]
                """))
            }
            return (200, json("""
            {"trackName":"爱你没错","artistName":"张信哲","duration":256.63,"plainLyrics":"Plain only"}
            """))
        }
        let result = try await client.fetchLyrics(title: "爱你没错", artist: "张信哲", album: "还爱", durationMs: 256_627)
        #expect(result == .synced("[00:01.00]原创测试"))
        #expect(StubURLProtocol.requests.count == 3)
    }

    @Test func alternateChineseScriptFindsSyncedVersion() async throws {
        StubURLProtocol.reset { request in
            guard request.url?.path == "/api/search" else { return (404, Data()) }
            if queryValue(request, "track_name") == "爱你没错" {
                return (200, json("""
                [{"trackName":"爱你没错","artistName":"张信哲","duration":256,"syncedLyrics":"[00:01.00]原创测试"}]
                """))
            }
            return (200, json("[]"))
        }
        let result = try await client.fetchLyrics(title: "愛你沒錯", artist: "張信哲", album: nil, durationMs: 256_000)
        #expect(result == .synced("[00:01.00]原创测试"))
    }

    @Test func alinChineseTitleMatchesTraditionalSpacedCatalogueEntry() async throws {
        StubURLProtocol.reset { request in
            guard request.url?.path == "/api/search" else { return (404, Data()) }
            if queryValue(request, "track_name") == "愛 請問怎麼走" {
                return (200, json("""
                [{"trackName":"愛 請問怎麼走","artistName":"A-Lin","duration":268,"syncedLyrics":"[00:01.00]原创测试"}]
                """))
            }
            return (200, json("[]"))
        }
        #expect(try await client.fetchLyrics(title: "爱，请问怎么走", artist: "A-Lin", album: nil, durationMs: 268_000) == .synced("[00:01.00]原创测试"))
    }

    @Test func temporaryFailureDoesNotPreventAlternateScriptSearch() async throws {
        StubURLProtocol.reset { request in
            guard request.url?.path == "/api/search" else { return (404, Data()) }
            if queryValue(request, "track_name") == "爱 请问怎么走" { return (503, Data()) }
            return (200, json("""
            [{"trackName":"愛 請問怎麼走","artistName":"A-Lin","duration":268,"syncedLyrics":"[00:01.00]原创测试"}]
            """))
        }
        #expect(try await client.fetchLyrics(title: "爱 请问怎么走", artist: "A-Lin", album: nil, durationMs: 268_000) == .synced("[00:01.00]原创测试"))
    }

    @Test func failedExactEndpointStillUsesAvailableSearchAndArtistAlias() async throws {
        StubURLProtocol.reset { request in
            guard request.url?.path == "/api/search" else { return (503, Data()) }
            if queryValue(request, "artist_name") == "david tao" {
                return (200, Data(#"[{"trackName":"王八蛋","artistName":"David Tao","duration":255,"syncedLyrics":"[00:01.00]原创测试"}]"#.utf8))
            }
            return (200, Data("[]".utf8))
        }
        #expect(try await client.fetchLyrics(title: "王八蛋", artist: "陶喆", album: "陶喆", durationMs: 255_000) == .synced("[00:01.00]原创测试"))
    }

    @Test func taoChineseNameFindsVerifiedEnglishArtistAlias() async throws {
        StubURLProtocol.reset { request in
            guard request.url?.path == "/api/search" else { return (404, Data()) }
            if queryValue(request, "artist_name") == "david tao" {
                return (200, Data(#"[{"trackName":"王八蛋","artistName":"David Tao","duration":255,"syncedLyrics":"[00:01.00]原創測試"}]"#.utf8))
            }
            return (200, Data("[]".utf8))
        }
        #expect(try await client.fetchLyrics(title: "王八蛋", artist: "陶喆", album: nil, durationMs: 255_000) == .synced("[00:01.00]原創測試"))
    }

    @Test func abelTesfayeFallsBackToWeekndWhenOriginalNameEndpointFails() async throws {
        StubURLProtocol.reset { request in
            guard request.url?.path == "/api/search" else { return (503, Data()) }
            if queryValue(request, "artist_name") == "abel tesfaye" { return (503, Data()) }
            return (200, Data(#"[{"id":1,"trackName":"In The Night","artistName":"The Weeknd","duration":236,"syncedLyrics":"[00:01.00]Original test"},{"id":2,"trackName":"In The Night","artistName":"The Weeknd","duration":173,"syncedLyrics":"[00:01.00]Short edit"}]"#.utf8))
        }
        #expect(try await client.fetchLyrics(title: "In the Night", artist: "Abel Tesfaye", album: "Beauty Behind the Madness", durationMs: 235_653) == .synced("[00:01.00]Original test"))
    }

    @Test func sameTitleByAnotherArtistIsRejected() async throws {
        StubURLProtocol.reset { request in
            if request.url?.path == "/api/search" {
                return (200, json("""
                [{"trackName":"song","artistName":"Another singer","duration":200,"syncedLyrics":"[00:01.00]Wrong singer"}]
                """))
            }
            return (404, Data())
        }
        #expect(try await client.fetchLyrics(title: "Song", artist: "Artist", album: nil, durationMs: 200_000) == .notFound)
    }

    @Test func searchFailurePreservesPlainText() async throws {
        StubURLProtocol.reset { request in
            if request.url?.path == "/api/search" { return (503, Data()) }
            return (200, json("{\"plainLyrics\":\"Already downloaded\"}"))
        }
        #expect(try await client.fetchLyrics(title: "Song", artist: "Artist", album: nil, durationMs: 200_000) == .plain("Already downloaded"))
    }

    @Test func oldPlainCacheIsUpgradedAndExplicitRetryBypassesCache() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = LyricsCache(directory: dir)
        let state = NowPlayingState(title: "Song", artist: "Artist", album: "Album", durationMs: 200_000, positionMs: 0, isPlaying: true, source: .appleMusic, capturedAt: Date())
        let oldKey = LyricsMatcher.signature(title: state.title, artist: state.artist, durationMs: state.durationMs, album: state.album)
        cache.store(.plain("Old plain result"), signature: oldKey)
        StubURLProtocol.reset { _ in (200, syncedHit) }
        let service = LyricsService(client: client, cache: cache)
        #expect(try await service.lyrics(for: state) == .synced("[00:01.00]Hello world"))
        #expect(StubURLProtocol.requests.count == 1)
        _ = try await service.lyrics(for: state)
        #expect(StubURLProtocol.requests.count == 1)
        _ = try await service.lyrics(for: state, refresh: true)
        #expect(StubURLProtocol.requests.count == 2)
    }

    @Test func missingLyricsAutomaticallyRetryWithoutNegativeCacheLoop() async throws {
        var clock = 0.0
        var sleeps: [Double] = []
        var gets = 0
        StubURLProtocol.reset { request in
            if request.url?.path == "/api/get" {
                gets += 1
                return gets == 1 ? (404, Data()) : (200, syncedHit)
            }
            return (200, json("[]"))
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = LyricsService(client: client, cache: LyricsCache(directory: dir), now: { clock }, sleep: { delay in sleeps.append(delay); clock += delay })
        let state = NowPlayingState(title: "Song", artist: "Artist", album: nil, durationMs: 200_000, positionMs: 0, isPlaying: true, source: .appleMusic, capturedAt: Date())
        #expect(try await service.lyrics(for: state) == .synced("[00:01.00]Hello world"))
        #expect(gets == 2)
        #expect(sleeps == [1])
    }

    @Test func networkFailureIsRetriedButCappedAtTwoAdditionalLookups() async throws {
        var clock = 0.0
        var sleeps: [Double] = []
        StubURLProtocol.reset { _ in (503, Data()) }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = LyricsService(client: client, cache: LyricsCache(directory: dir), now: { clock }, sleep: { delay in sleeps.append(delay); clock += delay })
        let state = NowPlayingState(title: "Song", artist: "Artist", album: nil, durationMs: 200_000, positionMs: 0, isPlaying: true, source: .appleMusic, capturedAt: Date())
        await #expect(throws: LRCLIBClient.ClientError.badStatus(503)) { _ = try await service.lyrics(for: state) }
        #expect(StubURLProtocol.requests.filter { $0.url?.path == "/api/get" }.count == 3)
        #expect(sleeps == [1, 2])
    }

    @Test func slowFirstRequestDoesNotStartRetriesOutsideFiveSecondWindow() async throws {
        var clock = 0.0
        var slept = false
        StubURLProtocol.reset { _ in clock = 6; return (503, Data()) }
        let service = LyricsService(client: client, now: { clock }, sleep: { _ in slept = true })
        let state = NowPlayingState(title: "Slow song", artist: "Artist", album: nil, durationMs: 200_000, positionMs: 0, isPlaying: true, source: .appleMusic, capturedAt: Date())
        await #expect(throws: LRCLIBClient.ClientError.badStatus(503)) { _ = try await service.lyrics(for: state, refresh: true) }
        #expect(StubURLProtocol.requests.count == 2)
        #expect(!slept)
    }

    @Test func cancellationDuringBackoffDoesNotIssueAnotherRequest() async throws {
        StubURLProtocol.reset { _ in (503, Data()) }
        let service = LyricsService(client: client, sleep: { _ in throw CancellationError() })
        let state = NowPlayingState(title: "Cancelled song", artist: "Artist", album: nil, durationMs: 200_000, positionMs: 0, isPlaying: true, source: .appleMusic, capturedAt: Date())
        await #expect(throws: CancellationError.self) { _ = try await service.lyrics(for: state, refresh: true) }
        #expect(StubURLProtocol.requests.count == 2)
    }

    @Test func resumedAppDoesNotRetryAfterItsWindowHasExpired() async throws {
        var clock = 0.0
        StubURLProtocol.reset { _ in (503, Data()) }
        let service = LyricsService(client: client, now: { clock }, sleep: { _ in clock = 20 })
        let state = NowPlayingState(title: "Suspended song", artist: "Artist", album: nil, durationMs: 200_000, positionMs: 0, isPlaying: true, source: .appleMusic, capturedAt: Date())
        await #expect(throws: LRCLIBClient.ClientError.badStatus(503)) { _ = try await service.lyrics(for: state, refresh: true) }
        #expect(StubURLProtocol.requests.count == 2)
    }

    // Lives in this suite (not its own) because it shares StubURLProtocol's
    // static state — suites run in parallel, .serialized only orders within one.
    @Test func secondLookupServedFromCache() async throws {
        StubURLProtocol.reset { _ in (200, syncedHit) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("driveverse-tests-\(UUID().uuidString)")
        let service = LyricsService(
            client: LRCLIBClient(session: StubURLProtocol.makeSession()),
            cache: LyricsCache(directory: dir)
        )
        let state = NowPlayingState(
            title: "Song", artist: "Artist", album: "Album",
            durationMs: 200_000, positionMs: 0,
            isPlaying: true, source: .spotify, capturedAt: Date()
        )

        let first = try await service.lyrics(for: state)
        #expect(first == .synced("[00:01.00]Hello world"))
        #expect(StubURLProtocol.requests.count == 1)

        let second = try await service.lyrics(for: state)
        #expect(second == first)
        #expect(StubURLProtocol.requests.count == 1) // no extra network hit

        try? FileManager.default.removeItem(at: dir)
    }
}
}
