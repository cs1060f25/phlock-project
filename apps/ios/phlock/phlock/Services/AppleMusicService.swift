import Foundation
import MusicKit

/// Service for Apple Music authentication and API interactions
class AppleMusicService {
    static let shared = AppleMusicService()

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

        // For Apple Music, we use a combination of authorization status + developer token
        // The "user token" is effectively the authorization grant
        let userToken = "apple-music-authorized-\(UUID().uuidString)"

        print("✅ Apple Music auth complete!")
        return AppleMusicAuthResult(
            userToken: userToken,
            storefront: storefront,
            developerToken: Config.appleMusicDeveloperToken
        )
    }

    // MARK: - User Data

    /// Fetch user's recently played tracks
    func getRecentlyPlayed() async throws -> [AppleMusicTrack] {
        var request = MusicRecentlyPlayedRequest<Song>()
        request.limit = 20
        let response = try await request.response()

        return response.items.compactMap { song in
            AppleMusicTrack(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString
            )
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
                artworkURL: playlist.artwork?.url(width: 300, height: 300)?.absoluteString,
                trackCount: nil // MusicKit doesn't expose track count directly
            )
        }
    }

    /// Search for top songs (approximation of "top tracks")
    func getTopSongs(limit: Int = 20) async throws -> [AppleMusicTrack] {
        // MusicKit doesn't have a direct "top tracks" endpoint
        // We'll use recently played as a proxy
        let recentTracks = try await getRecentlyPlayed()
        return Array(recentTracks.prefix(limit))
    }

    /// Get user's storefront
    func getStorefront() async throws -> String {
        return try await MusicDataRequest.currentCountryCode
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
}

struct AppleMusicPlaylist: Codable {
    let id: String
    let name: String
    let artworkURL: String?
    let trackCount: Int?
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
