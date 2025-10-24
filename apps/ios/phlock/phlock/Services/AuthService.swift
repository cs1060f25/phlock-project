import Foundation
import Supabase

/// Main authentication service that coordinates platform OAuth with Supabase
class AuthService {
    static let shared = AuthService()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    // MARK: - Spotify Authentication Flow

    /// Complete Spotify sign-in flow: OAuth -> fetch data -> create/update Supabase user
    func signInWithSpotify() async throws -> User {
        // Step 1: Authenticate with Spotify
        let authResult = try await SpotifyService.shared.authenticate()

        // Step 2: Fetch user data from Spotify
        let profile = try await SpotifyService.shared.getUserProfile(accessToken: authResult.accessToken)
        let playlists = try await SpotifyService.shared.getUserPlaylists(accessToken: authResult.accessToken)
        let topTracks = try await SpotifyService.shared.getTopTracks(accessToken: authResult.accessToken)
        let topArtists = try await SpotifyService.shared.getTopArtists(accessToken: authResult.accessToken)

        // Step 3: Create or update user in Supabase
        let user = try await createOrUpdateUser(
            platformType: .spotify,
            platformUserId: profile.id,
            email: profile.email,
            displayName: profile.displayName ?? "Spotify User",
            profilePhotoUrl: profile.images?.first?.url,
            platformData: PlatformUserData(
                spotifyEmail: profile.email,
                spotifyDisplayName: profile.displayName,
                spotifyImageUrl: profile.images?.first?.url,
                spotifyCountry: profile.country,
                spotifyProduct: profile.product,
                appleMusicUserId: nil,
                appleMusicStorefront: nil,
                topArtists: topArtists.items.prefix(10).map { $0.name },
                topTracks: topTracks.items.prefix(10).map { $0.name },
                playlists: playlists.items.prefix(10).map { playlist in
                    PlaylistInfo(
                        id: playlist.id,
                        name: playlist.name,
                        imageUrl: playlist.images?.first?.url,
                        trackCount: playlist.tracks.total
                    )
                }
            )
        )

        // Step 4: Store platform token
        try await storePlatformToken(
            userId: user.id,
            platformType: .spotify,
            accessToken: authResult.accessToken,
            refreshToken: authResult.refreshToken,
            expiresIn: authResult.expiresIn,
            scope: authResult.scope
        )

        return user
    }

    // MARK: - Apple Music Authentication Flow

    /// Complete Apple Music sign-in flow
    func signInWithAppleMusic() async throws -> User {
        // Step 1: Authenticate with Apple Music
        let authResult = try await AppleMusicService.shared.authenticate()

        // Step 2: Fetch user data from Apple Music
        let playlists = try await AppleMusicService.shared.getUserPlaylists()
        let topSongs = try await AppleMusicService.shared.getTopSongs()
        let storefront = try await AppleMusicService.shared.getStorefront()

        // Step 3: Create or update user in Supabase
        // Note: Apple Music doesn't provide email/name directly through MusicKit
        // We'll need to get this from profile setup screen
        let user = try await createOrUpdateUser(
            platformType: .appleMusic,
            platformUserId: authResult.userToken, // Using user token as ID
            email: nil, // Will be set during profile setup
            displayName: "Apple Music User", // Will be updated during profile setup
            profilePhotoUrl: nil,
            platformData: PlatformUserData(
                spotifyEmail: nil,
                spotifyDisplayName: nil,
                spotifyImageUrl: nil,
                spotifyCountry: nil,
                spotifyProduct: nil,
                appleMusicUserId: authResult.userToken,
                appleMusicStorefront: storefront,
                topArtists: nil,
                topTracks: topSongs.prefix(10).map { $0.title },
                playlists: playlists.prefix(10).map { playlist in
                    PlaylistInfo(
                        id: playlist.id,
                        name: playlist.name,
                        imageUrl: playlist.artworkURL,
                        trackCount: playlist.trackCount
                    )
                }
            )
        )

        // Step 4: Store platform token
        try await storePlatformToken(
            userId: user.id,
            platformType: .appleMusic,
            accessToken: authResult.userToken,
            refreshToken: nil,
            expiresIn: 86400 * 365, // Apple Music tokens last 1 year
            scope: "music"
        )

        return user
    }

