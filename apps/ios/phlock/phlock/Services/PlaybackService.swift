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

    // Throttle time updates to reduce view recomposition overhead
    private var lastReportedTime: Double = 0
    private let timeUpdateThreshold: Double = 0.3 // Only update every 0.3 seconds

    // Prevent duplicate preview fetches for the same track
    private var currentFetchingTrackId: String? = nil

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
    /// Uses server-side validate-track edge function (no MusicKit permission needed)
    func prefetchPreviewUrls(for tracks: [MusicItem]) {
        Task {
            for track in tracks {
                // Skip if already has preview URL
                if track.previewUrl != nil { continue }
                guard let spotifyId = track.spotifyId else { continue }

                // Check if already fully cached
                if let cachedIsrc = getCachedISRC(for: spotifyId),
                   getCachedPreviewUrl(for: cachedIsrc) != nil {
                    continue // Already cached
                }

                // Fetch in background using server-side API
                do {
                    let validatedTrack = try await fetchPreviewFromServer(
                        spotifyId: spotifyId,
                        trackName: track.name,
                        artistName: track.artistName ?? ""
                    )

                    // Cache the results
                    if let isrc = validatedTrack.isrc, let previewUrl = validatedTrack.previewUrl, !previewUrl.isEmpty {
                        setCachedISRC(isrc, for: spotifyId)
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
        allowSameSourceToggle: Bool = true,
        autoPlay: Bool = true,
        seekToPosition: Double? = nil
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
            PhlockLogger.playback.debugLog("Show Mini Player: \(showMiniPlayer), autoPlay: \(autoPlay), seekTo: \(seekToPosition ?? -1)")
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

        // IMPORTANT: Set currentTrack immediately so mini player shows correct artwork
        // This prevents briefly showing stale artwork while fetching preview URL
        currentTrack = track

        // If track has a preview URL, use it
        if let previewUrl = track.previewUrl, !previewUrl.isEmpty {
            playFromURL(previewUrl, track: track, sourceId: sourceId, autoPlay: autoPlay, seekToPosition: seekToPosition)
            return
        }

        // No preview URL - fetch from server using validate-track edge function
        // This uses Apple Music Catalog API server-side (no MusicKit permission needed)
        // Use spotifyId if available, otherwise fall back to track.id (which is often the Spotify ID for Spotify tracks)
        let effectiveSpotifyId = track.spotifyId ?? track.id
        if !effectiveSpotifyId.isEmpty {
            // Guard against duplicate fetches for the same track
            // This can happen when view recomposition triggers multiple play() calls
            if currentFetchingTrackId == track.id {
                print("⚠️ Already fetching preview for track \(track.name), skipping duplicate request")
                return
            }
            currentFetchingTrackId = track.id

            print("⚠️ No preview URL, fetching from server via validate-track (id: \(effectiveSpotifyId))")
            Task { [weak self] in
                defer {
                    Task { @MainActor in
                        self?.currentFetchingTrackId = nil
                    }
                }
                do {
                    // Check cache first
                    if let cachedIsrc = self?.getCachedISRC(for: effectiveSpotifyId),
                       let cachedUrl = self?.getCachedPreviewUrl(for: cachedIsrc) {
                        print("⚡️ Using cached preview URL")
                        await MainActor.run {
                            self?.playFromURL(cachedUrl, track: MusicItem(
                                id: track.id,
                                name: track.name,
                                artistName: track.artistName,
                                previewUrl: cachedUrl,
                                albumArtUrl: track.albumArtUrl,
                                isrc: cachedIsrc,
                                playedAt: track.playedAt,
                                spotifyId: track.spotifyId ?? effectiveSpotifyId,
                                appleMusicId: track.appleMusicId,
                                popularity: track.popularity,
                                followerCount: track.followerCount
                            ), sourceId: sourceId, autoPlay: autoPlay, seekToPosition: seekToPosition)
                        }
                        return
                    }

                    // Call validate-track edge function which uses Apple Music Catalog API server-side
                    guard let self = self else { return }
                    let validatedTrack = try await self.fetchPreviewFromServer(
                        spotifyId: effectiveSpotifyId,
                        trackName: track.name,
                        artistName: track.artistName ?? ""
                    )

                    if let previewUrl = validatedTrack.previewUrl, !previewUrl.isEmpty {
                        print("✅ Got preview URL from server: \(previewUrl)")

                        // Cache the results
                        if let isrc = validatedTrack.isrc {
                            self.setCachedISRC(isrc, for: effectiveSpotifyId)
                            self.setCachedPreviewUrl(previewUrl, for: isrc)
                        }

                        let updatedTrack = MusicItem(
                            id: track.id,
                            name: track.name,
                            artistName: track.artistName,
                            previewUrl: previewUrl,
                            albumArtUrl: track.albumArtUrl,
                            isrc: validatedTrack.isrc,
                            playedAt: track.playedAt,
                            spotifyId: track.spotifyId ?? effectiveSpotifyId,
                            appleMusicId: track.appleMusicId,  // Keep original, not available from edge function
                            popularity: track.popularity,
                            followerCount: track.followerCount
                        )
                        await MainActor.run {
                            self.playFromURL(previewUrl, track: updatedTrack, sourceId: sourceId, autoPlay: autoPlay, seekToPosition: seekToPosition)
                        }
                    } else {
                        print("❌ No preview URL available from server")
                    }
                } catch {
                    print("❌ Error fetching preview from server: \(error)")
                }
            }
            return
        }

        // No Spotify ID available - cannot fetch preview
        print("❌ No Spotify ID available, cannot fetch preview")
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

    /// Fetch preview URL from server using validate-track edge function
    /// This uses Apple Music Catalog API server-side (no MusicKit permission needed)
    private func fetchPreviewFromServer(spotifyId: String, trackName: String, artistName: String) async throws -> ValidatedTrack {
        let supabase = PhlockSupabaseClient.shared.client

        // The edge function expects 'trackId', not 'spotifyId'
        struct ValidateRequest: Encodable {
            let trackId: String
            let trackName: String
            let artistName: String
        }

        let request = ValidateRequest(trackId: spotifyId, trackName: trackName, artistName: artistName)
        let response: ValidateTrackResponse = try await supabase.functions.invoke(
            "validate-track",
            options: FunctionInvokeOptions(body: request)
        )

        guard response.success, let track = response.track else {
            throw NSError(domain: "PlaybackService", code: 1, userInfo: [NSLocalizedDescriptionKey: response.error ?? "Track not found"])
        }

        return track
    }

    /// Response wrapper from validate-track edge function
    private struct ValidateTrackResponse: Decodable {
        let success: Bool
        let method: String?
        let track: ValidatedTrack?
        let error: String?
    }

    /// Track data from validate-track edge function
    private struct ValidatedTrack: Decodable {
        let id: String
        let name: String
        let artistName: String
        let artists: [String]?
        let albumArtUrl: String?
        let previewUrl: String?
        let isrc: String?
        let popularity: Int?
        let spotifyUrl: String?
    }

    private func playFromURL(_ urlString: String, track: MusicItem, sourceId: String? = nil, autoPlay: Bool = true, seekToPosition: Double? = nil) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }

        // Signal track switch start to prevent time observer from updating currentTime
        // This prevents the playhead from briefly jumping to 0:00 during track transitions
        isTrackSwitching = true

        // Preserve the shouldShowMiniPlayer flag before stopPlayback resets it
        let preserveShowMiniPlayer = shouldShowMiniPlayer

        // Always stop and start fresh when playing from URL
        // The decision to reuse or restart should be made at higher level (play method)
        stopPlayback(clearQueue: false)

        // Restore the flag after stopPlayback
        shouldShowMiniPlayer = preserveShowMiniPlayer

        // IMPORTANT: Pre-set currentTime to seekToPosition IMMEDIATELY after stopPlayback
        // This prevents the UI from briefly showing 0:00 before the seek completes
        // Must happen BEFORE setupTimeObserver() so the time observer doesn't overwrite it
        if let position = seekToPosition, position > 0 {
            currentTime = position
        }

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

        // Set initial playback state based on autoPlay
        isPlaying = autoPlay

        // Get duration on background thread to avoid blocking main thread
        // Then seek if needed
        Task.detached { [weak self] in
            let loadedDuration = try? await playerItem.asset.load(.duration)

            await MainActor.run {
                guard let self = self else { return }

                if let duration = loadedDuration {
                    self.duration = CMTimeGetSeconds(duration)
                }

                // Seek to saved position if provided (must happen after player is ready)
                if let position = seekToPosition, position > 0 {
                    let cmTime = CMTime(seconds: position, preferredTimescale: 600)
                    self.player?.seek(to: cmTime)
                    // currentTime already set above, but update again to be safe
                    self.currentTime = position
                    print("⏩ Seeked to saved position: \(position)s")
                }

                // Signal that track switch is complete - time observer can now update currentTime
                self.isTrackSwitching = false
            }
        }

        // Start or pause based on autoPlay
        if autoPlay {
            player?.play()
            print("▶️ Playing: \(track.name)")
        } else {
            player?.pause()
            print("⏸️ Loaded (paused): \(track.name)")
        }
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
        lastReportedTime = 0 // Reset throttle tracking
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
        isPerformingSeek = true
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Optimistically update current time so UI reflects target immediately
        currentTime = time
        
        player?.seek(to: cmTime) { [weak self] _ in
            // Seek finished (or cancelled)
            MainActor.assumeIsolated {
                self?.isPerformingSeek = false
            }
        }
    }

    private var isPerformingSeek = false

    // MARK: - Private Helpers

    private func setupTimeObserver() {
        // Use 0.3s interval for smoother playhead but throttle @Published updates
        // to reduce SwiftUI view recomposition overhead
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            // Use MainActor.assumeIsolated since we know we're on main queue
            MainActor.assumeIsolated { [weak self] in
                guard let self = self else { return }
                // Ignore updates while seeking or switching tracks to prevent UI jitter
                // This prevents the playhead from briefly jumping to 0:00 before seek completes
                guard !self.isPerformingSeek && !self.isTrackSwitching else { return }

                let seconds = CMTimeGetSeconds(time)
                // Throttle updates: only publish if changed by threshold OR if paused (need accurate final position)
                // This significantly reduces SwiftUI view recomposition causing main thread hangs
                if abs(seconds - self.lastReportedTime) >= self.timeUpdateThreshold || !self.isPlaying {
                    self.lastReportedTime = seconds
                    self.currentTime = seconds
                }
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
        // Note: PhlockView's onReceive will call skipForward for autoplay
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

    private func playQueueItem(at index: Int, showMiniPlayer: Bool, autoPlay: Bool = true, seekToPosition: Double? = nil) {
        guard queue.indices.contains(index) else { return }
        currentQueueIndex = index
        let item = queue[index]
        play(
            track: item.track,
            sourceId: item.sourceId,
            showMiniPlayer: showMiniPlayer,
            resetQueue: false,
            allowSameSourceToggle: false,
            autoPlay: autoPlay,
            seekToPosition: seekToPosition
        )
    }

    var canGoToPreviousTrack: Bool {
        return currentTrack != nil && !queue.isEmpty
    }

    var canGoToNextTrack: Bool {
        return currentTrack != nil && !queue.isEmpty
    }

    func startQueue(tracks: [MusicItem], startAt index: Int, sourceIds: [String?]? = nil, showMiniPlayer: Bool = true, autoPlay: Bool = true, seekToPosition: Double? = nil) {
        guard !tracks.isEmpty, index >= 0, index < tracks.count else { return }

        queue = tracks.enumerated().map { idx, track in
            let sourceId = (sourceIds?.indices.contains(idx) == true) ? sourceIds?[idx] : nil
            return PlaybackQueueItem(track: track, sourceId: sourceId)
        }

        playQueueItem(at: index, showMiniPlayer: showMiniPlayer, autoPlay: autoPlay, seekToPosition: seekToPosition)
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

    /// Always skips to the previous track without restart threshold check.
    /// Used for swipe gestures where the user explicitly wants the previous track.
    func skipToPreviousTrack() {
        guard !queue.isEmpty else { return }
        let index = currentQueueIndex ?? 0
        let previousIndex = index == 0 ? (queue.count - 1) : (index - 1)
        playQueueItem(at: previousIndex, showMiniPlayer: shouldShowMiniPlayer)
    }

    // MARK: - Position Saving (for immersive layout resume)

    private nonisolated(unsafe) var savedPositions: [String: Double] = [:]
    private nonisolated(unsafe) var isTrackSwitching = false

    /// Save the current playback position for the current track
    func saveCurrentPosition() {
        guard let trackId = currentTrack?.id else { return }
        savedPositions[trackId] = currentTime
    }

    /// Get the saved position for a track (if any)
    func getSavedPosition(for trackId: String) -> Double? {
        return savedPositions[trackId]
    }

    /// Signal that we're about to switch tracks (prevents time observer jitter)
    func beginTrackSwitch() {
        isTrackSwitching = true
    }

    /// Called after track switch is complete
    func endTrackSwitch() {
        isTrackSwitching = false
    }
}
