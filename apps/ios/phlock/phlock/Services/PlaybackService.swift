import Foundation
import AVFoundation
import Combine
import Supabase
import OSLog

/// Service for managing music playback
@MainActor
class PlaybackService: ObservableObject {
    static let shared = PlaybackService()

    private var player: AVPlayer?
    private var timeObserver: Any?

    struct PlaybackQueueItem: Hashable {
        let track: MusicItem
        let sourceId: String?
    }

    // Thread-safe cache for ISRC and preview URL lookups
    private let cacheQueue = DispatchQueue(label: "com.phlock.playback.cache", attributes: .concurrent)
    private nonisolated(unsafe) var _isrcCache: [String: String] = [:] // spotifyId -> ISRC
    private nonisolated(unsafe) var _previewUrlCache: [String: String] = [:] // ISRC -> previewUrl

    // Thread-safe cache accessors
    private func getCachedISRC(for spotifyId: String) -> String? {
        cacheQueue.sync { _isrcCache[spotifyId] }
    }

    private func setCachedISRC(_ isrc: String, for spotifyId: String) {
        cacheQueue.async(flags: .barrier) {
            self._isrcCache[spotifyId] = isrc
        }
    }

    private func getCachedPreviewUrl(for isrc: String) -> String? {
        cacheQueue.sync { _previewUrlCache[isrc] }
    }

    private func setCachedPreviewUrl(_ url: String, for isrc: String) {
        cacheQueue.async(flags: .barrier) {
            self._previewUrlCache[isrc] = url
        }
    }

    @Published var currentTrack: MusicItem?
    @Published var currentSourceId: String? // Track which specific share/source is playing
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var shouldShowMiniPlayer = true // Controls whether mini player appears
    @Published var isShareOverlayPresented = false
    @Published private(set) var queue: [PlaybackQueueItem] = []
    @Published private(set) var currentQueueIndex: Int? = nil

    /// Track IDs that are marked as saved in the current playback context
    /// This is set by the view that starts playback and allows FullScreenPlayerView to show correct saved state
    @Published var savedTrackIds: Set<String> = []

    nonisolated private init() {
        Task { @MainActor in
            setupAudioSession()
        }
    }

