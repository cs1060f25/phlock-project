import Foundation
import AuthenticationServices
import Supabase
import OSLog

/// Clean authentication service using Apple + Google SSO
/// Separates account authentication from music platform connection
class AuthServiceV3 {
    static let shared = AuthServiceV3()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {
        // Set up session listener
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    print("📱 Initial session: \(session?.user.email ?? "no email")")
                case .signedIn:
                    print("✅ Signed in: \(session?.user.email ?? "no email")")
                case .signedOut:
                    print("👋 Signed out")
                case .tokenRefreshed:
                    print("🔄 Token refreshed")
                case .userUpdated:
                    print("📝 User updated")
                default:
                    break
                }
            }
        }
    }

    // MARK: - Session Management

    /// Get current authenticated user
    var currentUser: User? {
        get async throws {
            guard let session = try? await supabase.auth.session else {
                return nil
            }

            let authUserId = session.user.id

            let users: [User] = try await supabase
                .from("users")
                .select("*")
                .eq("auth_user_id", value: authUserId.uuidString)
                .execute()
                .value

            return users.first
        }
    }

    var currentUserId: UUID? {
        get async {
            do {
                return try await currentUser?.id
            } catch {
                return nil
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Sign in with Apple using native ASAuthorization
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> (session: Session, isNewUser: Bool) {
        guard let identityToken = credential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        print("🍎 Signing in with Apple...")

        // Sign in to Supabase with Apple ID token
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idTokenString
            )
        )

        print("✅ Supabase session created for: \(session.user.email ?? "no email")")

        // Check if user record exists
        let existingUsers: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("auth_user_id", value: session.user.id.uuidString)
            .execute()
            .value

        let isNewUser = existingUsers.isEmpty

        if isNewUser {
            // Create user record with info from Apple
            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            try await createUserRecord(
                authUserId: session.user.id,
                email: session.user.email ?? credential.email ?? "",
                displayName: displayName.isEmpty ? "Phlock User" : displayName,
                authProvider: "apple"
            )
            print("✅ Created new user record")
        }

        return (session, isNewUser)
    }

    // MARK: - Sign in with Google

    /// Sign in with Google using ID token from Google Sign-In SDK
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> (session: Session, isNewUser: Bool) {
        print("🔵 Signing in with Google...")

        // Sign in to Supabase with Google ID token
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )

        print("✅ Supabase session created for: \(session.user.email ?? "no email")")

        // Check if user record exists
        let existingUsers: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("auth_user_id", value: session.user.id.uuidString)
            .execute()
            .value

        let isNewUser = existingUsers.isEmpty

        if isNewUser {
            // Create user record with info from Google
            let metadata = session.user.userMetadata
            let displayName = metadata["full_name"]?.stringValue
                ?? metadata["name"]?.stringValue
                ?? "Phlock User"
            // Don't use Google's default avatar - let ProfilePhotoPlaceholder handle it
            let profilePhotoUrl: String? = nil

            try await createUserRecord(
                authUserId: session.user.id,
                email: session.user.email ?? "",
                displayName: displayName,
                profilePhotoUrl: profilePhotoUrl,
                authProvider: "google"
            )
            print("✅ Created new user record")
        }

        return (session, isNewUser)
    }

    // MARK: - User Record Management

    /// Create user record in public.users table
    private func createUserRecord(
        authUserId: UUID,
        email: String,
        displayName: String,
        profilePhotoUrl: String? = nil,
        authProvider: String
    ) async throws {
        struct CreateUserPayload: Encodable {
            let auth_user_id: String
            let email: String
            let display_name: String
            let profile_photo_url: String?
            let auth_provider: String
            let created_at: String
            let updated_at: String
        }

        let payload = CreateUserPayload(
            auth_user_id: authUserId.uuidString,
            email: email,
            display_name: displayName,
            profile_photo_url: profilePhotoUrl,
            auth_provider: authProvider,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("users")
            .insert(payload)
            .execute()
    }

    // MARK: - Username Management

    /// Check if username is available
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let users: [User] = try await supabase
            .from("users")
            .select("id")
            .eq("username", value: normalizedUsername)
            .execute()
            .value

        return users.isEmpty
    }

    /// Set username for current user
    func setUsername(_ username: String) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate username format - letters, numbers, underscores, periods
        let basicRegex = "^[a-z0-9_.]{3,20}$"
        guard normalizedUsername.range(of: basicRegex, options: .regularExpression) != nil else {
            throw AuthError.invalidUsername
        }

        // Cannot start or end with a period (underscores OK)
        guard !normalizedUsername.hasPrefix(".") && !normalizedUsername.hasSuffix(".") else {
            throw AuthError.invalidUsername
        }

        // Cannot have consecutive periods (consecutive underscores OK)
        guard !normalizedUsername.contains("..") else {
            throw AuthError.invalidUsername
        }

        // Must contain at least one letter (blocks only numbers, periods, underscores)
        guard normalizedUsername.contains(where: { $0.isLetter }) else {
            throw AuthError.invalidUsername
        }

        // Check availability
        guard try await isUsernameAvailable(normalizedUsername) else {
            throw AuthError.usernameTaken
        }

        struct UpdatePayload: Encodable {
            let username: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                username: normalizedUsername,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: user.id.uuidString)
            .execute()

        print("✅ Username set to: @\(normalizedUsername)")
    }

    /// Set display name for current user
    func setDisplayName(_ displayName: String) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate display name
        guard !trimmedDisplayName.isEmpty && trimmedDisplayName.count <= 50 else {
            throw AuthError.invalidCredential
        }

        struct UpdatePayload: Encodable {
            let display_name: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                display_name: trimmedDisplayName,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: user.id.uuidString)
            .execute()

        print("✅ Display name set to: \(trimmedDisplayName)")
    }

    /// Set username and display name for current user
    func setUsernameAndDisplayName(username: String, displayName: String) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate display name
        guard !trimmedDisplayName.isEmpty && trimmedDisplayName.count <= 50 else {
            throw AuthError.invalidCredential
        }

        // Validate username format - letters, numbers, underscores, periods
        let basicRegex = "^[a-z0-9_.]{3,20}$"
        guard normalizedUsername.range(of: basicRegex, options: .regularExpression) != nil else {
            throw AuthError.invalidUsername
        }

        // Cannot start or end with a period (underscores OK)
        guard !normalizedUsername.hasPrefix(".") && !normalizedUsername.hasSuffix(".") else {
            throw AuthError.invalidUsername
        }

        // Cannot have consecutive periods (consecutive underscores OK)
        guard !normalizedUsername.contains("..") else {
            throw AuthError.invalidUsername
        }

        // Must contain at least one letter (blocks only numbers, periods, underscores)
        guard normalizedUsername.contains(where: { $0.isLetter }) else {
            throw AuthError.invalidUsername
        }

        // Check availability
        guard try await isUsernameAvailable(normalizedUsername) else {
            throw AuthError.usernameTaken
        }

        struct UpdatePayload: Encodable {
            let username: String
            let display_name: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                username: normalizedUsername,
                display_name: trimmedDisplayName,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: user.id.uuidString)
            .execute()

        print("✅ Profile set - Username: @\(normalizedUsername), Display name: \(trimmedDisplayName)")
    }

    // MARK: - Music Platform Connection

    /// Connect Spotify account (stores OAuth tokens)
    func connectSpotify(accessToken: String, refreshToken: String?, expiresIn: Int, scope: String) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        // Get Spotify user profile - this is required
        let profile: SpotifyUserProfile
        do {
            profile = try await SpotifyService.shared.getUserProfile(accessToken: accessToken)
        } catch {
            print("❌ Failed to get Spotify profile: \(error)")
            throw error
        }

        // Get music data
        let recentlyPlayed = try await SpotifyService.shared.getRecentlyPlayed(accessToken: accessToken)
        let topArtistsResponse = try await SpotifyService.shared.getTopArtists(accessToken: accessToken)

        // Convert recently played to MusicItem array (top tracks)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Filter out tracks missing album art (local files, podcasts, etc.)
        let topTracks = recentlyPlayed.items.prefix(20).compactMap { item -> MusicItem? in
            guard let albumArtUrl = item.track.album?.images?.first?.url else {
                return nil
            }
            return MusicItem(
                id: item.track.id,
                name: item.track.name,
                artistName: item.track.artists?.first?.name,
                previewUrl: item.track.previewUrl,
                albumArtUrl: albumArtUrl,
                isrc: item.track.externalIds?.isrc,
                playedAt: isoFormatter.date(from: item.playedAt),
                spotifyId: item.track.id,
                appleMusicId: nil,
                popularity: nil
            )
        }

        // Convert top artists to MusicItem array (filter out those without images)
        let topArtists = topArtistsResponse.items.prefix(10).compactMap { artist -> MusicItem? in
            guard let albumArtUrl = artist.images?.first?.url else {
                return nil
            }
            return MusicItem(
                id: artist.id,
                name: artist.name,
                artistName: nil,
                previewUrl: nil,
                albumArtUrl: albumArtUrl,
                isrc: nil,
                playedAt: nil,
                spotifyId: artist.id,
                appleMusicId: nil,
                popularity: nil,
                followerCount: nil,
                genres: artist.genres
            )
        }

        // Create platform data
        let platformData = PlatformUserData(
            spotifyEmail: profile.email,
            spotifyDisplayName: profile.displayName,
            spotifyImageUrl: profile.images?.first?.url,
            spotifyCountry: profile.country,
            spotifyProduct: profile.product,
            appleMusicUserId: nil,
            appleMusicStorefront: nil,
            topArtists: Array(topArtists),
            topTracks: Array(topTracks)
        )

        // Encode platform data as JSON string - use empty object if encoding fails
        var platformDataJSON = "{}"
        do {
            if let jsonData = try? JSONEncoder().encode(platformData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                platformDataJSON = jsonString
            }
        }

        // Update user with Spotify info and platform data
        struct UpdatePayload: Encodable {
            let spotify_user_id: String
            let music_platform: String
            let platform_type: String
            let platform_data: String
            let updated_at: String
        }

        do {
            try await supabase
                .from("users")
                .update(UpdatePayload(
                    spotify_user_id: profile.id,
                    music_platform: "spotify",
                    platform_type: "spotify",
                    platform_data: platformDataJSON,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                ))
                .eq("id", value: user.id.uuidString)
                .execute()
        } catch {
            print("❌ Failed to update user with Spotify info: \(error)")
            throw error
        }

        // Store platform token
        do {
            try await storePlatformToken(
                userId: user.id,
                platformType: .spotify,
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: expiresIn,
                scope: scope
            )
        } catch {
            print("❌ Failed to store platform token: \(error)")
            throw error
        }

        print("✅ Spotify connected for user: \(user.id)")
    }

    /// Connect Apple Music account
    func connectAppleMusic(userToken: String) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        // Fetch Apple Music data
        let recentTracksWithArtists = try await AppleMusicService.shared.getRecentlyPlayed()
        let topArtistsResult = try await AppleMusicService.shared.getTopArtists(limit: 10)

        // Convert recently played to MusicItem array (top tracks)
        let topTracks = recentTracksWithArtists.prefix(20).map { item in
            MusicItem(
                id: item.track.id,
                name: item.track.title,
                artistName: item.track.artistName,
                previewUrl: item.track.previewURL,
                albumArtUrl: item.track.artworkURL,
                isrc: nil,
                playedAt: nil,
                spotifyId: nil,
                appleMusicId: item.track.id,
                popularity: nil
            )
        }

        // Fetch artwork for top artists in parallel
        let topArtistsWithArtwork = await withTaskGroup(of: (String, String, String?).self) { group in
            for artist in topArtistsResult {
                group.addTask {
                    let artwork = try? await AppleMusicService.shared.fetchArtistArtwork(artistName: artist.name)
                    return (artist.id, artist.name, artwork)
                }
            }

            var results: [(String, String, String?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // Convert top artists to MusicItem array with artwork
        let topArtists = topArtistsWithArtwork.map { (id, name, artwork) in
            MusicItem(
                id: id,
                name: name,
                artistName: nil,
                previewUrl: nil,
                albumArtUrl: artwork,
                isrc: nil,
                playedAt: nil,
                spotifyId: nil,
                appleMusicId: id,
                popularity: nil,
                followerCount: nil,
                genres: nil
            )
        }

        // Create platform data
        let platformData = PlatformUserData(
            spotifyEmail: nil,
            spotifyDisplayName: nil,
            spotifyImageUrl: nil,
            spotifyCountry: nil,
            spotifyProduct: nil,
            appleMusicUserId: userToken,
            appleMusicStorefront: nil,
            topArtists: Array(topArtists),
            topTracks: Array(topTracks)
        )

        // Encode platform data as JSON string
        let platformDataJSON = String(data: try JSONEncoder().encode(platformData), encoding: .utf8) ?? "{}"

        // Update user with Apple Music info and platform data
        struct UpdatePayload: Encodable {
            let apple_user_id: String
            let music_platform: String
            let platform_type: String
            let platform_data: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                apple_user_id: userToken,
                music_platform: "apple_music",
                platform_type: "apple_music",
                platform_data: platformDataJSON,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: user.id.uuidString)
            .execute()

        // Store platform token
        try await storePlatformToken(
            userId: user.id,
            platformType: .appleMusic,
            accessToken: userToken,
            refreshToken: nil,
            expiresIn: 86400 * 365, // Apple Music tokens last much longer
            scope: "music"
        )

        print("✅ Apple Music connected for user: \(user.id)")
    }

    // MARK: - Token Storage

    private func storePlatformToken(
        userId: UUID,
        platformType: PlatformType,
        accessToken: String,
        refreshToken: String?,
        expiresIn: Int,
        scope: String
    ) async throws {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        struct TokenPayload: Encodable {
            let user_id: String
            let platform_type: String
            let access_token: String
            let refresh_token: String?
            let token_expires_at: String
            let scope: String
            let created_at: String
            let updated_at: String
        }

        let payload = TokenPayload(
            user_id: userId.uuidString,
            platform_type: platformType.rawValue,
            access_token: accessToken,
            refresh_token: refreshToken,
            token_expires_at: ISO8601DateFormatter().string(from: expiresAt),
            scope: scope,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("platform_tokens")
            .upsert(payload)
            .execute()
    }

    // MARK: - User Management

    func getUserById(_ userId: UUID) async throws -> User? {
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return users.first
    }

    func updateUserProfile(
        userId: UUID,
        displayName: String,
        username: String? = nil,
        bio: String?,
        profilePhotoUrl: String?
    ) async throws {
        struct UpdatePayload: Encodable {
            let display_name: String
            let username: String?
            let bio: String?
            let profile_photo_url: String?
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                display_name: displayName,
                username: username,
                bio: bio,
                profile_photo_url: profilePhotoUrl,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func uploadProfilePhoto(userId: UUID, imageData: Data) async throws -> String {
        let fileName = "\(userId.uuidString).jpg"
        let filePath = "profile-photos/\(fileName)"

        try await supabase.storage
            .from("profile-photos")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let publicURL = try supabase.storage
            .from("profile-photos")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    /// Update user's privacy setting (public/private profile)
    func setPrivateProfile(_ isPrivate: Bool) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        struct UpdatePayload: Encodable {
            let is_private: Bool
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                is_private: isPrivate,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: user.id.uuidString)
            .execute()

        print("✅ Profile privacy set to: \(isPrivate ? "private" : "public")")
    }

    /// Set music platform preference without OAuth connection
    /// Used for Spotify users who select Spotify but don't complete OAuth
    func setMusicPlatformPreference(_ platform: String) async throws {
        guard let user = try await currentUser else {
            throw AuthError.noUser
        }

        struct UpdatePayload: Encodable {
            let music_platform: String
            let platform_type: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                music_platform: platform,
                platform_type: platform,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: user.id.uuidString)
            .execute()

        print("✅ Music platform preference set to: \(platform)")
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
        print("👋 Signed out")
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case noUser
    case invalidUsername
    case usernameTaken
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credential"
        case .noUser:
            return "No authenticated user found"
        case .invalidUsername:
            return "Username must be 3-20 characters, lowercase letters, numbers, and underscores only"
        case .usernameTaken:
            return "This username is already taken"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - JSON Value Extension

extension Supabase.AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
}
