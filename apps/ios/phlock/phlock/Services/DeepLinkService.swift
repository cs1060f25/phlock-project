import Foundation
import UIKit
import Supabase

/// Service for handling deep links to external music apps
class DeepLinkService {
    static let shared = DeepLinkService()
    
    private init() {}
    
    /// Open a track in the user's native music app
    func openInNativeApp(track: MusicItem, platform: PlatformType) {
        print("🔗 Opening track in native app - Platform: \(platform)")
        print("   Track: \(track.name) by \(track.artistName ?? "Unknown")")
        
        Task {
            do {
                switch platform {
                case .spotify:
                    try await openInSpotify(track: track)
                case .appleMusic:
                    try await openInAppleMusic(track: track)
                }
            } catch {
                print("   ❌ Failed to open track: \(error)")
            }
        }
    }
    
    // MARK: - Spotify
    
    private func openInSpotify(track: MusicItem) async throws {
        print("🎵 Opening track in Spotify: '\(track.name)' by \(track.artistName ?? "Unknown")")
        print("   Track ID: \(track.id)")
        print("   Spotify ID: \(track.spotifyId ?? "nil")")
        
        // ALWAYS validate track ID to ensure we open the correct track
        let spotifyId: String
        
        // Validate the track ID using the validate-track edge function
        print("   🔍 Validating track ID with Spotify API...")
        print("   ISRC: \(track.isrc ?? "none")")
        let validatedTrack = try await validateTrack(
            name: track.name,
            artist: track.artistName ?? "Unknown",
            existingId: track.spotifyId,
            isrc: track.isrc
        )
        
        if let validated = validatedTrack {
            spotifyId = validated
            print("   ✅ Using validated Spotify ID: \(spotifyId)")
        } else {
            // Fallback: Search for the track
            print("   🔍 Validation failed, searching: \(track.name) - \(track.artistName ?? "")")
            
            let results = try await SearchService.shared.search(
                query: "\(track.name) \(track.artistName ?? "")",
                type: .tracks,
                platformType: .spotify
            )
            
            guard !results.tracks.isEmpty else {
                print("   ❌ No results found on Spotify")
                return
            }
            
            // Smart matching: find best match by comparing track name and artist
            guard let foundTrack = findBestMatch(
                searchResults: results.tracks,
                targetTrackName: track.name,
                targetArtistName: track.artistName
            ) else {
                print("   ❌ Could not find matching track on Spotify")
                print("   📊 Search returned \(results.tracks.count) results but none matched")
                return
            }
            
            spotifyId = foundTrack.spotifyId ?? foundTrack.id
            print("   ✅ Found match: \(foundTrack.name) (ID: \(spotifyId))")
        }
        
        let spotifyURL = URL(string: "spotify:track:\(spotifyId)")
        let webURL = URL(string: "https://open.spotify.com/track/\(spotifyId)")
        
        await MainActor.run {
            if let spotifyURL = spotifyURL, UIApplication.shared.canOpenURL(spotifyURL) {
                print("   ✅ Opening in Spotify app")
                UIApplication.shared.open(spotifyURL)
            } else if let webURL = webURL {
                print("   ✅ Opening in Spotify web player")
                UIApplication.shared.open(webURL)
            }
        }
    }
    
    // MARK: - Apple Music
    
