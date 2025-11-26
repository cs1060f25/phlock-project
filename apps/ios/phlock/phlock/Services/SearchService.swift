import Foundation
import MusicKit
import Supabase

enum SearchType {
    case all
    case tracks
    case artists
}

struct SearchResult {
    let tracks: [MusicItem]
    let artists: [MusicItem]
}

class SearchService {
    static let shared = SearchService()

    private let spotifyService = SpotifyService.shared
    private let appleMusicService = AppleMusicService.shared
    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    /// Search for music using the user's preferred platform (Apple Music searches use MusicKit, otherwise Spotify)
    /// Falls back to Spotify if Apple Music search fails (e.g., missing permission)
    func search(query: String, type: SearchType = .all, platformType: PlatformType? = nil) async throws -> SearchResult {
        guard !query.isEmpty else {
            return SearchResult(tracks: [], artists: [])
        }

        let effectivePlatform: PlatformType
        if let platformType {
            effectivePlatform = platformType
        } else if let userPlatform = try? await AuthServiceV2.shared.currentUser?.resolvedPlatformType {
            effectivePlatform = userPlatform
        } else {
            effectivePlatform = .spotify
        }

        if effectivePlatform == .appleMusic {
            do {
                return try await searchAppleMusic(query: query, type: type)
            } catch {
                // Fall back to Spotify if Apple Music search fails (e.g., missing MusicKit authorization)
                print("⚠️ Apple Music search failed, falling back to Spotify: \(error.localizedDescription)")
            }
        }

        return try await searchSpotify(query: query, type: type)
    }

    // MARK: - Spotify Search

    private func searchSpotify(query: String, type: SearchType) async throws -> SearchResult {
        var tracks: [MusicItem] = []
        var artists: [MusicItem] = []

        // Search tracks via edge function (keeps client secret secure)
        if type == .all || type == .tracks {
            tracks = try await searchSpotifyTracks(query: query)
        }

        // Search artists via edge function
        if type == .all || type == .artists {
            artists = try await searchSpotifyArtists(query: query)
        }

        return SearchResult(tracks: tracks, artists: artists)
    }

