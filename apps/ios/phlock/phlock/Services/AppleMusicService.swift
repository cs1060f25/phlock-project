import Foundation
import MusicKit
import UIKit
import StoreKit
import MediaPlayer

/// Service for Apple Music authentication and API interactions
class AppleMusicService {
    static let shared = AppleMusicService()

    // Stable device-based identifier for Apple Music users
    private let appleMusicUserIdKey = "phlock_apple_music_user_id"

    private var stableUserId: String {
        // Check if we already have a stored ID
        if let existingId = UserDefaults.standard.string(forKey: appleMusicUserIdKey) {
            return existingId
        }

        // Create a new stable ID and store it
        let newId = "apple-music-\(UUID().uuidString)"
        UserDefaults.standard.set(newId, forKey: appleMusicUserIdKey)
        return newId
    }

    private init() {}

    // MARK: - Authentication

    /// Check the current Apple Music authorization status without prompting
    var currentAuthorizationStatus: MusicAuthorization.Status {
        MusicAuthorization.currentStatus
    }

    /// Check if authorization was previously denied (user needs to go to Settings)
    var isAuthorizationDenied: Bool {
        MusicAuthorization.currentStatus == .denied
    }

    /// Request Apple Music authorization and get user token
    func authenticate() async throws -> AppleMusicAuthResult {
        print("🎵 Requesting Apple Music authorization...")

        // Check current status first
        let currentStatus = MusicAuthorization.currentStatus
        print("🎵 Current authorization status: \(currentStatus)")

        // If previously denied, user must go to Settings - throw specific error
        if currentStatus == .denied {
            print("❌ Apple Music authorization was previously denied. User must enable in Settings.")
            throw AppleMusicError.authorizationPreviouslyDenied
        }

        // Request authorization
        let status = await MusicAuthorization.request()

        print("🎵 Authorization status after request: \(status)")

        guard status == .authorized else {
            print("❌ Apple Music authorization denied. Status: \(status)")
            throw AppleMusicError.authorizationDenied
        }

        print("✅ Apple Music authorized!")

        // Get storefront (country code)
        print("🌍 Fetching storefront...")
        let storefront = try await MusicDataRequest.currentCountryCode
        print("✅ Storefront: \(storefront)")

        // For Apple Music, we use a stable device-based identifier
        // This ensures the same user profile is used across sign-ins
        let userToken = stableUserId

        print("✅ Apple Music auth complete with stable user ID: \(userToken)")
        return AppleMusicAuthResult(
            userToken: userToken,
            storefront: storefront,
            developerToken: Config.appleMusicDeveloperToken
        )
    }

    // MARK: - User Data

    /// Fetch user's recently played tracks with artist IDs
    func getRecentlyPlayed() async throws -> [(track: AppleMusicTrack, artistId: String?)] {
        var results: [(track: AppleMusicTrack, artistId: String?)] = []
        var seenIds = Set<String>()

        // 1. Try MusicRecentlyPlayedRequest first with timeout
        do {
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = 20

            // Add timeout to prevent indefinite hangs
            let response = try await withTimeout(seconds: 10) {
                try await request.response()
            }

            for song in response.items {
                let id = song.id.rawValue
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    let track = AppleMusicTrack(
                        id: id,
                        title: song.title,
                        artistName: song.artistName,
                        artworkURL: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                        previewURL: song.previewAssets?.first?.url?.absoluteString,
                        url: song.url?.absoluteString
                    )
                    results.append((track: track, artistId: song.artists?.first?.id.rawValue))
                }
            }
        } catch {
            // Silently handle errors - don't spam console with entitlement errors
        }

        // 2. Only fetch from Library if we have zero tracks (not just < 20)
        // This avoids unnecessary slow library queries
        if results.isEmpty {
            do {
                var libraryRequest = MusicLibraryRequest<Song>()
                libraryRequest.limit = 20
                libraryRequest.sort(by: \.lastPlayedDate, ascending: false)

                // Add timeout to prevent indefinite hangs
                let libraryResponse = try await withTimeout(seconds: 10) {
                    try await libraryRequest.response()
                }

                for song in libraryResponse.items {
                    let id = song.id.rawValue
                    if !seenIds.contains(id) {
                        seenIds.insert(id)

                        // Only add if it has a valid title (some local files might be weird)
                        if !song.title.isEmpty {
                            let track = AppleMusicTrack(
                                id: id,
                                title: song.title,
                                artistName: song.artistName,
                                artworkURL: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                                previewURL: song.previewAssets?.first?.url?.absoluteString,
                                url: song.url?.absoluteString
                            )
                            results.append((track: track, artistId: song.artists?.first?.id.rawValue))
                        }
                    }

                    if results.count >= 20 { break }
                }
            } catch {
                // Silently handle errors - library access may fail due to entitlements
            }
        }

