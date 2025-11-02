import Foundation
import Supabase

/// Service for user-related operations (search, friends, etc.)
class UserService {
    static let shared = UserService()

    private let supabase = PhlockSupabaseClient.shared.client

    // Cache for user data and friends list
    private var userCache: [UUID: User] = [:]
    private var friendsCache: [UUID: [User]] = [:]
    private var pendingRequestsCache: [UUID: [FriendshipWithUser]] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheExpiration: TimeInterval = 60 // 1 minute

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

    /// Get a specific user by ID (with caching)
    func getUser(userId: UUID) async throws -> User? {
        // Check cache first
        if let cachedUser = userCache[userId] {
            return cachedUser
        }

        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        // Cache the result
        if let user = users.first {
            userCache[userId] = user
        }

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

    /// Get all accepted friends for a user (with caching)
    func getFriends(for userId: UUID) async throws -> [User] {
        // Check cache first
        let cacheKey = "friends_\(userId.uuidString)"
        if let cachedFriends = friendsCache[userId],
           let timestamp = cacheTimestamp[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            print("⚡️ Using cached friends list")
            return cachedFriends
        }

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

        guard !friendIds.isEmpty else {
            // Cache empty result
            friendsCache[userId] = []
            cacheTimestamp[cacheKey] = Date()
            return []
        }

        // Fetch friend user data
        let friends: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: friendIds.map { $0.uuidString })
            .execute()
            .value

        // Cache the results
        friendsCache[userId] = friends
        cacheTimestamp[cacheKey] = Date()

        // Also cache individual users
        for friend in friends {
            userCache[friend.id] = friend
        }

        return friends
    }

    /// Get all pending friend requests (sent to the user) - optimized with batch query
    func getPendingRequests(for userId: UUID) async throws -> [FriendshipWithUser] {
        // Check cache first
        let cacheKey = "pending_\(userId.uuidString)"
        if let cachedRequests = pendingRequestsCache[userId],
           let timestamp = cacheTimestamp[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            print("⚡️ Using cached pending requests")
            return cachedRequests
        }

        // Get pending friendships where user is user_id_2 (recipient)
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .eq("user_id_2", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        guard !friendships.isEmpty else {
            // Cache empty result
            pendingRequestsCache[userId] = []
            cacheTimestamp[cacheKey] = Date()
            return []
        }

        // OPTIMIZATION: Batch fetch all requesters in ONE query instead of N queries
        let requesterIds = friendships.map { $0.userId1 }
        let requesters: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: requesterIds.map { $0.uuidString })
            .execute()
            .value

        // Create lookup dictionary
        let userDict = Dictionary(uniqueKeysWithValues: requesters.map { ($0.id, $0) })

        // Build friendships with user data
        var friendshipsWithUsers: [FriendshipWithUser] = []
        for friendship in friendships {
            if let user = userDict[friendship.userId1] {
                friendshipsWithUsers.append(
                    FriendshipWithUser(
                        id: friendship.id,
                        friendship: friendship,
                        user: user,
                        isRequester: false
                    )
                )

                // Cache individual users
                userCache[user.id] = user
            }
        }

        // Cache the results
        pendingRequestsCache[userId] = friendshipsWithUsers
        cacheTimestamp[cacheKey] = Date()

        return friendshipsWithUsers
    }

    /// Clear cache (call after accepting/rejecting friend requests)
    func clearCache(for userId: UUID) {
        friendsCache.removeValue(forKey: userId)
        pendingRequestsCache.removeValue(forKey: userId)
        cacheTimestamp.removeValue(forKey: "friends_\(userId.uuidString)")
        cacheTimestamp.removeValue(forKey: "pending_\(userId.uuidString)")
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