    deinit {
        // Clean up synchronously in deinit
        player?.pause()
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Pre-fetching

    /// Pre-fetch preview URLs for tracks in the background to reduce latency
    func prefetchPreviewUrls(for tracks: [MusicItem]) {
        Task {
            for track in tracks {
                // Skip if already has preview URL or already cached
                if track.previewUrl != nil { continue }
                guard let spotifyId = track.spotifyId else { continue }
                if getCachedISRC(for: spotifyId) != nil {
                    continue // Already cached
                }

                // Fetch in background
                do {
                    // Get ISRC if not cached
                    let isrc: String
                    if let cachedIsrc = getCachedISRC(for: spotifyId) {
                        isrc = cachedIsrc
                    } else if let fetchedIsrc = try await fetchSpotifyISRC(spotifyId: spotifyId) {
                        setCachedISRC(fetchedIsrc, for: spotifyId)
                        isrc = fetchedIsrc
                    } else {
                        continue
                    }

                    // Skip if preview URL already cached
                    if getCachedPreviewUrl(for: isrc) != nil { continue }

                    // Fetch Apple Music preview
                    guard let artistName = track.artistName else { continue }
                    if let appleMusicTrack = try await AppleMusicService.shared.searchTrack(
                        name: track.name,
                        artist: artistName,
                        isrc: isrc
                    ), let previewUrl = appleMusicTrack.previewURL, !previewUrl.isEmpty {
                        setCachedPreviewUrl(previewUrl, for: isrc)
                    }
                } catch {
                    // Silently fail for background pre-fetching
                }
            }
        }
    }

    // MARK: - Playback Control

    /// Play a track by its preview URL
    func play(
        track: MusicItem,
        sourceId: String? = nil,
        showMiniPlayer: Bool = true,
        resetQueue: Bool = true,
        allowSameSourceToggle: Bool = true
    ) {
        // Set whether mini player should be shown
        shouldShowMiniPlayer = showMiniPlayer

        if resetQueue {
            queue = [PlaybackQueueItem(track: track, sourceId: sourceId)]
            currentQueueIndex = 0
        }

        if #available(iOS 14.0, *) {
            PhlockLogger.playback.infoLog("Attempting to play track: \(track.name)")
            PhlockLogger.playback.debugLog("Source ID: \(sourceId ?? "nil"), Current: \(self.currentSourceId ?? "nil")")
            PhlockLogger.playback.debugLog("Preview URL: \(track.previewUrl ?? "nil")")
            PhlockLogger.playback.debugLog("Show Mini Player: \(showMiniPlayer)")
        }

        // Check if this is the exact same instance already playing
        if allowSameSourceToggle,
           let sourceId = sourceId,
           currentTrack?.id == track.id,
           currentSourceId == sourceId,
           player != nil {
            // Same exact share instance - just toggle play/pause
            if isPlaying {
                pause()
            } else {
                shouldShowMiniPlayer = showMiniPlayer  // Ensure flag is updated even on resume
                resume()
            }
            return
        }

        // Different instance or different track - update sourceId and play fresh
        currentSourceId = sourceId

        // If track has a preview URL, use it
        if let previewUrl = track.previewUrl, !previewUrl.isEmpty {
            playFromURL(previewUrl, track: track, sourceId: sourceId)
            return
        }

        // No preview URL - fetch ISRC from Spotify, then find exact match on Apple Music
        if let spotifyId = track.spotifyId {
            print("⚠️ No preview URL, fetching ISRC and Apple Music preview")
            Task {
                do {
                    // Step 1: Get ISRC from Spotify (check cache first)
                    let isrc: String
                    if let cachedIsrc = getCachedISRC(for: spotifyId) {
                        print("⚡️ Using cached ISRC: \(cachedIsrc)")
                        isrc = cachedIsrc
                    } else if let fetchedIsrc = try await fetchSpotifyISRC(spotifyId: spotifyId) {
                        print("✅ Got ISRC from Spotify: \(fetchedIsrc)")
                        setCachedISRC(fetchedIsrc, for: spotifyId)
                        isrc = fetchedIsrc
                    } else {
                        print("⚠️ No ISRC available from Spotify")
                        return
                    }

                    // Step 2: Get preview URL from Apple Music (check cache first)
                    let applePreviewUrl: String
                    var appleMusicTrack: AppleMusicTrack? = nil

                    if let cachedUrl = getCachedPreviewUrl(for: isrc) {
                        print("⚡️ Using cached preview URL")
                        applePreviewUrl = cachedUrl
                    } else {
                        // Search Apple Music with ISRC
                        guard let artistName = track.artistName else {
                            print("❌ Cannot search Apple Music - missing artist name")
                            return
                        }

                        // Store the Apple Music track for later use
                        if let fetchedTrack = try await AppleMusicService.shared.searchTrack(
                            name: track.name,
                            artist: artistName,
                            isrc: isrc
                        ) {
                            appleMusicTrack = fetchedTrack
                            if let url = fetchedTrack.previewURL, !url.isEmpty {
                                print("✅ Found exact match on Apple Music with preview URL")
                                setCachedPreviewUrl(url, for: isrc)
                                applePreviewUrl = url
                            } else {
                                print("❌ Apple Music match found but no preview URL available")
                                return
                            }
                        } else {
                            print("❌ Could not find matching track on Apple Music with ISRC")
                            return
                        }
                    }

                    // Use Apple Music preview but keep original Spotify metadata
                    var updatedTrack = track
                    updatedTrack = MusicItem(
                        id: track.id,
                        name: track.name,
                        artistName: track.artistName,
                        previewUrl: applePreviewUrl,
                        // IMPORTANT: Keep original Spotify album art
                        albumArtUrl: track.albumArtUrl,
                        isrc: isrc,
                        playedAt: track.playedAt,
                        spotifyId: track.spotifyId,
                        appleMusicId: appleMusicTrack?.id ?? track.appleMusicId,
                        popularity: track.popularity,
                        followerCount: track.followerCount
                    )
                    await MainActor.run {
                        self.playFromURL(applePreviewUrl, track: updatedTrack, sourceId: sourceId)
                    }
                } catch {
                    print("❌ Error fetching preview: \(error)")
                }
            }
            return
        }

        // Fallback: try to find preview from Apple Music catalog
        print("⚠️ No Spotify ID, searching Apple Music catalog as fallback...")

        guard let artistName = track.artistName else {
            print("❌ Cannot search Apple Music - missing artist name")
            return
        }

        Task {
            do {
                // Pass ISRC if available for exact matching
                if let appleMusicTrack = try await AppleMusicService.shared.searchTrack(
                    name: track.name,
                    artist: artistName,
                    isrc: track.isrc
                ) {
                    if let applePreviewUrl = appleMusicTrack.previewURL, !applePreviewUrl.isEmpty {
                        // Update track with Apple Music preview but keep original Spotify metadata
                        var updatedTrack = track
                        updatedTrack = MusicItem(
                            id: track.id,
                            name: track.name,
                            artistName: track.artistName,
                            previewUrl: applePreviewUrl,
                            // IMPORTANT: Keep original Spotify album art
                            albumArtUrl: track.albumArtUrl,
                            isrc: track.isrc,
                            playedAt: track.playedAt,
                            spotifyId: track.spotifyId, // Preserve Spotify ID
                            appleMusicId: appleMusicTrack.id, // Use Apple Music ID from match
                            popularity: track.popularity,
                            followerCount: track.followerCount
                        )
                        await MainActor.run {
                            self.playFromURL(applePreviewUrl, track: updatedTrack, sourceId: sourceId)
                        }
                    } else {
                        print("❌ Apple Music match found but no preview URL available")
                    }
                } else {
                    print("❌ Could not find track in Apple Music catalog")
                }
            } catch {
                print("❌ Error searching Apple Music: \(error)")
            }
        }
    }

