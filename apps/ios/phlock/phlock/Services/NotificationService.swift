import Foundation
import Supabase

/// Service for fetching user notifications
/// Currently supports friend request acceptance and daily song nudges
class NotificationService {
    static let shared = NotificationService()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    private struct NotificationRecord: Decodable {
        let id: UUID
        let userId: UUID
        let actorUserId: UUID?
        let type: String
        let message: String?
        let createdAt: Date
        let readAt: Date?
        let metadata: [String: [String]]?

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

    // MARK: - Create

    /// Create a notification row
    func createNotification(
        userId: UUID,
        actorId: UUID,
        type: NotificationType,
        message: String? = nil,
        metadata: [String: [String]]? = nil
    ) async throws {
        print("🔔 Creating notification: type=\(type.rawValue), user=\(userId), actor=\(actorId)")
        
        if type == .dailyNudge {
            try await upsertDailyNudge(userId: userId, actorId: actorId, message: message)
            return
        }

        struct NotificationInsert: Encodable {
            let user_id: String
            let actor_user_id: String
            let type: String
            let message: String?
            let metadata: [String: [String]]?
        }

        let insert = NotificationInsert(
            user_id: userId.uuidString,
            actor_user_id: actorId.uuidString,
            type: type.rawValue,
            message: message,
            metadata: metadata
        )

        try await supabase
            .from("notifications")
            .insert(insert)
            .execute()
        
        print("✅ Notification created successfully")
    }

    private func upsertDailyNudge(userId: UUID, actorId: UUID, message: String?) async throws {
        // Find today's existing daily_nudge notification (unread or read) to aggregate
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
            var actorIds = Set(current.metadata?["actor_ids"] ?? [])
            actorIds.insert(actorId.uuidString)
            var mergedMetadata = current.metadata ?? [:]
            mergedMetadata["actor_ids"] = Array(actorIds)

            struct NotificationUpdate: Encodable {
                let actor_user_id: String
                let metadata: [String: [String]]
                let message: String?
            }

            let update = NotificationUpdate(
                actor_user_id: actorId.uuidString,
                metadata: mergedMetadata,
                message: message ?? current.message
            )

            try await supabase
                .from("notifications")
                .update(update)
                .eq("id", value: current.id.uuidString)
                .execute()
            
            print("✅ Updated existing nudge")
            return
        }

        print("✨ No existing nudge found, creating new one...")

        struct NotificationInsert: Encodable {
            let user_id: String
            let actor_user_id: String
            let type: String
            let message: String?
            let metadata: [String: [String]]
        }

        let insert = NotificationInsert(
            user_id: userId.uuidString,
            actor_user_id: actorId.uuidString,
            type: NotificationType.dailyNudge.rawValue,
            message: message,
            metadata: ["actor_ids": [actorId.uuidString]]
        )

        try await supabase
            .from("notifications")
            .insert(insert)
            .execute()
            
        print("✅ Created new daily nudge")
    }

    /// Fetch notifications for the current user. If the notifications table is not present yet,
    /// we fall back to synthesized notifications so the UI still renders.
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
                let metadataActorIds = record.metadata?["actor_ids"] ?? []
                for idString in metadataActorIds {
                    if let id = UUID(uuidString: idString) {
                        actorIdsSet.insert(id)
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
                let metadataActorIds = record.metadata?["actor_ids"] ?? []

                for idString in metadataActorIds {
                    if let id = UUID(uuidString: idString), let user = userMap[id] {
                        actors.append(user)
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
                    isRead: record.readAt != nil
                )
            }

            if mapped.isEmpty {
                #if DEBUG
                print("ℹ️ No notifications found for user \(userId). Returning demo notifications.")
                return try await fallbackNotifications(for: userId)
                #else
                return []
                #endif
            }

            return mapped
        } catch {
            print("⚠️ Notifications table not available yet, using fallback: \(error)")
            #if DEBUG
            return try await fallbackNotifications(for: userId)
            #else
            return []
            #endif
        }
    }

    // MARK: - Fallback (until backend notifications table lands)

