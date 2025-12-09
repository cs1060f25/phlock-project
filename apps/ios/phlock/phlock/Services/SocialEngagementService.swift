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

    /// Adjustments to like counts (tracks delta from original count)
    /// Positive = added likes, Negative = removed likes
    @Published private(set) var likeCountAdjustments: [UUID: Int] = [:]

    /// Adjustments to comment counts (tracks delta from original count)
    @Published private(set) var commentCountAdjustments: [UUID: Int] = [:]

    /// Get the adjusted like count for a share
    func adjustedLikeCount(for shareId: UUID, originalCount: Int) -> Int {
        let adjustment = likeCountAdjustments[shareId] ?? 0
        return max(0, originalCount + adjustment)
    }

    /// Get the adjusted comment count for a share
    func adjustedCommentCount(for shareId: UUID, originalCount: Int) -> Int {
        let adjustment = commentCountAdjustments[shareId] ?? 0
        return max(0, originalCount + adjustment)
    }

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

    // MARK: - User ID Helper

    /// Get the current user's users.id (not auth.uid())
    /// The users table has auth_user_id which maps to auth.uid()
    private func getCurrentUserId() async throws -> UUID {
        guard let authUserId = try? await supabase.auth.session.user.id else {
            throw SocialEngagementError.notAuthenticated
        }

        // Fetch the users.id that corresponds to this auth.uid()
        struct UserIdResult: Codable {
            let id: UUID
        }

        let result: [UserIdResult] = try await supabase
            .from("users")
            .select("id")
            .eq("auth_user_id", value: authUserId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let userId = result.first?.id else {
            throw SocialEngagementError.notAuthenticated
        }

        return userId
    }

    /// Helper struct for fetching share info for notifications
    private struct ShareInfo: Codable {
        let id: UUID
        let senderId: UUID
        let trackName: String
        let albumArtUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case senderId = "sender_id"
            case trackName = "track_name"
            case albumArtUrl = "album_art_url"
        }
    }

    /// Fetch share info for notifications
    private func fetchShareInfo(_ shareId: UUID) async throws -> ShareInfo? {
        print("📋 Fetching share info for notification: \(shareId)")
        do {
            let result: [ShareInfo] = try await supabase
                .from("shares")
                .select("id, sender_id, track_name, album_art_url")
                .eq("id", value: shareId.uuidString)
                .limit(1)
                .execute()
                .value

            if let info = result.first {
                print("✅ Found share info: senderId=\(info.senderId), trackName=\(info.trackName), albumArt=\(info.albumArtUrl ?? "nil")")
            } else {
                print("⚠️ No share found with id: \(shareId)")
            }
            return result.first
        } catch {
            print("❌ Error fetching share info: \(error)")
            throw error
        }
    }

    // MARK: - Like Operations

    /// Like a share
    func likeShare(_ shareId: UUID) async throws {
        let userId = try await getCurrentUserId()

        // Optimistic update for heart icon state and count
        likedShareIds.insert(shareId)
        likeCountAdjustments[shareId, default: 0] += 1

        do {
            try await supabase
                .from("share_likes")
                .insert([
                    "share_id": shareId.uuidString,
                    "user_id": userId.uuidString
                ])
                .execute()

            print("❤️ Liked share: \(shareId)")

            // Send notification to share owner (fire and forget - don't block UI)
            let likerIdCopy = userId
            let shareIdCopy = shareId
            Task {
                print("📤 Starting like notification task for share: \(shareIdCopy)")
                do {
                    if let shareInfo = try await self.fetchShareInfo(shareIdCopy) {
                        print("📤 Sending like notification: owner=\(shareInfo.senderId), liker=\(likerIdCopy)")
                        try await NotificationService.shared.createShareLikedNotification(
                            shareOwnerId: shareInfo.senderId,
                            likerId: likerIdCopy,
                            shareId: shareIdCopy,
                            trackName: shareInfo.trackName,
                            albumArtUrl: shareInfo.albumArtUrl
                        )
                        print("📤 Like notification task completed successfully")
                    } else {
                        print("⚠️ Could not find share info for notification")
                    }
                } catch {
                    print("⚠️ Failed to send like notification: \(error)")
                }
            }
        } catch {
            // Rollback on failure
            likedShareIds.remove(shareId)
            likeCountAdjustments[shareId, default: 0] -= 1
            print("❌ Failed to like share: \(error)")
            throw SocialEngagementError.likeFailed(error)
        }
    }

    /// Unlike a share
    func unlikeShare(_ shareId: UUID) async throws {
        let userId = try await getCurrentUserId()

        // Optimistic update for heart icon state and count
        likedShareIds.remove(shareId)
        likeCountAdjustments[shareId, default: 0] -= 1

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
            likeCountAdjustments[shareId, default: 0] += 1
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

        let userId = try await getCurrentUserId()

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

    // MARK: - Likers List

    /// Fetch users who liked a specific share
    func fetchLikersForShare(shareId: UUID) async throws -> [LikerInfo] {
        do {
            let response: [LikeWithUser] = try await supabase
                .from("share_likes")
                .select("id, user_id, created_at, user:users(id, username, display_name, profile_photo_url)")
                .eq("share_id", value: shareId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let likers = response.map { like in
                LikerInfo(
                    id: like.id,
                    userId: like.userId,
                    username: like.user?.username,
                    displayName: like.user?.displayName ?? "User",
                    profilePhotoUrl: like.user?.profilePhotoUrl,
                    likedAt: like.createdAt
                )
            }

            print("👥 Fetched \(likers.count) likers for share: \(shareId)")
            return likers
        } catch {
            print("❌ Failed to fetch likers: \(error)")
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
                .select("*, user:users(id, username, profile_photo_url)")
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
                        profileImageUrl: userData.profilePhotoUrl
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
        let userId = try await getCurrentUserId()

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

        let isReply = parentCommentId != nil
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

            // Send notification to share owner (fire and forget - don't block UI)
            let commenterIdCopy = userId
            let isReplyCopy = isReply
            let shareIdCopy = shareId
            let commentTextCopy = text
            Task {
                print("📤 Starting comment notification task for share: \(shareIdCopy)")
                do {
                    if let shareInfo = try await self.fetchShareInfo(shareIdCopy) {
                        print("📤 Sending comment notification: owner=\(shareInfo.senderId), commenter=\(commenterIdCopy), isReply=\(isReplyCopy)")
                        try await NotificationService.shared.createShareCommentedNotification(
                            shareOwnerId: shareInfo.senderId,
                            commenterId: commenterIdCopy,
                            shareId: shareIdCopy,
                            trackName: shareInfo.trackName,
                            albumArtUrl: shareInfo.albumArtUrl,
                            commentText: commentTextCopy,
                            isReply: isReplyCopy
                        )
                        print("📤 Comment notification task completed successfully")
                    } else {
                        print("⚠️ Could not find share info for comment notification")
                    }
                } catch {
                    print("⚠️ Failed to send comment notification: \(error)")
                }
            }

            return response
        } catch {
            print("❌ Failed to add comment: \(error)")
            throw SocialEngagementError.commentFailed(error)
        }
    }

    /// Delete a comment (only own comments)
    func deleteComment(_ commentId: UUID) async throws {
        // Verify user is authenticated (RLS will enforce ownership)
        _ = try await getCurrentUserId()

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

    // MARK: - Count Adjustment Methods

    /// Increment comment count for a share (called after successfully adding a comment)
    func incrementCommentCount(for shareId: UUID) {
        commentCountAdjustments[shareId, default: 0] += 1
    }

    /// Decrement comment count for a share (called after successfully deleting a comment)
    func decrementCommentCount(for shareId: UUID) {
        commentCountAdjustments[shareId, default: 0] -= 1
    }

    // MARK: - Comment Like Operations

    /// Set of comment IDs that the current user has liked
    @Published private(set) var likedCommentIds: Set<UUID> = []

    /// Adjustments to comment like counts
    @Published private(set) var commentLikeCountAdjustments: [UUID: Int] = [:]

    /// Get the adjusted like count for a comment
    func adjustedCommentLikeCount(for commentId: UUID, originalCount: Int) -> Int {
        let adjustment = commentLikeCountAdjustments[commentId] ?? 0
        return max(0, originalCount + adjustment)
    }

    /// Check if the current user has liked a comment
    func isCommentLiked(_ commentId: UUID) -> Bool {
        return likedCommentIds.contains(commentId)
    }

    /// Like a comment
    func likeComment(_ commentId: UUID, commentOwnerId: UUID, shareId: UUID, trackName: String, albumArtUrl: String?) async throws {
        let userId = try await getCurrentUserId()

        // Optimistic update
        likedCommentIds.insert(commentId)
        commentLikeCountAdjustments[commentId, default: 0] += 1

        do {
            try await supabase
                .from("share_comment_likes")
                .insert([
                    "comment_id": commentId.uuidString,
                    "user_id": userId.uuidString
                ])
                .execute()

            print("❤️ Liked comment: \(commentId)")

            // Send notification to comment owner (fire and forget)
            let likerIdCopy = userId
            let shareIdCopy = shareId
            Task {
                do {
                    try await NotificationService.shared.createCommentLikedNotification(
                        commentOwnerId: commentOwnerId,
                        likerId: likerIdCopy,
                        shareId: shareIdCopy,
                        trackName: trackName,
                        albumArtUrl: albumArtUrl
                    )
                } catch {
                    print("⚠️ Failed to send comment like notification: \(error)")
                }
            }
        } catch {
            // Rollback on failure
            likedCommentIds.remove(commentId)
            commentLikeCountAdjustments[commentId, default: 0] -= 1
            print("❌ Failed to like comment: \(error)")
            throw SocialEngagementError.likeFailed(error)
        }
    }

    /// Unlike a comment
    func unlikeComment(_ commentId: UUID) async throws {
        let userId = try await getCurrentUserId()

        // Optimistic update
        likedCommentIds.remove(commentId)
        commentLikeCountAdjustments[commentId, default: 0] -= 1

        do {
            try await supabase
                .from("share_comment_likes")
                .delete()
                .eq("comment_id", value: commentId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("💔 Unliked comment: \(commentId)")
        } catch {
            // Rollback on failure
            likedCommentIds.insert(commentId)
            commentLikeCountAdjustments[commentId, default: 0] += 1
            print("❌ Failed to unlike comment: \(error)")
            throw SocialEngagementError.unlikeFailed(error)
        }
    }

    /// Toggle like status for a comment
    func toggleCommentLike(_ commentId: UUID, commentOwnerId: UUID, shareId: UUID, trackName: String, albumArtUrl: String?) async throws {
        if likedCommentIds.contains(commentId) {
            try await unlikeComment(commentId)
        } else {
            try await likeComment(commentId, commentOwnerId: commentOwnerId, shareId: shareId, trackName: trackName, albumArtUrl: albumArtUrl)
        }
    }

    /// Fetch like status for multiple comments (batch operation)
    func fetchCommentLikeStatus(for commentIds: [UUID]) async throws {
        guard !commentIds.isEmpty else { return }

        let userId = try await getCurrentUserId()
        let commentIdStrings = commentIds.map { $0.uuidString }

        do {
            struct CommentLike: Codable {
                let commentId: UUID

                enum CodingKeys: String, CodingKey {
                    case commentId = "comment_id"
                }
            }

            let response: [CommentLike] = try await supabase
                .from("share_comment_likes")
                .select("comment_id")
                .eq("user_id", value: userId.uuidString)
                .in("comment_id", values: commentIdStrings)
                .execute()
                .value

            let newLikedIds = Set(response.map { $0.commentId })
            likedCommentIds = likedCommentIds.union(newLikedIds)

            print("📊 Fetched comment like status for \(commentIds.count) comments, \(newLikedIds.count) liked")
        } catch {
            print("❌ Failed to fetch comment like status: \(error)")
            throw SocialEngagementError.fetchFailed(error)
        }
    }

    // MARK: - Cache Management

    /// Clear cached like status (e.g., on sign out)
    func clearCache() {
        likedShareIds.removeAll()
        likeCountAdjustments.removeAll()
        commentCountAdjustments.removeAll()
        likedCommentIds.removeAll()
        commentLikeCountAdjustments.removeAll()
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
    let profilePhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profilePhotoUrl = "profile_photo_url"
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

// MARK: - Liker Info Model

/// Information about a user who liked a share
struct LikerInfo: Identifiable {
    let id: UUID
    let userId: UUID
    let username: String?
    let displayName: String
    let profilePhotoUrl: String?
    let likedAt: Date
}

// MARK: - Like With User Data

/// Like with joined user data from Supabase
private struct LikeWithUser: Codable {
    let id: UUID
    let userId: UUID
    let createdAt: Date
    let user: LikerUserData?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case user
    }
}

private struct LikerUserData: Codable {
    let id: UUID
    let username: String?
    let displayName: String?
    let profilePhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case profilePhotoUrl = "profile_photo_url"
    }
}
