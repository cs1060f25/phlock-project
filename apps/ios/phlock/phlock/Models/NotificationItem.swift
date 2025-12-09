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
    case shareLiked = "share_liked"
    case shareCommented = "share_commented"
    case commentLiked = "comment_liked"
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
    let trackName: String?       // For phlock_song_ready, share_liked, share_commented
    let albumArtUrl: String?     // For share_liked, share_commented (thumbnail)
    let count: Int?              // For song_played/song_saved (anonymous aggregate)
    let streakDays: Int?         // For streak_milestone
    let shareId: UUID?           // For share_liked, share_commented, comment_liked (navigation)
    let commentText: String?     // For share_commented (preview of comment)

    var primaryActor: User? { actors.first }

    init(
        id: UUID,
        type: NotificationType,
        actors: [User],
        createdAt: Date,
        message: String?,
        isRead: Bool,
        trackName: String? = nil,
        albumArtUrl: String? = nil,
        count: Int? = nil,
        streakDays: Int? = nil,
        shareId: UUID? = nil,
        commentText: String? = nil
    ) {
        self.id = id
        self.type = type
        self.actors = actors
        self.createdAt = createdAt
        self.message = message
        self.isRead = isRead
        self.trackName = trackName
        self.albumArtUrl = albumArtUrl
        self.count = count
        self.streakDays = streakDays
        self.shareId = shareId
        self.commentText = commentText
    }
}
