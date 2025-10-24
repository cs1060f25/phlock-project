import Foundation

/// Represents a friendship relationship between two users
/// Maps to the 'friendships' table in Supabase
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    let status: FriendshipStatus
    let createdAt: Date
    let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
    }
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case blocked
}
