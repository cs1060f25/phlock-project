import Foundation

/// Helper for cross-platform music service operations
/// Eliminates code duplication across services
@available(iOS 13.0, *)
struct CrossPlatformHelper {

    /// Artist data structure for cross-platform operations
    struct CrossPlatformArtist {
        let id: String
        let name: String
        let imageUrl: String?
        let crossPlatformId: String?
    }

    /// Fetch cross-platform IDs for a list of artists
    /// This replaces duplicated TaskGroup pattern found in multiple services
    /// - Parameters:
    ///   - artists: Array of artists to process
    ///   - platformType: Source platform (Spotify or Apple Music)
    ///   - fetchCrossPlatformId: Async function to fetch the cross-platform ID
    /// - Returns: Array of artists with cross-platform IDs populated
    static func fetchCrossPlatformArtistIds<T>(
        artists: [T],
        platformType: PlatformType,
        getId: @escaping (T) -> String,
        getName: @escaping (T) -> String,
        getImageUrl: @escaping (T) -> String?,
        fetchCrossPlatformId: @escaping (String) async throws -> String?
    ) async -> [CrossPlatformArtist] {

        await withTaskGroup(of: CrossPlatformArtist.self) { group in
            for artist in artists {
                group.addTask {
                    let crossPlatformId = try? await fetchCrossPlatformId(getName(artist))
                    return CrossPlatformArtist(
                        id: getId(artist),
                        name: getName(artist),
                        imageUrl: getImageUrl(artist),
                        crossPlatformId: crossPlatformId
                    )
                }
            }

            var results: [CrossPlatformArtist] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    /// Simplified version for Spotify artists fetching Apple Music IDs
    static func enrichSpotifyArtistsWithAppleMusicIds(
        _ artists: [(id: String, name: String, imageUrl: String?)]
    ) async -> [CrossPlatformArtist] {
        await fetchCrossPlatformArtistIds(
            artists: artists,
            platformType: .spotify,
            getId: { $0.id },
            getName: { $0.name },
            getImageUrl: { $0.imageUrl },
            fetchCrossPlatformId: { artistName in
                try? await AppleMusicService.shared.searchArtistId(artistName: artistName)
            }
        )
    }

    /// Simplified version for Apple Music artists fetching Spotify IDs
    static func enrichAppleMusicArtistsWithSpotifyIds(
        _ artists: [(id: String, name: String, imageUrl: String?)]
    ) async -> [CrossPlatformArtist] {
        await fetchCrossPlatformArtistIds(
            artists: artists,
            platformType: .appleMusic,
            getId: { $0.id },
            getName: { $0.name },
            getImageUrl: { $0.imageUrl },
            fetchCrossPlatformId: { artistName in
                // Note: This would need SpotifyService.searchArtistId implementation
                // For now, returning nil as placeholder
                return nil
            }
        )
    }
}