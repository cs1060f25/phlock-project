import Foundation
import Supabase

/// Service for music sharing operations between users
class ShareService {
    static let shared = ShareService()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    // MARK: - Create Shares

    /// Validate and enrich track metadata by fetching fresh data from Spotify
    /// - Parameter track: The music item to validate
    /// - Returns: Validated music item with fresh metadata
    private func validateTrackMetadata(_ track: MusicItem) async throws -> MusicItem {
        print("🔍 Validating track: '\(track.name)' by \(track.artistName ?? "Unknown")")

        do {
            struct ValidationRequest: Encodable, @unchecked Sendable {
                let trackId: String?
                let trackName: String
                let artistName: String
            }

            struct ValidationResponse: Decodable, @unchecked Sendable {
                let success: Bool
                let method: String?
                let track: ValidatedTrack?
                let error: String?

                struct ValidatedTrack: Decodable, @unchecked Sendable {
                    let id: String
                    let name: String
                    let artistName: String
                    let artistId: String?  // Spotify artist ID for direct profile linking
                    let artists: [String]
                    let albumArtUrl: String?
                    let previewUrl: String?
                    let isrc: String?
                    let popularity: Int?
                    let spotifyUrl: String
                }
            }

            // Use the new validate-track edge function
            let request = ValidationRequest(
                trackId: track.spotifyId,
                trackName: track.name,
                artistName: track.artistName ?? "Unknown"
            )

            let response: ValidationResponse = try await supabase.functions.invoke(
                "validate-track",
                options: FunctionInvokeOptions(body: request)
            )

            guard response.success, let validatedTrack = response.track else {
                print("⚠️ Could not validate track: \(response.error ?? "Unknown error")")
                print("   Using original track data")
                return track
            }

            print("✅ Track validated via \(response.method ?? "unknown method")")
            print("   Correct ID: \(validatedTrack.id)")
            print("   Correct name: \(validatedTrack.name)")
            print("   Album art: \(validatedTrack.albumArtUrl ?? "nil")")

            // Return validated track with corrected metadata
            return MusicItem(
                id: validatedTrack.id,  // Use corrected ID as primary ID
                name: validatedTrack.name,  // Use validated name
                artistName: validatedTrack.artistName,  // Use validated artist
                artistSpotifyId: validatedTrack.artistId,  // Artist Spotify ID for direct profile linking
                previewUrl: validatedTrack.previewUrl ?? track.previewUrl,
                albumArtUrl: validatedTrack.albumArtUrl,  // Use fresh album art
                isrc: validatedTrack.isrc ?? track.isrc,
                playedAt: track.playedAt,
                spotifyId: validatedTrack.id,  // Use validated Spotify ID
                appleMusicId: track.appleMusicId,
                popularity: validatedTrack.popularity ?? track.popularity,
                followerCount: track.followerCount
            )
        } catch {
            print("⚠️ Failed to validate track '\(track.name)': \(error)")
            print("   Using original track data without validation")
            return track  // Return original if validation fails
        }
    }

    /// Create a new share and send to multiple recipients
    /// - Parameters:
    ///   - track: The music item to share
    ///   - recipients: Array of recipient user IDs
    ///   - message: Optional personal message to include
    ///   - senderId: ID of the user sending the share
    /// - Returns: Array of created share IDs
    func createShare(track: MusicItem, recipients: [UUID], message: String? = nil, senderId: UUID) async throws -> [UUID] {
        // Validate and enrich track metadata before sharing
        let validatedTrack = try await validateTrackMetadata(track)

        var shareIds: [UUID] = []

        for recipientId in recipients {
            struct ShareInsert: Encodable, @unchecked Sendable {
                let sender_id: String
                let recipient_id: String
                let track_id: String
                let track_name: String
                let artist_name: String
                let album_art_url: String?
                let message: String?
                let status: String
                let preview_url: String?
            }

            let shareData = ShareInsert(
                sender_id: senderId.uuidString,
                recipient_id: recipientId.uuidString,
                track_id: validatedTrack.spotifyId ?? validatedTrack.id,  // Use validated Spotify ID if available
                track_name: validatedTrack.name,
                artist_name: validatedTrack.artistName ?? "Unknown Artist",
                album_art_url: validatedTrack.albumArtUrl,  // Use validated album art
                message: message,
                status: ShareStatus.sent.rawValue,
                preview_url: validatedTrack.previewUrl
            )
            print("📤 Creating share for '\(validatedTrack.name)' with validated album art: \(validatedTrack.albumArtUrl ?? "nil")")

            let insertedShares: [Share] = try await supabase
                .from("shares")
                .insert(shareData)
                .select()
                .execute()
                .value

            if let shareId = insertedShares.first?.id {
                shareIds.append(shareId)
                print("✅ Created share: \(shareId) from \(senderId) to \(recipientId)")
            }
        }

        return shareIds
    }

