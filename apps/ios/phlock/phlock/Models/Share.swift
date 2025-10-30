import Foundation

/// Represents a music share transaction between two users
/// Maps to the 'shares' table in Supabase
struct Share: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let trackId: String
    let trackName: String
    let artistName: String
    let albumArtUrl: String?
    let message: String?
    var status: ShareStatus
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case trackId = "track_id"
        case trackName = "track_name"
        case artistName = "artist_name"
        case albumArtUrl = "album_art_url"
        case message
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Status of a share transaction
enum ShareStatus: String, Codable {
    case sent
    case received
    case played
    case saved
    case forwarded
    case dismissed
}
