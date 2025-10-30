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
            let recentSharingScore = await calculateRecentSharingScore(
                friendId: friend.id,
                currentUserId: currentUser.id
            )
            score += recentSharingScore * RECENT_SHARING_WEIGHT

            // 3. Time Pattern Match (20%)
            let timePatternScore = await calculateTimePatternScore(
                friendId: friend.id,
                currentUserId: currentUser.id
            )
            score += timePatternScore * TIME_PATTERN_WEIGHT

            // 4. Engagement Rate (10%)
            let engagementScore = await calculateEngagementScore(
                friendId: friend.id,
                currentUserId: currentUser.id
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

    /// Calculate recent sharing frequency score (0.0 - 1.0)
    /// Based on how often user has shared with this friend in the last 7 days
    private static func calculateRecentSharingScore(
        friendId: UUID,
        currentUserId: UUID
    ) async -> Double {
        do {
            // Get shares from last 7 days
            let recentRecipients = try await ShareService.shared.getRecentRecipients(
                userId: currentUserId,
                limit: 20
            )

            // Find position of this friend in recent recipients (if any)
            if let index = recentRecipients.firstIndex(of: friendId) {
                // Score decreases with position: 1.0 for first, 0.5 for 10th, 0.0 for 20th+
                let score = max(0.0, 1.0 - (Double(index) / 20.0))
                return score
            }

            return 0.0
        } catch {
            print("    ⚠️ Failed to calculate recent sharing score: \(error)")
            return 0.0
        }
    }

    /// Calculate time pattern match score (0.0 - 1.0)
    /// Based on whether user typically shares with this friend at this time of day
    private static func calculateTimePatternScore(
        friendId: UUID,
        currentUserId: UUID
    ) async -> Double {
        // TODO: Implement time pattern analysis
        // For now, return neutral score
        // In future: analyze historical share times and compare to current hour
        return 0.5
    }

    /// Calculate engagement rate score (0.0 - 1.0)
    /// Based on how often friend actually plays/saves shares from user
    private static func calculateEngagementScore(
        friendId: UUID,
        currentUserId: UUID
    ) async -> Double {
        do {
            let engagementRate = try await ShareService.shared.getEngagementRate(
                senderId: currentUserId,
                recipientId: friendId
            )

            // Convert percentage (0-100) to score (0.0-1.0)
            return engagementRate / 100.0
        } catch {
            print("    ⚠️ Failed to calculate engagement score: \(error)")
            return 0.5 // Neutral score if we can't calculate
        }
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
