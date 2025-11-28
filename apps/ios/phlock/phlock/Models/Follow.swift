import Foundation

/// Represents a unilateral follow relationship
/// follower_id follows following_id (no reciprocation required)
/// Maps to the 'follows' table in Supabase
struct Follow: Codable, Identifiable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date?

    // Phlock fields - follower's settings for this relationship
    let isInPhlock: Bool
    let phlockPosition: Int?
    let phlockAddedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
        case isInPhlock = "is_in_phlock"
        case phlockPosition = "phlock_position"
        case phlockAddedAt = "phlock_added_at"
    }
}

/// Follow with the user data of who is being followed
struct FollowWithUser: Identifiable {
    let id: UUID
    let follow: Follow
    let user: User  // The user being followed (for following list) or the follower (for followers list)
}

/// Follow with position info for phlock display
struct FollowWithPosition: Identifiable {
    var id: UUID { user.id }
    let user: User
    let position: Int

    init(user: User, position: Int) {
        self.user = user
        self.position = position
    }
}

/// Relationship status between current user and another user
struct RelationshipStatus {
    let isFollowing: Bool      // Current user follows them
    let isFollowedBy: Bool     // They follow current user
    let isMutual: Bool         // Both follow each other
    var hasPendingRequest: Bool = false  // Current user has pending follow request

    var displayText: String {
        if isMutual {
            return "Mutual"
        } else if isFollowing {
            return "Following"
        } else if hasPendingRequest {
            return "Requested"
        } else if isFollowedBy {
            return "Follows you"
        }
        return ""
    }
}

// MARK: - Follow Requests (for private profiles)

/// Status of a follow request
enum FollowRequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

/// Represents a follow request for a private profile
/// Maps to the 'follow_requests' table in Supabase
struct FollowRequest: Codable, Identifiable {
    let id: UUID
    let requesterId: UUID
    let targetId: UUID
    let status: FollowRequestStatus
    let createdAt: Date?
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case targetId = "target_id"
        case status
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}

/// Follow request with requester user data (for displaying incoming requests)
struct FollowRequestWithUser: Identifiable {
    let id: UUID
    let request: FollowRequest
    let user: User  // The user who sent the request
}
