import Foundation

/// Supported notification types for the app
enum NotificationType: String, Codable, Sendable {
    case dailyNudge = "daily_nudge"
    case newFollower = "new_follower"
    case followRequestReceived = "follow_request_received"
    case followRequestAccepted = "follow_request_accepted"
    case friendJoined = "friend_joined"
    case phlockSongReady = "phlock_song_ready"
    case songPlayed = "song_played"
    case songSaved = "song_saved"
    case streakMilestone = "streak_milestone"
}

/// Lightweight notification model rendered in the Notifications tab
struct NotificationItem: Identifiable, @unchecked Sendable {
    let id: UUID
    let type: NotificationType
    let actors: [User]
    let createdAt: Date
    let message: String?
    var isRead: Bool

    // Metadata for specific notification types
    let trackName: String?       // For phlock_song_ready
    let count: Int?              // For song_played/song_saved (anonymous aggregate)
    let streakDays: Int?         // For streak_milestone

    var primaryActor: User? { actors.first }

    init(
        id: UUID,
        type: NotificationType,
        actors: [User],
        createdAt: Date,
        message: String?,
        isRead: Bool,
        trackName: String? = nil,
        count: Int? = nil,
        streakDays: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.actors = actors
        self.createdAt = createdAt
        self.message = message
        self.isRead = isRead
        self.trackName = trackName
        self.count = count
        self.streakDays = streakDays
    }
}
