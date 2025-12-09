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
    var likeCount: Int

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
        case likeCount = "like_count"
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
        likeCount: Int = 0,
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
        self.likeCount = likeCount
        self.user = user
        self.replies = replies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        shareId = try container.decode(UUID.self, forKey: .shareId)
        userId = try container.decode(UUID.self, forKey: .userId)
        commentText = try container.decode(String.self, forKey: .commentText)
        parentCommentId = try container.decodeIfPresent(UUID.self, forKey: .parentCommentId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        user = nil
        replies = nil
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
