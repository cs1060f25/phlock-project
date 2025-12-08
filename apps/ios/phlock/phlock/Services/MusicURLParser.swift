//
//  MusicURLParser.swift
//  phlock
//
//  Parses Spotify and Apple Music URLs to extract track IDs
//

import Foundation

struct MusicURLParser {

    enum MusicPlatform {
        case spotify
        case appleMusic
    }

    struct ParsedTrack {
        let platform: MusicPlatform
        let trackId: String
        let originalURL: String
    }

    /// Attempts to parse a string as a music URL and extract track information
    /// - Parameter urlString: The string to parse (may be a URL or URI)
    /// - Returns: ParsedTrack if valid music URL, nil otherwise
    static func parse(_ urlString: String) -> ParsedTrack? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try Spotify first
        if let spotifyTrack = parseSpotify(trimmed) {
            return spotifyTrack
        }

        // Try Apple Music
        if let appleMusicTrack = parseAppleMusic(trimmed) {
            return appleMusicTrack
        }

        return nil
    }

    /// Quick check if a string might be a music URL (for early filtering)
    static func mightBeMusicURL(_ string: String) -> Bool {
        let lowercased = string.lowercased()
        return lowercased.contains("spotify.com/track") ||
               lowercased.contains("spotify:track:") ||
               lowercased.contains("music.apple.com") ||
               lowercased.contains("itunes.apple.com")
    }

    // MARK: - Spotify Parsing

    private static func parseSpotify(_ urlString: String) -> ParsedTrack? {
        // Handle Spotify URI format: spotify:track:6rqhFgbbKwnb9MLmUQDhG6
        if urlString.hasPrefix("spotify:track:") {
            let trackId = String(urlString.dropFirst("spotify:track:".count))
            if isValidSpotifyId(trackId) {
                return ParsedTrack(platform: .spotify, trackId: trackId, originalURL: urlString)
            }
        }

        // Handle Spotify web URL: https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6?si=...
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              host.contains("spotify.com") else {
            return nil
        }

        let pathComponents = url.pathComponents

        // Look for /track/{id} pattern
        if let trackIndex = pathComponents.firstIndex(of: "track"),
           trackIndex + 1 < pathComponents.count {
            let trackId = pathComponents[trackIndex + 1]
            if isValidSpotifyId(trackId) {
                return ParsedTrack(platform: .spotify, trackId: trackId, originalURL: urlString)
            }
        }

        // Handle intl-* subdomains: https://open.spotify.com/intl-de/track/...
        // The path would be: ["", "intl-de", "track", "{id}"]
        for (index, component) in pathComponents.enumerated() {
            if component == "track" && index + 1 < pathComponents.count {
                let trackId = pathComponents[index + 1]
                if isValidSpotifyId(trackId) {
                    return ParsedTrack(platform: .spotify, trackId: trackId, originalURL: urlString)
                }
            }
        }

        return nil
    }

    private static func isValidSpotifyId(_ id: String) -> Bool {
        // Spotify IDs are 22 characters, base62 encoded
        // Allow some flexibility in case format changes
        let cleaned = id.components(separatedBy: "?").first ?? id
        return cleaned.count >= 20 && cleaned.count <= 25 && cleaned.allSatisfy { $0.isLetter || $0.isNumber }
    }

    // MARK: - Apple Music Parsing

    private static func parseAppleMusic(_ urlString: String) -> ParsedTrack? {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              (host.contains("music.apple.com") || host.contains("itunes.apple.com")) else {
            return nil
        }

        // Apple Music URLs have various formats:
        // https://music.apple.com/us/album/song-name/1234567890?i=1234567891
        // https://music.apple.com/us/song/song-name/1234567891
        // https://music.apple.com/song/1234567891

        // Check for ?i= parameter (song within album)
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let songId = queryItems.first(where: { $0.name == "i" })?.value,
           isValidAppleMusicId(songId) {
            return ParsedTrack(platform: .appleMusic, trackId: songId, originalURL: urlString)
        }

        let pathComponents = url.pathComponents

        // Look for /song/{name}/{id} or /song/{id} pattern
        if let songIndex = pathComponents.firstIndex(of: "song") {
            // The ID is the last numeric component after "song"
            for i in stride(from: pathComponents.count - 1, through: songIndex + 1, by: -1) {
                let component = pathComponents[i]
                if isValidAppleMusicId(component) {
                    return ParsedTrack(platform: .appleMusic, trackId: component, originalURL: urlString)
                }
            }
        }

        return nil
    }

    private static func isValidAppleMusicId(_ id: String) -> Bool {
        // Apple Music IDs are numeric, typically 9-12 digits
        let cleaned = id.components(separatedBy: "?").first ?? id
        return cleaned.count >= 8 && cleaned.count <= 15 && cleaned.allSatisfy { $0.isNumber }
    }
}
