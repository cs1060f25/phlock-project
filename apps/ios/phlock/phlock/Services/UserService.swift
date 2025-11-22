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

    /// Batch fetch users by IDs to avoid N+1 queries
    func getUsers(userIds: [UUID]) async throws -> [UUID: User] {
        let uniqueIds = Array(Set(userIds))
        guard !uniqueIds.isEmpty else { return [:] }

        // Serve cached users without hitting the network
        var result: [UUID: User] = [:]
        var idsToFetch: [UUID] = []
        for id in uniqueIds {
            if let cached = userCache[id] {
                result[id] = cached
            } else {
                idsToFetch.append(id)
            }
        }

        if !idsToFetch.isEmpty {
            let fetched: [User] = try await supabase
                .from("users")
                .select("*")
                .in("id", values: idsToFetch.map { $0.uuidString })
                .execute()
                .value

            for user in fetched {
                userCache[user.id] = user
                result[user.id] = user
            }
        }

        return result
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

    // MARK: - Phlock Management

    /// Get the user's phlock members (up to 5 friends with positions 1-5)
    /// Returns friends ordered by position (1 is first in playlist)
    func getPhlockMembers(for userId: UUID) async throws -> [FriendWithPosition] {
        // Get all friendships where user is either party and is_phlock_member = true
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
            .eq("status", value: "accepted")
            .eq("is_phlock_member", value: true)
            .order("position", ascending: true)
            .limit(5)
            .execute()
            .value

        guard !friendships.isEmpty else { return [] }

        // Extract friend IDs based on who the user is in the relationship
        var friendIdsWithPositions: [(UUID, Int?)] = []
        for friendship in friendships {
            let friendId = friendship.userId1 == userId ? friendship.userId2 : friendship.userId1
            friendIdsWithPositions.append((friendId, friendship.position))
        }

        // Batch fetch friend user data
        let friendIds = friendIdsWithPositions.map { $0.0 }
        let friends: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: friendIds.map { $0.uuidString })
            .execute()
            .value

        // Create lookup dictionary
        let userDict = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        // Build result with positions
        var result: [FriendWithPosition] = []
        for (friendId, position) in friendIdsWithPositions {
            if let user = userDict[friendId] {
                result.append(FriendWithPosition(user: user, position: position ?? 0))
            }
        }

        // Sort by position (1-5)
        return result.sorted { $0.position < $1.position }
    }

    /// Add a friend to the user's phlock at a specific position (1-5)
    /// If position is occupied, this will shift other members
    func addToPhlockAtPosition(friendId: UUID, position: Int, for userId: UUID) async throws {
        // Validate position
        guard (1...5).contains(position) else {
            throw UserServiceError.invalidPhlockPosition
        }

        // Check friendship exists and is accepted
        let friendship = try await getFriendship(currentUserId: userId, otherUserId: friendId)
        guard let friendship = friendship, friendship.status == .accepted else {
            throw UserServiceError.notFriends
        }

        // Check if user already has 5 phlock members
        let currentMembers = try await getPhlockMembers(for: userId)
        if currentMembers.count >= 5 && !currentMembers.contains(where: { $0.user.id == friendId }) {
            throw UserServiceError.phlockFull
        }

        // Update the friendship to add as phlock member with position
        struct PhlockUpdate: Encodable {
            let is_phlock_member: Bool
            let position: Int
            let last_swapped_at: String
        }

        let update = PhlockUpdate(
            is_phlock_member: true,
            position: position,
            last_swapped_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("friendships")
            .update(update)
            .eq("id", value: friendship.id.uuidString)
            .execute()

        // Clear cache since phlock changed
        clearCache(for: userId)
    }

    /// Remove a friend from the user's phlock
    func removeFromPhlock(friendId: UUID, for userId: UUID) async throws {
        let friendship = try await getFriendship(currentUserId: userId, otherUserId: friendId)
        guard let friendship = friendship else {
            throw UserServiceError.notFriends
        }

        // Update the friendship to remove from phlock
        struct PhlockRemoveUpdate: Encodable {
            let is_phlock_member: Bool
            let position: Int?
            let last_swapped_at: String
        }

        let update = PhlockRemoveUpdate(
            is_phlock_member: false,
            position: nil,
            last_swapped_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("friendships")
            .update(update)
            .eq("id", value: friendship.id.uuidString)
            .execute()

        // Clear cache since phlock changed
        clearCache(for: userId)
    }

    /// Reorder phlock members by updating positions
    /// Takes an array of friend IDs in desired order (position 1-5)
    func reorderPhlockMembers(friendIds: [UUID], for userId: UUID) async throws {
        guard friendIds.count <= 5 else {
            throw UserServiceError.phlockFull
        }

        // Update each friendship with new position
        for (index, friendId) in friendIds.enumerated() {
            let position = index + 1 // 1-indexed positions

            if let friendship = try await getFriendship(currentUserId: userId, otherUserId: friendId) {
                struct PhlockReorderUpdate: Encodable {
                    let is_phlock_member: Bool
                    let position: Int
                    let last_swapped_at: String
                }

                let update = PhlockReorderUpdate(
                    is_phlock_member: true,
                    position: position,
                    last_swapped_at: ISO8601DateFormatter().string(from: Date())
                )

                try await supabase
                    .from("friendships")
                    .update(update)
                    .eq("id", value: friendship.id.uuidString)
                    .execute()
            }
        }

        // Clear cache since phlock changed
        clearCache(for: userId)
    }

    /// Get all users who have included this user in their phlock (premium feature)
    /// Returns count and optionally the list of users
    func getWhoIncludesMe(userId: UUID) async throws -> (count: Int, users: [User]?) {
        // Get all friendships where user is included in someone's phlock
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("*")
            .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
            .eq("status", value: "accepted")
            .eq("is_phlock_member", value: true)
            .execute()
            .value

        // Filter to find who has current user as phlock member
        var includerIds: [UUID] = []
        for friendship in friendships {
            // If user is user_id_2, then user_id_1 included them
            if friendship.userId2 == userId {
                includerIds.append(friendship.userId1)
            }
            // If user is user_id_1, then user_id_2 included them
            else if friendship.userId1 == userId {
                includerIds.append(friendship.userId2)
            }
        }

        let count = includerIds.count

        // Fetch user data for includers
        guard !includerIds.isEmpty else {
            return (count: 0, users: [])
        }

        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: includerIds.map { $0.uuidString })
            .execute()
            .value

        return (count: count, users: users)
    }

    /// Check if a friend is in the user's phlock
    func isInPhlock(friendId: UUID, for userId: UUID) async throws -> Bool {
        let members = try await getPhlockMembers(for: userId)
        return members.contains { $0.user.id == friendId }
    }

    /// Get available phlock slots (5 - current members)
    func getAvailablePhlockSlots(for userId: UUID) async throws -> Int {
        let members = try await getPhlockMembers(for: userId)
        return max(0, 5 - members.count)
    }
}

// MARK: - Helper Structures

/// Represents a friend with their position in the user's phlock (1-5)
struct FriendWithPosition: Identifiable {
    let user: User
    let position: Int

    var id: UUID { user.id }
}

// MARK: - Errors

enum UserServiceError: LocalizedError {
    case friendshipAlreadyExists
    case userNotFound
    case invalidPhlockPosition
    case phlockFull
    case notFriends

    var errorDescription: String? {
        switch self {
        case .friendshipAlreadyExists:
            return "You are already friends or have a pending request with this user"
        case .userNotFound:
            return "User not found"
        case .invalidPhlockPosition:
            return "Phlock position must be between 1 and 5"
        case .phlockFull:
            return "Your phlock is full (max 5 members)"
        case .notFriends:
            return "You must be friends to add them to your phlock"
        }
    }
}