    /// Fetch ISRC from Spotify by track ID to enable exact matching on Apple Music
    private func fetchSpotifyISRC(spotifyId: String) async throws -> String? {
        let supabase = PhlockSupabaseClient.shared.client

        struct TrackRequest: Encodable {
            let trackId: String
        }

        struct SpotifyTrackResponse: Decodable {
            let id: String
            let name: String
            let artists: [Artist]
            let album: Album
            let previewUrl: String?
            let externalIds: ExternalIds?
            let popularity: Int?

            struct Artist: Decodable {
                let id: String
                let name: String
            }

            struct Album: Decodable {
                let id: String
                let name: String
                let images: [Image]

                struct Image: Decodable {
                    let url: String
                    let height: Int?
                    let width: Int?
                }
            }

            struct ExternalIds: Decodable {
                let isrc: String?
            }

            enum CodingKeys: String, CodingKey {
                case id, name, artists, album, popularity
                case previewUrl = "preview_url"
                case externalIds = "external_ids"
            }
        }

        let request = TrackRequest(trackId: spotifyId)
        let response: SpotifyTrackResponse = try await supabase.functions.invoke(
            "get-spotify-track",
            options: FunctionInvokeOptions(body: request)
        )

        return response.externalIds?.isrc
    }

    private func playFromURL(_ urlString: String, track: MusicItem, sourceId: String? = nil) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }

        // Preserve the shouldShowMiniPlayer flag before stopPlayback resets it
        let preserveShowMiniPlayer = shouldShowMiniPlayer

        // Always stop and start fresh when playing from URL
        // The decision to reuse or restart should be made at higher level (play method)
        stopPlayback(clearQueue: false)

        // Restore the flag after stopPlayback
        shouldShowMiniPlayer = preserveShowMiniPlayer

        // Create new player
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Set up time observer
        setupTimeObserver()

        // Set up playback end observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // Update state
        currentTrack = track
        currentSourceId = sourceId  // Preserve source ID so we can detect same track on next tap
        isPlaying = true

        // Get duration
        Task { @MainActor in
            if let duration = try? await playerItem.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
        }

        // Start playback
        player?.play()

        print("▶️ Playing: \(track.name)")
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        print("⏸️ Paused")
    }

    /// Resume playback
    func resume() {
        player?.play()
        isPlaying = true
        print("▶️ Resumed")
    }

    /// Stop playback and clear current track
    func stopPlayback(clearQueue: Bool = true) {
        // First pause playback
        player?.pause()

        // Remove time observer BEFORE setting player to nil (fix memory leak)
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        // Now we can safely clear the player
        player = nil

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        currentTrack = nil
        currentSourceId = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        if clearQueue {
            queue.removeAll()
            currentQueueIndex = nil
            shouldShowMiniPlayer = true // Reset to default
        }

        if #available(iOS 14.0, *) {
            PhlockLogger.playback.debugLog("Playback stopped")
        }
    }

    /// Seek to specific time
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTime = time
    }

    // MARK: - Private Helpers

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            // Use MainActor.assumeIsolated since we know we're on main queue
            MainActor.assumeIsolated { [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
            }
        }
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        // Only handle if this notification is for the current player item
        // This prevents race conditions when autoplay quickly starts the next track
        guard let finishedItem = notification.object as? AVPlayerItem,
              finishedItem == player?.currentItem else {
            return
        }

        // Pause at end but keep track info (don't clear currentTrack)
        // Note: FeedView's onReceive will call skipForward for autoplay
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Double-check we haven't already moved to a new track
            guard finishedItem == self.player?.currentItem else { return }

            self.isPlaying = false
            self.player?.pause()
            // Reset to beginning
            self.player?.seek(to: .zero)
            self.currentTime = 0
        }
    }

    // MARK: - Queue Helpers

    private func playQueueItem(at index: Int, showMiniPlayer: Bool) {
        guard queue.indices.contains(index) else { return }
        currentQueueIndex = index
        let item = queue[index]
        play(
            track: item.track,
            sourceId: item.sourceId,
            showMiniPlayer: showMiniPlayer,
            resetQueue: false,
            allowSameSourceToggle: false
        )
    }

    var canGoToPreviousTrack: Bool {
        return currentTrack != nil && !queue.isEmpty
    }

    var canGoToNextTrack: Bool {
        return currentTrack != nil && !queue.isEmpty
    }

    func startQueue(tracks: [MusicItem], startAt index: Int, sourceIds: [String?]? = nil, showMiniPlayer: Bool = true) {
        guard !tracks.isEmpty, index >= 0, index < tracks.count else { return }

        queue = tracks.enumerated().map { idx, track in
            let sourceId = (sourceIds?.indices.contains(idx) == true) ? sourceIds?[idx] : nil
            return PlaybackQueueItem(track: track, sourceId: sourceId)
        }

        playQueueItem(at: index, showMiniPlayer: showMiniPlayer)
    }

    func skipForward(wrap: Bool = true) {
        guard !queue.isEmpty else { return }
        let index = currentQueueIndex ?? 0

        let nextIndex: Int
        if index + 1 < queue.count {
            nextIndex = index + 1
        } else if wrap {
            nextIndex = 0
        } else {
            return
        }

        playQueueItem(at: nextIndex, showMiniPlayer: shouldShowMiniPlayer)
    }

    func skipBackward() {
        guard !queue.isEmpty else { return }
        let restartThreshold: Double = 3.0

        // If we're a few seconds into the song, jump to start
        if currentTime > restartThreshold {
            seek(to: 0)
            return
        }

        let index = currentQueueIndex ?? 0
        let previousIndex = index == 0 ? (queue.count - 1) : (index - 1)
        playQueueItem(at: previousIndex, showMiniPlayer: shouldShowMiniPlayer)
    }
}
