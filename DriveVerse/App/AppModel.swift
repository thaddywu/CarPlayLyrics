import Foundation
import Combine
import os

enum LyricsDisplayState: Equatable {
    case idle, loading, synced([LRCLine]), plain(String), instrumental, notFound, failed
}

/// Apple Music observation stays independent of the user-controlled car card.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private static let log = Logger(subsystem: "com.thaddywu.along", category: "pipeline")

    @Published private(set) var nowPlaying: NowPlayingState?
    @Published private(set) var lyricsState: LyricsDisplayState = .idle
    @Published private(set) var position: LyricsPosition?
    @Published private(set) var appleMusicAuth: MediaAuthStatus = .unknown
    @Published private(set) var lyricsEnabled = false
    @Published var errorMessage: String?
    @Published private(set) var isControllingPlayback = false
    @Published private(set) var playbackError: String?

    func togglePlayback() async {
        guard let state = nowPlaying else { return }
        await controlPlayback(state.isPlaying ? .pause : .play, source: state.source)
    }

    func nextTrack() async {
        guard let source = nowPlaying?.source else { return }
        await controlPlayback(.next, source: source)
    }

    private func controlPlayback(_ command: PlaybackCommand, source: MusicSource) async {
        guard !isControllingPlayback else { return }
        isControllingPlayback = true
        playbackError = nil
        defer { isControllingPlayback = false }
        do {
            switch source {
            case .appleMusic:
#if os(iOS)
                try appleSource.perform(command)
#else
                throw PlaybackControlError.unavailable
#endif
            case .spotify:
                try await SpotifyPlaybackClient(tokenProvider: spotifyAuth).perform(command)
            }
            // Allow the real player to publish the result; do not fake success.
            try await Task.sleep(for: .milliseconds(350))
            foregroundResync()
        } catch is CancellationError { }
        catch { playbackError = error.localizedDescription }
    }
    @Published private(set) var isConnectingSpotify = false
    @Published private(set) var spotifyIssue: String?
    let spotifyAuth: SpotifyAuth
    private let spotifySource: SpotifySource
    private let coordinator: NowPlayingCoordinator

    var sourcePin: SourcePin {
        get { coordinator.pin }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue.rawValue, forKey: "sourcePin")
            coordinator.pin = newValue
            updateSpotifyObservation()
        }
    }

    private func updateSpotifyObservation() {
        if spotifyAuth.isConnected, sourcePin != .appleMusic {
            spotifySource.start()
            spotifySource.pollNow()
        } else { spotifySource.stop() }
    }

    func connectSpotify(clientID: String) async {
        guard !isConnectingSpotify else { return }
        isConnectingSpotify = true
        errorMessage = nil
        defer { isConnectingSpotify = false }
        do {
            try spotifyAuth.configureClientID(clientID)
#if os(iOS)
            try await spotifyAuth.connect()
            sourcePin = .spotify
#endif
        } catch is CancellationError { }
        catch SpotifyAuthError.invalidClientID { errorMessage = "Client ID 应为 32 位字母数字，请从 Spotify 开发者应用复制。" }
        catch { errorMessage = "Spotify 连接未完成，请核对 Client ID 和回调地址后重试。" }
    }

    func disconnectSpotify() {
        spotifySource.stop()
        spotifyAuth.disconnect()
        spotifyIssue = nil
        if sourcePin == .spotify { sourcePin = .auto }
    }

#if os(iOS)
    private let appleSource = AppleMusicSource()
    private let liveActivity = LiveActivityController()
    private let backgroundKeeper = BackgroundKeeper()
#endif
    private let syncEngine = SyncEngine()
    private let lyricsService = LyricsService()
    private var cancellables: Set<AnyCancellable> = []
    private var lyricsTask: Task<Void, Never>?
    private var currentSignature: String?
    private var started = false

    init() {
        let auth = SpotifyAuth()
        spotifyAuth = auth
        let spotify = SpotifySource(tokenProvider: auth)
        spotifySource = spotify
        let applePublisher: AnyPublisher<NowPlayingState?, Never>
#if os(iOS)
        applePublisher = appleSource.statePublisher
#else
        applePublisher = Just<NowPlayingState?>(nil).eraseToAnyPublisher()
#endif
        let savedPin = UserDefaults.standard.string(forKey: "sourcePin").flatMap(SourcePin.init(rawValue:)) ?? .auto
        coordinator = NowPlayingCoordinator(applePublisher: applePublisher, spotifyPublisher: spotify.statePublisher, pin: savedPin)
        coordinator.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handle(state) }
            .store(in: &cancellables)
        auth.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        auth.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateSpotifyObservation() }
            .store(in: &cancellables)
        spotify.issuePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.spotifyIssue = $0 }
            .store(in: &cancellables)
        // SyncEngine publishes on the main thread. Consume synchronously to avoid
        // queued positions from the previous track reaching the new track's card.
        syncEngine.positionSubject
            .sink { [weak self] position in
                self?.position = position
                self?.syncLiveActivity()
            }
            .store(in: &cancellables)
