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

    enum CodingKeys: String, CodingKey {
        case id
        case shareId = "share_id"
        case userId = "user_id"
        case commentText = "comment_text"
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
