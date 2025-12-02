import Foundation
import Supabase

/// Service for follow-related operations (follow, unfollow, phlock management)
/// Uses the unilateral follow model where A can follow B without B following A
/// Thread-safe using actor isolation for cache access
class FollowService {
    static let shared = FollowService()

    private let supabase = PhlockSupabaseClient.shared.client

    // Thread-safe cache actor
    private actor CacheStore {
        var followingCache: [UUID: [User]] = [:]
        var followersCache: [UUID: [User]] = [:]
        var phlockMembersCache: [UUID: [FollowWithPosition]] = [:]
        var cacheTimestamp: [String: Date] = [:]
        let cacheExpiration: TimeInterval = 60 // 1 minute

        func getFollowing(for userId: UUID) -> [User]? {
            let cacheKey = "following_\(userId.uuidString)"
            guard let cached = followingCache[userId],
                  let timestamp = cacheTimestamp[cacheKey],
                  Date().timeIntervalSince(timestamp) < cacheExpiration else {
                return nil
            }
            return cached
        }

        func setFollowing(_ users: [User], for userId: UUID) {
            let cacheKey = "following_\(userId.uuidString)"
            followingCache[userId] = users
            cacheTimestamp[cacheKey] = Date()
        }

        func getFollowers(for userId: UUID) -> [User]? {
            let cacheKey = "followers_\(userId.uuidString)"
            guard let cached = followersCache[userId],
                  let timestamp = cacheTimestamp[cacheKey],
                  Date().timeIntervalSince(timestamp) < cacheExpiration else {
                return nil
            }
            return cached
        }

        func setFollowers(_ users: [User], for userId: UUID) {
            let cacheKey = "followers_\(userId.uuidString)"
            followersCache[userId] = users
            cacheTimestamp[cacheKey] = Date()
        }

        func getPhlockMembers(for userId: UUID) -> [FollowWithPosition]? {
            let cacheKey = "phlock_\(userId.uuidString)"
            guard let cached = phlockMembersCache[userId],
                  let timestamp = cacheTimestamp[cacheKey],
                  Date().timeIntervalSince(timestamp) < cacheExpiration else {
                return nil
            }
            return cached
        }

        func setPhlockMembers(_ members: [FollowWithPosition], for userId: UUID) {
            let cacheKey = "phlock_\(userId.uuidString)"
            phlockMembersCache[userId] = members
            cacheTimestamp[cacheKey] = Date()
        }

        func clear(for userId: UUID) {
            followingCache.removeValue(forKey: userId)
            followersCache.removeValue(forKey: userId)
            phlockMembersCache.removeValue(forKey: userId)
            cacheTimestamp.removeValue(forKey: "following_\(userId.uuidString)")
            cacheTimestamp.removeValue(forKey: "followers_\(userId.uuidString)")
            cacheTimestamp.removeValue(forKey: "phlock_\(userId.uuidString)")
        }

        func clearAll() {
            followingCache.removeAll()
            followersCache.removeAll()
            phlockMembersCache.removeAll()
            cacheTimestamp.removeAll()
        }
    }

    private let cache = CacheStore()

    private init() {}

    // MARK: - Follow/Unfollow

    /// Follow a user
    func follow(userId: UUID, currentUserId: UUID) async throws {
        // Check if already following
        let existing = try await getFollow(followerId: currentUserId, followingId: userId)
        if existing != nil {
            throw FollowServiceError.alreadyFollowing
        }

        // Create follow relationship
        struct FollowInsert: Encodable {
            let follower_id: String
            let following_id: String
        }

        let followData = FollowInsert(
            follower_id: currentUserId.uuidString,
            following_id: userId.uuidString
        )

        try await supabase
            .from("follows")
            .insert(followData)
            .execute()

        // Clear caches
        clearCache(for: currentUserId)

        // Notify the user that they have a new follower
        Task {
            do {
                try await NotificationService.shared.createNewFollowerNotification(
                    userId: userId,
                    followerId: currentUserId
                )
            } catch {
                print("⚠️ Failed to create new follower notification: \(error)")
            }
        }
    }

