import Foundation
import AVFoundation
import Combine
import Supabase

/// Service for managing music playback
class PlaybackService: ObservableObject {
    static let shared = PlaybackService()

    private var player: AVPlayer?
    private var timeObserver: Any?

    // Cache for ISRC and preview URL lookups
    private var isrcCache: [String: String] = [:] // spotifyId -> ISRC
    private var previewUrlCache: [String: String] = [:] // ISRC -> previewUrl

    @Published var currentTrack: MusicItem?
    @Published var currentSourceId: String? // Track which specific share/source is playing
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private init() {
        setupAudioSession()
    }

    deinit {
        stopPlayback()
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
                if previewUrlCache.values.contains(where: { _ in true }) && isrcCache[spotifyId] != nil {
                    continue // Already cached
                }

                // Fetch in background
                do {
                    // Get ISRC if not cached
                    let isrc: String
                    if let cachedIsrc = isrcCache[spotifyId] {
                        isrc = cachedIsrc
                    } else if let fetchedIsrc = try await fetchSpotifyISRC(spotifyId: spotifyId) {
                        isrcCache[spotifyId] = fetchedIsrc
                        isrc = fetchedIsrc
                    } else {
                        continue
                    }

                    // Skip if preview URL already cached
                    if previewUrlCache[isrc] != nil { continue }

                    // Fetch Apple Music preview
                    guard let artistName = track.artistName else { continue }
                    if let appleMusicTrack = try await AppleMusicService.shared.searchTrack(
                        name: track.name,
                        artist: artistName,
                        isrc: isrc
                    ), let previewUrl = appleMusicTrack.previewURL, !previewUrl.isEmpty {
                        previewUrlCache[isrc] = previewUrl
                        print("⚡️ Pre-fetched preview for: \(track.name)")
                    }
                } catch {
                    // Silently fail for background pre-fetching
                }
            }
        }
    }

    // MARK: - Playback Control

    /// Play a track by its preview URL
    func play(track: MusicItem, sourceId: String? = nil) {
        print("🎵 Attempting to play track: \(track.name)")
        print("   Source ID: \(sourceId ?? "nil")")
        print("   Current Source ID: \(currentSourceId ?? "nil")")
        print("   Preview URL: \(track.previewUrl ?? "nil")")
        print("   Album Art URL: \(track.albumArtUrl ?? "nil")")
        print("   Spotify ID: \(track.spotifyId ?? "nil")")
        print("   ISRC: \(track.isrc ?? "nil")")

        // Check if this is the exact same instance already playing
        if let sourceId = sourceId,
           currentTrack?.id == track.id,
           currentSourceId == sourceId,
           player != nil {
            // Same exact share instance - just toggle play/pause
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }

        // Different instance or different track - update sourceId and play fresh
        currentSourceId = sourceId

        // If track has a preview URL, use it
        if let previewUrl = track.previewUrl, !previewUrl.isEmpty {
            playFromURL(previewUrl, track: track)
            return
        }

        // No preview URL - fetch ISRC from Spotify, then find exact match on Apple Music
        if let spotifyId = track.spotifyId {
            print("⚠️ No preview URL, fetching ISRC and Apple Music preview")
            Task {
                do {
                    // Step 1: Get ISRC from Spotify (check cache first)
                    let isrc: String
                    if let cachedIsrc = isrcCache[spotifyId] {
                        print("⚡️ Using cached ISRC: \(cachedIsrc)")
                        isrc = cachedIsrc
                    } else if let fetchedIsrc = try await fetchSpotifyISRC(spotifyId: spotifyId) {
                        print("✅ Got ISRC from Spotify: \(fetchedIsrc)")
                        isrcCache[spotifyId] = fetchedIsrc
                        isrc = fetchedIsrc
                    } else {
                        print("⚠️ No ISRC available from Spotify")
                        return
                    }

                    // Step 2: Get preview URL from Apple Music (check cache first)
                    let applePreviewUrl: String
                    var appleMusicTrack: AppleMusicTrack? = nil

                    if let cachedUrl = previewUrlCache[isrc] {
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
                                previewUrlCache[isrc] = url
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

                    // Use Apple Music preview and artwork from the matched track
                    var updatedTrack = track
                    updatedTrack = MusicItem(
                        id: track.id,
                        name: track.name,
                        artistName: track.artistName,
                        previewUrl: applePreviewUrl,
                        // Use Apple Music artwork if available, otherwise keep original
                        albumArtUrl: appleMusicTrack?.artworkURL ?? track.albumArtUrl,
                        isrc: isrc,
                        playedAt: track.playedAt,
                        spotifyId: track.spotifyId,
                        appleMusicId: appleMusicTrack?.id ?? track.appleMusicId,
                        popularity: track.popularity,
                        followerCount: track.followerCount
                    )
                    await MainActor.run {
                        self.playFromURL(applePreviewUrl, track: updatedTrack)
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
                        // Update track with Apple Music preview and artwork
                        var updatedTrack = track
                        updatedTrack = MusicItem(
                            id: track.id,
                            name: track.name,
                            artistName: track.artistName,
                            previewUrl: applePreviewUrl,
                            // Use Apple Music artwork if available, otherwise keep original
                            albumArtUrl: appleMusicTrack.artworkURL ?? track.albumArtUrl,
                            isrc: track.isrc,
                            playedAt: track.playedAt,
                            spotifyId: track.spotifyId, // Preserve Spotify ID
                            appleMusicId: appleMusicTrack.id, // Use Apple Music ID from match
                            popularity: track.popularity,
                            followerCount: track.followerCount
                        )
                        await MainActor.run {
                            self.playFromURL(applePreviewUrl, track: updatedTrack)
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

    private func playFromURL(_ urlString: String, track: MusicItem) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }

        // Always stop and start fresh when playing from URL
        // The decision to reuse or restart should be made at higher level (play method)
        stopPlayback()

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
    func stopPlayback() {
        player?.pause()
        player = nil

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        currentTrack = nil
        currentSourceId = nil
        isPlaying = false
        currentTime = 0
        duration = 0

        print("⏹️ Stopped")
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
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }
    }

    @objc private func playerDidFinishPlaying() {
        // Just stop playback (don't auto-advance)
        DispatchQueue.main.async {
            self.stopPlayback()
        }
    }
}
