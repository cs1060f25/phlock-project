import Foundation
import Supabase
import AuthenticationServices

/// Production-grade authentication service using Supabase Auth with OAuth
/// This replaces the manual user creation approach with proper auth.uid() integration
class AuthServiceV2 {
    static let shared = AuthServiceV2()

    private let supabase = PhlockSupabaseClient.shared.client

    // MARK: - Session Management

    /// Get current authenticated user from Supabase session
    var currentUser: User? {
        get async throws {
            // Get Supabase Auth session
            guard let session = try? await supabase.auth.session else {
                print("❌ No active Supabase Auth session")
                return nil
            }

            let authUserId = session.user.id
            print("✅ Found Supabase Auth session for user: \(authUserId)")

            // Look up custom user record linked to this auth user
            let users: [User] = try await supabase
                .from("users")
                .select("*")
                .eq("auth_user_id", value: authUserId.uuidString)
                .execute()
                .value

            return users.first
        }
    }

    /// Get current user ID from session (for services that just need the ID)
    var currentUserId: UUID? {
        get async {
            do {
                return try await currentUser?.id
            } catch {
                print("❌ Failed to get current user ID: \(error)")
                return nil
            }
        }
    }

    private init() {
        // Set up session listener to handle token refresh
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
                    print("🔄 Token refreshed for: \(session?.user.email ?? "no email")")
                case .userUpdated:
                    print("📝 User updated: \(session?.user.email ?? "no email")")
                case .userDeleted:
                    print("🗑️ User deleted")
                case .mfaChallengeVerified:
                    print("🔐 MFA challenge verified")
                @unknown default:
                    print("⚠️ Unknown auth state change")
                }
            }
        }
    }

    // MARK: - Spotify Authentication

    /// Sign in with Spotify using native OAuth + Supabase session exchange
    func signInWithSpotify() async throws -> User {
        print("🎵 Starting native Spotify authentication...")

        // Step 1: Use native Spotify OAuth (seamless UX)
        let spotifyAuth = try await SpotifyService.shared.authenticate()
        let accessToken = spotifyAuth.accessToken

        print("✅ Native Spotify auth successful")

        // Step 2: Exchange Spotify token for Supabase Auth session
        let exchangeResponse = try await exchangeTokenForSupabaseSession(
            provider: "spotify",
            accessToken: accessToken
        )

        print("✅ Exchanged token for Supabase session, auth user ID: \(exchangeResponse.authUserId)")

        // Step 3: Sign in to Supabase with temporary credentials
        let session = try await supabase.auth.signIn(
            email: exchangeResponse.email,
            password: exchangeResponse.tempPassword
        )

        print("✅ Supabase session established")

        let providerToken = accessToken

        // Step 4: Check for existing user by email (account linking)
        let email = session.user.email ?? "noemail@phlock.app"
        let linkedUser = try await findAndLinkExistingUser(
            authUserId: session.user.id,
            email: email,
            provider: "spotify"
        )

        if let existingUser = linkedUser {
            // User already exists, linked accounts
            print("✅ Linked Spotify to existing user: \(existingUser.id)")

            // Update music data in background
            Task {
                try? await updateSpotifyMusicData(
                    userId: existingUser.id,
                    accessToken: providerToken
                )
            }

            return existingUser
        }

        // Step 5: Fetch music data from Spotify
        let profile = try await SpotifyService.shared.getUserProfile(accessToken: providerToken)
        let recentlyPlayed = try await SpotifyService.shared.getRecentlyPlayed(accessToken: providerToken)
        let topArtistsResponse = try await SpotifyService.shared.getTopArtists(accessToken: providerToken)

        // Fetch Apple Music IDs for cross-platform linking
        let topArtistsWithCrossPlatformIds = await withTaskGroup(of: (String, String, String?, String?).self) { group in
            for artist in topArtistsResponse.items.prefix(10) {
                group.addTask {
                    let appleMusicId = try? await AppleMusicService.shared.searchArtistId(artistName: artist.name)
                    return (artist.id, artist.name, artist.images?.first?.url, appleMusicId)
                }
            }

            var results: [(String, String, String?, String?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // Step 6: Create new user record in users table
        let platformData = PlatformUserData(
            spotifyEmail: profile.email,
            spotifyDisplayName: profile.displayName,
            spotifyImageUrl: profile.images?.first?.url,
            spotifyCountry: profile.country,
            spotifyProduct: profile.product,
            appleMusicUserId: nil,
            appleMusicStorefront: nil,
            topArtists: topArtistsWithCrossPlatformIds.map {
                MusicItem(
                    id: $0.0,
                    name: $0.1,
                    artistName: nil,
                    previewUrl: nil,
                    albumArtUrl: $0.2,
                    isrc: nil,
                    playedAt: nil,
                    spotifyId: $0.0,
                    appleMusicId: $0.3
                )
            },
            topTracks: recentlyPlayed.items.prefix(20).map {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let playedDate = formatter.date(from: $0.playedAt)
                return MusicItem(
                    id: $0.track.id,
                    name: $0.track.name,
                    artistName: $0.track.artists.first?.name,
                    previewUrl: $0.track.previewUrl,
                    albumArtUrl: $0.track.album.images.first?.url,
                    isrc: $0.track.externalIds?.isrc,
                    playedAt: playedDate
                )
            },
            recentlyPlayed: recentlyPlayed.items.prefix(20).map {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let playedDate = formatter.date(from: $0.playedAt)
                return MusicItem(
                    id: $0.track.id,
                    name: $0.track.name,
                    artistName: $0.track.artists.first?.name,
                    previewUrl: $0.track.previewUrl,
                    albumArtUrl: $0.track.album.images.first?.url,
                    isrc: $0.track.externalIds?.isrc,
                    playedAt: playedDate
                )
            },
            playlists: nil
        )

        let newUser = try await createUser(
            authUserId: session.user.id,
            email: email,
            displayName: profile.displayName ?? "Spotify User",
            profilePhotoUrl: profile.images?.first?.url,
            authProvider: "spotify",
            musicPlatform: "spotify",
            spotifyUserId: profile.id,
            platformData: platformData
        )

        // Step 7: Store platform token
        try await storePlatformToken(
            userId: newUser.id,
            platformType: .spotify,
            accessToken: providerToken,
            refreshToken: spotifyAuth.refreshToken,
            expiresIn: 3600, // Spotify tokens expire in 1 hour
            scope: "user-read-email user-read-private user-top-read"
        )

        print("✅ Created new user with Spotify auth: \(newUser.id)")
        return newUser
    }

    // MARK: - Apple Sign In Authentication

    /// Sign in with Apple Music using native OAuth + Supabase session exchange
    /// Note: This provides authentication only. Music data comes from MusicKit separately.
    func signInWithApple() async throws -> User {
        print("🍎 Starting native Apple Music authentication...")

        // Step 1: Use native Apple Music OAuth (seamless UX)
        let appleMusicAuth = try await AppleMusicService.shared.authenticate()
        let userToken = appleMusicAuth.userToken

        print("✅ Native Apple Music auth successful")

        // Step 2: Exchange Apple Music token for Supabase Auth session
        let exchangeResponse = try await exchangeTokenForSupabaseSession(
            provider: "apple",
            accessToken: userToken
        )

        print("✅ Exchanged token for Supabase session, auth user ID: \(exchangeResponse.authUserId)")

        // Step 3: Sign in to Supabase with temporary credentials
        let session = try await supabase.auth.signIn(
            email: exchangeResponse.email,
            password: exchangeResponse.tempPassword
        )

        print("✅ Supabase session established")

        // Step 4: Get email from session
        let email = session.user.email ?? "\(session.user.id.uuidString)@privaterelay.appleid.com"

        // Step 5: Check for existing user by email (account linking)
        let linkedUser = try await findAndLinkExistingUser(
            authUserId: session.user.id,
            email: email,
            provider: "apple"
        )

        if let existingUser = linkedUser {
            print("✅ Linked Apple to existing user: \(existingUser.id)")

            // Check if they need to connect music platform
            if existingUser.musicPlatform == nil {
                // Prompt user to select music platform
                print("⚠️ User needs to select music platform (Spotify or Apple Music)")
            }

            return existingUser
        }

        // Step 6: New user - need to determine music platform
        // For now, assume they want Apple Music since they signed in with Apple
        // In production, you'd show a selection screen
        let musicPlatform = "apple_music"

        // Step 7: Fetch Apple Music data (we already have auth from Step 1)
        var musicData: PlatformUserData? = nil
        var appleUserId: String? = nil

        if musicPlatform == "apple_music" {
            do {
                appleUserId = userToken

                // Fetch music data
                let topSongs = try await AppleMusicService.shared.getTopSongs()
                let topArtists = try await AppleMusicService.shared.getTopArtists()
                let storefront = try await AppleMusicService.shared.getStorefront()

                // Fetch cross-platform data
                let topArtistsWithCrossPlatformData = await withTaskGroup(of: (String, String, String?, String?).self) { group in
                    for artist in topArtists {
                        group.addTask {
                            let artwork = try? await AppleMusicService.shared.fetchArtistArtwork(artistName: artist.name)
                            let spotifyId = try? await self.searchSpotifyArtist(artistName: artist.name)
                            return (artist.id, artist.name, artwork, spotifyId)
                        }
                    }

                    var results: [(String, String, String?, String?)] = []
                    for await result in group {
                        results.append(result)
                    }
                    return results
                }

                musicData = PlatformUserData(
                    spotifyEmail: nil,
                    spotifyDisplayName: nil,
                    spotifyImageUrl: nil,
                    spotifyCountry: nil,
                    spotifyProduct: nil,
                    appleMusicUserId: userToken,
                    appleMusicStorefront: storefront,
                    topArtists: topArtistsWithCrossPlatformData.map {
                        MusicItem(
                            id: $0.0,
                            name: $0.1,
                            artistName: nil,
                            previewUrl: nil,
                            albumArtUrl: $0.2,
                            isrc: nil,
                            playedAt: nil,
                            spotifyId: $0.3,
                            appleMusicId: $0.0
                        )
                    },
                    topTracks: topSongs.prefix(20).map {
                        MusicItem(
                            id: $0.id,
                            name: $0.title,
                            artistName: $0.artistName,
                            previewUrl: $0.previewURL,
                            albumArtUrl: $0.artworkURL,
                            isrc: nil,
                            playedAt: nil
                        )
                    },
                    recentlyPlayed: [],
                    playlists: nil
                )
            } catch {
                print("⚠️ Failed to get Apple Music data: \(error)")
                // Continue without music data, user can connect later
            }
        }

        // Step 8: Create new user record
        let newUser = try await createUser(
            authUserId: session.user.id,
            email: email,
            displayName: "Apple Music User", // Apple Music doesn't provide name, user can update in profile
            profilePhotoUrl: nil,
            authProvider: "apple",
            musicPlatform: musicPlatform,
            appleUserId: appleUserId,
            platformData: musicData ?? PlatformUserData()
        )

        // Step 9: Store Apple Music token
        if appleUserId != nil {
            try await storePlatformToken(
                userId: newUser.id,
                platformType: .appleMusic,
                accessToken: userToken,
                refreshToken: nil,
                expiresIn: 86400 * 365, // Apple Music tokens last much longer
                scope: "music"
            )
        }

        print("✅ Created new user with Apple auth: \(newUser.id)")
        return newUser
    }

    // MARK: - Account Linking

    /// Find existing user by email and link new OAuth provider
    private func findAndLinkExistingUser(
        authUserId: UUID,
        email: String,
        provider: String
    ) async throws -> User? {
        // Search for existing user by email
        let existingUsers: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("email", value: email)
            .execute()
            .value

        guard let existingUser = existingUsers.first else {
            // No existing user found
            return nil
        }

        print("🔗 Found existing user with email \(email), linking \(provider)")

        // Determine new auth_provider value
        let newAuthProvider: String
        if let currentProvider = existingUser.authProvider {
            if currentProvider == provider {
                newAuthProvider = provider
            } else {
                newAuthProvider = "both"
            }
        } else {
            newAuthProvider = provider
        }

        // Update user record with new auth_user_id and auth_provider
        struct LinkUserPayload: Encodable {
            let auth_user_id: String
            let auth_provider: String
            let updated_at: String
        }

        let updatedUsers: [User] = try await supabase
            .from("users")
            .update(LinkUserPayload(
                auth_user_id: authUserId.uuidString,
                auth_provider: newAuthProvider,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: existingUser.id.uuidString)
            .select()
            .execute()
            .value

        return updatedUsers.first
    }

    // MARK: - User Creation

    /// Create new user in users table linked to Supabase Auth
    private func createUser(
        authUserId: UUID,
        email: String,
        displayName: String,
        profilePhotoUrl: String?,
        authProvider: String,
        musicPlatform: String,
        spotifyUserId: String? = nil,
        appleUserId: String? = nil,
        platformData: PlatformUserData
    ) async throws -> User {
        let platformDataJSON = String(data: try JSONEncoder().encode(platformData), encoding: .utf8) ?? "{}"

        struct CreateUserPayload: Encodable {
            let auth_user_id: String
            let email: String
            let display_name: String
            let profile_photo_url: String?
            let auth_provider: String
            let music_platform: String
            let spotify_user_id: String?
            let apple_user_id: String?
            let platform_data: String
            let created_at: String
            let updated_at: String
        }

        let payload = CreateUserPayload(
            auth_user_id: authUserId.uuidString,
            email: email,
            display_name: displayName,
            profile_photo_url: profilePhotoUrl,
            auth_provider: authProvider,
            music_platform: musicPlatform,
            spotify_user_id: spotifyUserId,
            apple_user_id: appleUserId,
            platform_data: platformDataJSON,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        let newUser: User = try await supabase
            .from("users")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return newUser
    }

    // MARK: - Music Data Updates

    /// Update Spotify music data for existing user
    private func updateSpotifyMusicData(userId: UUID, accessToken: String) async throws {
        print("🎵 Fetching fresh Spotify data for user: \(userId)")

        let recentlyPlayed = try await SpotifyService.shared.getRecentlyPlayed(accessToken: accessToken)
        let topArtists = try await SpotifyService.shared.getTopArtists(accessToken: accessToken)

        print("📊 Fetched \(recentlyPlayed.items.count) recently played tracks")
        print("🎤 Fetched \(topArtists.items.count) top artists")

        // Fetch existing platform_data
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        guard let user = users.first, let platformData = user.platformData else {
            print("⚠️ User not found or no platform data")
            return
        }

        // Create new platform data with updated tracks
        let newTopTracks = recentlyPlayed.items.prefix(20).map {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let playedDate = formatter.date(from: $0.playedAt)
            return MusicItem(
                id: $0.track.id,
                name: $0.track.name,
                artistName: $0.track.artists.first?.name,
                previewUrl: $0.track.previewUrl,
                albumArtUrl: $0.track.album.images.first?.url,
                isrc: $0.track.externalIds?.isrc,
                playedAt: playedDate
            )
        }

        // Create new top artists list
        let newTopArtists = topArtists.items.prefix(10).map { artist in
            MusicItem(
                id: artist.id,
                name: artist.name,
                artistName: nil,
                previewUrl: nil,
                albumArtUrl: artist.images?.first?.url,
                isrc: nil,
                playedAt: nil,
                spotifyId: artist.id,
                appleMusicId: nil,
                popularity: nil,
                followerCount: nil
            )
        }

        print("🔄 Updating platform_data with \(newTopTracks.count) tracks and \(newTopArtists.count) artists")

        let updatedData = PlatformUserData(
            spotifyEmail: platformData.spotifyEmail,
            spotifyDisplayName: platformData.spotifyDisplayName,
            spotifyImageUrl: platformData.spotifyImageUrl,
            spotifyCountry: platformData.spotifyCountry,
            spotifyProduct: platformData.spotifyProduct,
            appleMusicUserId: platformData.appleMusicUserId,
            appleMusicStorefront: platformData.appleMusicStorefront,
            topArtists: Array(newTopArtists),
            topTracks: Array(newTopTracks),
            recentlyPlayed: Array(newTopTracks),
            playlists: platformData.playlists
        )

        let updatedDataJSON = String(data: try JSONEncoder().encode(updatedData), encoding: .utf8) ?? "{}"

        struct UpdatePayload: Encodable {
            let platform_data: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                platform_data: updatedDataJSON,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: userId.uuidString)
            .execute()

        print("✅ Updated Spotify music data for user: \(userId)")
    }

    // MARK: - Platform Token Storage

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

        // Upsert token (insert or update)
        try await supabase
            .from("platform_tokens")
            .upsert(payload)
            .execute()
    }

    // MARK: - Helper Methods

    /// Search for Spotify artist ID (using edge function to keep client secret secure)
    private func searchSpotifyArtist(artistName: String) async throws -> String {
        // For now, return empty string - edge function may not be deployed yet
        // TODO: Implement when edge function is ready
        return ""
    }

    /// Exchange native OAuth token for Supabase Auth session
    private func exchangeTokenForSupabaseSession(
        provider: String,
        accessToken: String
    ) async throws -> ExchangeResponse {
        let functionUrl = Config.supabaseURL.appendingPathComponent("functions/v1/exchange-auth-token")

        var request = URLRequest(url: functionUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let body = [
            "provider": provider,
            "accessToken": accessToken
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.userCreationFailed
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Edge Function error: \(errorMessage)")
            throw AuthError.userCreationFailed
        }

        let result = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        return result
    }

    // MARK: - User Management

    /// Get user by ID
    func getUserById(_ userId: UUID) async throws -> User? {
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return users.first
    }

    /// Update user profile (display name, bio, photo)
    func updateUserProfile(
        userId: UUID,
        displayName: String,
        bio: String?,
        profilePhotoUrl: String?
    ) async throws {
        struct UpdateProfilePayload: Encodable {
            let display_name: String
            let bio: String?
            let profile_photo_url: String?
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdateProfilePayload(
                display_name: displayName,
                bio: bio,
                profile_photo_url: profilePhotoUrl,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: userId.uuidString)
            .execute()

        print("✅ Updated user profile for: \(userId)")
    }

    /// Upload profile photo to Supabase Storage
    func uploadProfilePhoto(userId: UUID, imageData: Data) async throws -> String {
        let fileName = "\(userId.uuidString).jpg"
        let filePath = "profile-photos/\(fileName)"

        // Upload to Supabase Storage
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

        // Get public URL
        let publicURL = try supabase.storage
            .from("profile-photos")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    /// Refresh music data for current user
    func refreshMusicData() async throws -> User? {
        guard let user = try await currentUser else {
            print("❌ No current user to refresh")
            return nil
        }

        // Get platform tokens to refresh music data
        let tokens: [PlatformToken] = try await supabase
            .from("platform_tokens")
            .select("*")
            .eq("user_id", value: user.id.uuidString)
            .execute()
            .value

        guard let token = tokens.first else {
            print("⚠️ No platform token found")
            return user
        }

        // Refresh based on platform
        if token.platformType == .spotify {
            try await updateSpotifyMusicData(userId: user.id, accessToken: token.accessToken)
        }
        // Could add Apple Music refresh here in the future

        // Return updated user
        return try await getUserById(user.id)
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
        print("👋 Signed out successfully")
    }
}

// Note: PlatformType is defined in User.swift
// Note: PlatformToken is defined in Models/PlatformToken.swift
// Note: AuthError is defined in Services/AuthService.swift

// MARK: - Exchange Response

/// Response from the exchange-auth-token Edge Function
struct ExchangeResponse: Codable {
    let authUserId: String
    let email: String
    let tempPassword: String
    let provider: String

    enum CodingKeys: String, CodingKey {
        case authUserId = "auth_user_id"
        case email
        case tempPassword = "temp_password"
        case provider
    }
}