    private func fallbackNotifications(for userId: UUID) async throws -> [NotificationItem] {
        let friends = (try? await UserService.shared.getFriends(for: userId)) ?? []
        var actorPool: [User] = Array(friends.prefix(8))

        // Ensure we have enough actors for a rich feed
        let placeholders = [
            makePlaceholderUser(name: "Alex"),
            makePlaceholderUser(name: "Sam"),
            makePlaceholderUser(name: "Jordan"),
            makePlaceholderUser(name: "Taylor"),
            makePlaceholderUser(name: "Casey"),
            makePlaceholderUser(name: "Jamie"),
            makePlaceholderUser(name: "Riley"),
            makePlaceholderUser(name: "Morgan")
        ]
        for placeholder in placeholders where actorPool.count < 8 {
            actorPool.append(placeholder)
        }

        let now = Date()
        var demo: [NotificationItem] = []

        // Helper to get a random actor
        func randomActor() -> User { actorPool.randomElement() ?? placeholders[0] }

        // 1. Recent Activity (Today)
        
        // Friend Request Received (Unread)
        demo.append(NotificationItem(
            id: UUID(),
            type: .friendRequestReceived,
            actors: [actorPool[0]],
            createdAt: now.addingTimeInterval(-60 * 5), // 5 mins ago
            message: nil,
            isRead: false
        ))

        // Daily Nudge (Unread)
        demo.append(NotificationItem(
            id: UUID(),
            type: .dailyNudge,
            actors: [actorPool[1]],
            createdAt: now.addingTimeInterval(-60 * 15), // 15 mins ago
            message: "\(actorPool[1].displayName) nudged you to pick today's song",
            isRead: false
        ))

        // Reaction (Unread)
        demo.append(NotificationItem(
            id: UUID(),
            type: .reactionReceived,
            actors: [actorPool[2]],
            createdAt: now.addingTimeInterval(-60 * 45), // 45 mins ago
            message: nil,
            isRead: false
        ))

        // Friend Picked Song (Read)
        demo.append(NotificationItem(
            id: UUID(),
            type: .friendPickedSong,
            actors: [actorPool[3]],
            createdAt: now.addingTimeInterval(-60 * 120), // 2 hours ago
            message: "\(actorPool[3].displayName) picked 'Bohemian Rhapsody'",
            isRead: true
        ))
        
        // Friend Joined (Read)
        demo.append(NotificationItem(
            id: UUID(),
            type: .friendJoined,
            actors: [actorPool[4]],
            createdAt: now.addingTimeInterval(-60 * 240), // 4 hours ago
            message: nil,
            isRead: true
        ))

        // 2. Yesterday
        
        // Streak Milestone
        demo.append(NotificationItem(
            id: UUID(),
            type: .streakMilestone,
            actors: [],
            createdAt: now.addingTimeInterval(-60 * 60 * 25), // 25 hours ago
            message: "You reached a 7-day streak!",
            isRead: true
        ))

        // Multiple Nudges
        demo.append(NotificationItem(
            id: UUID(),
            type: .dailyNudge,
            actors: [actorPool[0], actorPool[2], actorPool[4]],
            createdAt: now.addingTimeInterval(-60 * 60 * 26),
            message: "\(actorPool[0].displayName), \(actorPool[2].displayName), and others nudged you",
            isRead: true
        ))

        // Friend Accepted
        demo.append(NotificationItem(
            id: UUID(),
            type: .friendRequestAccepted,
            actors: [actorPool[5]],
            createdAt: now.addingTimeInterval(-60 * 60 * 28),
            message: "\(actorPool[5].displayName) accepted your friend request",
            isRead: true
        ))

        // 3. This Week (Random mix)
        for _ in 0..<12 {
            let type: NotificationType = [.friendPickedSong, .reactionReceived, .dailyNudge].randomElement()!
            let actor = randomActor()
            let daysAgo = Double.random(in: 2...6)
            
            var message: String? = nil
            if type == .friendPickedSong {
                let songs = ["Hotel California", "Imagine", "Hey Jude", "Smells Like Teen Spirit", "Wonderwall"]
                message = "\(actor.displayName) picked '\(songs.randomElement()!)'"
            } else if type == .dailyNudge {
                message = "\(actor.displayName) nudged you to pick today's song"
            }

            demo.append(NotificationItem(
                id: UUID(),
                type: type,
                actors: [actor],
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * daysAgo),
                message: message,
                isRead: true
            ))
        }

        return demo.sorted { $0.createdAt > $1.createdAt }
    }

    private func makePlaceholderUser(name: String = "Your friend") -> User {
        User(
            id: UUID(),
            displayName: name,
            profilePhotoUrl: nil,
            bio: nil,
            email: nil,
            phone: nil,
            platformType: nil,
            platformUserId: nil,
            platformData: nil,
            privacyWhoCanSend: "everyone",
            createdAt: nil,
            updatedAt: nil,
            authUserId: nil,
            authProvider: nil,
            musicPlatform: nil,
            spotifyUserId: nil,
            appleUserId: nil,
            username: nil,
            phlockCount: 0,
            dailySongStreak: 0,
            lastDailySongDate: nil
        )
    }
}
