import Foundation

/// Represents a friendship/friend request between two users
/// Maps to the 'friendships' table in Supabase
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId1: UUID
    let userId2: UUID
    let status: FriendshipStatus
    let createdAt: Date?

    // Daily curation / phlock fields
    let position: Int?
    let isPhlockMember: Bool
    let lastSwappedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId1 = "user_id_1"
        case userId2 = "user_id_2"
        case status
        case createdAt = "created_at"
        case position
        case isPhlockMember = "is_phlock_member"
        case lastSwappedAt = "last_swapped_at"
    }
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case blocked
}

/// Enriched friendship with user data
struct FriendshipWithUser: Identifiable {
    let id: UUID
    let friendship: Friendship
    let user: User
    let isRequester: Bool // true if current user sent the request
}
