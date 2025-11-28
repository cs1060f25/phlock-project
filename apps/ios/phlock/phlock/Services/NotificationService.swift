import Foundation
import Supabase

/// Service for fetching and creating user notifications
/// Supports various notification types including follows, song picks, and engagement
class NotificationService {
    static let shared = NotificationService()

    private let supabase = PhlockSupabaseClient.shared.client

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
        let streakDays: Int?

        enum CodingKeys: String, CodingKey {
            case actorIds = "actor_ids"
            case count
            case trackName = "track_name"
            case streakDays = "streak_days"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            actorIds = try container.decodeIfPresent([String].self, forKey: .actorIds)
            count = try container.decodeIfPresent(Int.self, forKey: .count)
            trackName = try container.decodeIfPresent(String.self, forKey: .trackName)
            streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays)
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
    func createNewFollowerNotification(userId: UUID, followerId: UUID) async throws {
        try await createNotification(
            userId: userId,
            actorId: followerId,
            type: .newFollower
        )
    }

    /// Notify private profile user that someone requested to follow them
    func createFollowRequestNotification(userId: UUID, requesterId: UUID) async throws {
        try await createNotification(
            userId: userId,
            actorId: requesterId,
            type: .followRequestReceived
        )
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
                    count: record.metadata?.count,
                    streakDays: record.metadata?.streakDays
                )
            }

            return mapped
        } catch {
            print("⚠️ Error fetching notifications: \(error)")
            return []
        }
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
}
