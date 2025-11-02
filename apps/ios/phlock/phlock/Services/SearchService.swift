import Foundation
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

    /// Search for music based on user's authenticated platform
    func search(query: String, type: SearchType = .all, platformType: PlatformType) async throws -> SearchResult {
        guard !query.isEmpty else {
            return SearchResult(tracks: [], artists: [])
        }

        switch platformType {
        case .spotify:
            return try await searchSpotify(query: query, type: type)
        case .appleMusic:
            return try await searchAppleMusic(query: query, type: type)
        }
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
                // We want the medium one for better performance
                let url = track.album.images.count > 1 ? track.album.images[1].url : track.album.images.first?.url
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
            // Get medium-sized image or fallback to first available
            let artistImageUrl: String? = {
                guard !artist.images.isEmpty else { return nil }
                // Artists also typically have multiple image sizes
                if artist.images.count > 1 {
                    return artist.images[1].url
                } else {
                    return artist.images.first?.url
                }
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
        var tracks: [MusicItem] = []
        let artists: [MusicItem] = []

        // Use existing AppleMusicService search capabilities
        if type == .all || type == .tracks {
            // Search by track name (use existing search logic)
            if let trackResult = try? await appleMusicService.searchTrack(name: query, artist: "", isrc: nil) {
                // Convert AppleMusicTrack to MusicItem
                let musicItem = MusicItem(
                    id: trackResult.id,
                    name: trackResult.title,
                    artistName: trackResult.artistName,
                    previewUrl: trackResult.previewURL,
                    albumArtUrl: trackResult.artworkURL,
                    isrc: nil,
                    playedAt: nil,
                    spotifyId: nil,
                    appleMusicId: trackResult.id
                )
                tracks = [musicItem]
            }
        }

        // For artists, we'll need to add artist search to AppleMusicService
        // For now, return empty artists array

        return SearchResult(tracks: tracks, artists: artists)
    }

    // MARK: - Artist Top Tracks

    /// Fetch top tracks for a specific artist
    func getArtistTopTracks(artistId: String, platformType: PlatformType) async throws -> [MusicItem] {
        switch platformType {
        case .spotify:
            return try await getSpotifyArtistTopTracks(artistId: artistId)
        case .appleMusic:
            // Apple Music doesn't have a direct "top tracks" API yet
            return []
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
                // We want the medium one for better performance
                let url = track.album.images.count > 1 ? track.album.images[1].url : track.album.images.first?.url
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
