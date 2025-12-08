import Foundation
import Supabase

/// Service for managing social engagement features (likes, comments) on shares
@MainActor
final class SocialEngagementService: ObservableObject {
    static let shared = SocialEngagementService()

    private let supabase = PhlockSupabaseClient.shared.client

    // MARK: - Published State

    /// Set of share IDs that the current user has liked
    @Published private(set) var likedShareIds: Set<UUID> = []

    // MARK: - Like Model

    struct ShareLike: Codable, Identifiable {
        let id: UUID
        let shareId: UUID
        let userId: UUID
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case shareId = "share_id"
            case userId = "user_id"
            case createdAt = "created_at"
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Like Operations

    /// Like a share
    func likeShare(_ shareId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SocialEngagementError.notAuthenticated
        }

        // Optimistic update
        likedShareIds.insert(shareId)

        do {
            try await supabase
                .from("share_likes")
                .insert([
                    "share_id": shareId.uuidString,
                    "user_id": userId.uuidString
                ])
                .execute()

            print("❤️ Liked share: \(shareId)")
        } catch {
            // Rollback on failure
            likedShareIds.remove(shareId)
            print("❌ Failed to like share: \(error)")
            throw SocialEngagementError.likeFailed(error)
        }
    }

    /// Unlike a share
    func unlikeShare(_ shareId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SocialEngagementError.notAuthenticated
        }

        // Optimistic update
        likedShareIds.remove(shareId)

        do {
            try await supabase
                .from("share_likes")
                .delete()
                .eq("share_id", value: shareId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("💔 Unliked share: \(shareId)")
        } catch {
            // Rollback on failure
            likedShareIds.insert(shareId)
            print("❌ Failed to unlike share: \(error)")
            throw SocialEngagementError.unlikeFailed(error)
        }
    }

    /// Toggle like status for a share
    func toggleLike(_ shareId: UUID) async throws {
        if likedShareIds.contains(shareId) {
            try await unlikeShare(shareId)
        } else {
            try await likeShare(shareId)
        }
    }

    /// Check if the current user has liked a share
    func isLiked(_ shareId: UUID) -> Bool {
        return likedShareIds.contains(shareId)
    }

    /// Fetch like status for multiple shares (batch operation)
    func fetchLikeStatus(for shareIds: [UUID]) async throws {
        guard !shareIds.isEmpty else { return }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw SocialEngagementError.notAuthenticated
        }

        let shareIdStrings = shareIds.map { $0.uuidString }

        do {
            let response: [ShareLike] = try await supabase
                .from("share_likes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("share_id", values: shareIdStrings)
                .execute()
                .value

            // Update liked set
            let newLikedIds = Set(response.map { $0.shareId })
            likedShareIds = likedShareIds.union(newLikedIds)

            print("📊 Fetched like status for \(shareIds.count) shares, \(newLikedIds.count) liked")
        } catch {
            print("❌ Failed to fetch like status: \(error)")
            throw SocialEngagementError.fetchFailed(error)
        }
    }

    // MARK: - Comment Operations

    /// Fetch comments for a share
    func fetchComments(for shareId: UUID) async throws -> [ShareComment] {
        do {
            // Fetch comments with user data joined
            let response: [CommentWithUser] = try await supabase
                .from("share_comments")
                .select("*, user:users(id, username, profile_image_url)")
                .eq("share_id", value: shareId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Convert to ShareComment with nested user
            let comments = response.map { commentWithUser -> ShareComment in
                var comment = ShareComment(
                    id: commentWithUser.id,
                    shareId: commentWithUser.shareId,
                    userId: commentWithUser.userId,
                    commentText: commentWithUser.commentText,
                    parentCommentId: commentWithUser.parentCommentId,
                    createdAt: commentWithUser.createdAt,
                    updatedAt: commentWithUser.updatedAt
                )
                if let userData = commentWithUser.user {
                    comment.user = User.forComment(
                        id: userData.id,
                        username: userData.username,
                        profileImageUrl: userData.profileImageUrl
                    )
                }
                return comment
            }

            print("💬 Fetched \(comments.count) comments for share: \(shareId)")
            return comments
        } catch {
            print("❌ Failed to fetch comments: \(error)")
            throw SocialEngagementError.fetchFailed(error)
        }
    }

    /// Add a comment to a share
    func addComment(to shareId: UUID, text: String, parentCommentId: UUID? = nil) async throws -> ShareComment {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SocialEngagementError.notAuthenticated
        }

        // Validate comment length
        guard text.count <= 280 else {
            throw SocialEngagementError.commentTooLong
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SocialEngagementError.commentEmpty
        }

        var insertData: [String: String] = [
            "share_id": shareId.uuidString,
            "user_id": userId.uuidString,
            "comment_text": text
        ]

        if let parentId = parentCommentId {
            insertData["parent_comment_id"] = parentId.uuidString
        }

        do {
            let response: ShareComment = try await supabase
                .from("share_comments")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value

            print("✍️ Added comment to share: \(shareId)")
            return response
        } catch {
            print("❌ Failed to add comment: \(error)")
            throw SocialEngagementError.commentFailed(error)
        }
    }