        return results
    }

    // MARK: - Timeout Helper

    /// Execute an async operation with a timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppleMusicError.apiError("Request timed out")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Fetch user's library playlists
    func getUserPlaylists() async throws -> [AppleMusicPlaylist] {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()

        return response.items.map { playlist in
            AppleMusicPlaylist(
                id: playlist.id.rawValue,
                name: playlist.name,
                artworkURL: playlist.artwork?.url(width: 640, height: 640)?.absoluteString,
                trackCount: nil // MusicKit doesn't expose track count directly
            )
        }
    }

    /// Get user's favorite/added songs from library (different from recently played)
    /// Filters out local files to only show Apple Music catalog tracks
    func getTopSongs(limit: Int = 20) async throws -> [AppleMusicTrack] {
        // Get songs from user's library (their favorites/added songs)
        // This is different from recently played
        var request = MusicLibraryRequest<Song>()
        request.limit = limit * 2 // Request more to account for filtering

        do {
            let response = try await request.response()

            // Filter out local files and convert to tracks
            let catalogTracks = response.items.compactMap { song -> AppleMusicTrack? in
                // Filter out local-only files by checking for catalog indicators
                // Local files typically don't have ISRC codes or valid play parameters
                guard song.playParameters != nil else {
                    print("⚠️ Skipping local file (no play parameters): \(song.title)")
                    return nil
                }

                // Additional check: ensure the song has catalog URL
                // Local files won't have proper Apple Music URLs
                if song.url == nil {
                    print("⚠️ Skipping local file (no catalog URL): \(song.title)")
                    return nil
                }

                return AppleMusicTrack(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName,
                    artworkURL: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                    previewURL: song.previewAssets?.first?.url?.absoluteString,
                    url: song.url?.absoluteString
                )
            }

            // Take only the requested limit after filtering
            let limitedTracks = Array(catalogTracks.prefix(limit))

            if limitedTracks.isEmpty {
                print("⚠️ No catalog songs found in library, falling back to recently played")
                throw AppleMusicError.apiError("No catalog songs in library")
            }

            return limitedTracks
        } catch {
            print("⚠️ Could not fetch library songs, falling back to recently played: \(error)")
            // Fallback to recently played if library access fails
            let recentTracksWithArtists = try await getRecentlyPlayed()
            let tracks = recentTracksWithArtists.map { $0.track }
            return Array(tracks.prefix(limit))
        }
    }

    /// Get top artists from recently played tracks
    func getTopArtists(limit: Int = 10) async throws -> [AppleMusicArtist] {
        // Get recently played tracks with artist IDs
        let recentTracksWithArtists = try await getRecentlyPlayed()

        // Count artist occurrences
        var artistCounts: [String: (name: String, id: String, count: Int)] = [:]

        for item in recentTracksWithArtists {
            let artistName = item.track.artistName
            // Use the proper artist ID from MusicKit, fallback to artist name if not available
            let artistId = item.artistId ?? artistName

            if let existing = artistCounts[artistName] {
                artistCounts[artistName] = (artistName, existing.id, existing.count + 1)
            } else {
                artistCounts[artistName] = (artistName, artistId, 1)
            }
        }

        // Sort by count and take top N
        let topArtists = artistCounts.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { AppleMusicArtist(id: $0.id, name: $0.name) }

        return Array(topArtists)
    }

    /// Get user's storefront
    func getStorefront() async throws -> String {
        return try await MusicDataRequest.currentCountryCode
    }

    /// Search for an artist by name and return their Apple Music ID
    /// Used for cross-platform artist matching (e.g., Spotify -> Apple Music)
    func searchArtistId(artistName: String) async throws -> String? {
        var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [Artist.self])
        searchRequest.limit = 1

        do {
            let searchResponse = try await searchRequest.response()
            return searchResponse.artists.first?.id.rawValue
        } catch {
            return nil
        }
    }

    /// Fetch artist artwork from Apple Music catalog
    func fetchArtistArtwork(artistName: String) async throws -> String? {
        print("🎨 Fetching artwork for artist: \(artistName)")

        var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [Artist.self])
        searchRequest.limit = 5 // Get more results to find best match

        do {
            let searchResponse = try await searchRequest.response()

            // Try to find exact or close match
            for artist in searchResponse.artists {
                print("   Found artist: \(artist.name)")

                // Check for exact or close name match
                let searchLower = artistName.lowercased()
                let artistLower = artist.name.lowercased()

                if artistLower == searchLower ||
                   artistLower.contains(searchLower) ||
                   searchLower.contains(artistLower) {
                    if let artwork = artist.artwork {
                        let url = artwork.url(width: 640, height: 640)?.absoluteString
                        print("   ✅ Found artwork URL: \(url ?? "nil")")
                        return url
                    } else {
                        print("   ⚠️ Artist found but no artwork available")
                    }
                }
            }

            // If no exact match, try first result as fallback
            if let firstArtist = searchResponse.artists.first {
                if let artwork = firstArtist.artwork {
                    let url = artwork.url(width: 640, height: 640)?.absoluteString
                    print("   ✅ Using first result artwork: \(url ?? "nil")")
                    return url
                } else {
                    print("   ⚠️ First artist has no artwork")
                }
            }

            print("   ❌ No artists found for: \(artistName)")
            return nil
        } catch {
            print("   ❌ Error fetching artwork: \(error)")
            return nil
        }
    }

    // MARK: - Catalog Search

    /// Search Apple Music catalog for a track, preferring ISRC for exact matching
    /// Falls back to text search if ISRC is not available or doesn't find a match
    func searchTrack(name: String, artist: String, isrc: String? = nil) async throws -> AppleMusicTrack? {
        // Try ISRC search first if available
        if let isrc = isrc, !isrc.isEmpty {
            if let track = try await searchByISRC(isrc) {
                return track
            }
        }

        // Fall back to text search with validation
        var searchRequest = MusicCatalogSearchRequest(term: "\(name) \(artist)", types: [Song.self])
        searchRequest.limit = 10 // Get more results to find best match

        let searchResponse = try await searchRequest.response()

        // Try to find best match with validation
        for song in searchResponse.songs {
            // Validate: Check if ISRC matches (if we have it)
            if let isrc = isrc, let songISRC = song.isrc {
                if songISRC.uppercased() == isrc.uppercased() {
                    return AppleMusicTrack(
                        id: song.id.rawValue,
                        title: song.title,
                        artistName: song.artistName,
                        artworkURL: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                        previewURL: song.previewAssets?.first?.url?.absoluteString,
                        url: song.url?.absoluteString
                    )
                }
            }

            // Validate: Check if track name matches closely
            let normalizedSearchName = name.lowercased()
                .replacingOccurrences(of: "(feat.", with: "")
                .replacingOccurrences(of: "feat.", with: "")
                .replacingOccurrences(of: "ft.", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let normalizedSongName = song.title.lowercased()
                .replacingOccurrences(of: "(feat.", with: "")
                .replacingOccurrences(of: "feat.", with: "")
                .replacingOccurrences(of: "ft.", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Check if names match (ignoring featuring artists)
            if normalizedSongName.contains(normalizedSearchName) || normalizedSearchName.contains(normalizedSongName) {
                // Validate artist name also matches
                if song.artistName.lowercased().contains(artist.lowercased().split(separator: " ").first?.lowercased() ?? "") {
                    return AppleMusicTrack(
                        id: song.id.rawValue,
                        title: song.title,
                        artistName: song.artistName,
                        artworkURL: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                        previewURL: song.previewAssets?.first?.url?.absoluteString,
                        url: song.url?.absoluteString
                    )
                }
            }
        }

        return nil
    }

    /// Search Apple Music catalog by ISRC code for exact track matching
    /// Note: Apple Music doesn't support ISRC in text search, so we search by name
    /// and then filter by ISRC from the Song metadata
    private func searchByISRC(_ isrc: String) async throws -> AppleMusicTrack? {
        // Apple Music's MusicCatalogSearchRequest doesn't support ISRC as a search term
        // We would need to use the catalog lookup API which requires an Apple Music ID
        // For now, return nil to fall back to text search with validation
        return nil
    }

    /// Fetch an artist's top songs from Apple Music (with fallback search)
    func getArtistTopTracks(artistId: String, artistName: String? = nil, limit: Int = 10) async throws -> [MusicItem] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw AppleMusicError.authorizationDenied
        }

        var resolvedArtistName = artistName
        var songs: [Song] = []

        // Primary: artist lookup with topSongs relationship
        do {
            var artistRequest = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(artistId))
            artistRequest.properties = [.topSongs]
            let response = try await artistRequest.response()

            if let artist = response.items.first {
                resolvedArtistName = resolvedArtistName ?? artist.name
                if let topSongs = artist.topSongs {
                    songs = Array(topSongs.prefix(limit))
                }
            }
        } catch {
            // Silently handle errors and try fallback
        }

        // Fallback: search songs by artist name if needed
        if songs.isEmpty, let name = resolvedArtistName {
            do {
                var searchRequest = MusicCatalogSearchRequest(term: name, types: [Song.self])
                searchRequest.limit = limit * 2
                let searchResponse = try await searchRequest.response()
                let filtered = searchResponse.songs.filter { song in
                    song.artistName.lowercased().contains(name.lowercased())
                }
                songs = Array(filtered.prefix(limit))
            } catch {
                // Silently handle errors
            }
        }

        return songs.map { song in
            MusicItem(
                id: song.id.rawValue,
                name: song.title,
                artistName: song.artistName,
                previewUrl: song.previewAssets?.first?.url?.absoluteString,
                albumArtUrl: song.artwork?.url(width: 640, height: 640)?.absoluteString,
                isrc: song.isrc,
                playedAt: nil,
                spotifyId: nil,
                appleMusicId: song.id.rawValue,
                popularity: nil,
                followerCount: nil
            )
        }
    }


    /// Save a track to the user's Apple Music library
    /// - Parameter trackId: The Apple Music catalog track ID
    func saveTrackToLibrary(trackId: String) async throws {
        print("💾 Saving track \(trackId) to Apple Music library...")

        // Check authorization status
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            print("❌ Apple Music authorization required")
            throw AppleMusicError.authorizationDenied
        }

        // MusicKit still relies on cloud service capabilities for library writes
        let cloudStatus = await requestCloudServiceAuthorization()
        guard cloudStatus == .authorized else {
            print("❌ Apple Music cloud service authorization denied")
            throw AppleMusicError.authorizationDenied
        }

        let capabilities = try await requestCapabilities()
        guard capabilities.contains(.addToCloudMusicLibrary) else {
            print("❌ Missing add-to-library capability")
            throw AppleMusicError.authorizationDenied
        }

        do {
            try await addProductToLibrary(productId: trackId)
            print("✅ Added track to Apple Music library")
        } catch {
            print("❌ Failed to save track to Apple Music library: \(error)")
            throw AppleMusicError.apiError("Failed to add to library: \(error.localizedDescription)")
        }
    }

    private func requestCloudServiceAuthorization() async -> SKCloudServiceAuthorizationStatus {
        await withCheckedContinuation { (continuation: CheckedContinuation<SKCloudServiceAuthorizationStatus, Never>) in
            SKCloudServiceController.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestCapabilities() async throws -> SKCloudServiceCapability {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SKCloudServiceCapability, Error>) in
            let controller = SKCloudServiceController()
            controller.requestCapabilities { capability, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: capability)
                }
            }
        }
    }

    private func addProductToLibrary(productId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            MPMediaLibrary.default().addItem(withProductID: productId) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // MARK: - Convenience Methods for Daily Playlist

    /// Add a track to the user's library
    /// Note: For Apple Music, this will open the track in the Music app where the user can add it
    func addToLibrary(trackId: String) async throws {
        try await saveTrackToLibrary(trackId: trackId)
    }
}

// MARK: - Models

struct AppleMusicAuthResult {
    let userToken: String
    let storefront: String
    let developerToken: String
}

struct AppleMusicTrack: Codable {
    let id: String
    let title: String
    let artistName: String
    let artworkURL: String?
    let previewURL: String?
    let url: String?
}

struct AppleMusicPlaylist: Codable {
    let id: String
    let name: String
    let artworkURL: String?
    let trackCount: Int?
}

struct AppleMusicArtist: Codable {
    let id: String
    let name: String
}

// MARK: - Errors

enum AppleMusicError: LocalizedError {
    case authorizationDenied
    case authorizationPreviouslyDenied
    case noUserToken
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Apple Music authorization was denied"
        case .authorizationPreviouslyDenied:
            return "Apple Music access was previously denied. Please enable it in Settings."
        case .noUserToken:
            return "Could not retrieve Apple Music user token"
        case .apiError(let message):
            return "Apple Music API error: \(message)"
        }
    }

    /// Whether this error requires the user to go to Settings to fix
    var requiresSettingsRedirect: Bool {
        switch self {
        case .authorizationPreviouslyDenied:
            return true
        default:
            return false
        }
    }
}
