import Foundation
import AuthenticationServices
import Supabase

/// Service for Spotify OAuth and API interactions
class SpotifyService: NSObject {
    static let shared = SpotifyService()

    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String?

    private override init() {
        super.init()
    }

    // MARK: - OAuth Authentication

    /// Initiate Spotify OAuth flow with PKCE
    func authenticate() async throws -> SpotifyAuthResult {
        // Generate PKCE code verifier and challenge
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        self.codeVerifier = verifier

        // Build authorization URL
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.spotifyClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Config.spotifyRedirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: Config.spotifyScopes.joined(separator: " "))
        ]

        guard let authURL = components.url else {
            throw SpotifyError.invalidURL
        }

        // Start auth session
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "phlock-spotify"
            ) { callbackURL, error in
                if let error = error {
                    print("❌ Spotify auth cancelled: \(error.localizedDescription)")
                    continuation.resume(throwing: SpotifyError.authCancelled)
                    return
                }

                guard let callbackURL = callbackURL else {
                    print("❌ No callback URL received")
                    continuation.resume(throwing: SpotifyError.noAuthCode)
                    return
                }

                print("✅ Callback URL: \(callbackURL)")

                guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    print("❌ Failed to extract code from callback")
                    continuation.resume(throwing: SpotifyError.noAuthCode)
                    return
                }

                print("✅ Got auth code: \(code.prefix(20))...")

                // Exchange code for token
                Task {
                    do {
                        let result = try await self.exchangeCodeForToken(code: code, verifier: verifier)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()

            self.authSession = session
        }
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(code: String, verifier: String) async throws -> SpotifyAuthResult {
        print("🔄 Exchanging code for token...")
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Config.spotifyRedirectURI,
            "client_id": Config.spotifyClientId,
            "code_verifier": verifier
        ]

        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ Token exchange failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0), Body: \(responseBody)")
            throw SpotifyError.tokenExchangeFailed
        }

        print("✅ Token exchange successful!")

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        return SpotifyAuthResult(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn,
            scope: tokenResponse.scope
        )
    }

    // MARK: - Token Refresh

    /// Refresh an expired access token using the refresh token
    func refreshAccessToken(refreshToken: String) async throws -> SpotifyAuthResult {
        print("🔄 Refreshing Spotify access token...")
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Config.spotifyClientId
        ]

        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ Token refresh failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0), Body: \(responseBody)")
            throw SpotifyError.tokenExchangeFailed
        }

        print("✅ Token refresh successful!")

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        return SpotifyAuthResult(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken, // Spotify may not return a new refresh token
            expiresIn: tokenResponse.expiresIn,
            scope: tokenResponse.scope
        )
    }

    // MARK: - API Calls

    /// Fetch current user's Spotify profile
    func getUserProfile(accessToken: String) async throws -> SpotifyUserProfile {
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
    }

    /// Fetch user's top tracks
    func getTopTracks(accessToken: String, limit: Int = 20) async throws -> SpotifyTopTracksResponse {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/top/tracks")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "time_range", value: "medium_term"),
            URLQueryItem(name: "market", value: "from_token") // Use user's market for preview availability
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15 // 15 second timeout

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyTopTracksResponse.self, from: data)
    }

    /// Fetch user's top artists
    func getTopArtists(accessToken: String, limit: Int = 20) async throws -> SpotifyTopArtistsResponse {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/top/artists")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "time_range", value: "short_term") // Last 4 weeks
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15 // 15 second timeout

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyTopArtistsResponse.self, from: data)
    }

    /// Fetch user's playlists
    func getUserPlaylists(accessToken: String) async throws -> SpotifyPlaylistsResponse {
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15 // 15 second timeout

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
    }

    func getRecentlyPlayed(accessToken: String, limit: Int = 50) async throws -> SpotifyRecentlyPlayedResponse {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/player/recently-played")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"), // Get up to 50 tracks from Spotify
            URLQueryItem(name: "market", value: "from_token") // Use user's market for preview availability
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15 // 15 second timeout

        // Add cache-busting headers to ensure fresh data
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse else {
            throw SpotifyError.networkError
        }

        // Handle authentication errors
        if response.statusCode == 401 {
            throw SpotifyError.tokenExpired
        }

        if response.statusCode != 200 {
            throw SpotifyError.apiStatusError(response.statusCode)
        }

        return try JSONDecoder().decode(SpotifyRecentlyPlayedResponse.self, from: data)
    }

    /// Search for an artist by name and return their Spotify ID
    /// Used for cross-platform artist matching (e.g., Apple Music -> Spotify)
    func searchArtist(name: String, accessToken: String) async throws -> String? {
        let searchQuery = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let searchURL = "https://api.spotify.com/v1/search?q=\(searchQuery)&type=artist&limit=1"

        guard let url = URL(string: searchURL) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse JSON to get first artist's ID
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let artists = json["artists"] as? [String: Any],
           let items = artists["items"] as? [[String: Any]],
           let firstArtist = items.first,
           let spotifyId = firstArtist["id"] as? String {
            print("✅ Found Spotify ID for '\(name)': \(spotifyId)")
            return spotifyId
        }

        print("⚠️ No Spotify artist found for: \(name)")
        return nil
    }

    /// Save a track to the user's Spotify library
    /// - Parameters:
    ///   - trackId: The Spotify track ID
    ///   - accessToken: User's Spotify access token
    func saveTrackToLibrary(trackId: String, accessToken: String) async throws {
        print("💾 Saving track \(trackId) to Spotify library...")

        guard let url = URL(string: "https://api.spotify.com/v1/me/tracks") else {
            throw SpotifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Body: array of track IDs
        let body = ["ids": [trackId]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            print("✅ Track saved to Spotify library")
        } else if httpResponse.statusCode == 401 {
            throw SpotifyError.apiError("Unauthorized - token may be expired")
        } else if httpResponse.statusCode == 403 {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.lowercased().contains("insufficient") || body.lowercased().contains("scope") {
                throw SpotifyError.apiError("Missing permission to save tracks. Please relink Spotify to grant library access.")
            }
            throw SpotifyError.apiError("Forbidden - check Spotify scopes/permissions")
        } else {
            throw SpotifyError.apiError("Failed to save track (status: \(httpResponse.statusCode))")
        }
    }

    /// Remove a track from the user's Spotify library
    /// - Parameters:
    ///   - trackId: The Spotify track ID
    ///   - accessToken: User's Spotify access token
    func removeTrackFromLibrary(trackId: String, accessToken: String) async throws {
        print("🗑️ Removing track \(trackId) from Spotify library...")

        guard let url = URL(string: "https://api.spotify.com/v1/me/tracks") else {
            throw SpotifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Body: array of track IDs
        let body = ["ids": [trackId]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            print("✅ Track removed from Spotify library")
        } else if httpResponse.statusCode == 401 {
            throw SpotifyError.apiError("Unauthorized - token may be expired")
        } else {
            throw SpotifyError.apiError("Failed to remove track (status: \(httpResponse.statusCode))")
        }
    }

    /// Check if a track is saved in the user's Spotify library
    /// - Parameters:
    ///   - trackId: The Spotify track ID
    ///   - accessToken: User's Spotify access token
    /// - Returns: True if the track is saved, false otherwise
    func isTrackSaved(trackId: String, accessToken: String) async throws -> Bool {
        guard let url = URL(string: "https://api.spotify.com/v1/me/tracks/contains?ids=\(trackId)") else {
            throw SpotifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            // Parse response as array of booleans
            if let results = try? JSONDecoder().decode([Bool].self, from: data), let isSaved = results.first {
                print("✅ Track saved status: \(isSaved)")
                return isSaved
            }
        } else if httpResponse.statusCode == 401 {
            throw SpotifyError.apiError("Unauthorized - token may be expired")
        }

        return false
    }

    /// Check if multiple tracks are saved in the user's Spotify library (batch check)
    /// - Parameters:
    ///   - trackIds: Array of Spotify track IDs (max 50)
    ///   - accessToken: User's Spotify access token
    /// - Returns: Dictionary mapping track ID to saved status
    func areTracksSaved(trackIds: [String], accessToken: String) async throws -> [String: Bool] {
        guard !trackIds.isEmpty else { return [:] }

        // Spotify API supports up to 50 IDs at once
        let limitedIds = Array(trackIds.prefix(50))
        let idsString = limitedIds.joined(separator: ",")

        guard let url = URL(string: "https://api.spotify.com/v1/me/tracks/contains?ids=\(idsString)") else {
            throw SpotifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let results = try? JSONDecoder().decode([Bool].self, from: data) {
                var resultDict: [String: Bool] = [:]
                for (index, trackId) in limitedIds.enumerated() where index < results.count {
                    resultDict[trackId] = results[index]
                }
                return resultDict
            }
        } else if httpResponse.statusCode == 401 {
            throw SpotifyError.apiError("Unauthorized - token may be expired")
        }

        return [:]
    }

    // MARK: - Convenience Methods for Daily Playlist

    /// Add a track to the user's library
    /// Note: This requires the access token to be provided by the caller
    /// The caller should retrieve the token from the platform_tokens table
    func addToLibrary(trackId: String) async throws {
        // Get the current user's token from the database
        let supabase = PhlockSupabaseClient.shared.client

        // Get current user ID from Auth
        guard let userId = supabase.auth.currentUser?.id else {
            throw SpotifyError.apiError("No authenticated user")
        }

        // Get the platform token from database
        let tokens: [PlatformToken] = try await supabase
            .from("platform_tokens")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("platform_type", value: "spotify")
            .execute()
            .value

        guard let token = tokens.first else {
            throw SpotifyError.apiError("No Spotify token found for user")
        }

        try await saveTrackToLibrary(trackId: trackId, accessToken: token.accessToken)
    }

    // MARK: - PKCE Helper Methods

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the first connected window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        // Fallback to deprecated initializer if no window scene available
        return ASPresentationAnchor()
    }
}