    /// Delete a comment (only own comments)
    func deleteComment(_ commentId: UUID) async throws {
        guard (try? await supabase.auth.session.user.id) != nil else {
            throw SocialEngagementError.notAuthenticated
        }

        do {
            try await supabase
                .from("share_comments")
                .delete()
                .eq("id", value: commentId.uuidString)
                .execute()

            print("🗑️ Deleted comment: \(commentId)")
        } catch {
            print("❌ Failed to delete comment: \(error)")
            throw SocialEngagementError.deleteFailed(error)
        }
    }

    // MARK: - Helper to organize comments into thread structure

    /// Organize flat comment list into threaded structure
    func organizeIntoThreads(_ comments: [ShareComment]) -> [ShareComment] {
        // Separate root comments and replies
        var rootComments: [ShareComment] = []
        var repliesByParent: [UUID: [ShareComment]] = [:]

        for comment in comments {
            if let parentId = comment.parentCommentId {
                repliesByParent[parentId, default: []].append(comment)
            } else {
                rootComments.append(comment)
            }
        }

        // Build threaded structure (one level deep for simplicity)
        // Note: If you need deeper nesting, recursion would be needed
        return rootComments
    }

    /// Get replies for a specific comment
    func getReplies(for commentId: UUID, from comments: [ShareComment]) -> [ShareComment] {
        return comments.filter { $0.parentCommentId == commentId }
    }

    // MARK: - Cache Management

    /// Clear cached like status (e.g., on sign out)
    func clearCache() {
        likedShareIds.removeAll()
    }
}

// MARK: - Error Types

enum SocialEngagementError: LocalizedError {
    case notAuthenticated
    case likeFailed(Error)
    case unlikeFailed(Error)
    case fetchFailed(Error)
    case commentFailed(Error)
    case deleteFailed(Error)
    case commentTooLong
    case commentEmpty

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .likeFailed(let error):
            return "Failed to like: \(error.localizedDescription)"
        case .unlikeFailed(let error):
            return "Failed to unlike: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .commentFailed(let error):
            return "Failed to post comment: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete comment: \(error.localizedDescription)"
        case .commentTooLong:
            return "Comment must be 280 characters or less"
        case .commentEmpty:
            return "Comment cannot be empty"
        }
    }
}

// MARK: - Helper Models for Supabase Queries

/// Comment with joined user data from Supabase
private struct CommentWithUser: Codable {
    let id: UUID
    let shareId: UUID
    let userId: UUID
    let commentText: String
    let parentCommentId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let user: CommentUserData?

    enum CodingKeys: String, CodingKey {
        case id
        case shareId = "share_id"
        case userId = "user_id"
        case commentText = "comment_text"
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
    }
}

private struct CommentUserData: Codable {
    let id: UUID
    let username: String?
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageUrl = "profile_image_url"
    }
}

// MARK: - User Extension for Comments

private extension User {
    /// Minimal initializer for comment user data
    static func forComment(id: UUID, username: String?, profileImageUrl: String?) -> User {
        return User(
            id: id,
            displayName: username ?? "User",
            profilePhotoUrl: profileImageUrl,
            username: username
        )
    }
}
