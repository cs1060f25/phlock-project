import Foundation

/// Engine for ranking friends based on smart contextual factors
/// Used to determine which friends should appear in the quick-send bar
class FriendRankingEngine {

    // Weights for different ranking factors (should sum to 1.0)
    private static let MUSIC_TASTE_WEIGHT = 0.4
    private static let RECENT_SHARING_WEIGHT = 0.3
    private static let TIME_PATTERN_WEIGHT = 0.2
    private static let ENGAGEMENT_WEIGHT = 0.1

    /// Rank friends based on multiple contextual factors for a specific track
    /// - Parameters:
    ///   - friends: Array of friend users
    ///   - currentUser: The current user
    ///   - track: The track being shared (optional, for artist matching)
    ///   - limit: Maximum number of ranked friends to return
    /// - Returns: Array of friend user IDs ordered by relevance score (highest first)
    static func rankFriends(
        friends: [User],
        currentUser: User,
        track: MusicItem?,
        limit: Int = 5
    ) async -> [UUID] {
        guard !friends.isEmpty else {
            return []
        }

        print("🧮 Ranking \(friends.count) friends for quick-send (track: \(track?.name ?? "nil"))")

        // OPTIMIZATION: Batch-fetch all sharing data ONCE instead of N queries
        var recentRecipients: [UUID] = []
        var allShares: [Share] = []

        do {
            recentRecipients = try await ShareService.shared.getRecentRecipients(
                userId: currentUser.id,
                limit: 50
            )
        } catch {
            print("⚠️ Failed to fetch recent recipients for ranking: \(error.localizedDescription)")
            // Continue with empty list - ranking will still work based on other factors
        }

        do {
            allShares = try await ShareService.shared.getAllSharesForSender(
                senderId: currentUser.id
            )
        } catch {
            print("⚠️ Failed to fetch shares for ranking: \(error.localizedDescription)")
            // Continue with empty list - ranking will still work based on other factors
        }

        // Calculate scores for each friend
        var friendScores: [(userId: UUID, score: Double)] = []

        for friend in friends {
            var score = 0.0

            // 1. Music Taste Match (40%)
            let musicTasteScore = calculateMusicTasteScore(
                friend: friend,
                currentUser: currentUser,
                track: track
            )
            score += musicTasteScore * MUSIC_TASTE_WEIGHT

            // 2. Recent Sharing Frequency (30%)
            let recentSharingScore = calculateRecentSharingScoreFromCache(
                friendId: friend.id,
                recentRecipients: recentRecipients
            )
            score += recentSharingScore * RECENT_SHARING_WEIGHT

            // 3. Time Pattern Match (20%)
            let timePatternScore = calculateTimePatternScore()
            score += timePatternScore * TIME_PATTERN_WEIGHT

            // 4. Engagement Rate (10%)
            let engagementScore = calculateEngagementScoreFromCache(
                friendId: friend.id,
                allShares: allShares
            )
            score += engagementScore * ENGAGEMENT_WEIGHT

            friendScores.append((userId: friend.id, score: score))

            print("  👤 \(friend.displayName): score=\(String(format: "%.2f", score)) " +
                  "(taste=\(String(format: "%.2f", musicTasteScore)), " +
                  "recent=\(String(format: "%.2f", recentSharingScore)), " +
                  "time=\(String(format: "%.2f", timePatternScore)), " +
                  "engage=\(String(format: "%.2f", engagementScore)))")
        }

        // Sort by score (highest first) and return top N
        let rankedFriends = friendScores
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.userId }