    /// Unfollow a user
    func unfollow(userId: UUID, currentUserId: UUID) async throws {
        try await supabase
            .from("follows")
            .delete()
            .eq("follower_id", value: currentUserId.uuidString)
            .eq("following_id", value: userId.uuidString)
            .execute()

        // Clear caches
        clearCache(for: currentUserId)
    }

    /// Check if current user is following another user
    func isFollowing(userId: UUID, currentUserId: UUID) async throws -> Bool {
        let follow = try await getFollow(followerId: currentUserId, followingId: userId)
        return follow != nil
    }

    /// Get the follow relationship between two users
    func getFollow(followerId: UUID, followingId: UUID) async throws -> Follow? {
        let follows: [Follow] = try await supabase
            .from("follows")
            .select("*")
            .eq("follower_id", value: followerId.uuidString)
            .eq("following_id", value: followingId.uuidString)
            .limit(1)
            .execute()
            .value

        return follows.first
    }

    /// Get full relationship status between current user and another user
    func getRelationshipStatus(currentUserId: UUID, otherUserId: UUID) async throws -> RelationshipStatus {
        let currentFollowsThem = try await self.isFollowing(userId: otherUserId, currentUserId: currentUserId)
        let theyFollowCurrent = try await self.isFollowing(userId: currentUserId, currentUserId: otherUserId)

        // Check for pending follow request if not already following
        var hasPendingRequest = false
        if !currentFollowsThem {
            let pendingRequest = try await getFollowRequest(requesterId: currentUserId, targetId: otherUserId)
            hasPendingRequest = pendingRequest?.status == .pending
        }

        return RelationshipStatus(
            isFollowing: currentFollowsThem,
            isFollowedBy: theyFollowCurrent,
            isMutual: currentFollowsThem && theyFollowCurrent,
            hasPendingRequest: hasPendingRequest
        )
    }

    /// Follow a user or send a follow request if they have a private profile
    func followOrRequest(userId: UUID, currentUserId: UUID, targetUser: User) async throws {
        if targetUser.isPrivate {
            // Send follow request for private profiles
            try await sendFollowRequest(to: userId, from: currentUserId)
        } else {
            // Directly follow public profiles
            try await follow(userId: userId, currentUserId: currentUserId)
        }
    }

    // MARK: - Following/Followers Lists

    /// Get all users that a user is following (with caching)
    func getFollowing(for userId: UUID) async throws -> [User] {
        // Check cache first (thread-safe via actor)
        if let cached = await cache.getFollowing(for: userId) {
            return cached
        }

        // Get all follows where user is the follower
        let follows: [Follow] = try await supabase
            .from("follows")
            .select("*")
            .eq("follower_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        let followingIds = follows.map { $0.followingId }

        guard !followingIds.isEmpty else {
            await cache.setFollowing([], for: userId)
            return []
        }

        // Fetch user data
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: followingIds.map { $0.uuidString })
            .execute()
            .value

        await cache.setFollowing(users, for: userId)

        return users
    }

    /// Get all users who follow a user (with caching)
    func getFollowers(for userId: UUID) async throws -> [User] {
        // Check cache first (thread-safe via actor)
        if let cached = await cache.getFollowers(for: userId) {
            return cached
        }

        // Get all follows where user is being followed
        let follows: [Follow] = try await supabase
            .from("follows")
            .select("*")
            .eq("following_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        let followerIds = follows.map { $0.followerId }

        guard !followerIds.isEmpty else {
            await cache.setFollowers([], for: userId)
            return []
        }

        // Fetch user data
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: followerIds.map { $0.uuidString })
            .execute()
            .value

        await cache.setFollowers(users, for: userId)

        return users
    }

    /// Get mutual follows (users who follow each other)
    func getMutualFollows(for userId: UUID) async throws -> [User] {
        let following = try await getFollowing(for: userId)
        let followers = try await getFollowers(for: userId)

        let followerIds = Set(followers.map { $0.id })
        return following.filter { followerIds.contains($0.id) }
    }