    private func searchSpotifyTracks(query: String) async throws -> [MusicItem] {
        struct TrackSearchRequest: Encodable {
            let query: String
            let limit: Int
        }

        struct TrackSearchResponse: Decodable {
            let tracks: [SpotifyTrack]
        }

        struct SpotifyTrack: Decodable {
            let id: String
            let name: String
            let artists: [SpotifyArtist]
            let album: SpotifyAlbum
            let previewUrl: String?
            let externalIds: ExternalIds?
            let popularity: Int?

            struct SpotifyArtist: Decodable {
                let name: String
            }

            struct SpotifyAlbum: Decodable {
                let images: [SpotifyImage]
            }

            struct SpotifyImage: Decodable {
                let url: String
                let height: Int?
                let width: Int?
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

        let request = TrackSearchRequest(query: query, limit: 20)
        let response: TrackSearchResponse = try await supabase.functions.invoke(
            "search-spotify-tracks",
            options: FunctionInvokeOptions(body: request)
        )

        return response.tracks.map { track in
            // Get medium-sized image (usually index 1) or fallback to first available
            let albumArtUrl: String? = {
                guard !track.album.images.isEmpty else {
                    print("⚠️ Track '\(track.name)' has no album images")
                    return nil
                }
                // Spotify typically returns 3 sizes: 640x640, 300x300, 64x64
                // Use the largest (first) for best quality, especially for full-screen player
                let url = track.album.images.first?.url
                print("🎨 Track '\(track.name)' album art: \(url ?? "nil") (from \(track.album.images.count) images)")
                return url
            }()

            return MusicItem(
                id: track.id,
                name: track.name,
                artistName: track.artists.first?.name,
                previewUrl: track.previewUrl,
                albumArtUrl: albumArtUrl,
                isrc: track.externalIds?.isrc,
                playedAt: nil,
                spotifyId: track.id,
                appleMusicId: nil,
                popularity: track.popularity
            )
        }
    }

    private func searchSpotifyArtists(query: String) async throws -> [MusicItem] {
        struct ArtistSearchResponse: Decodable {
            let artists: [SpotifyArtist]
        }

        struct SpotifyArtist: Decodable {
            let id: String
            let name: String
            let images: [SpotifyImage]
            let popularity: Int?
            let followers: Int?

            struct SpotifyImage: Decodable {
                let url: String
            }
        }

        struct SearchRequest: Encodable {
            let artistName: String
        }

        let request = SearchRequest(artistName: query)
        let response: ArtistSearchResponse = try await supabase.functions.invoke(
            "search-spotify-artist",
            options: FunctionInvokeOptions(body: request)
        )

        return response.artists.map { artist in
            // Get largest image for best quality
            let artistImageUrl: String? = {
                guard !artist.images.isEmpty else { return nil }
                return artist.images.first?.url
            }()

            return MusicItem(
                id: artist.id,
                name: artist.name,
                artistName: nil,
                previewUrl: nil,
                albumArtUrl: artistImageUrl,  // For artists, we use the artist image
                isrc: nil,
                playedAt: nil,
                spotifyId: artist.id,
                appleMusicId: nil,
                popularity: artist.popularity,
                followerCount: artist.followers
            )
        }
    }

    // MARK: - Apple Music Search

    private func searchAppleMusic(query: String, type: SearchType) async throws -> SearchResult {
        // Ensure MusicKit access
        let currentStatus = MusicAuthorization.currentStatus
        if currentStatus != .authorized {
            let newStatus = await MusicAuthorization.request()
            guard newStatus == .authorized else {
                throw AppleMusicError.authorizationDenied
            }
        }

        var searchTypes: [MusicCatalogSearchable.Type] = []
        switch type {
        case .all:
            searchTypes = [Song.self, Artist.self]
        case .tracks:
            searchTypes = [Song.self]
        case .artists:
            searchTypes = [Artist.self]
        }

        var request = MusicCatalogSearchRequest(term: query, types: searchTypes)
        request.limit = 20

        let response = try await request.response()

        let tracks: [MusicItem]
        if type == .artists {
            tracks = []
        } else {
            tracks = response.songs.map { song in
                MusicItem(
                    id: song.id.rawValue,
                    name: song.title,
                    artistName: song.artistName,
                    previewUrl: song.previewAssets?.first?.url?.absoluteString,
                    albumArtUrl: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                    isrc: song.isrc,
                    playedAt: nil,
                    spotifyId: nil,
                    appleMusicId: song.id.rawValue
                )
            }
        }

        let artists: [MusicItem]
        if type == .tracks {
            artists = []
        } else {
            artists = response.artists.map { artist in
                MusicItem(
                    id: artist.id.rawValue,
                    name: artist.name,
                    artistName: nil,
                    previewUrl: nil,
                    albumArtUrl: artist.artwork?.url(width: 640, height: 640)?.absoluteString,
                    isrc: nil,
                    playedAt: nil,
                    spotifyId: nil,
                    appleMusicId: artist.id.rawValue,
                    popularity: nil,
                    followerCount: nil,
                    genres: artist.genreNames
                )
            }
        }

        return SearchResult(tracks: tracks, artists: artists)
    }

    // MARK: - Recently Played Tracks

    /// Fetch recently played tracks for the current user
    func getRecentlyPlayed(userId: UUID, platformType: PlatformType) async throws -> [MusicItem] {
        switch platformType {
        case .spotify:
            // Get access token from database
            let tokens: [PlatformToken] = try await supabase
                .from("platform_tokens")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            guard let token = tokens.first else {
                print("❌ No platform token found for user: \(userId)")
                throw NSError(domain: "SearchService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No platform token found"])
            }

            print("🎵 Fetching recently played from Spotify for user: \(userId)")

            // Fetch from Spotify API (with automatic token refresh on 401)
            do {
                let response = try await spotifyService.getRecentlyPlayed(accessToken: token.accessToken)
                print("✅ Got \(response.items.count) recently played tracks from Spotify")

                // Convert to MusicItems first
                let allTracks = response.items.enumerated().map { (index, item) -> MusicItem in
                    // Get medium-sized image
                    let albumArtUrl: String? = {
                        guard !item.track.album.images.isEmpty else { return nil }
                        return item.track.album.images.first?.url
                    }()

                    // Convert ISO 8601 string to Date
                    let playedDate: Date? = {
                        let formatter = ISO8601DateFormatter()
                        return formatter.date(from: item.playedAt)
                    }()

                    // Use played_at timestamp + index to ensure unique IDs for duplicate tracks
                    let uniqueId = "\(item.track.id)_\(item.playedAt)_\(index)"

                    return MusicItem(
                        id: uniqueId,
                        name: item.track.name,
                        artistName: item.track.artists.first?.name,
                        previewUrl: item.track.previewUrl,
                        albumArtUrl: albumArtUrl,
                        isrc: item.track.externalIds?.isrc,
                        playedAt: playedDate,
                        spotifyId: item.track.id,
                        appleMusicId: nil,
                        popularity: nil
                    )
                }

                // Remove duplicates by track ID (keep most recent play)
                // Sort by playedAt descending (most recent first)
                var seenTrackIds = Set<String>()
                let uniqueTracks = allTracks
                    .sorted { ($0.playedAt ?? Date.distantPast) > ($1.playedAt ?? Date.distantPast) }
                    .filter { track in
                        guard let spotifyId = track.spotifyId else { return true }
                        if seenTrackIds.contains(spotifyId) {
                            return false
                        }
                        seenTrackIds.insert(spotifyId)
                        return true
                    }

                print("✅ Removed \(allTracks.count - uniqueTracks.count) duplicate tracks")

                // Debug: Log the first 5 tracks with their played_at timestamps
                if uniqueTracks.count > 0 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .short
                    dateFormatter.timeStyle = .medium

                    print("📅 Recently played tracks order (first 5):")
                    for (index, track) in uniqueTracks.prefix(5).enumerated() {
                        let timeStr = track.playedAt.map { dateFormatter.string(from: $0) } ?? "unknown"
                        print("   \(index + 1). \(track.name) - played at: \(timeStr)")
                    }
                }

                return uniqueTracks
            } catch {
                print("❌ Spotify API error: \(error)")
                if let decodingError = error as? DecodingError {
                    print("❌ Decoding error details: \(decodingError)")
                }

                // Check if token expired - try to refresh
                guard let refreshToken = token.refreshToken else {
                    print("❌ No refresh token available")
                    throw error
                }

                print("🔄 Token might be expired, attempting refresh...")

                do {
                    // Refresh the token
                    let newAuth = try await spotifyService.refreshAccessToken(refreshToken: refreshToken)

                    // Update token in database
                    let now = Date()
                    let expiresAt = now.addingTimeInterval(TimeInterval(newAuth.expiresIn))

                    struct TokenUpdate: Encodable {
                        let access_token: String
                        let refresh_token: String
                        let token_expires_at: String
                        let updated_at: String
                    }

                    let updatePayload = TokenUpdate(
                        access_token: newAuth.accessToken,
                        refresh_token: newAuth.refreshToken ?? refreshToken,
                        token_expires_at: ISO8601DateFormatter().string(from: expiresAt),
                        updated_at: ISO8601DateFormatter().string(from: now)
                    )

                    try await supabase
                        .from("platform_tokens")
                        .update(updatePayload)
                        .eq("id", value: token.id.uuidString)
                        .execute()

                    print("✅ Token refreshed and updated in database")

                    // Retry with new token
                    let response = try await spotifyService.getRecentlyPlayed(accessToken: newAuth.accessToken)
                    print("✅ Got \(response.items.count) recently played tracks from Spotify (after refresh)")

                    // Convert to MusicItems first
                    let allTracks = response.items.enumerated().map { (index, item) -> MusicItem in
                        let albumArtUrl: String? = {
                            guard !item.track.album.images.isEmpty else { return nil }
                            return item.track.album.images.first?.url
                        }()

                        let playedDate: Date? = {
                            let formatter = ISO8601DateFormatter()
                            return formatter.date(from: item.playedAt)
                        }()

                        // Use played_at timestamp + index to ensure unique IDs for duplicate tracks
                        let uniqueId = "\(item.track.id)_\(item.playedAt)_\(index)"

                        return MusicItem(
                            id: uniqueId,
                            name: item.track.name,
                            artistName: item.track.artists.first?.name,
                            previewUrl: item.track.previewUrl,
                            albumArtUrl: albumArtUrl,
                            isrc: item.track.externalIds?.isrc,
                            playedAt: playedDate,
                            spotifyId: item.track.id,
                            appleMusicId: nil,
                            popularity: nil
                        )
                    }

                    // Remove duplicates by track ID (keep most recent play)
                    // Sort by playedAt descending (most recent first)
                    var seenTrackIds = Set<String>()
                    let uniqueTracks = allTracks
                        .sorted { ($0.playedAt ?? Date.distantPast) > ($1.playedAt ?? Date.distantPast) }
                        .filter { track in
                            guard let spotifyId = track.spotifyId else { return true }
                            if seenTrackIds.contains(spotifyId) {
                                return false
                            }
                            seenTrackIds.insert(spotifyId)
                            return true
                        }

                    print("✅ Removed \(allTracks.count - uniqueTracks.count) duplicate tracks")

                    // Debug: Log the first 5 tracks with their played_at timestamps
                    if uniqueTracks.count > 0 {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .short
                        dateFormatter.timeStyle = .medium

                        print("📅 Recently played tracks order (first 5 - after refresh):")
                        for (index, track) in uniqueTracks.prefix(5).enumerated() {
                            let timeStr = track.playedAt.map { dateFormatter.string(from: $0) } ?? "unknown"
                            print("   \(index + 1). \(track.name) - played at: \(timeStr)")
                        }
                    }

                    return uniqueTracks
                } catch {
                    print("❌ Failed to refresh token or retry: \(error)")
                    throw error
                }
            }

        case .appleMusic:
            // Fetch from Apple Music API (no token needed for MusicKit)
            let recentTracksWithArtists = try await appleMusicService.getRecentlyPlayed()
            return recentTracksWithArtists.map { item in
                MusicItem(
                    id: item.track.id,
                    name: item.track.title,
                    artistName: item.track.artistName,
                    previewUrl: item.track.previewURL,
                    albumArtUrl: item.track.artworkURL,
                    isrc: nil,
                    playedAt: nil,
                    spotifyId: nil,
                    appleMusicId: item.track.id,
                    popularity: nil,
                    followerCount: nil
                )
            }
        }
    }

