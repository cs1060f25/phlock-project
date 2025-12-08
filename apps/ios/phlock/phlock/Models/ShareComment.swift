import Foundation

/// Represents a comment on a shared song
/// Enables tweet-sized threads (max 280 characters) on shares for conversation
struct ShareComment: Codable, Identifiable, @unchecked Sendable {
    let id: UUID
    let shareId: UUID
    let userId: UUID
    let commentText: String
    let parentCommentId: UUID?
    let createdAt: Date
    let updatedAt: Date

    // Optional user data (fetched separately)
    var user: User?

    // Replies to this comment (client-side computed for threading)
    var replies: [ShareComment]?

    enum CodingKeys: String, CodingKey {
        case id
        case shareId = "share_id"
        case userId = "user_id"
        case commentText = "comment_text"
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer for manual construction
    init(
        id: UUID,
        shareId: UUID,
        userId: UUID,
        commentText: String,
        parentCommentId: UUID? = nil,
        createdAt: Date,
        updatedAt: Date,
        user: User? = nil,
        replies: [ShareComment]? = nil
    ) {
        self.id = id
        self.shareId = shareId
        self.userId = userId
        self.commentText = commentText
        self.parentCommentId = parentCommentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.user = user
        self.replies = replies
    }
}

// MARK: - Helpers

extension ShareComment {
    /// Check if this is a reply to another comment
    var isReply: Bool {
        parentCommentId != nil
    }

    /// Formatted timestamp for display
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
