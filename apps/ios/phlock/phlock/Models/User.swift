import Foundation

/// Represents a user in the Phlock app
/// Maps to the 'users' table in Supabase
struct User: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let profilePhotoUrl: String?
    let bio: String?
    let email: String?
    let phone: String?
    let platformType: PlatformType?
    let platformUserId: String?
    let platformData: PlatformUserData?
    let privacyWhoCanSend: String
    let createdAt: Date?
    let updatedAt: Date?

    // New Supabase Auth fields
    let authUserId: UUID?
    let authProvider: String?
    let musicPlatform: String?
    let spotifyUserId: String?
    let appleUserId: String?

    // Daily curation fields
    let username: String?
    let phlockCount: Int
    let dailySongStreak: Int
    let lastDailySongDate: Date?

    // Privacy settings
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case profilePhotoUrl = "profile_photo_url"
        case bio
        case email
        case phone
        case platformType = "platform_type"
        case platformUserId = "platform_user_id"
        case platformData = "platform_data"
        case privacyWhoCanSend = "privacy_who_can_send"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authUserId = "auth_user_id"
        case authProvider = "auth_provider"
        case musicPlatform = "music_platform"
        case spotifyUserId = "spotify_user_id"
        case appleUserId = "apple_user_id"
        case username
        case phlockCount = "phlock_count"
        case dailySongStreak = "daily_song_streak"
        case lastDailySongDate = "last_daily_song_date"
        case isPrivate = "is_private"
    }

    // Helper: Check if user selected a song today
    var hasSelectedToday: Bool {
        guard let lastSongDate = lastDailySongDate else { return false }
        return Calendar.current.isDateInToday(lastSongDate)
    }

    // Helper: Get the effective streak for display
    // The database trigger handles streak expiration, so we trust the DB value
    var effectiveStreak: Int {
        return dailySongStreak
    }

    // Helper: Streak emoji for display
    var streakEmoji: String {
        switch effectiveStreak {
        case 0: return ""
        case 1...6: return "🔥"
        case 7...29: return "🔥🔥"
        case 30...99: return "🔥🔥🔥"
        default: return "🔥💎"
        }
    }

    // Custom decoding to handle platform_data as either JSON object or string
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        profilePhotoUrl = try container.decodeIfPresent(String.self, forKey: .profilePhotoUrl)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        platformType = try? container.decode(PlatformType.self, forKey: .platformType)
        platformUserId = try? container.decode(String.self, forKey: .platformUserId)
        privacyWhoCanSend = try container.decode(String.self, forKey: .privacyWhoCanSend)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
        updatedAt = try? container.decode(Date.self, forKey: .updatedAt)

        // New Supabase Auth fields
        authUserId = try? container.decode(UUID.self, forKey: .authUserId)
        authProvider = try? container.decode(String.self, forKey: .authProvider)
        musicPlatform = try? container.decode(String.self, forKey: .musicPlatform)
        spotifyUserId = try? container.decode(String.self, forKey: .spotifyUserId)
        appleUserId = try? container.decode(String.self, forKey: .appleUserId)

        // Daily curation fields
        username = try? container.decode(String.self, forKey: .username)
        phlockCount = try container.decodeIfPresent(Int.self, forKey: .phlockCount) ?? 0
        dailySongStreak = try container.decodeIfPresent(Int.self, forKey: .dailySongStreak) ?? 0
        lastDailySongDate = try? container.decode(Date.self, forKey: .lastDailySongDate)

        // Privacy settings
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false

        // Handle platform_data which might be a string or object
        if let platformDataString = try? container.decode(String.self, forKey: .platformData) {
            // It's a JSON string, decode it
            if let data = platformDataString.data(using: .utf8) {
                platformData = try? JSONDecoder().decode(PlatformUserData.self, from: data)
            } else {
                platformData = nil
            }
        } else {
            // It's already an object, decode directly
            platformData = try? container.decode(PlatformUserData.self, forKey: .platformData)
        }
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profilePhotoUrl, forKey: .profilePhotoUrl)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(platformType, forKey: .platformType)
        try container.encodeIfPresent(platformUserId, forKey: .platformUserId)
        try container.encode(privacyWhoCanSend, forKey: .privacyWhoCanSend)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

        // Encode new auth fields
        try container.encodeIfPresent(authUserId, forKey: .authUserId)
        try container.encodeIfPresent(authProvider, forKey: .authProvider)
        try container.encodeIfPresent(musicPlatform, forKey: .musicPlatform)
        try container.encodeIfPresent(spotifyUserId, forKey: .spotifyUserId)
        try container.encodeIfPresent(appleUserId, forKey: .appleUserId)

        // Encode daily curation fields
        try container.encodeIfPresent(username, forKey: .username)
        try container.encode(phlockCount, forKey: .phlockCount)
        try container.encode(dailySongStreak, forKey: .dailySongStreak)
        try container.encodeIfPresent(lastDailySongDate, forKey: .lastDailySongDate)

        // Encode privacy settings
        try container.encode(isPrivate, forKey: .isPrivate)

        // Encode platform_data as object
        try container.encodeIfPresent(platformData, forKey: .platformData)
    }



    // Convenience initializer for manual construction (e.g., placeholders)
    init(
        id: UUID = UUID(),
        displayName: String,
        profilePhotoUrl: String? = nil,
        bio: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        platformType: PlatformType? = nil,
        platformUserId: String? = nil,
        platformData: PlatformUserData? = nil,
        privacyWhoCanSend: String = "everyone",
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        authUserId: UUID? = nil,
        authProvider: String? = nil,
        musicPlatform: String? = nil,
        spotifyUserId: String? = nil,
        appleUserId: String? = nil,
        username: String? = nil,
        phlockCount: Int = 0,
        dailySongStreak: Int = 0,
        lastDailySongDate: Date? = nil,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.profilePhotoUrl = profilePhotoUrl
        self.bio = bio
        self.email = email
        self.phone = phone
        self.platformType = platformType
        self.platformUserId = platformUserId
        self.platformData = platformData
        self.privacyWhoCanSend = privacyWhoCanSend
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authUserId = authUserId
        self.authProvider = authProvider
        self.musicPlatform = musicPlatform
        self.spotifyUserId = spotifyUserId
        self.appleUserId = appleUserId
        self.username = username
        self.phlockCount = phlockCount
        self.dailySongStreak = dailySongStreak
        self.lastDailySongDate = lastDailySongDate
        self.isPrivate = isPrivate
    }
}