    // MARK: - User Profile Management

    /// Update user profile after setup screen
    func updateUserProfile(
        userId: UUID,
        displayName: String,
        bio: String?,
        profilePhotoUrl: String?
    ) async throws {
        var updates: [String: String] = [
            "display_name": displayName,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let bio = bio {
            updates["bio"] = bio
        }
        if let profilePhotoUrl = profilePhotoUrl {
            updates["profile_photo_url"] = profilePhotoUrl
        }

        try await supabase
            .from("users")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Upload profile photo to Supabase Storage
    func uploadProfilePhoto(userId: UUID, imageData: Data) async throws -> String {
        let fileName = "\(userId.uuidString).jpg"
        let filePath = "profile-photos/\(fileName)"

        try await supabase.storage
            .from("profile-photos")
            .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))

        let publicURL = try supabase.storage
            .from("profile-photos")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    /// Get current user profile
    func getCurrentUser() async throws -> User? {
        let session: Session
        do {
            session = try await supabase.auth.session
        } catch {
            return nil
        }

        let response: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: session.user.id.uuidString)
            .execute()
            .value

        return response.first
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Private Helper Methods

    private func createOrUpdateUser(
        platformType: PlatformType,
        platformUserId: String,
        email: String?,
        displayName: String,
        profilePhotoUrl: String?,
        platformData: PlatformUserData
    ) async throws -> User {
        // Check if user exists
        let existingUsers: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("platform_type", value: platformType.rawValue)
            .eq("platform_user_id", value: platformUserId)
            .execute()
            .value

        // Encode platform data as JSON string
        let platformDataJSON = String(data: try JSONEncoder().encode(platformData), encoding: .utf8) ?? "{}"

        if let existingUser = existingUsers.first {
            // Update existing user
            let updatedUsers: [User] = try await supabase
                .from("users")
                .update([
                    "platform_data": platformDataJSON,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: existingUser.id.uuidString)
                .select("*")
                .execute()
                .value

            guard let user = updatedUsers.first else {
                throw AuthError.userUpdateFailed
            }
            return user
        } else {
            // Create new user
            var insertData: [String: String] = [
                "platform_type": platformType.rawValue,
                "platform_user_id": platformUserId,
                "display_name": displayName,
                "platform_data": platformDataJSON
            ]

            if let email = email {
                insertData["email"] = email
            }
            if let profilePhotoUrl = profilePhotoUrl {
                insertData["profile_photo_url"] = profilePhotoUrl
            }

            let newUsers: [User] = try await supabase
                .from("users")
                .insert(insertData)
                .select("*")
                .execute()
                .value

            guard let user = newUsers.first else {
                throw AuthError.userCreationFailed
            }
            return user
        }
    }

    private func storePlatformToken(
        userId: UUID,
        platformType: PlatformType,
        accessToken: String,
        refreshToken: String?,
        expiresIn: Int,
        scope: String
    ) async throws {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        var tokenData: [String: String] = [
            "user_id": userId.uuidString,
            "platform_type": platformType.rawValue,
            "access_token": accessToken,
            "token_expires_at": ISO8601DateFormatter().string(from: expiresAt),
            "scope": scope
        ]

        if let refreshToken = refreshToken {
            tokenData["refresh_token"] = refreshToken
        }

        try await supabase
            .from("platform_tokens")
            .insert(tokenData)
            .execute()
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case userCreationFailed
    case userUpdateFailed
    case profileUploadFailed

    var errorDescription: String? {
        switch self {
        case .userCreationFailed:
            return "Failed to create user profile"
        case .userUpdateFailed:
            return "Failed to update user profile"
        case .profileUploadFailed:
            return "Failed to upload profile photo"
        }
    }
}