    // MARK: - Artist Top Tracks

    /// Fetch top tracks for a specific artist
    func getArtistTopTracks(artistId: String, artistName: String? = nil, platformType: PlatformType) async throws -> [MusicItem] {
        switch platformType {
        case .spotify:
            return try await getSpotifyArtistTopTracks(artistId: artistId)
        case .appleMusic:
            return try await appleMusicService.getArtistTopTracks(
                artistId: artistId,
                artistName: artistName
            )
        }
    }

    private func getSpotifyArtistTopTracks(artistId: String) async throws -> [MusicItem] {
        struct ArtistTopTracksRequest: Encodable {
            let artistId: String
        }

        struct ArtistTopTracksResponse: Decodable {
            let tracks: [SpotifyTrack]
        }

        struct SpotifyTrack: Decodable {
            let id: String
            let name: String
            let artists: [SpotifyArtist]
            let album: SpotifyAlbum
            let previewUrl: String?
            let externalIds: ExternalIds?
            let popularity: Int?

            struct SpotifyArtist: Decodable {
                let name: String
            }

            struct SpotifyAlbum: Decodable {
                let images: [SpotifyImage]
            }

            struct SpotifyImage: Decodable {
                let url: String
                let height: Int?
                let width: Int?
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

        let request = ArtistTopTracksRequest(artistId: artistId)
        let response: ArtistTopTracksResponse = try await supabase.functions.invoke(
            "get-artist-top-tracks",
            options: FunctionInvokeOptions(body: request)
        )

        return response.tracks.map { track in
            // Get medium-sized image (usually index 1) or fallback to first available
            let albumArtUrl: String? = {
                guard !track.album.images.isEmpty else {
                    print("⚠️ Track '\(track.name)' has no album images")
                    return nil
                }
                // Spotify typically returns 3 sizes: 640x640, 300x300, 64x64
                // Use the largest (first) for best quality, especially for full-screen player
                let url = track.album.images.first?.url
                print("🎨 Track '\(track.name)' album art: \(url ?? "nil") (from \(track.album.images.count) images)")
                return url
            }()

            return MusicItem(
                id: track.id,
                name: track.name,
                artistName: track.artists.first?.name,
                previewUrl: track.previewUrl,
                albumArtUrl: albumArtUrl,
                isrc: track.externalIds?.isrc,
                playedAt: nil,
                spotifyId: track.id,
                appleMusicId: nil,
                popularity: track.popularity
            )
        }
    }
}