    private func openInAppleMusic(track: MusicItem) async throws {
        // Search for the track to get the correct Apple Music ID
        print("   🔍 Searching Apple Music for: \(track.name) - \(track.artistName ?? "")")
        
        guard let artistName = track.artistName else {
            print("   ❌ No artist name available")
            return
        }
        
        guard let foundTrack = try await AppleMusicService.shared.searchTrack(
            name: track.name,
            artist: artistName,
            isrc: track.isrc
        ) else {
            print("   ❌ Could not find track on Apple Music")
            return
        }
        
        // Use the direct URL if available (best for deep linking)
        if let urlString = foundTrack.url, let url = URL(string: urlString) {
            print("   ✅ Found Apple Music URL: \(urlString)")
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            return
        }
        
        // Fallback to constructing URL manually
        let appleMusicId = foundTrack.id
        let appleMusicURL = URL(string: "music://music.apple.com/song/\(appleMusicId)")
        let webURL = URL(string: "https://music.apple.com/song/\(appleMusicId)")
        
        print("   ✅ Found on Apple Music: \(foundTrack.title) (ID: \(appleMusicId))")
        
        await MainActor.run {
            if let appleMusicURL = appleMusicURL, UIApplication.shared.canOpenURL(appleMusicURL) {
                print("   ✅ Opening in Apple Music app")
                UIApplication.shared.open(appleMusicURL)
            } else if let webURL = webURL {
                print("   ✅ Opening in Apple Music web player")
                UIApplication.shared.open(webURL)
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Validate track ID using the validate-track edge function
    private func validateTrack(name: String, artist: String, existingId: String?, isrc: String?) async throws -> String? {
        struct ValidationRequest: Encodable {
            let trackId: String?
            let trackName: String
            let artistName: String
            let isrc: String?  // For exact version matching
        }
        
        struct ValidationResponse: Decodable {
            let success: Bool
            let method: String?
            let track: ValidatedTrack?
            
            struct ValidatedTrack: Decodable {
                let id: String
                let name: String
                let artistName: String
            }
        }
        
        do {
            let request = ValidationRequest(
                trackId: existingId,
                trackName: name,
                artistName: artist,
                isrc: isrc
            )
            
            let response: ValidationResponse = try await PhlockSupabaseClient.shared.client.functions.invoke(
                "validate-track",
                options: FunctionInvokeOptions(body: request)
            )
            
            if response.success, let track = response.track {
                print("   ✅ Track validated via \(response.method ?? "unknown"): \(track.id)")
                return track.id
            }
            
            return nil
        } catch {
            print("   ⚠️ Track validation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func findBestMatch(
        searchResults: [MusicItem],
        targetTrackName: String,
        targetArtistName: String?
    ) -> MusicItem? {
        let normalizedTargetTrack = targetTrackName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTargetArtist = targetArtistName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("   🎯 Matching against: '\(normalizedTargetTrack)' by '\(normalizedTargetArtist ?? "Unknown")'")
        
        // Score each result
        var scoredResults: [(track: MusicItem, score: Int)] = []
        
        for result in searchResults {
            let normalizedResultTrack = result.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedResultArtist = result.artistName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            var score = 0
            
            // Track name matching (most important)
            if normalizedResultTrack == normalizedTargetTrack {
                score += 100 // Exact match
            } else if normalizedResultTrack.contains(normalizedTargetTrack) || normalizedTargetTrack.contains(normalizedResultTrack) {
                score += 50 // Partial match (handles "feat.", remixes, etc.)
            } else {
                continue // Skip if track name doesn't match at all
            }
            
            // Artist name matching
            if let targetArtist = normalizedTargetArtist, let resultArtist = normalizedResultArtist {
                if resultArtist == targetArtist {
                    score += 100 // Exact artist match
                } else if resultArtist.contains(targetArtist) || targetArtist.contains(resultArtist) {
                    score += 50 // Partial artist match (handles "feat.", "& The Band", etc.)
                } else {
                    score += 10 // Artist doesn't match but track does (could be cover)
                }
            } else {
                score += 20 // No artist to compare
            }
            
            // Popularity bonus (prefer more popular versions)
            if let popularity = result.popularity {
                score += popularity / 10 // Up to 10 points for popularity
            }
            
            scoredResults.append((track: result, score: score))
            print("      - '\(result.name)' by '\(result.artistName ?? "Unknown")': score \(score)")
        }
        
        // Sort by score descending and return best match
        let bestMatch = scoredResults.sorted { $0.score > $1.score }.first
        
        if let best = bestMatch {
            print("   🏆 Best match: '\(best.track.name)' by '\(best.track.artistName ?? "Unknown")' (score: \(best.score))")
        }
        
        return bestMatch?.track
    }
}