// MARK: - Models

struct SpotifyAuthResult {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: String
}

struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct SpotifyUserProfile: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let country: String?
    let product: String?
    let images: [SpotifyImage]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email, country, product, images
    }
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyTopTracksResponse: Codable {
    let items: [SpotifyTrack]
}

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let previewUrl: String?
    let externalIds: SpotifyExternalIds?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
        case previewUrl = "preview_url"
        case externalIds = "external_ids"
    }
}

struct SpotifyExternalIds: Codable {
    let isrc: String?
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
}

struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyTopArtistsResponse: Codable {
    let items: [SpotifyArtistFull]
}

struct SpotifyArtistFull: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let genres: [String]?
}

struct SpotifyPlaylistsResponse: Codable {
    let items: [SpotifyPlaylist]
}

struct SpotifyPlaylist: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let tracks: SpotifyPlaylistTracks

    struct SpotifyPlaylistTracks: Codable {
        let total: Int
    }
}

struct SpotifyRecentlyPlayedResponse: Codable {
    let items: [SpotifyPlayHistoryItem]

    struct SpotifyPlayHistoryItem: Codable {
        let track: SpotifyTrack
        let playedAt: String // ISO 8601 timestamp

        enum CodingKeys: String, CodingKey {
            case track
            case playedAt = "played_at"
        }
    }
}

// MARK: - Errors

enum SpotifyError: LocalizedError, Equatable {
    case invalidURL
    case authCancelled
    case noAuthCode
    case tokenExchangeFailed
    case apiError(String)
    case apiStatusError(Int)
    case tokenExpired
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Spotify URL"
        case .authCancelled:
            return "Authentication cancelled"
        case .noAuthCode:
            return "No authorization code received"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token"
        case .apiError(let message):
            return "Spotify API error: \(message)"
        case .apiStatusError(let code):
            return "Spotify API error (status \(code))"
        case .tokenExpired:
            return "Spotify access token expired. Please reconnect Spotify."
        case .networkError:
            return "Network error connecting to Spotify"
        }
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
