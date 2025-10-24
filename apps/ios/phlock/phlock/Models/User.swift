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
    let createdAt: Date
    let updatedAt: Date

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
