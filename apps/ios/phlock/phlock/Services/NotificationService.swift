import Foundation
import Supabase

/// Service for fetching and creating user notifications
/// Supports various notification types including follows, song picks, and engagement
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private let supabase = PhlockSupabaseClient.shared.client

    /// Number of unread notifications
    @Published private(set) var unreadCount: Int = 0

    /// Whether there are any unread notifications
    var hasUnreadNotifications: Bool {
        unreadCount > 0
    }

    private init() {}

    // MARK: - Decodable Records

    private struct NotificationRecord: Decodable {
        let id: UUID
        let userId: UUID
        let actorUserId: UUID?
        let type: String
        let message: String?
        let createdAt: Date
        let readAt: Date?
        let metadata: NotificationMetadataRead?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case actorUserId = "actor_user_id"
            case type
            case message
            case createdAt = "created_at"
            case readAt = "read_at"
            case metadata
        }
    }

    private struct NotificationMetadataRead: Decodable {
        let actorIds: [String]?
        let count: Int?
        let trackName: String?
        let albumArtUrl: String?
        let streakDays: Int?
        let shareId: String?
        let commentText: String?

        enum CodingKeys: String, CodingKey {
            case actorIds = "actor_ids"
            case count
            case trackName = "track_name"
            case albumArtUrl = "album_art_url"
            case streakDays = "streak_days"
            case shareId = "share_id"
            case commentText = "comment_text"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            actorIds = try container.decodeIfPresent([String].self, forKey: .actorIds)
            count = try container.decodeIfPresent(Int.self, forKey: .count)
            trackName = try container.decodeIfPresent(String.self, forKey: .trackName)
            albumArtUrl = try container.decodeIfPresent(String.self, forKey: .albumArtUrl)
            streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays)
            shareId = try container.decodeIfPresent(String.self, forKey: .shareId)
            commentText = try container.decodeIfPresent(String.self, forKey: .commentText)
        }
    }

    // MARK: - Encodable Structs for Insert/Update

    private struct BasicNotificationInsert: Encodable {
        let user_id: String
        let actor_user_id: String
        let type: String
        let message: String?
    }

    private struct NotificationWithTrackInsert: Encodable {
        let user_id: String
        let actor_user_id: String
        let type: String
        let metadata: TrackMetadata

        struct TrackMetadata: Encodable {
            let track_name: String
        }
    }

    private struct NotificationWithTrackAndArtInsert: Encodable {
        let user_id: String
        let actor_user_id: String
        let type: String
        let metadata: TrackAndArtMetadata

        struct TrackAndArtMetadata: Encodable {
            let track_name: String
            let album_art_url: String?
            let share_id: String?
        }
    }

    private struct NotificationWithCommentInsert: Encodable {
        let user_id: String
        let actor_user_id: String
        let type: String
        let metadata: CommentMetadata

        struct CommentMetadata: Encodable {
            let track_name: String
            let album_art_url: String?
            let share_id: String?
            let comment_text: String?
        }
    }

    private struct NotificationWithStreakInsert: Encodable {
        let user_id: String
        let type: String
        let message: String
        let metadata: StreakMetadata

        struct StreakMetadata: Encodable {
            let streak_days: Int
        }
    }

    private struct NotificationWithCountInsert: Encodable {
        let user_id: String
        let type: String
        let metadata: CountMetadata

        struct CountMetadata: Encodable {
            let count: Int
        }
    }

    private struct NotificationWithActorsInsert: Encodable {
        let user_id: String
        let actor_user_id: String
        let type: String
        let message: String?
        let metadata: ActorsMetadata

        struct ActorsMetadata: Encodable {
            let actor_ids: [String]
        }
    }

    private struct NudgeUpdate: Encodable {
        let actor_user_id: String
        let message: String?
        let metadata: ActorsMetadata

        struct ActorsMetadata: Encodable {
            let actor_ids: [String]
        }
    }

    private struct CountUpdate: Encodable {
        let metadata: CountMetadata

        struct CountMetadata: Encodable {
            let count: Int
        }
    }

    private struct ReadAtUpdate: Encodable {
        let read_at: String
    }

    // MARK: - Create Notifications

    /// Create a basic notification with an actor
    func createNotification(
        userId: UUID,
        actorId: UUID,
        type: NotificationType,
        message: String? = nil
    ) async throws {
        print("🔔 Creating notification: type=\(type.rawValue), user=\(userId), actor=\(actorId)")

        if type == .dailyNudge {
            try await upsertDailyNudge(userId: userId, actorId: actorId, message: message)
            return
        }

        let insertData = BasicNotificationInsert(
            user_id: userId.uuidString,
            actor_user_id: actorId.uuidString,
            type: type.rawValue,
            message: message
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Notification created successfully")

        // Send push notification
        await sendPushNotification(userId: userId, type: type, message: message)
    }

    // MARK: - Specific Notification Creators

    /// Notify user that someone followed them
    /// Uses upsert pattern (like Instagram) - if the same person unfollows and refollows,
    /// we update the existing notification instead of creating a duplicate
    func createNewFollowerNotification(userId: UUID, followerId: UUID) async throws {
        try await upsertFollowerNotification(userId: userId, followerId: followerId)
    }

    /// Notify private profile user that someone requested to follow them
    /// Uses upsert pattern to prevent duplicates from same requester
    func createFollowRequestNotification(userId: UUID, requesterId: UUID) async throws {
        try await upsertFollowRequestNotification(userId: userId, requesterId: requesterId)
    }

    /// Notify user that a contact joined (requires contacts sync)
    func createFriendJoinedNotification(userId: UUID, newFriendId: UUID) async throws {
        try await createNotification(
            userId: userId,
            actorId: newFriendId,
            type: .friendJoined
        )
    }

    /// Notify phlock members that someone picked their daily song
    func createPhlockSongReadyNotification(userId: UUID, pickerId: UUID, trackName: String) async throws {
        print("🔔 Creating phlock song ready notification for user=\(userId)")

        let insertData = NotificationWithTrackInsert(
            user_id: userId.uuidString,
            actor_user_id: pickerId.uuidString,
            type: NotificationType.phlockSongReady.rawValue,
            metadata: .init(track_name: trackName)
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Phlock song ready notification created")
        await sendPushNotification(userId: userId, type: .phlockSongReady, message: "has a new song for you")
    }

    /// Upsert anonymous song played notification (aggregates count)
    func upsertSongPlayedNotification(userId: UUID) async throws {
        try await upsertAnonymousEngagementNotification(userId: userId, type: .songPlayed)
    }

    /// Upsert anonymous song saved notification (aggregates count)
    func upsertSongSavedNotification(userId: UUID) async throws {
        try await upsertAnonymousEngagementNotification(userId: userId, type: .songSaved)
    }

    /// Nudge a user to pick their daily song
    /// Aggregates multiple nudges from different users into a single notification
    func sendDailyNudge(to userId: UUID, from nudgerId: UUID) async throws {
        print("🔔 Sending daily nudge to user=\(userId) from \(nudgerId)")
        try await upsertDailyNudge(userId: userId, actorId: nudgerId, message: "nudged you to pick today's song")
    }

    /// Create streak milestone notification
    func createStreakMilestoneNotification(userId: UUID, streakDays: Int) async throws {
        print("🔔 Creating streak milestone notification: \(streakDays) days")

        let message = "You've reached a \(streakDays)-day streak!"

        let insertData = NotificationWithStreakInsert(
            user_id: userId.uuidString,
            type: NotificationType.streakMilestone.rawValue,
            message: message,
            metadata: .init(streak_days: streakDays)
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Streak milestone notification created")
        await sendPushNotification(userId: userId, type: .streakMilestone, message: message)
    }

    // MARK: - Aggregation Helpers

    /// Upsert daily nudge - aggregates multiple nudgers into single notification
    private func upsertDailyNudge(userId: UUID, actorId: UUID, message: String?) async throws {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)

        print("🔍 Checking for existing daily nudge since \(iso)")

        let existing: [NotificationRecord] = try await supabase
            .from("notifications")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("type", value: NotificationType.dailyNudge.rawValue)
            .gte("created_at", value: iso)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let current = existing.first {
            print("📝 Found existing nudge (id: \(current.id)), updating...")
            var actorIds = Set(current.metadata?.actorIds ?? [])
            actorIds.insert(actorId.uuidString)

            let updateData = NudgeUpdate(
                actor_user_id: actorId.uuidString,
                message: message,
                metadata: .init(actor_ids: Array(actorIds))
            )

            try await supabase
                .from("notifications")
                .update(updateData)
                .eq("id", value: current.id.uuidString)
                .execute()

            print("✅ Updated existing nudge")
            return
        }

        print("✨ No existing nudge found, creating new one...")

        let insertData = NotificationWithActorsInsert(
            user_id: userId.uuidString,
            actor_user_id: actorId.uuidString,
            type: NotificationType.dailyNudge.rawValue,
            message: message,
            metadata: .init(actor_ids: [actorId.uuidString])
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Created new daily nudge")
        await sendPushNotification(userId: userId, type: .dailyNudge, message: "nudged you to pick today's song")
    }

    /// Upsert anonymous engagement notification (song_played or song_saved)
    /// Aggregates count for today, keeps identities anonymous
    private func upsertAnonymousEngagementNotification(userId: UUID, type: NotificationType) async throws {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)

        print("🔍 Checking for existing \(type.rawValue) notification since \(iso)")

        let existing: [NotificationRecord] = try await supabase
            .from("notifications")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("type", value: type.rawValue)
            .gte("created_at", value: iso)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let current = existing.first {
            let currentCount = current.metadata?.count ?? 1
            let newCount = currentCount + 1

            print("📝 Found existing \(type.rawValue) notification, updating count to \(newCount)")

            let updateData = CountUpdate(metadata: .init(count: newCount))

            try await supabase
                .from("notifications")
                .update(updateData)
                .eq("id", value: current.id.uuidString)
                .execute()

            print("✅ Updated \(type.rawValue) count")
            return
        }

        print("✨ No existing \(type.rawValue) notification found, creating new one...")

        let insertData = NotificationWithCountInsert(
            user_id: userId.uuidString,
            type: type.rawValue,
            metadata: .init(count: 1)
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Created new \(type.rawValue) notification")

        let message = type == .songPlayed ? "Someone played your song" : "Someone saved your song"
        await sendPushNotification(userId: userId, type: type, message: message)
    }

    /// Upsert new follower notification - prevents duplicates from same follower
    /// Like Instagram: if someone unfollows and refollows, we update the existing
    /// notification instead of creating a new one (brings it to top with fresh timestamp)
    private func upsertFollowerNotification(userId: UUID, followerId: UUID) async throws {
        print("🔍 Checking for existing new_follower notification from \(followerId)")

        // Check if there's already a notification from this follower
        let existing: [NotificationRecord] = try await supabase
            .from("notifications")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("actor_user_id", value: followerId.uuidString)
            .eq("type", value: NotificationType.newFollower.rawValue)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let current = existing.first {
            print("📝 Found existing follower notification (id: \(current.id)), updating timestamp...")

            // Update the notification to bring it to the top with fresh timestamp
            // We update created_at to make it appear as a new notification
            // Also mark as unread so user sees it again
            struct FollowerNotificationUpdate: Encodable {
                let created_at: String
                let read_at: String?
            }

            let updateData = FollowerNotificationUpdate(
                created_at: ISO8601DateFormatter().string(from: Date()),
                read_at: nil  // Mark as unread
            )

            try await supabase
                .from("notifications")
                .update(updateData)
                .eq("id", value: current.id.uuidString)
                .execute()

            print("✅ Updated existing follower notification (refreshed to top)")
            // Don't send push again for re-follow
            return
        }

        print("✨ No existing follower notification found, creating new one...")

        let insertData = BasicNotificationInsert(
            user_id: userId.uuidString,
            actor_user_id: followerId.uuidString,
            type: NotificationType.newFollower.rawValue,
            message: nil
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Created new follower notification")
        await sendPushNotification(userId: userId, type: .newFollower, message: "started following you")
    }

    /// Upsert follow request notification - prevents duplicates from same requester
    private func upsertFollowRequestNotification(userId: UUID, requesterId: UUID) async throws {
        print("🔍 Checking for existing follow_request notification from \(requesterId)")

        // Check if there's already a notification from this requester
        let existing: [NotificationRecord] = try await supabase
            .from("notifications")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("actor_user_id", value: requesterId.uuidString)
            .eq("type", value: NotificationType.followRequestReceived.rawValue)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let current = existing.first {
            print("📝 Found existing follow request notification (id: \(current.id)), updating timestamp...")

            struct FollowRequestNotificationUpdate: Encodable {
                let created_at: String
                let read_at: String?
            }

            let updateData = FollowRequestNotificationUpdate(
                created_at: ISO8601DateFormatter().string(from: Date()),
                read_at: nil
            )

            try await supabase
                .from("notifications")
                .update(updateData)
                .eq("id", value: current.id.uuidString)
                .execute()

            print("✅ Updated existing follow request notification")
            return
        }

        print("✨ No existing follow request notification found, creating new one...")

        let insertData = BasicNotificationInsert(
            user_id: userId.uuidString,
            actor_user_id: requesterId.uuidString,
            type: NotificationType.followRequestReceived.rawValue,
            message: nil
        )

        try await supabase
            .from("notifications")
            .insert(insertData)
            .execute()

        print("✅ Created new follow request notification")
        await sendPushNotification(userId: userId, type: .followRequestReceived, message: "requested to follow you")
    }

    // MARK: - Social Engagement Notifications

    /// Notify user that someone liked their share
    /// Does not notify if the liker is the same as the share owner
    func createShareLikedNotification(shareOwnerId: UUID, likerId: UUID, shareId: UUID, trackName: String, albumArtUrl: String? = nil) async throws {
        // Don't notify yourself
        guard shareOwnerId != likerId else {
            print("⏭️ Skipping like notification - user liked their own share")
            return
        }

        print("🔔 Creating share_liked notification: owner=\(shareOwnerId), liker=\(likerId), track=\(trackName)")

        let insertData = NotificationWithTrackAndArtInsert(
            user_id: shareOwnerId.uuidString,
            actor_user_id: likerId.uuidString,
            type: NotificationType.shareLiked.rawValue,
            metadata: .init(track_name: trackName, album_art_url: albumArtUrl, share_id: shareId.uuidString)
        )

        do {
            try await supabase
                .from("notifications")
                .insert(insertData)
                .execute()

            print("✅ Share liked notification created successfully")
            await sendPushNotification(userId: shareOwnerId, type: .shareLiked, message: "liked your song \"\(trackName)\"")
        } catch {
            print("❌ Failed to insert share_liked notification: \(error)")
            throw error
        }
    }

    /// Notify user that someone commented on their share
    /// Does not notify if the commenter is the same as the share owner
    func createShareCommentedNotification(shareOwnerId: UUID, commenterId: UUID, shareId: UUID, trackName: String, albumArtUrl: String? = nil, commentText: String? = nil, isReply: Bool = false) async throws {
        // Don't notify yourself
        guard shareOwnerId != commenterId else {
            print("⏭️ Skipping comment notification - user commented on their own share")
            return
        }

        print("🔔 Creating share_commented notification: owner=\(shareOwnerId), commenter=\(commenterId), track=\(trackName), isReply=\(isReply)")

        // Truncate comment text to first 100 chars for preview
        let truncatedComment: String? = commentText.map { text in
            if text.count > 100 {
                return String(text.prefix(100)) + "..."
            }
            return text
        }

        let insertData = NotificationWithCommentInsert(
            user_id: shareOwnerId.uuidString,
            actor_user_id: commenterId.uuidString,
            type: NotificationType.shareCommented.rawValue,
            metadata: .init(track_name: trackName, album_art_url: albumArtUrl, share_id: shareId.uuidString, comment_text: truncatedComment)
        )

        do {
            try await supabase
                .from("notifications")
                .insert(insertData)
                .execute()

            print("✅ Share commented notification created successfully")
            let action = isReply ? "replied to a comment on" : "commented on"
            await sendPushNotification(userId: shareOwnerId, type: .shareCommented, message: "\(action) \"\(trackName)\"")
        } catch {
            print("❌ Failed to insert share_commented notification: \(error)")
            throw error
        }
    }

    /// Notify user that someone liked their comment
    /// Does not notify if the liker is the same as the comment owner
    func createCommentLikedNotification(commentOwnerId: UUID, likerId: UUID, shareId: UUID, trackName: String, albumArtUrl: String? = nil) async throws {
        // Don't notify yourself
        guard commentOwnerId != likerId else {
            print("⏭️ Skipping comment like notification - user liked their own comment")
            return
        }

        print("🔔 Creating comment_liked notification: owner=\(commentOwnerId), liker=\(likerId), track=\(trackName)")

        let insertData = NotificationWithTrackAndArtInsert(
            user_id: commentOwnerId.uuidString,
            actor_user_id: likerId.uuidString,
            type: NotificationType.commentLiked.rawValue,
            metadata: .init(track_name: trackName, album_art_url: albumArtUrl, share_id: shareId.uuidString)
        )

        do {
            try await supabase
                .from("notifications")
                .insert(insertData)
                .execute()

            print("✅ Comment liked notification created successfully")
            await sendPushNotification(userId: commentOwnerId, type: .commentLiked, message: "liked your comment on \"\(trackName)\"")
        } catch {
            print("❌ Failed to insert comment_liked notification: \(error)")
            throw error
        }
    }

    // MARK: - Push Notifications

    private struct PushNotificationPayload: Encodable {
        let user_id: String
        let title: String
        let body: String
        let type: String
    }

    private func sendPushNotification(userId: UUID, type: NotificationType, message: String?) async {
        do {
            let title: String
            let body: String

            switch type {
            case .dailyNudge:
                title = "Pick your song!"
                body = message ?? "Your phlock is waiting for your pick"
            case .newFollower:
                title = "New follower"
                body = "Someone started following you"
            case .followRequestReceived:
                title = "Follow request"
                body = "Someone wants to follow you"
            case .followRequestAccepted:
                title = "Request accepted"
                body = "Your follow request was accepted"
            case .friendJoined:
                title = "Friend joined!"
                body = "A contact just joined Phlock"
            case .phlockSongReady:
                title = "New song in your phlock"
                body = message ?? "A phlock member picked their song"
            case .songPlayed:
                title = "Your song was played"
                body = message ?? "Someone listened to your pick"
            case .songSaved:
                title = "Your song was saved"
                body = message ?? "Someone saved your pick"
            case .streakMilestone:
                title = "Streak milestone!"
                body = message ?? "You reached a new milestone"
            case .shareLiked:
                title = "Someone liked your song"
                body = message ?? "Your pick got some love"
            case .shareCommented:
                title = "New comment"
                body = message ?? "Someone commented on your pick"
            case .commentLiked:
                title = "Someone liked your comment"
                body = message ?? "Your comment got some love"
            }

            let payload = PushNotificationPayload(
                user_id: userId.uuidString,
                title: title,
                body: body,
                type: type.rawValue
            )

            try await supabase.functions.invoke("send-push-notification", options: .init(body: payload))

            print("📲 Push notification sent for \(type.rawValue)")
        } catch {
            print("⚠️ Failed to send push notification: \(error)")
        }
    }

    // MARK: - Fetch Notifications

    /// Fetch notifications for the current user
    func fetchNotifications(for userId: UUID, limit: Int = 50) async throws -> [NotificationItem] {
        do {
            let records: [NotificationRecord] = try await supabase
                .from("notifications")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Update unread count
            unreadCount = records.filter { $0.readAt == nil }.count

            // Batch-load actors to avoid N+1 user lookups (include aggregated actor_ids)
            var actorIdsSet = Set<UUID>()
            for record in records {
                if let id = record.actorUserId {
                    actorIdsSet.insert(id)
                }
                if let metadataActorIds = record.metadata?.actorIds {
                    for idString in metadataActorIds {
                        if let id = UUID(uuidString: idString) {
                            actorIdsSet.insert(id)
                        }
                    }
                }
            }

            let userMap = try await UserService.shared.getUsers(userIds: Array(actorIdsSet))

            let mapped: [NotificationItem] = records.compactMap { record in
                guard let type = NotificationType(rawValue: record.type) else {
                    return nil
                }

                // Build actor list
                var actors: [User] = []

                if let metadataActorIds = record.metadata?.actorIds {
                    for idString in metadataActorIds {
                        if let id = UUID(uuidString: idString), let user = userMap[id] {
                            actors.append(user)
                        }
                    }
                }

                if actors.isEmpty, let actorId = record.actorUserId, let actor = userMap[actorId] {
                    actors.append(actor)
                }

                return NotificationItem(
                    id: record.id,
                    type: type,
                    actors: actors,
                    createdAt: record.createdAt,
                    message: record.message,
                    isRead: record.readAt != nil,
                    trackName: record.metadata?.trackName,
                    albumArtUrl: record.metadata?.albumArtUrl,
                    count: record.metadata?.count,
                    streakDays: record.metadata?.streakDays,
                    shareId: record.metadata?.shareId.flatMap { UUID(uuidString: $0) },
                    commentText: record.metadata?.commentText
                )
            }

            return mapped
        } catch {
            print("⚠️ Error fetching notifications: \(error)")
            return []
        }
    }

    /// Fetch just the unread count (lightweight query)
    func fetchUnreadCount(for userId: UUID) async {
        do {
            struct IdOnly: Decodable {
                let id: UUID
            }

            let results: [IdOnly] = try await supabase
                .from("notifications")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .is("read_at", value: nil)
                .execute()
                .value

            unreadCount = results.count
            print("📬 Unread notifications: \(unreadCount)")
        } catch {
            print("⚠️ Error fetching unread count: \(error)")
        }
    }

    /// Decrement unread count when a notification is marked as read
    func decrementUnreadCount() {
        if unreadCount > 0 {
            unreadCount -= 1
        }
    }

    /// Set unread count to zero (e.g., when marking all as read)
    func clearUnreadCount() {
        unreadCount = 0
    }

    // MARK: - Mark as Read

    /// Mark a notification as read
    func markAsRead(notificationId: UUID) async throws {
        let updateData = ReadAtUpdate(read_at: ISO8601DateFormatter().string(from: Date()))

        try await supabase
            .from("notifications")
            .update(updateData)
            .eq("id", value: notificationId.uuidString)
            .execute()

        print("✅ Marked notification \(notificationId) as read")
    }

    /// Mark multiple notifications as read in a single batch
    func markAllAsRead(notificationIds: [UUID]) async throws {
        guard !notificationIds.isEmpty else { return }

        let updateData = ReadAtUpdate(read_at: ISO8601DateFormatter().string(from: Date()))

        try await supabase
            .from("notifications")
            .update(updateData)
            .in("id", values: notificationIds.map { $0.uuidString })
            .execute()

        print("✅ Marked \(notificationIds.count) notifications as read")
    }
}
