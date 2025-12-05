import Foundation

/// Represents a phlock - a network visualization of how a song spreads through your social network
/// Maps to the 'phlocks' table in Supabase
struct Phlock: Codable, Identifiable, @unchecked Sendable {
    let id: UUID
    let originShareId: UUID?  // Optional because we may create phlocks without a share (for demos/testing)
    let createdBy: UUID
    let trackId: String
    let trackName: String
    let artistName: String
    let albumArtUrl: String?
    var totalReach: Int
    var maxDepth: Int
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case originShareId = "origin_share_id"
        case createdBy = "created_by"
        case trackId = "track_id"
        case trackName = "track_name"
        case artistName = "artist_name"
        case albumArtUrl = "album_art_url"
        case totalReach = "total_reach"
        case maxDepth = "max_depth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