    // MARK: - Fetch Shares

    /// Get all shares received by a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of shares ordered by most recent first
    func getReceivedShares(userId: UUID, limit: Int = 200) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("recipient_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        print("📨 Fetched \(shares.count) received shares for user \(userId)")
        return shares
    }

    /// Get all shares sent by a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of shares ordered by most recent first
    func getSentShares(userId: UUID, limit: Int = 200) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        print("📤 Fetched \(shares.count) sent shares for user \(userId)")
        return shares
    }

    /// Get recent recipients for smart suggestions
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - limit: Maximum number of recipients to return
    /// - Returns: Array of user IDs ordered by most recent sharing
    func getRecentRecipients(userId: UUID, limit: Int = 10) async throws -> [UUID] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("recipient_id")
            .eq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit * 2) // Get more to account for duplicates
            .execute()
            .value

        // Deduplicate while maintaining order
        var seen = Set<UUID>()
        var uniqueRecipients: [UUID] = []

        for share in shares {
            if !seen.contains(share.recipientId) {
                seen.insert(share.recipientId)
                uniqueRecipients.append(share.recipientId)
                if uniqueRecipients.count >= limit {
                    break
                }
            }
        }

        print("👥 Found \(uniqueRecipients.count) recent recipients for user \(userId)")
        return uniqueRecipients
    }

    /// Get network activity (shares sent by friends to anyone)
    /// - Parameter userId: The current user's ID
    /// - Returns: Array of shares from friends, ordered by most recent first
    func getNetworkActivity(userId: UUID) async throws -> [Share] {
        // First, get the user's friends
        let friendIds = try await UserService.shared.getFriends(for: userId).map { $0.id }

        guard !friendIds.isEmpty else {
            print("🌐 No friends found for network activity")
            return []
        }

        // Get all shares sent by friends (excluding shares sent TO the current user, as those are in inbox)
        let friendIdStrings = friendIds.map { $0.uuidString }

        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .in("sender_id", values: friendIdStrings)
            .neq("recipient_id", value: userId.uuidString) // Exclude shares sent to current user
            .order("created_at", ascending: false)
            .limit(50) // Limit to most recent 50 for performance
            .execute()
            .value

        return shares
    }

    // MARK: - Update Shares

    /// Update the status of a share
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - status: The new status
    func updateShareStatus(shareId: UUID, status: ShareStatus) async throws {
        try await supabase
            .from("shares")
            .update(["status": status.rawValue])
            .eq("id", value: shareId.uuidString)
            .execute()

        print("✅ Updated share \(shareId) status to: \(status.rawValue)")
    }

    /// Mark a share as played and record the engagement
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who played it
    func markAsPlayed(shareId: UUID, userId: UUID) async throws {
        // Get the share to find the sender
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("id", value: shareId.uuidString)
            .limit(1)
            .execute()
            .value

        // Update share status
        try await updateShareStatus(shareId: shareId, status: .played)

        // Record engagement
        try await recordEngagement(shareId: shareId, userId: userId, action: "played")
    }

    /// Mark a share as saved and record the engagement
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who saved it
    func markAsSaved(shareId: UUID, userId: UUID) async throws {
        // Get the share to find the sender
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("id", value: shareId.uuidString)
            .limit(1)
            .execute()
            .value

        // Update share status AND saved_at timestamp
        try await supabase
            .from("shares")
            .update([
                "status": ShareStatus.saved.rawValue,
                "saved_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: shareId.uuidString)
            .execute()

        // Record engagement
        try await recordEngagement(shareId: shareId, userId: userId, action: "saved")
    }

    /// Mark a share as unsaved (clear saved_at timestamp)
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who unsaved it
    func markAsUnsaved(shareId: UUID, userId: UUID) async throws {
        // Use AnyJSON to properly encode null for saved_at
        let update: [String: AnyJSON] = [
            "status": .string(ShareStatus.played.rawValue),
            "saved_at": .null
        ]

        try await supabase
            .from("shares")
            .update(update)
            .eq("id", value: shareId.uuidString)
            .execute()

        print("✅ Cleared saved_at for share \(shareId)")
    }

    /// Mark a share as dismissed and record the engagement
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who dismissed it
    func markAsDismissed(shareId: UUID, userId: UUID) async throws {
        // Update share status
        try await updateShareStatus(shareId: shareId, status: .dismissed)

        // Record engagement
        try await recordEngagement(shareId: shareId, userId: userId, action: "dismissed")
    }

    /// Update the message on a share (for editing daily song message)
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - message: New message text (empty string to clear)
    func updateShareMessage(shareId: UUID, message: String) async throws {
        // Validate message length
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedMessage.count <= 280 else {
            throw ShareError.messageTooLong
        }

        // Use AnyJSON to properly encode empty string or null
        let messageValue: AnyJSON = trimmedMessage.isEmpty ? .null : .string(trimmedMessage)

        try await supabase
            .from("shares")
            .update(["message": messageValue])
            .eq("id", value: shareId.uuidString)
            .execute()

        print("✏️ Updated share message for \(shareId)")
    }

    // MARK: - Forward Shares

    /// Forward an existing share to new recipients
    /// - Parameters:
    ///   - shareId: The original share's ID
    ///   - newRecipients: Array of recipient user IDs
    ///   - forwarderId: ID of the user forwarding the share
    /// - Returns: Array of created share IDs
    func forwardShare(shareId: UUID, newRecipients: [UUID], forwarderId: UUID) async throws -> [UUID] {
        // Get the original share
        let originalShares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("id", value: shareId.uuidString)
            .execute()
            .value

        guard let originalShare = originalShares.first else {
            throw ShareServiceError.shareNotFound
        }

        // Create track object from share data
        let track = MusicItem(
            id: originalShare.trackId,
            name: originalShare.trackName,
            artistName: originalShare.artistName,
            previewUrl: originalShare.previewUrl,
            albumArtUrl: originalShare.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: originalShare.trackId,  // Pass Spotify ID for DeepLinkService
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )

        // Create new shares with forwarded status
        let shareIds = try await createShare(
            track: track,
            recipients: newRecipients,
            message: originalShare.message,
            senderId: forwarderId
        )

        // Record engagement for forwarding
        try await recordEngagement(shareId: shareId, userId: forwarderId, action: "forwarded")

        // Update original share status
        try await updateShareStatus(shareId: shareId, status: .forwarded)

        print("📨 Forwarded share \(shareId) to \(newRecipients.count) recipients")
        return shareIds
    }

    // MARK: - Engagements

    /// Record a user's engagement with a share
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who engaged
    ///   - action: The action taken (played, saved, forwarded, dismissed)
    private func recordEngagement(shareId: UUID, userId: UUID, action: String) async throws {
        let engagementData: [String: String] = [
            "share_id": shareId.uuidString,
            "user_id": userId.uuidString,
            "action": action
        ]

        try await supabase
            .from("engagements")
            .insert(engagementData)
            .execute()

        print("📊 Recorded \(action) engagement for share \(shareId)")
    }

    /// Get engagement rate for shares sent by a user to a specific recipient
    /// - Parameters:
    ///   - senderId: The sender's ID
    ///   - recipientId: The recipient's ID
    /// - Returns: Engagement rate as a percentage (0-100)
    func getEngagementRate(senderId: UUID, recipientId: UUID) async throws -> Double {
        // Get all shares sent to this recipient
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: senderId.uuidString)
            .eq("recipient_id", value: recipientId.uuidString)
            .execute()
            .value

        guard !shares.isEmpty else {
            return 0.0
        }

        // Count how many were played or saved
        let engagedShares = shares.filter { share in
            share.status == .played || share.status == .saved || share.status == .forwarded
        }

        let rate = (Double(engagedShares.count) / Double(shares.count)) * 100
        print("📊 Engagement rate for \(senderId) → \(recipientId): \(String(format: "%.1f", rate))%")
        return rate
    }

    /// Get all shares sent by a user (for batch processing in ranking engine)
    /// - Parameter senderId: The sender's ID
    /// - Returns: Array of all shares sent by this user
    func getAllSharesForSender(senderId: UUID) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: senderId.uuidString)
            .order("created_at", ascending: false)
            .limit(200) // Limit to recent 200 shares for performance
            .execute()
            .value

        return shares
    }

    /// Get saved shares for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of saved shares, ordered by saved date
    func getSavedShares(userId: UUID) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("recipient_id", value: userId.uuidString)
            .eq("status", value: ShareStatus.saved.rawValue)
            .order("saved_at", ascending: false)
            .limit(200) // Limit to recent 200 for performance
            .execute()
            .value

        print("💾 Fetched \(shares.count) saved shares for user \(userId)")
        return shares
    }

    // MARK: - Conversations

    /// Get all shares between two users (conversation view)
    /// - Parameters:
    ///   - userId1: First user's ID
    ///   - userId2: Second user's ID
    /// - Returns: Array of shares between these users, ordered chronologically (oldest first)
    func getConversation(userId1: UUID, userId2: UUID) async throws -> [Share] {
        // Query shares in both directions
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .or("and(sender_id.eq.\(userId1.uuidString),recipient_id.eq.\(userId2.uuidString)),and(sender_id.eq.\(userId2.uuidString),recipient_id.eq.\(userId1.uuidString))")
            .order("created_at", ascending: true)
            .execute()
            .value

        print("💬 Fetched \(shares.count) shares in conversation between \(userId1) and \(userId2)")
        return shares
    }

    // MARK: - Comments

    /// Add a comment to a share
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The commenter's ID
    ///   - text: Comment text (max 280 characters)
    ///   - parentCommentId: Optional parent comment for threading
    /// - Returns: The created comment ID
    func addComment(shareId: UUID, userId: UUID, text: String, parentCommentId: UUID? = nil) async throws -> UUID {
        guard text.count <= 280 else {
            throw ShareServiceError.commentTooLong
        }

        struct CommentInsert: Encodable, @unchecked Sendable {
            let share_id: String
            let user_id: String
            let comment_text: String
            let parent_comment_id: String?
        }

        struct CommentResponse: Decodable, @unchecked Sendable {
            let id: UUID
        }

        let insert = CommentInsert(
            share_id: shareId.uuidString,
            user_id: userId.uuidString,
            comment_text: text,
            parent_comment_id: parentCommentId?.uuidString
        )

        let response: [CommentResponse] = try await supabase
            .from("share_comments")
            .insert(insert)
            .select("id")
            .execute()
            .value

        guard let commentId = response.first?.id else {
            throw ShareServiceError.commentCreationFailed
        }

        print("💬 Created comment on share \(shareId)")
        return commentId
    }

    /// Get comments for a share
    /// - Parameter shareId: The share's ID
    /// - Returns: Array of comments with user info
    func getComments(shareId: UUID) async throws -> [ShareComment] {
        let comments: [ShareComment] = try await supabase
            .from("share_comments")
            .select("*")
            .eq("share_id", value: shareId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        print("💬 Fetched \(comments.count) comments for share \(shareId)")
        return comments
    }

    /// Delete a comment
    /// - Parameters:
    ///   - commentId: The comment's ID
    ///   - userId: The user requesting deletion (must be comment author)
    func deleteComment(commentId: UUID, userId: UUID) async throws {
        try await supabase
            .from("share_comments")
            .delete()
            .eq("id", value: commentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        print("🗑️ Deleted comment \(commentId)")
    }

    // MARK: - Counts

    /// Get count of unplayed shares for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Number of unplayed shares
    func getUnplayedShareCount(userId: UUID) async throws -> Int {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("id")
            .eq("recipient_id", value: userId.uuidString)
            .eq("status", value: ShareStatus.sent.rawValue)
            .execute()
            .value

        return shares.count
    }

    // MARK: - Library Saves

    /// Track when a user saves a track to their native library
    /// This is separate from share saves - it tracks general library additions
    /// - Parameters:
    ///   - trackId: The track ID (Spotify or Apple Music)
    ///   - userId: The user who saved the track
    ///   - platformType: The platform where it was saved
    func trackLibrarySave(trackId: String, userId: UUID, platformType: PlatformType) async throws {
        print("📚 Tracked library save: track=\(trackId), user=\(userId), platform=\(platformType.rawValue)")

        // First, check for direct shares sent TO this user
        let directShares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("recipient_id", value: userId.uuidString)
            .eq("track_id", value: trackId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let latestShare = directShares.first {
            try await markAsSaved(shareId: latestShare.id, userId: userId)
            print("✅ Updated direct share \(latestShare.id) to saved status")
            return
        }

        // If no direct share, check for daily songs from other users (self-shares)
        // Daily songs are self-shares (sender_id == recipient_id) that other users can view/save
        let dailySongShares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("track_id", value: trackId)
            .eq("is_daily_song", value: true)
            .neq("sender_id", value: userId.uuidString) // Not the current user's own daily song
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let dailySong = dailySongShares.first {
            try await markAsSaved(shareId: dailySong.id, userId: userId)
            print("✅ Updated daily song share \(dailySong.id) from \(dailySong.senderId) to saved status")
        }
    }

    // MARK: - Daily Song Selection

    /// Select a song as today's daily song
    /// - Parameters:
    ///   - track: The music item to set as daily song
    ///   - note: Optional note (max 280 characters)
    ///   - userId: The user's ID
    /// - Returns: The created share representing the daily song
    func selectDailySong(track: MusicItem, note: String? = nil, userId: UUID) async throws -> Share {
        // Validate note length
        if let note = note, note.count > 280 {
            throw ShareError.commentTooLong
        }

        // Check if user already selected a song today
        if let existing = try await getTodaysDailySong(for: userId) {
            print("⚠️ User already selected daily song today: \(existing.trackName)")
            throw ShareError.customError("You've already selected '\(existing.trackName)' as today's song")
        }

        // Validate and enrich track metadata
        let validatedTrack = try await validateTrackMetadata(track)

        // Create a self-share with is_daily_song = true
        struct DailySongInsert: Encodable, @unchecked Sendable {
            let sender_id: String
            let recipient_id: String
            let track_id: String
            let track_name: String
            let artist_name: String
            let artist_id: String?  // Spotify artist ID for direct profile linking
            let album_art_url: String
            let message: String
            let status: String
            let is_daily_song: Bool
            let selected_date: String
            let preview_url: String?
        }

        // Use date-only format (yyyy-MM-dd) for consistent querying
        // This avoids timezone issues that occur with ISO8601 timestamps
        let todayString = Self.dateOnlyString(for: Date())

        // Only store preview_url if it's non-empty
        let previewUrl: String? = validatedTrack.previewUrl?.isEmpty == false ? validatedTrack.previewUrl : nil

        let shareData = DailySongInsert(
            sender_id: userId.uuidString,
            recipient_id: userId.uuidString, // Self-share
            track_id: validatedTrack.id,
            track_name: validatedTrack.name,
            artist_name: validatedTrack.artistName ?? "Unknown Artist",
            artist_id: validatedTrack.artistSpotifyId,  // Store artist ID for direct profile linking
            album_art_url: validatedTrack.albumArtUrl ?? "",
            message: note ?? "",
            status: ShareStatus.sent.rawValue,
            is_daily_song: true,
            selected_date: todayString,
            preview_url: previewUrl
        )

        let share: Share = try await supabase
            .from("shares")
            .insert(shareData)
            .select()
            .single()
            .execute()
            .value

        print("✨ Selected daily song: '\(share.trackName)' for user \(userId)")

        // Notify all users who have this user in their phlock
        Task {
            await notifyPhlockMembersOfNewSong(pickerId: userId, trackName: share.trackName)
        }

        // Check for streak milestones
        Task {
            await checkAndNotifyStreakMilestone(userId: userId)
        }

        return share
    }

    /// Notify all users who have the picker in their phlock
    private func notifyPhlockMembersOfNewSong(pickerId: UUID, trackName: String) async {
        do {
            let result = try await FollowService.shared.getWhoHasMeInPhlock(userId: pickerId)
            guard let users = result.users, !users.isEmpty else {
                print("📭 No one has this user in their phlock, skipping notifications")
                return
            }

            print("📬 Notifying \(users.count) phlock members about new song")

            for user in users {
                do {
                    try await NotificationService.shared.createPhlockSongReadyNotification(
                        userId: user.id,
                        pickerId: pickerId,
                        trackName: trackName
                    )
                } catch {
                    print("⚠️ Failed to notify user \(user.id): \(error)")
                }
            }
        } catch {
            print("⚠️ Failed to get phlock members for notification: \(error)")
        }
    }

    /// Check if user hit a streak milestone and notify them
    private func checkAndNotifyStreakMilestone(userId: UUID) async {
        do {
            // Fetch user's current streak from the database
            struct UserStreak: Decodable, @unchecked Sendable {
                let dailySongStreak: Int?

                enum CodingKeys: String, CodingKey {
                    case dailySongStreak = "daily_song_streak"
                }
            }

            let users: [UserStreak] = try await supabase
                .from("users")
                .select("daily_song_streak")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let streak = users.first?.dailySongStreak else { return }

            // Check for milestone (7, 30, 100 days)
            let milestones = [7, 30, 100]
            if milestones.contains(streak) {
                try await NotificationService.shared.createStreakMilestoneNotification(
                    userId: userId,
                    streakDays: streak
                )
            }
        } catch {
            print("⚠️ Failed to check streak milestone: \(error)")
        }
    }

    /// Get today's daily song for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Today's daily song share, or nil if not selected
    func getTodaysDailySong(for userId: UUID) async throws -> Share? {
        let todayString = Self.dateOnlyString(for: Date())

        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: userId.uuidString)
            .eq("is_daily_song", value: true)
            .eq("selected_date", value: todayString)
            .limit(1)
            .execute()
            .value

        return shares.first
    }

    /// Check if a user has selected a daily song today (bypasses RLS)
    /// This uses a SECURITY DEFINER function to check without revealing the song content
    /// - Parameter userId: The user's ID to check
    /// - Returns: true if the user has selected a song today, false otherwise
    func hasDailySongToday(for userId: UUID) async throws -> Bool {
        // Pass the local date to handle timezone correctly
        let todayString = Self.dateOnlyString(for: Date())

        do {
            let result: Bool = try await supabase
                .rpc("has_daily_song_today", params: [
                    "check_user_id": userId.uuidString,
                    "check_date": todayString
                ])
                .execute()
                .value
            print("🔍 hasDailySongToday(\(userId), date=\(todayString)): \(result)")
            return result
        } catch {
            print("❌ hasDailySongToday(\(userId)) FAILED: \(error)")
            throw error
        }
    }

    func getDailySongs(from userIds: [UUID], for date: Date = Date()) async throws -> [Share] {
        guard !userIds.isEmpty else {
            return []
        }

        let dateString = Self.dateOnlyString(for: date)

        // Batch query: fetch all daily songs in a single request
        let allShares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .in("sender_id", values: userIds.map { $0.uuidString })
            .eq("is_daily_song", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        // Filter for today's songs
        // Check both selected_date string match AND created_at within last 24h as fallback
        let filteredShares = allShares.filter { share in
            // 1. Check explicit selected_date match
            if let selectedDate = share.selectedDate {
                let selectedString = Self.dateOnlyString(for: selectedDate)
                if selectedString == dateString { return true }
            }

            // 2. Fallback: Check if created today (local time)
            if Calendar.current.isDate(share.createdAt, inSameDayAs: date) {
                return true
            }

            return false
        }

        return filteredShares
    }

    /// Update the note for today's daily song
    /// - Parameters:
    ///   - note: New note text (max 280 characters)
    ///   - userId: The user's ID
    func updateDailySongNote(_ note: String, for userId: UUID) async throws {
        if note.count > 280 {
            throw ShareError.commentTooLong
        }

        guard let todaysSong = try await getTodaysDailySong(for: userId) else {
            throw ShareError.shareNotFound
        }

        try await supabase
            .from("shares")
            .update(["message": note])
            .eq("id", value: todaysSong.id.uuidString)
            .execute()

        print("✏️ Updated daily song note for user \(userId)")
    }

    /// Get daily songs history for a user (excludes today's pick)
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - limit: Maximum number of days to fetch
    /// - Returns: Array of past daily songs, most recent first (today excluded)
    func getDailySongHistory(for userId: UUID, limit: Int = 30) async throws -> [Share] {
        let todayString = Self.dateOnlyString(for: Date())

        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: userId.uuidString)
            .eq("is_daily_song", value: true)
            .neq("selected_date", value: todayString) // Exclude today
            .order("selected_date", ascending: false)
            .limit(limit)
            .execute()
            .value

        return shares
    }
    /// Delete today's daily song for a user (Debug/Reset purposes)
    /// - Parameter userId: The user's ID
    func deleteDailySong(for userId: UUID) async throws {
        let todayString = Self.dateOnlyString(for: Date())

        try await supabase
            .from("shares")
            .delete()
            .eq("sender_id", value: userId.uuidString)
            .eq("is_daily_song", value: true)
            .eq("selected_date", value: todayString)
            .execute()

        print("🗑️ Deleted all daily songs for user \(userId) on \(todayString)")
    }

    // MARK: - Viral Sharing Data

    /// Get aggregated data for viral sharing artifacts
    /// - Parameter userId: The current user's ID
    /// - Returns: ViralShareData containing user's song and friends' songs
    func getViralShareData(for userId: UUID) async throws -> ViralShareData {
        // 1. Get user's daily song
        guard let userShare = try await getTodaysDailySong(for: userId) else {
            throw ShareError.shareNotFound
        }
        
        // 2. Get friends' daily songs
        let friendIds = try await UserService.shared.getFriends(for: userId).map { $0.id }
        let friendShares = try await getDailySongs(from: friendIds)
        
        // 3. Map to ViralShareData
        let userTrack = MusicItem(
            id: userShare.trackId,
            name: userShare.trackName,
            artistName: userShare.artistName,
            artistSpotifyId: userShare.artistId,
            previewUrl: userShare.previewUrl,
            albumArtUrl: userShare.albumArtUrl,
            spotifyId: userShare.trackId
        )
        
        // Fetch usernames for friends (Optimization: This should ideally be a join query)
        var enrichedFriendsTracks: [ViralShareData.FriendTrack] = []
        for share in friendShares {
            let profile = try? await UserService.shared.getUser(userId: share.senderId)
            enrichedFriendsTracks.append(ViralShareData.FriendTrack(
                username: profile?.username ?? "friend",
                trackName: share.trackName,
                artistName: share.artistName,
                albumArtUrl: share.albumArtUrl
            ))
        }
        
        // Fetch the current user's username
        let currentUserProfile = try? await UserService.shared.getUser(userId: userId)
        let userName = currentUserProfile?.username ?? "you"

        return ViralShareData(
            userTrack: userTrack,
            userName: userName,
            date: Date(),
            friendsTracks: enrichedFriendsTracks
        )
    }

    // MARK: - Date Helper

    /// Get date-only string in yyyy-MM-dd format for the user's local timezone
    /// This ensures consistent date handling regardless of time of day
    private static func dateOnlyString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current // Use local timezone
        return formatter.string(from: date)
    }
}

// MARK: - Errors

enum ShareServiceError: LocalizedError {
    case shareNotFound
    case invalidTrackData
    case noRecipients
    case commentTooLong
    case commentCreationFailed

    var errorDescription: String? {
        switch self {
        case .shareNotFound:
            return "Share not found"
        case .invalidTrackData:
            return "Invalid track data"
        case .noRecipients:
            return "No recipients specified"
        case .commentTooLong:
            return "Comment must be 280 characters or less"
        case .commentCreationFailed:
            return "Failed to create comment"
        }
    }
}

enum ShareError: LocalizedError {
    case commentTooLong
    case messageTooLong
    case shareNotFound
    case commentCreationFailed
    case customError(String)

    var errorDescription: String? {
        switch self {
        case .commentTooLong:
            return "Comment must be 280 characters or less"
        case .messageTooLong:
            return "Message must be 280 characters or less"
        case .shareNotFound:
            return "Share not found"
        case .commentCreationFailed:
            return "Failed to add comment"
        case .customError(let message):
            return message
        }
    }
}