    // MARK: - Phlock Management

    /// Get the user's phlock members (up to 5 users they follow with positions 1-5)
    func getPhlockMembers(for userId: UUID) async throws -> [FollowWithPosition] {
        // Check cache first (thread-safe via actor)
        if let cached = await cache.getPhlockMembers(for: userId) {
            return cached
        }

        // Get follows where user has added someone to their phlock
        let follows: [Follow] = try await supabase
            .from("follows")
            .select("*")
            .eq("follower_id", value: userId.uuidString)
            .eq("is_in_phlock", value: true)
            .order("phlock_position", ascending: true)
            .execute()
            .value

        guard !follows.isEmpty else {
            await cache.setPhlockMembers([], for: userId)
            return []
        }

        // Fetch user data
        let userIds = follows.map { $0.followingId }
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: userIds.map { $0.uuidString })
            .execute()
            .value

        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        // Build result with positions
        var result: [FollowWithPosition] = []
        for follow in follows {
            guard let user = userDict[follow.followingId],
                  let position = follow.phlockPosition else { continue }
            result.append(FollowWithPosition(user: user, position: position))
        }

        // Sort by position
        result.sort { $0.position < $1.position }

        await cache.setPhlockMembers(result, for: userId)

        return result
    }

    /// Add someone to your phlock at a specific position
    /// Requires that you already follow them
    func addToPhlock(userId: UUID, position: Int, currentUserId: UUID) async throws {
        guard (1...5).contains(position) else {
            throw FollowServiceError.invalidPhlockPosition
        }

        // Check if following
        guard let follow = try await getFollow(followerId: currentUserId, followingId: userId) else {
            throw FollowServiceError.mustFollowFirst
        }

        // Check current phlock count
        let currentPhlock = try await getPhlockMembers(for: currentUserId)
        let isAlreadyInPhlock = currentPhlock.contains { $0.user.id == userId }

        if !isAlreadyInPhlock && currentPhlock.count >= 5 {
            throw FollowServiceError.phlockFull
        }

        // If position is occupied by someone else, remove them first
        if let conflicting = currentPhlock.first(where: { $0.position == position && $0.user.id != userId }) {
            try await removeFromPhlock(userId: conflicting.user.id, currentUserId: currentUserId)
        }

        // Update the follow to add to phlock
        struct PhlockUpdate: Encodable {
            let is_in_phlock: Bool
            let phlock_position: Int
            let phlock_added_at: String
        }

        let update = PhlockUpdate(
            is_in_phlock: true,
            phlock_position: position,
            phlock_added_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("follows")
            .update(update)
            .eq("id", value: follow.id.uuidString)
            .execute()

        clearCache(for: currentUserId)
    }

    /// Remove someone from your phlock
    func removeFromPhlock(userId: UUID, currentUserId: UUID) async throws {
        guard let follow = try await getFollow(followerId: currentUserId, followingId: userId) else {
            throw FollowServiceError.notFollowing
        }

        struct PhlockRemove: Encodable {
            let is_in_phlock: Bool
            let phlock_position: Int?
            let phlock_added_at: String?
        }

        let update = PhlockRemove(
            is_in_phlock: false,
            phlock_position: nil,
            phlock_added_at: nil
        )

        try await supabase
            .from("follows")
            .update(update)
            .eq("id", value: follow.id.uuidString)
            .execute()

        clearCache(for: currentUserId)
    }

    /// Reorder phlock members
    func reorderPhlock(userIds: [UUID], currentUserId: UUID) async throws {
        guard userIds.count <= 5 else {
            throw FollowServiceError.phlockFull
        }

        for (index, userId) in userIds.enumerated() {
            let position = index + 1
            if let follow = try await getFollow(followerId: currentUserId, followingId: userId) {
                struct PhlockUpdate: Encodable {
                    let is_in_phlock: Bool
                    let phlock_position: Int
                    let phlock_added_at: String
                }

                let update = PhlockUpdate(
                    is_in_phlock: true,
                    phlock_position: position,
                    phlock_added_at: ISO8601DateFormatter().string(from: Date())
                )

                try await supabase
                    .from("follows")
                    .update(update)
                    .eq("id", value: follow.id.uuidString)
                    .execute()
            }
        }

        clearCache(for: currentUserId)
    }

    /// Swap phlock members (immediate or scheduled)
    func swapPhlockMember(oldUserId: UUID, newUserId: UUID, currentUserId: UUID) async throws -> Bool {
        let currentPhlock = try await getPhlockMembers(for: currentUserId)

        guard let oldMember = currentPhlock.first(where: { $0.user.id == oldUserId }) else {
            throw FollowServiceError.userNotInPhlock
        }

        // Check if new user has picked a song today
        let newUserHasSongToday = (try? await ShareService.shared.getTodaysDailySong(for: newUserId)) != nil

        if !newUserHasSongToday {
            // Immediate swap
            try await removeFromPhlock(userId: oldUserId, currentUserId: currentUserId)
            try await addToPhlock(userId: newUserId, position: oldMember.position, currentUserId: currentUserId)
            return true
        }

        // Schedule for midnight
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            throw FollowServiceError.schedulingFailed
        }

        struct ScheduledSwapInsert: Encodable {
            let user_id: String
            let old_member_id: String
            let new_member_id: String
            let scheduled_for: String
            let status: String
        }

        let insert = ScheduledSwapInsert(
            user_id: currentUserId.uuidString,
            old_member_id: oldUserId.uuidString,
            new_member_id: newUserId.uuidString,
            scheduled_for: ISO8601DateFormatter().string(from: midnight),
            status: "pending"
        )

        try await supabase
            .from("scheduled_swaps")
            .insert(insert)
            .execute()

        return false
    }

    /// Get all users who currently have the current user in their phlock
    func getWhoHasMeInPhlock(userId: UUID) async throws -> (count: Int, users: [User]?) {
        let follows: [Follow] = try await supabase
            .from("follows")
            .select("*")
            .eq("following_id", value: userId.uuidString)
            .eq("is_in_phlock", value: true)
            .execute()
            .value

        let followerIds = follows.map { $0.followerId }
        let count = followerIds.count

        guard !followerIds.isEmpty else {
            return (count: 0, users: [])
        }

        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: followerIds.map { $0.uuidString })
            .execute()
            .value

        return (count: count, users: users)
    }

    /// Get historical reach: count of unique users who have EVER had this user in their phlock
    /// This queries the phlock_history table which tracks all-time phlock additions
    func getHistoricalReach(userId: UUID) async throws -> Int {
        // Query phlock_history for distinct phlock owners who have ever added this user
        // Use lowercased UUID to match Postgres format
        let userIdString = userId.uuidString.lowercased()
        print("🔍 getHistoricalReach: querying for phlock_member_id = \(userIdString)")

        let history: [[String: String]] = try await supabase
            .from("phlock_history")
            .select("phlock_owner_id")
            .eq("phlock_member_id", value: userIdString)
            .execute()
            .value

        print("🔍 getHistoricalReach: got \(history.count) records: \(history)")

        // Count unique phlock owners
        let uniqueOwners = Set(history.compactMap { $0["phlock_owner_id"] })
        print("🔍 getHistoricalReach: unique owners = \(uniqueOwners.count)")
        return uniqueOwners.count
    }

    // MARK: - Follow Requests (for private profiles)

    /// Send a follow request to a private profile
    func sendFollowRequest(to targetId: UUID, from requesterId: UUID) async throws {
        // Check if already following
        let existing = try await getFollow(followerId: requesterId, followingId: targetId)
        if existing != nil {
            throw FollowServiceError.alreadyFollowing
        }

        // Check if request already exists
        let existingRequest = try await getFollowRequest(requesterId: requesterId, targetId: targetId)
        if existingRequest != nil {
            throw FollowServiceError.requestAlreadyExists
        }

        struct FollowRequestInsert: Encodable {
            let requester_id: String
            let target_id: String
        }

        let requestData = FollowRequestInsert(
            requester_id: requesterId.uuidString,
            target_id: targetId.uuidString
        )

        try await supabase
            .from("follow_requests")
            .insert(requestData)
            .execute()

        // Notify the target user that they received a follow request
        Task {
            do {
                try await NotificationService.shared.createFollowRequestNotification(
                    userId: targetId,
                    requesterId: requesterId
                )
            } catch {
                print("⚠️ Failed to create follow request notification: \(error)")
            }
        }
    }

    /// Get a specific follow request
    func getFollowRequest(requesterId: UUID, targetId: UUID) async throws -> FollowRequest? {
        let requests: [FollowRequest] = try await supabase
            .from("follow_requests")
            .select("*")
            .eq("requester_id", value: requesterId.uuidString)
            .eq("target_id", value: targetId.uuidString)
            .limit(1)
            .execute()
            .value

        return requests.first
    }

    /// Get all pending follow requests for the current user (incoming)
    func getPendingFollowRequests(for userId: UUID) async throws -> [FollowRequestWithUser] {
        let requests: [FollowRequest] = try await supabase
            .from("follow_requests")
            .select("*")
            .eq("target_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !requests.isEmpty else { return [] }

        // Fetch requester user data
        let requesterIds = requests.map { $0.requesterId }
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: requesterIds.map { $0.uuidString })
            .execute()
            .value

        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        return requests.compactMap { request in
            guard let user = userDict[request.requesterId] else { return nil }
            return FollowRequestWithUser(id: request.id, request: request, user: user)
        }
    }

    /// Accept a follow request
    func acceptFollowRequest(requestId: UUID) async throws {
        // Use the database function that handles creating the follow relationship
        try await supabase.rpc("accept_follow_request", params: ["request_id": requestId.uuidString]).execute()
    }

    /// Reject a follow request
    func rejectFollowRequest(requestId: UUID) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let responded_at: String
        }

        let update = StatusUpdate(
            status: "rejected",
            responded_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("follow_requests")
            .update(update)
            .eq("id", value: requestId.uuidString)
            .execute()
    }

    /// Cancel a follow request (as requester)
    func cancelFollowRequest(requestId: UUID) async throws {
        try await supabase
            .from("follow_requests")
            .delete()
            .eq("id", value: requestId.uuidString)
            .execute()
    }

    /// Get the count of pending follow requests
    func getPendingFollowRequestCount(for userId: UUID) async throws -> Int {
        let requests: [FollowRequest] = try await supabase
            .from("follow_requests")
            .select("id")
            .eq("target_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        return requests.count
    }

    // MARK: - Friend Recommendations

    /// Get recommended friends for the current user
    /// Aggregates recommendations from contacts, mutual friends, and general discovery
    func getRecommendedFriends(for userId: UUID, contactMatches: [ContactMatch] = []) async throws -> [RecommendedFriend] {
        var recommendations: [RecommendedFriend] = []
        var seenUserIds = Set<UUID>()

        // Get users we're already following to exclude them
        let following = try await getFollowing(for: userId)
        let followingIds = Set(following.map { $0.id })

        // 1. Add contact matches (highest priority)
        for contact in contactMatches {
            guard !followingIds.contains(contact.user.id),
                  contact.user.id != userId,
                  !seenUserIds.contains(contact.user.id) else { continue }
            recommendations.append(RecommendedFriend(user: contact.user, context: .inContacts))
            seenUserIds.insert(contact.user.id)
        }

        // 2. Get mutual friends (friends of friends)
        let mutualRecommendations = try await getMutualFriendRecommendations(for: userId, excluding: followingIds.union(seenUserIds))
        for rec in mutualRecommendations where !seenUserIds.contains(rec.user.id) {
            recommendations.append(rec)
            seenUserIds.insert(rec.user.id)
        }

        // 3. Get "you may know" recommendations (users with similar activity or popular users)
        let youMayKnow = try await getYouMayKnowRecommendations(for: userId, excluding: followingIds.union(seenUserIds))
        for rec in youMayKnow where !seenUserIds.contains(rec.user.id) {
            recommendations.append(rec)
            seenUserIds.insert(rec.user.id)
        }

        return recommendations
    }

    /// Get recommendations based on mutual friends (friends of friends)
    /// Uses parallel fetching to avoid N+1 query performance issues
    private func getMutualFriendRecommendations(for userId: UUID, excluding: Set<UUID>) async throws -> [RecommendedFriend] {
        // Get who I follow
        let myFollowing = try await getFollowing(for: userId)

        guard !myFollowing.isEmpty else { return [] }

        // Fetch all friends' following lists in parallel (limit to 10 to reduce load)
        let friendsToQuery = Array(myFollowing.prefix(10))

        // Use TaskGroup for parallel fetching
        var friendsOfFriends: [UUID: Int] = [:]

        await withTaskGroup(of: [User].self) { group in
            for friend in friendsToQuery {
                group.addTask {
                    (try? await self.getFollowing(for: friend.id)) ?? []
                }
            }

            for await theirFollowing in group {
                for user in theirFollowing {
                    guard user.id != userId, !excluding.contains(user.id) else { continue }
                    friendsOfFriends[user.id, default: 0] += 1
                }
            }
        }

        // Sort by mutual count and take top 20
        let sortedIds = friendsOfFriends
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map { $0.key }

        guard !sortedIds.isEmpty else { return [] }

        // Fetch user data
        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: sortedIds.map { $0.uuidString })
            .execute()
            .value

        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        return sortedIds.compactMap { id -> RecommendedFriend? in
            guard let user = userDict[id] else { return nil }
            return RecommendedFriend(
                user: user,
                context: .mutualFriends,
                mutualCount: friendsOfFriends[id]
            )
        }
    }

    /// Get "you may know" recommendations based on popularity or recent activity
    private func getYouMayKnowRecommendations(for userId: UUID, excluding: Set<UUID>) async throws -> [RecommendedFriend] {
        // Get popular users (high phlock_count) that we're not following
        let excludeIds = Array(excluding).map { $0.uuidString }

        var query = supabase
            .from("users")
            .select("*")
            .neq("id", value: userId.uuidString)
            .gt("phlock_count", value: 0)
            .order("phlock_count", ascending: false)
            .limit(30)

        // Note: Can't directly exclude array in Supabase Swift SDK easily,
        // so we'll filter after fetching
        let users: [User] = try await query.execute().value

        return users
            .filter { !excluding.contains($0.id) }
            .prefix(15)
            .map { RecommendedFriend(user: $0, context: .youMayKnow) }
    }

    /// Get recommendations grouped by context type for section display
    func getRecommendationsByContext(for userId: UUID, contactMatches: [ContactMatch] = []) async throws -> [RecommendationContext: [RecommendedFriend]] {
        let all = try await getRecommendedFriends(for: userId, contactMatches: contactMatches)
        return Dictionary(grouping: all) { $0.context }
    }

    // MARK: - Cache Management

    func clearCache(for userId: UUID) {
        Task {
            await cache.clear(for: userId)
        }
    }

    func clearAllCaches() {
        Task {
            await cache.clearAll()
        }
    }
}

// MARK: - Errors

enum FollowServiceError: LocalizedError {
    case alreadyFollowing
    case notFollowing
    case mustFollowFirst
    case invalidPhlockPosition
    case phlockFull
    case userNotInPhlock
    case schedulingFailed
    case requestAlreadyExists
    case requestNotFound

    var errorDescription: String? {
        switch self {
        case .alreadyFollowing:
            return "You're already following this user"
        case .notFollowing:
            return "You're not following this user"
        case .mustFollowFirst:
            return "You must follow this user before adding them to your phlock"
        case .invalidPhlockPosition:
            return "Phlock position must be between 1 and 5"
        case .phlockFull:
            return "Your phlock is full (maximum 5 members)"
        case .userNotInPhlock:
            return "This user is not in your phlock"
        case .schedulingFailed:
            return "Failed to schedule the swap"
        case .requestAlreadyExists:
            return "You've already sent a follow request to this user"
        case .requestNotFound:
            return "Follow request not found"
        }
    }
}
