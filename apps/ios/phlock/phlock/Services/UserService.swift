import Foundation
import Supabase

/// Service for user-related operations (search, friends, etc.)
class UserService {
    static let shared = UserService()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    // MARK: - User Search

    /// Search for users by display name
    func searchUsers(query: String) async throws -> [User] {
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .ilike("display_name", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value

        return users
    }

    /// Get a specific user by ID
    func getUser(userId: UUID) async throws -> User? {
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return users.first
    }

    // MARK: - Friend Requests

    /// Send a friend request to another user
    func sendFriendRequest(to userId: UUID, from currentUserId: UUID) async throws {
        // Check if friendship already exists (in either direction)
        let existingFriendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .or("and(user_id_1.eq.\(currentUserId.uuidString),user_id_2.eq.\(userId.uuidString)),and(user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(currentUserId.uuidString))")
            .execute()
            .value

        if !existingFriendships.isEmpty {
            throw UserServiceError.friendshipAlreadyExists
        }

        // Create new friendship request
        let friendshipData: [String: String] = [
            "user_id_1": currentUserId.uuidString,
            "user_id_2": userId.uuidString,
            "status": "pending"
        ]

        try await supabase
            .from("friendships")
            .insert(friendshipData)
            .execute()
    }

    /// Accept a friend request
    func acceptFriendRequest(friendshipId: UUID) async throws {
        try await supabase
            .from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    /// Reject/remove a friend request or friendship
    func rejectFriendRequest(friendshipId: UUID) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    // MARK: - Friends List

    /// Get all accepted friends for a user
    func getFriends(for userId: UUID) async throws -> [User] {
        // Get all accepted friendships where user is either user_id_1 or user_id_2
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
            .eq("status", value: "accepted")
            .execute()
            .value

        // Extract friend user IDs
        var friendIds: [UUID] = []
        for friendship in friendships {
            if friendship.userId1 == userId {
                friendIds.append(friendship.userId2)
            } else {
                friendIds.append(friendship.userId1)
            }
        }

        guard !friendIds.isEmpty else { return [] }

        // Fetch friend user data
        let friends: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: friendIds.map { $0.uuidString })
            .execute()
            .value

        return friends
    }

    /// Get all pending friend requests (sent to the user)
    func getPendingRequests(for userId: UUID) async throws -> [FriendshipWithUser] {
        // Get pending friendships where user is user_id_2 (recipient)
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .eq("user_id_2", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        // Fetch requester user data
        var friendshipsWithUsers: [FriendshipWithUser] = []
        for friendship in friendships {
            if let user = try await getUser(userId: friendship.userId1) {
                friendshipsWithUsers.append(
                    FriendshipWithUser(
                        id: friendship.id,
                        friendship: friendship,
                        user: user,
                        isRequester: false
                    )
                )
            }
        }

        return friendshipsWithUsers
    }

    /// Get friendship status between current user and another user
    func getFriendshipStatus(currentUserId: UUID, otherUserId: UUID) async throws -> FriendshipStatus? {
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .or("and(user_id_1.eq.\(currentUserId.uuidString),user_id_2.eq.\(otherUserId.uuidString)),and(user_id_1.eq.\(otherUserId.uuidString),user_id_2.eq.\(currentUserId.uuidString))")
            .execute()
            .value

        return friendships.first?.status
    }

    /// Get friendship between current user and another user
    func getFriendship(currentUserId: UUID, otherUserId: UUID) async throws -> Friendship? {
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .or("and(user_id_1.eq.\(currentUserId.uuidString),user_id_2.eq.\(otherUserId.uuidString)),and(user_id_1.eq.\(otherUserId.uuidString),user_id_2.eq.\(currentUserId.uuidString))")
            .execute()
            .value

        return friendships.first
    }
}

// MARK: - Errors

enum UserServiceError: LocalizedError {
    case friendshipAlreadyExists
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .friendshipAlreadyExists:
            return "You are already friends or have a pending request with this user"
        case .userNotFound:
            return "User not found"
        }
    }
}
