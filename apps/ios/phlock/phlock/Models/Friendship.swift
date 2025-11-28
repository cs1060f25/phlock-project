import Foundation

/// Represents a friendship/friend request between two users
/// Maps to the 'friendships' table in Supabase
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId1: UUID
    let userId2: UUID
    let status: FriendshipStatus
    let createdAt: Date?

    // Legacy phlock fields (deprecated - use directional fields below)
    let position: Int?
    let isPhlockMember: Bool
    let lastSwappedAt: Date?

    // Directional phlock fields - each user independently manages their phlock
    // user_1 = userId1's phlock settings for userId2
    // user_2 = userId2's phlock settings for userId1
    let user1HasInPhlock: Bool?
    let user1PhlockPosition: Int?
    let user1PhlockAddedAt: Date?
    let user2HasInPhlock: Bool?
    let user2PhlockPosition: Int?
    let user2PhlockAddedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId1 = "user_id_1"
        case userId2 = "user_id_2"
        case status
        case createdAt = "created_at"
        case position
        case isPhlockMember = "is_phlock_member"
        case lastSwappedAt = "last_swapped_at"
        case user1HasInPhlock = "user_1_has_in_phlock"
        case user1PhlockPosition = "user_1_phlock_position"
        case user1PhlockAddedAt = "user_1_phlock_added_at"
        case user2HasInPhlock = "user_2_has_in_phlock"
        case user2PhlockPosition = "user_2_phlock_position"
        case user2PhlockAddedAt = "user_2_phlock_added_at"
    }

    /// Get whether a specific user has the other user in their phlock
    func hasInPhlock(for userId: UUID) -> Bool {
        if userId == userId1 {
            return user1HasInPhlock ?? false
        } else if userId == userId2 {
            return user2HasInPhlock ?? false
        }
        return false
    }

    /// Get the phlock position for a specific user's perspective
    func phlockPosition(for userId: UUID) -> Int? {
        if userId == userId1 {
            return user1PhlockPosition
        } else if userId == userId2 {
            return user2PhlockPosition
        }
        return nil
    }

    /// Get when a specific user added the other to their phlock
    func phlockAddedAt(for userId: UUID) -> Date? {
        if userId == userId1 {
            return user1PhlockAddedAt
        } else if userId == userId2 {
            return user2PhlockAddedAt
        }
        return nil
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
