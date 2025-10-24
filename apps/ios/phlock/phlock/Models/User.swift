import Foundation

/// Represents a user in the Phlock app
/// Maps to the 'users' table in Supabase
struct User: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let profilePhotoUrl: String?
    let bio: String?
    let email: String?
    let phone: String?
    let platformType: PlatformType
    let platformUserId: String
    let platformData: PlatformUserData?
    let privacyWhoCanSend: String
    let createdAt: Date?
    let updatedAt: Date?

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
        platformType = try container.decode(PlatformType.self, forKey: .platformType)
        platformUserId = try container.decode(String.self, forKey: .platformUserId)
        privacyWhoCanSend = try container.decode(String.self, forKey: .privacyWhoCanSend)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
        updatedAt = try? container.decode(Date.self, forKey: .updatedAt)

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
        try container.encode(platformType, forKey: .platformType)
        try container.encode(platformUserId, forKey: .platformUserId)
        try container.encode(privacyWhoCanSend, forKey: .privacyWhoCanSend)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

        // Encode platform_data as object
        try container.encodeIfPresent(platformData, forKey: .platformData)
    }
}

/// The music streaming platform the user authenticated with
enum PlatformType: String, Codable {
    case spotify
    case appleMusic = "apple_music"
}

/// Platform-specific user data stored as JSONB
struct PlatformUserData: Codable {
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
    let topArtists: [String]?
    let topTracks: [String]?
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
        case playlists
    }
}

/// Simplified playlist info for storage
struct PlaylistInfo: Codable {
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