        print("✅ Top \(rankedFriends.count) friends ranked")
        return rankedFriends
    }

    // MARK: - Scoring Functions

    /// Calculate music taste match score (0.0 - 1.0)
    /// Checks if friend's top artists include the track's artist or shares similar taste
    private static func calculateMusicTasteScore(
        friend: User,
        currentUser: User,
        track: MusicItem?
    ) -> Double {
        guard let friendPlatformData = friend.platformData,
              let friendTopArtists = friendPlatformData.topArtists else {
            return 0.0
        }

        var score = 0.0

        // If sharing a specific track, check if friend loves that artist
        if let track = track, let trackArtist = track.artistName {
            let artistMatch = friendTopArtists.contains { artist in
                artist.name.lowercased() == trackArtist.lowercased()
            }

            if artistMatch {
                score += 0.7 // High score for direct artist match
                print("    🎵 Friend loves this artist!")
            }
        }

        // Calculate overall taste compatibility
        guard let currentUserPlatformData = currentUser.platformData,
              let currentUserTopArtists = currentUserPlatformData.topArtists else {
            return score
        }

        // Count shared artists
        let sharedArtists = Set(currentUserTopArtists.map { $0.name.lowercased() })
            .intersection(Set(friendTopArtists.map { $0.name.lowercased() }))

        let tasteCompatibility = Double(sharedArtists.count) / Double(max(currentUserTopArtists.count, friendTopArtists.count))
        score += tasteCompatibility * 0.3 // Add some weight for overall compatibility

        return min(score, 1.0) // Cap at 1.0
    }

    /// Calculate recent sharing frequency score from cached data (0.0 - 1.0)
    /// Based on how often user has shared with this friend recently
    private static func calculateRecentSharingScoreFromCache(
        friendId: UUID,
        recentRecipients: [UUID]
    ) -> Double {
        // Find position of this friend in recent recipients (if any)
        if let index = recentRecipients.firstIndex(of: friendId) {
            // Score decreases with position: 1.0 for first, 0.5 for 25th, 0.0 for 50th+
            let score = max(0.0, 1.0 - (Double(index) / 50.0))
            return score
        }

        return 0.0
    }

    /// Calculate time pattern match score (0.0 - 1.0)
    /// Based on whether user typically shares with this friend at this time of day
    private static func calculateTimePatternScore() -> Double {
        // DEFERRED: Time pattern analysis - Ticket PHLOCK-9012
        // Feature: Analyze user's historical sharing patterns by time of day/week
        // Requires: Database view for share_time_patterns table
        // Current: Returns neutral score (0.5) to avoid bias
        return 0.5
    }

    /// Calculate engagement rate score from cached data (0.0 - 1.0)
    /// Based on how often friend actually plays/saves shares from user
    private static func calculateEngagementScoreFromCache(
        friendId: UUID,
        allShares: [Share]
    ) -> Double {
        // Filter shares sent to this friend
        var sharesToFriend: [Share] = []
        for share in allShares {
            if share.recipientId == friendId {
                sharesToFriend.append(share)
            }
        }

        guard !sharesToFriend.isEmpty else {
            return 0.5 // Neutral score if no history
        }

        // Count how many were played or saved
        var engagedCount = 0
        for share in sharesToFriend {
            if share.status == .played || share.status == .saved || share.status == .forwarded {
                engagedCount += 1
            }
        }

        // Calculate percentage
        let engagementRate = (Double(engagedCount) / Double(sharesToFriend.count)) * 100.0

        // Convert percentage (0-100) to score (0.0-1.0)
        return engagementRate / 100.0
    }

    /// Get quick friend suggestions for a track
    /// This is a convenience method that handles fetching friends and ranking them
    /// - Parameters:
    ///   - currentUser: The current user
    ///   - track: The track being shared (optional)
    ///   - limit: Maximum number of suggestions
    /// - Returns: Array of suggested friend user objects
    static func getQuickSuggestions(
        currentUser: User,
        track: MusicItem?,
        limit: Int = 5
    ) async -> [User] {
        do {
            // Get user's friends
            let friends = try await UserService.shared.getFriends(for: currentUser.id)

            guard !friends.isEmpty else {
                print("⚠️ No friends found for quick suggestions")
                return []
            }

            // Rank friends
            let rankedFriendIds = await rankFriends(
                friends: friends,
                currentUser: currentUser,
                track: track,
                limit: limit
            )

            // Return friends in ranked order
            let rankedFriends = rankedFriendIds.compactMap { friendId in
                friends.first { $0.id == friendId }
            }

            return rankedFriends
        } catch {
            print("❌ Failed to get quick suggestions: \(error)")
            return []
        }
    }
}
