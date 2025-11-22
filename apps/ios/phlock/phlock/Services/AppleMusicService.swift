import Foundation
import MusicKit
import UIKit

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

    /// Request Apple Music authorization and get user token
    func authenticate() async throws -> AppleMusicAuthResult {
        print("🎵 Requesting Apple Music authorization...")

        // Request authorization
        let status = await MusicAuthorization.request()

        print("🎵 Authorization status: \(status)")

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
        print("🎵 Fetching recently played tracks from Apple Music...")
        var request = MusicRecentlyPlayedRequest<Song>()
        request.limit = 20
        let response = try await request.response()

        print("📀 Apple Music returned \(response.items.count) recently played tracks:")

        let results = response.items.compactMap { song in
            print("   🎧 '\(song.title)' by \(song.artistName)")

            let track = AppleMusicTrack(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                previewURL: song.previewAssets?.first?.url?.absoluteString
            )
            // Extract artist ID from the first artist
            let artistId = song.artists?.first?.id.rawValue

            if let artistId = artistId {
                print("      ✅ Artist ID: \(artistId)")
            } else {
                print("      ⚠️ No artist ID available")
            }

            return (track: track, artistId: artistId)
        }

        print("✅ Processed \(results.count) tracks from Apple Music")
        return results
    }

    /// Fetch user's library playlists
    func getUserPlaylists() async throws -> [AppleMusicPlaylist] {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()

        return response.items.map { playlist in
            AppleMusicPlaylist(
                id: playlist.id.rawValue,
                name: playlist.name,
                artworkURL: playlist.artwork?.url(width: 300, height: 300)?.absoluteString,
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
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                    previewURL: song.previewAssets?.first?.url?.absoluteString
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
        print("🎵 Getting top artists from recently played tracks...")

        // Get recently played tracks with artist IDs
        let recentTracksWithArtists = try await getRecentlyPlayed()

        print("📊 Using all \(recentTracksWithArtists.count) recently played tracks")

        // Count artist occurrences
        var artistCounts: [String: (name: String, id: String, count: Int)] = [:]

        for item in recentTracksWithArtists {
            let artistName = item.track.artistName
            // Use the proper artist ID from MusicKit, fallback to artist name if not available
            let artistId = item.artistId ?? artistName

            if let existing = artistCounts[artistName] {
                artistCounts[artistName] = (artistName, existing.id, existing.count + 1)
                print("🔁 Artist '\(artistName)' count: \(existing.count + 1)")
            } else {
                artistCounts[artistName] = (artistName, artistId, 1)
                print("➕ New artist: '\(artistName)' (ID: \(artistId))")
            }
        }

        print("📈 Total unique artists: \(artistCounts.count)")

        // Sort by count and take top N
        let topArtists = artistCounts.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { AppleMusicArtist(id: $0.id, name: $0.name) }

        print("🏆 Top \(topArtists.count) artists:")
        for (index, artist) in topArtists.enumerated() {
            let count = artistCounts.values.first(where: { $0.name == artist.name })?.count ?? 0
            print("   \(index + 1). \(artist.name) - \(count) plays")
        }

        return Array(topArtists)
    }

    /// Get user's storefront
    func getStorefront() async throws -> String {
        return try await MusicDataRequest.currentCountryCode
    }

    /// Search for an artist by name and return their Apple Music ID
    /// Used for cross-platform artist matching (e.g., Spotify -> Apple Music)
    func searchArtistId(artistName: String) async throws -> String? {
        print("🔍 Searching for Apple Music artist ID: \(artistName)")

        var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [Artist.self])
        searchRequest.limit = 1

        do {
            let searchResponse = try await searchRequest.response()

            if let artist = searchResponse.artists.first {
                let artistId = artist.id.rawValue
                print("✅ Found Apple Music ID for '\(artistName)': \(artistId)")
                return artistId
            } else {
                print("⚠️ No Apple Music artist found for: \(artistName)")
                return nil
            }
        } catch {
            print("❌ Error searching for artist: \(error)")
            return nil
        }
    }

    /// Fetch artist artwork from Apple Music catalog
    func fetchArtistArtwork(artistName: String) async throws -> String? {
        print("🔍 Searching for artist artwork: \(artistName)")

        var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [Artist.self])
        searchRequest.limit = 1

        do {
            let searchResponse = try await searchRequest.response()

            if let artist = searchResponse.artists.first {
                let artworkURL = artist.artwork?.url(width: 300, height: 300)?.absoluteString
                print("✅ Found artist artwork for \(artistName)")
                return artworkURL
            } else {
                print("⚠️ No artist found for \(artistName)")
                return nil
            }
        } catch {
            print("❌ Error searching for artist: \(error)")
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

        do {
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
                            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                            previewURL: song.previewAssets?.first?.url?.absoluteString
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
                            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                            previewURL: song.previewAssets?.first?.url?.absoluteString
                        )
                    }
                }
            }

            return nil
        } catch {
            print("❌ Apple Music search failed: \(error)")
            throw error
        }
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

        // Convert string ID to MusicItemID
        let musicItemId = MusicItemID(trackId)

        // Create a library request to add the song
        do {
            // Note: MusicKit doesn't provide a direct "add" method
            // We need to use the Song ID and add it to the library
            // This requires creating a MusicLibraryRequest with the edit capability

            // Create the song reference from catalog ID
            let catalogRequest = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemId)
            let catalogResponse = try await catalogRequest.response()

            guard let song = catalogResponse.items.first else {
                print("❌ Could not find song in Apple Music catalog")
                throw AppleMusicError.apiError("Song not found in catalog")
            }

            // Add to library using play parameters
            // Note: MusicKit's library management is limited
            // The primary way to add songs is through the Music app UI
            // or using MusicPlayer to play and add
            print("⚠️ Apple Music library addition requires user interaction")
            print("   Opening song in Apple Music app for user to add...")

            // Open the song in Apple Music app where user can add it
            if let url = song.url {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }

            print("✅ Opened track in Apple Music for adding to library")
        } catch {
            print("❌ Failed to save track to Apple Music library: \(error)")
            throw AppleMusicError.apiError("Failed to add to library: \(error.localizedDescription)")
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
    case noUserToken
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Apple Music authorization was denied"
        case .noUserToken:
            return "Could not retrieve Apple Music user token"
        case .apiError(let message):
            return "Apple Music API error: \(message)"
        }
    }
}
