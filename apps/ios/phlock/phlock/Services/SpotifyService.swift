import Foundation
import AuthenticationServices

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
                    continuation.resume(throwing: SpotifyError.authCancelled(error))
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: SpotifyError.noAuthCode)
                    return
                }

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
            throw SpotifyError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        return SpotifyAuthResult(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
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
            URLQueryItem(name: "time_range", value: "medium_term")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyTopTracksResponse.self, from: data)
    }

    /// Fetch user's top artists
    func getTopArtists(accessToken: String, limit: Int = 20) async throws -> SpotifyTopArtistsResponse {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/top/artists")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "time_range", value: "medium_term")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyTopArtistsResponse.self, from: data)
    }

    /// Fetch user's playlists
    func getUserPlaylists(accessToken: String) async throws -> SpotifyPlaylistsResponse {
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
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

// MARK: - Errors

enum SpotifyError: LocalizedError {
    case invalidURL
    case authCancelled(Error)
    case noAuthCode
    case tokenExchangeFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Spotify URL"
        case .authCancelled(let error):
            return "Authentication cancelled: \(error.localizedDescription)"
        case .noAuthCode:
            return "No authorization code received"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token"
        case .apiError(let message):
            return "Spotify API error: \(message)"
        }
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
