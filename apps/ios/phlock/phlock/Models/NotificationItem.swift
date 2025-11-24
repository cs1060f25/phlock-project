import Foundation

/// Supported notification types for the app
enum NotificationType: String, Codable {
    case friendRequestAccepted = "friend_request_accepted"
    case friendRequestReceived = "friend_request_received"
    case friendJoined = "friend_joined"
    case friendPickedSong = "friend_picked_song"
    case reactionReceived = "reaction_received"
    case streakMilestone = "streak_milestone"
    case dailyNudge = "daily_nudge"
}

/// Lightweight notification model rendered in the Notifications tab
struct NotificationItem: Identifiable {
    let id: UUID
    let type: NotificationType
    let actors: [User]
    let createdAt: Date
    let message: String?
    var isRead: Bool

    var primaryActor: User? { actors.first }
}
