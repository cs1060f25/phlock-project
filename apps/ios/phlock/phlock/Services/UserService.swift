import Foundation
import Supabase

/// Type alias for backward compatibility with views expecting FriendWithPosition
typealias FriendWithPosition = FollowWithPosition

/// Service for user-related operations (search, follows, etc.)
/// NOTE: This service now uses the follow model instead of the old friendship model.
/// The old friendship methods are deprecated and will delegate to FollowService.
class UserService {
    static let shared = UserService()

    private let supabase = PhlockSupabaseClient.shared.client
    private let followService = FollowService.shared

    // Cache for user data
    private var userCache: [UUID: User] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheExpiration: TimeInterval = 60 // 1 minute

    private init() {}

    // MARK: - User Search

    /// Search for users by display name or username
    /// If query starts with @, search by username only
    func searchUsers(query: String) async throws -> [User] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // If searching by username (starts with @), do exact prefix match
        if trimmedQuery.hasPrefix("@") {
            let usernameQuery = String(trimmedQuery.dropFirst()).lowercased()
            guard !usernameQuery.isEmpty else { return [] }

            let users: [User] = try await supabase
                .from("users")
                .select("*")
                .ilike("username", pattern: "\(usernameQuery)%")
                .limit(20)
                .execute()
                .value

            return users
        }

        // Otherwise, search by both display name and username
        // Use OR condition via Supabase's .or() method
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .or("display_name.ilike.%\(trimmedQuery)%,username.ilike.%\(trimmedQuery)%")
            .limit(20)
            .execute()
            .value