#if os(iOS)
        appleSource.authStatusSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.appleMusicAuth = $0 }
            .store(in: &cancellables)
        backgroundKeeper.onIssue = { [weak self] _ in
            Task { @MainActor in
                self?.errorMessage = "持续显示歌词需要位置权限，请在系统设置中允许沿途访问位置。位置不会保存或上传。"
                self?.setLyricsEnabled(false)
            }
        }
#endif
    }

    func start() {
        guard !started else { return }
        started = true
#if os(iOS)
        appleSource.start()
#endif
        syncEngine.startTicking()
        updateSpotifyObservation()
    }

    func foregroundResync() {
        guard started else { return }
#if os(iOS)
        appleSource.refresh()
#endif
        if spotifyAuth.isConnected, sourcePin != .appleMusic { spotifySource.pollNow() }
    }

    /// Off detaches the activity immediately, so subsequent ticks cannot revive it.
    func setLyricsEnabled(_ enabled: Bool) {
        lyricsEnabled = enabled
#if os(iOS)
        liveActivity.setEnabled(enabled)
        if enabled {
            errorMessage = nil
            start()
            liveActivity.beginSession(state: nowPlaying, position: position)
            do { try backgroundKeeper.start() }
            catch {
                errorMessage = "持续显示歌词需要位置权限，请在系统设置中允许沿途访问位置。"
                setLyricsEnabled(false)
                return
            }
            foregroundResync()
        } else {
            backgroundKeeper.stop()
        }
#endif
    }

    // Preserve existing Shortcuts action identifiers for installed automations.
    func startDriveSession() { setLyricsEnabled(true) }
    func stopDriveSession() { setLyricsEnabled(false) }

    func retryLyrics() {
        guard let state = nowPlaying else { return }
        fetchLyrics(for: state, refresh: true)
    }

    func clearLyricsCache() { lyricsService.clearCache() }

    private func handle(_ state: NowPlayingState?) {
        let signature = state.map {
            LyricsMatcher.signature(title: $0.title, artist: $0.artist, durationMs: $0.durationMs, album: $0.album)
        }
        let changedTrack = signature != currentSignature
        if changedTrack {
            lyricsTask?.cancel()
            // Clear the old text before publishing the new song identity.
            syncEngine.setLyrics([])
            currentSignature = signature
        }
        nowPlaying = state
        syncEngine.apply(state)
        guard let state else {
            lyricsTask?.cancel()
            lyricsState = .idle
            syncEngine.setLyrics([])
            return
        }
        if changedTrack { fetchLyrics(for: state) }
        syncLiveActivity()
    }

    private func syncLiveActivity() {
#if os(iOS)
        guard lyricsEnabled else { return }
        let synced: Bool
        if case .synced = lyricsState { synced = true } else { synced = false }
        liveActivity.sync(state: nowPlaying, position: position, hasSyncedLyrics: synced)
#endif
    }

    private func fetchLyrics(for state: NowPlayingState, refresh: Bool = false) {
        lyricsTask?.cancel()
        syncEngine.setLyrics([])
        lyricsState = .loading
        lyricsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.lyricsService.lyrics(for: state, refresh: refresh)
                guard !Task.isCancelled else { return }
                switch result {
                case .synced(let raw):
                    let lines = LRCParser.parse(raw).map { LRCLine(timeMs: $0.timeMs, text: Transliterator.simplifiedChinese($0.text)) }
                    if lines.isEmpty { self.lyricsState = .notFound }
                    else {
                        self.lyricsState = .synced(lines)
                        self.syncEngine.setLyrics(lines)
                    }
                case .plain(let text): self.lyricsState = .plain(Transliterator.simplifiedChinese(text))
                case .instrumental: self.lyricsState = .instrumental
                case .notFound: self.lyricsState = .notFound
                }
                self.syncLiveActivity()
            } catch is CancellationError {
                // A newer song superseded this request.
            } catch {
                guard !Task.isCancelled else { return }
                self.lyricsState = .failed
                Self.log.warning("Lyrics lookup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