/// The music streaming platform the user authenticated with
enum PlatformType: String, Codable, Hashable {
    case spotify
    case appleMusic = "apple_music"
}

// Helper to smoothly bridge old platform_type and new music_platform fields
extension User {
    var resolvedPlatformType: PlatformType? {
        if let platformType {
            return platformType
        }
        if let musicPlatform,
           let derivedType = PlatformType(rawValue: musicPlatform) {
            return derivedType
        }
        return nil
    }

    /// Returns true if user has Spotify as preference but no OAuth connection
    /// (i.e., they selected Spotify during onboarding but didn't complete OAuth)
    var isSpotifyPreferenceOnly: Bool {
        musicPlatform == "spotify" && (spotifyUserId == nil || spotifyUserId?.isEmpty == true)
    }

    /// Returns true if user can save tracks to their library (has OAuth connection)
    var canSaveToLibrary: Bool {
        !isSpotifyPreferenceOnly
    }
}

/// Platform-specific user data stored as JSONB
struct PlatformUserData: Codable, Hashable, Sendable {
    // Spotify-specific fields
    let spotifyEmail: String?
    let spotifyDisplayName: String?
    let spotifyImageUrl: String?
    let spotifyCountry: String?
    let spotifyProduct: String? // premium, free, etc.

    // Apple Music-specific fields
    let appleMusicUserId: String?
    let appleMusicStorefront: String?

    // Shared fields
    let topArtists: [MusicItem]?
    let topTracks: [MusicItem]?
    let recentlyPlayed: [MusicItem]?
    let playlists: [PlaylistInfo]?

    enum CodingKeys: String, CodingKey {
        case spotifyEmail = "spotify_email"
        case spotifyDisplayName = "spotify_display_name"
        case spotifyImageUrl = "spotify_image_url"
        case spotifyCountry = "spotify_country"
        case spotifyProduct = "spotify_product"
        case appleMusicUserId = "apple_music_user_id"
        case appleMusicStorefront = "apple_music_storefront"
        case topArtists = "top_artists"
        case topTracks = "top_tracks"
        case recentlyPlayed = "recently_played"
        case playlists
    }

    // Empty init for cases where we don't have music data yet
    init(
        spotifyEmail: String? = nil,
        spotifyDisplayName: String? = nil,
        spotifyImageUrl: String? = nil,
        spotifyCountry: String? = nil,
        spotifyProduct: String? = nil,
        appleMusicUserId: String? = nil,
        appleMusicStorefront: String? = nil,
        topArtists: [MusicItem]? = nil,
        topTracks: [MusicItem]? = nil,
        recentlyPlayed: [MusicItem]? = nil,
        playlists: [PlaylistInfo]? = nil
    ) {
        self.spotifyEmail = spotifyEmail
        self.spotifyDisplayName = spotifyDisplayName
        self.spotifyImageUrl = spotifyImageUrl
        self.spotifyCountry = spotifyCountry
        self.spotifyProduct = spotifyProduct
        self.appleMusicUserId = appleMusicUserId
        self.appleMusicStorefront = appleMusicStorefront
        self.topArtists = topArtists
        self.topTracks = topTracks
        self.recentlyPlayed = recentlyPlayed
        self.playlists = playlists
    }
}

/// Represents a music track or artist with ID for deep linking
struct MusicItem: Codable, Hashable, Sendable {
    let id: String // Primary ID (platform-specific)
    let name: String
    var artistName: String?
    var artistSpotifyId: String? // Spotify ID of the primary artist (for direct profile linking)
    var previewUrl: String?
    var albumArtUrl: String?
    var isrc: String? // International Standard Recording Code for universal track matching
    var playedAt: Date? // When this track was last played (for recently played tracks)
    var spotifyId: String? // Spotify artist/track ID for cross-platform linking
    var appleMusicId: String? // Apple Music artist/track ID for cross-platform linking
    var popularity: Int? // Spotify popularity score (0-100)
    var followerCount: Int? // Follower count for artists
    var genres: [String]? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artistName = "artist_name"
        case artistSpotifyId = "artist_spotify_id"
        case previewUrl = "preview_url"
        case albumArtUrl = "album_art_url"
        case isrc
        case playedAt = "played_at"
        case spotifyId = "spotify_id"
        case appleMusicId = "apple_music_id"
        case popularity
        case followerCount = "followers"
        case genres
    }
}

/// Simplified playlist info for storage
struct PlaylistInfo: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let imageUrl: String?
    let trackCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUrl = "image_url"
        case trackCount = "track_count"
    }
}
