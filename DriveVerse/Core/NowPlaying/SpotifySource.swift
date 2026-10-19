import Foundation
import Combine

@MainActor
protocol SpotifyTokenProviding: AnyObject {
    var isConnected: Bool { get }
    func validAccessToken() async throws -> String
    func handleUnauthorized() async
}

extension SpotifyAuth: SpotifyTokenProviding {}

/// Polls the Spotify Web API's currently-playing endpoint. 5 s while Spotify
/// is playing, 15 s while idle-probing, per CLAUDE.md §4.3. Never talks to the
/// Spotify app — Web API only, Developer-Mode app, account owner.
final class SpotifySource: NowPlayingSource {
    static let endpoint = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
    static let defaultActiveInterval: TimeInterval = 5
    static let idleInterval: TimeInterval = 15

    private let subject = CurrentValueSubject<NowPlayingState?, Never>(nil)
    var statePublisher: AnyPublisher<NowPlayingState?, Never> { subject.eraseToAnyPublisher() }

    private let session: URLSession
    private let tokenProvider: any SpotifyTokenProviding
    /// Settings-backed (3–10 s); read each cycle so changes apply immediately.
    var activeInterval: () -> TimeInterval = { SpotifySource.defaultActiveInterval }

    private let issueSubject = CurrentValueSubject<String?, Never>(nil)
    var issuePublisher: AnyPublisher<String?, Never> { issueSubject.eraseToAnyPublisher() }
    private var generation = 0
    private var blockedUntil = Date.distantPast
    private var pollTask: Task<Void, Never>?

    init(session: URLSession = .shared, tokenProvider: any SpotifyTokenProviding) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = await self.pollOnce()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        generation += 1
        subject.send(nil)
        issueSubject.send(nil)
    }

    /// Foreground resync: abandon the current sleep and poll immediately.
    func pollNow() {
        guard pollTask != nil else { return }
        pollTask?.cancel()
        pollTask = nil
        generation += 1
        start()
    }

    /// One poll; returns the delay until the next one.
    func pollOnce() async -> TimeInterval {
        let epoch = generation
        let wait = blockedUntil.timeIntervalSinceNow
        if wait > 0 { return wait }
        guard await tokenProvider.isConnected else {
            subject.send(nil)
            return Self.idleInterval
        }
        let token: String
        do {
            token = try await tokenProvider.validAccessToken()
        } catch {
            subject.send(nil)
            return Self.idleInterval
        }

        guard epoch == generation, !Task.isCancelled else { return Self.idleInterval }
        var request = URLRequest(url: Self.endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard epoch == generation, !Task.isCancelled else { return Self.idleInterval }
            guard let http = response as? HTTPURLResponse else { return Self.idleInterval }
            switch http.statusCode {
            case 200:
                issueSubject.send(nil)
                let state = try Self.parseCurrentlyPlaying(data, capturedAt: Date())
                subject.send(state)
                return state?.isPlaying == true ? activeInterval() : Self.idleInterval
            case 204: // nothing playing
                issueSubject.send(nil)
                subject.send(nil)
                return Self.idleInterval
            case 401:
                await tokenProvider.handleUnauthorized()
                subject.send(nil)
                return Self.idleInterval
            case 429:
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                let delay = max(retryAfter ?? Self.idleInterval, 1)
                blockedUntil = Date().addingTimeInterval(delay)
                return delay
            case 403:
                subject.send(nil)
                issueSubject.send("Spotify 拒绝读取播放状态。请确认 Premium 有效，并在开发者应用中允许当前登录账号访问。")
                return Self.idleInterval
            default:
                subject.send(nil)
                issueSubject.send("Spotify 暂时无法读取播放状态，将稍后重试。")
                return Self.idleInterval
            }
        } catch {
            // Transient network error (tunnel, dead zone) — just try again.
            return Self.idleInterval
        }
    }

    // MARK: - Parsing (pure, fixture-tested)

    static func parseCurrentlyPlaying(_ data: Data, capturedAt: Date) throws -> NowPlayingState? {
        struct Payload: Decodable {
            struct Item: Decodable {
                struct Artist: Decodable { let name: String }
                struct Album: Decodable { let name: String? }
                let name: String
                let duration_ms: Int?
                let artists: [Artist]?
                let album: Album?
            }
            let progress_ms: Int?
            let is_playing: Bool?
            let item: Item?
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let item = payload.item else { return nil } // e.g. private session or ad
        return NowPlayingState(
            title: item.name,
            artist: item.artists?.first?.name ?? "",
            album: item.album?.name,
            durationMs: item.duration_ms,
            positionMs: payload.progress_ms ?? 0,
            isPlaying: payload.is_playing ?? false,
            source: .spotify,
            capturedAt: capturedAt
        )
    }
}

// Commands are explicit user actions. Never automatically replay a mutation:
// retrying a timed-out "next" request could skip a second song.
enum PlaybackCommand {
    case play, pause, next
    var path: String {
        switch self { case .play: return "play"; case .pause: return "pause"; case .next: return "next" }
    }
    var method: String { self == .next ? "POST" : "PUT" }
}

enum PlaybackControlError: Error, Equatable, LocalizedError {
    case unavailable, authorizationRequired, noActiveDevice, forbidden, rateLimited, http(Int)
    var errorDescription: String? {
        switch self {
        case .unavailable: return "请先在音乐 App 中播放一首歌。"
        case .authorizationRequired: return "请在设置中重新连接 Spotify，允许控制播放。"
        case .noActiveDevice: return "请先打开 Spotify 并播放歌曲，再使用这里的控制按钮。"
        case .forbidden: return "请重新连接 Spotify，确认播放控制授权和 Premium 有效。"
        case .rateLimited: return "操作过于频繁，请稍后再试。"
        case .http: return "播放操作暂未完成，请检查网络后重试。"
        }
    }
}

struct SpotifyPlaybackClient {
    let session: URLSession
    let tokenProvider: any SpotifyTokenProviding
    init(session: URLSession = .shared, tokenProvider: any SpotifyTokenProviding) {
        self.session = session
        self.tokenProvider = tokenProvider
    }
    func perform(_ command: PlaybackCommand) async throws {
        let token = try await tokenProvider.validAccessToken()
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/\(command.path)")!)
        request.httpMethod = command.method
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200, 204: return
        case 401:
            await tokenProvider.handleUnauthorized()
            throw PlaybackControlError.authorizationRequired
        case 403: throw PlaybackControlError.forbidden
        case 404: throw PlaybackControlError.noActiveDevice
        case 429: throw PlaybackControlError.rateLimited
        default: throw PlaybackControlError.http(http.statusCode)
        }
    }
}