        return users
    }

    /// Find users whose phone numbers match the provided contact numbers
    func findUsersByPhones(phoneNumbers: [String]) async throws -> [User] {
        let normalizedPhones = Array(
            Set(
                phoneNumbers
                    .map { ContactsService.normalizePhone($0) }
                    .filter { !$0.isEmpty }
            )
        )

        guard !normalizedPhones.isEmpty else { return [] }

        var results: [User] = []
        let chunkSize = 50
        let chunks = stride(from: 0, to: normalizedPhones.count, by: chunkSize).map { index in
            Array(normalizedPhones[index..<min(index + chunkSize, normalizedPhones.count)])
        }

        for chunk in chunks {
            let users: [User] = try await supabase
                .from("users")
                .select("*")
                .in("phone", values: chunk)
                .execute()
                .value

            results.append(contentsOf: users)
        }

        // Deduplicate by user id
        let unique = Dictionary(grouping: results, by: { $0.id }).compactMap { $0.value.first }
        return unique
    }

    /// Get a specific user by ID (with caching)
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - bypassCache: If true, fetches fresh data from the database (useful for getting up-to-date lastDailySongDate)
    func getUser(userId: UUID, bypassCache: Bool = false) async throws -> User? {
        // Check cache first (unless bypassing)
        if !bypassCache, let cachedUser = userCache[userId] {
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

    // MARK: - Follow/Unfollow (replaces Friend Requests)

    /// Follow a user (replaces sendFriendRequest - no acceptance needed)
    func sendFriendRequest(to userId: UUID, from currentUserId: UUID) async throws {
        try await followService.follow(userId: userId, currentUserId: currentUserId)
    }

    /// Follow a user
    func follow(userId: UUID, currentUserId: UUID) async throws {
        try await followService.follow(userId: userId, currentUserId: currentUserId)
    }

    /// Unfollow a user
    func unfollow(userId: UUID, currentUserId: UUID) async throws {
        try await followService.unfollow(userId: userId, currentUserId: currentUserId)
    }

    /// Check if current user follows another user
    func isFollowing(userId: UUID, currentUserId: UUID) async throws -> Bool {
        try await followService.isFollowing(userId: userId, currentUserId: currentUserId)
    }

    /// Get relationship status between users
    func getRelationshipStatus(currentUserId: UUID, otherUserId: UUID) async throws -> RelationshipStatus {
        try await followService.getRelationshipStatus(currentUserId: currentUserId, otherUserId: otherUserId)
    }

    /// Accept a friend request - DEPRECATED: Now just follows back
    /// Kept for backward compatibility with existing UI
    func acceptFriendRequest(friendshipId: UUID, currentUserId: UUID) async throws {
        // In the new model, "accepting" means following back
        // We need to find who sent the original follow
        // For now, this is a no-op since follows don't need acceptance
        print("⚠️ acceptFriendRequest is deprecated - follows don't require acceptance")
    }

    /// Reject/remove a follow relationship - DEPRECATED
    func rejectFriendRequest(friendshipId: UUID) async throws {
        // In the new model, this would be unfollowing
        print("⚠️ rejectFriendRequest is deprecated - use unfollow instead")
    }

    // MARK: - Following/Followers Lists (replaces Friends List)

    /// Get all users this user follows (replaces getFriends)
    /// For backward compatibility, this returns users the person follows
    func getFriends(for userId: UUID) async throws -> [User] {
        try await followService.getFollowing(for: userId)
    }

    /// Get all users this user follows
    func getFollowing(for userId: UUID) async throws -> [User] {
        try await followService.getFollowing(for: userId)
    }

    /// Get all users who follow this user
    func getFollowers(for userId: UUID) async throws -> [User] {
        try await followService.getFollowers(for: userId)
    }

    /// Get mutual follows (both follow each other)
    func getMutualFollows(for userId: UUID) async throws -> [User] {
        try await followService.getMutualFollows(for: userId)
    }

    /// Get all pending friend requests - DEPRECATED
    /// In the follow model, there are no pending requests - follows are instant
    func getPendingRequests(for userId: UUID) async throws -> [FriendshipWithUser] {
        // Return empty - follows don't require acceptance
        return []
    }

    /// Clear cache (call after follow/unfollow or phlock changes)
    func clearCache(for userId: UUID) {
        followService.clearCache(for: userId)
        cacheTimestamp.removeAll()
    }

    /// Get friendship status - DEPRECATED: Use getRelationshipStatus instead
    func getFriendshipStatus(currentUserId: UUID, otherUserId: UUID) async throws -> FriendshipStatus? {
        let status = try await getRelationshipStatus(currentUserId: currentUserId, otherUserId: otherUserId)
        // For backward compatibility, return .accepted if following
        return status.isFollowing ? .accepted : nil
    }

    /// Get friendship - DEPRECATED: Use FollowService.getFollow instead
    func getFriendship(currentUserId: UUID, otherUserId: UUID) async throws -> Friendship? {
        // Return nil - use the new follow model instead
        return nil
    }

    // MARK: - Phlock Management

    /// Get the user's phlock members (up to 5 users with positions 1-5)
    /// Returns users ordered by position (1 is first in playlist)
    func getPhlockMembers(for userId: UUID) async throws -> [FriendWithPosition] {
        try await followService.getPhlockMembers(for: userId)
    }

    /// Add a user to the phlock at a specific position
    func addToPhlockAtPosition(friendId: UUID, position: Int, for userId: UUID) async throws {
        try await followService.addToPhlock(userId: friendId, position: position, currentUserId: userId)
    }

    /// Remove a user from the phlock
    func removeFromPhlock(friendId: UUID, for userId: UUID) async throws {
        try await followService.removeFromPhlock(userId: friendId, currentUserId: userId)
    }

    /// Reorder phlock members
    func reorderPhlockMembers(friendIds: [UUID], for userId: UUID) async throws {
        try await followService.reorderPhlock(userIds: friendIds, currentUserId: userId)
    }

    /// Schedule a phlock swap (immediate if new member hasn't picked today, scheduled for midnight otherwise)
    func scheduleSwap(oldMemberId: UUID, newMemberId: UUID, for userId: UUID) async throws -> Bool {
        try await followService.swapPhlockMember(oldUserId: oldMemberId, newUserId: newMemberId, currentUserId: userId)
    }

    /// Schedule a phlock member removal for midnight (when they've already picked today)
    func scheduleRemoval(memberId: UUID, for userId: UUID) async throws {
        try await followService.scheduleRemoval(userId: memberId, currentUserId: userId)
    }

    /// Cancel a scheduled removal for a phlock member
    func cancelScheduledRemoval(memberId: UUID, for userId: UUID) async throws {
        try await followService.cancelScheduledRemoval(userId: memberId, currentUserId: userId)
    }

    /// Get all pending scheduled removals (member IDs scheduled to be removed at midnight)
    func getScheduledRemovals(for userId: UUID) async throws -> Set<UUID> {
        try await followService.getScheduledRemovals(for: userId)
    }

    /// Get who has this user in their phlock
    func getWhoIncludesMe(userId: UUID) async throws -> (count: Int, users: [User]?) {
        try await followService.getWhoHasMeInPhlock(userId: userId)
    }

    /// Check if a user is in the phlock
    func isInPhlock(friendId: UUID, for userId: UUID) async throws -> Bool {
        let members = try await getPhlockMembers(for: userId)
        return members.contains { $0.user.id == friendId }
    }

    /// Get available phlock slots
    func getAvailablePhlockSlots(for userId: UUID) async throws -> Int {
        let members = try await getPhlockMembers(for: userId)
        return max(0, 5 - members.count)
    }

    /// Get pending scheduled swaps for a user
    func getPendingSwaps(for userId: UUID) async throws -> [ScheduledSwap] {
        let swaps: [ScheduledSwap] = try await supabase
            .from("scheduled_swaps")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        return swaps
    }
    // MARK: - Blocking and Reporting

    /// Block a user
    func blockUser(userId: UUID, currentUserId: UUID) async throws {
        // 1. Remove follow relationships in both directions
        try? await followService.unfollow(userId: userId, currentUserId: currentUserId)
        // Note: We can't unfollow on their behalf, but blocking will prevent interactions

        // 2. Add to blocked_users table
        struct BlockInsert: Encodable, @unchecked Sendable {
            let blocker_id: String
            let blocked_id: String
        }

        let insert = BlockInsert(
            blocker_id: currentUserId.uuidString,
            blocked_id: userId.uuidString
        )

        try await supabase
            .from("blocked_users")
            .insert(insert)
            .execute()

        // 3. Clear cache
        clearCache(for: currentUserId)
    }

    /// Report a user
    func reportUser(userId: UUID, reporterId: UUID, reason: String) async throws {
        struct ReportInsert: Encodable, @unchecked Sendable {
            let reporter_id: String
            let reported_id: String
            let reason: String
            let status: String
        }

        let insert = ReportInsert(
            reporter_id: reporterId.uuidString,
            reported_id: userId.uuidString,
            reason: reason,
            status: "pending"
        )

        try await supabase
            .from("user_reports")
            .insert(insert)
            .execute()
    }

    // MARK: - Phone Number Management

    /// Update user's phone number
    /// The database trigger will automatically compute phone_hash
    func updateUserPhone(_ phone: String, for userId: UUID) async throws {
        let normalized = ContactsService.normalizePhone(phone)
        guard !normalized.isEmpty else {
            print("⚠️ Cannot update phone - normalized phone is empty")
            return
        }

        struct PhoneUpdate: Encodable {
            let phone: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(PhoneUpdate(
                phone: normalized,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: userId.uuidString)
            .execute()

        // Clear cache so next fetch gets updated phone
        userCache.removeValue(forKey: userId)

        print("📱 Phone number updated for user: \(userId)")
    }

    // MARK: - Platform Data Management

    /// Update user's platform data (topArtists and topTracks)
    /// Used for manual selection of favorite artists and tracks
    /// Returns the updated user with the new platform data
    @discardableResult
    func updatePlatformData(userId: UUID, topArtists: [MusicItem]?, topTracks: [MusicItem]?) async throws -> User {
        // Fetch current platform data to preserve other fields
        guard let user = try await getUser(userId: userId, bypassCache: true) else {
            throw UserServiceError.userNotFound
        }

        // Create updated platform data, preserving existing fields
        let existingData = user.platformData
        let updatedData = PlatformUserData(
            spotifyEmail: existingData?.spotifyEmail,
            spotifyDisplayName: existingData?.spotifyDisplayName,
            spotifyImageUrl: existingData?.spotifyImageUrl,
            spotifyCountry: existingData?.spotifyCountry,
            spotifyProduct: existingData?.spotifyProduct,
            appleMusicUserId: existingData?.appleMusicUserId,
            appleMusicStorefront: existingData?.appleMusicStorefront,
            topArtists: topArtists ?? existingData?.topArtists,
            topTracks: topTracks ?? existingData?.topTracks,
            recentlyPlayed: existingData?.recentlyPlayed,
            playlists: existingData?.playlists
        )

        // Encode platform data as JSON string
        let platformDataJSON = String(data: try JSONEncoder().encode(updatedData), encoding: .utf8) ?? "{}"

        struct UpdatePayload: Encodable {
            let platform_data: String
            let updated_at: String
        }

        try await supabase
            .from("users")
            .update(UpdatePayload(
                platform_data: platformDataJSON,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: userId.uuidString)
            .execute()

        // Construct the updated user locally
        let updatedUser = User(
            id: user.id,
            displayName: user.displayName,
            profilePhotoUrl: user.profilePhotoUrl,
            bio: user.bio,
            email: user.email,
            phone: user.phone,
            platformType: user.platformType,
            platformUserId: user.platformUserId,
            platformData: updatedData,
            privacyWhoCanSend: user.privacyWhoCanSend,
            createdAt: user.createdAt,
            updatedAt: Date(),
            authUserId: user.authUserId,
            authProvider: user.authProvider,
            musicPlatform: user.musicPlatform,
            spotifyUserId: user.spotifyUserId,
            appleUserId: user.appleUserId,
            username: user.username,
            phlockCount: user.phlockCount,
            dailySongStreak: user.dailySongStreak,
            lastDailySongDate: user.lastDailySongDate,
            isPrivate: user.isPrivate
        )

        // Update cache so next fetch gets updated data
        userCache[userId] = updatedUser

        print("✅ Platform data updated for user: \(userId)")

        return updatedUser
    }
}

// MARK: - Helper Structures

/// Represents a scheduled swap
struct ScheduledSwap: Decodable, @unchecked Sendable {
    let id: UUID
    let userId: UUID
    let oldMemberId: UUID
    let newMemberId: UUID
    let scheduledFor: Date
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case oldMemberId = "old_member_id"
        case newMemberId = "new_member_id"
        case scheduledFor = "scheduled_for"
        case status
    }
}

// MARK: - Errors

enum UserServiceError: LocalizedError {
    case friendshipAlreadyExists
    case friendshipNotFound
    case userNotFound
    case invalidPhlockPosition
    case phlockFull
    case notFriends
    case schedulingFailed

    var errorDescription: String? {
        switch self {
        case .friendshipAlreadyExists:
            return "You are already friends or have a pending request with this user"
        case .friendshipNotFound:
            return "Friend request not found"
        case .userNotFound:
            return "User not found"
        case .invalidPhlockPosition:
            return "Phlock position must be between 1 and 5"
        case .phlockFull:
            return "Your phlock is full (max 5 members)"
        case .notFriends:
            return "You must be friends to add them to your phlock"
        case .schedulingFailed:
            return "Failed to schedule swap"
        }
    }
}
