import Foundation
import Supabase

/// Service for music sharing operations between users
class ShareService {
    static let shared = ShareService()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    // MARK: - Create Shares

    /// Create a new share and send to multiple recipients
    /// - Parameters:
    ///   - track: The music item to share
    ///   - recipients: Array of recipient user IDs
    ///   - message: Optional personal message to include
    ///   - senderId: ID of the user sending the share
    /// - Returns: Array of created share IDs
    func createShare(track: MusicItem, recipients: [UUID], message: String? = nil, senderId: UUID) async throws -> [UUID] {
        var shareIds: [UUID] = []

        for recipientId in recipients {
            struct ShareInsert: Encodable {
                let sender_id: String
                let recipient_id: String
                let track_id: String
                let track_name: String
                let artist_name: String
                let album_art_url: String
                let message: String?
                let status: String
            }

            let shareData = ShareInsert(
                sender_id: senderId.uuidString,
                recipient_id: recipientId.uuidString,
                track_id: track.id,
                track_name: track.name,
                artist_name: track.artistName ?? "Unknown Artist",
                album_art_url: track.albumArtUrl ?? "",
                message: message,
                status: ShareStatus.sent.rawValue
            )

            let insertedShares: [Share] = try await supabase
                .from("shares")
                .insert(shareData)
                .select()
                .execute()
                .value

            if let shareId = insertedShares.first?.id {
                shareIds.append(shareId)
                print("✅ Created share: \(shareId) from \(senderId) to \(recipientId)")
            }
        }

        return shareIds
    }

    // MARK: - Fetch Shares

    /// Get all shares received by a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of shares ordered by most recent first
    func getReceivedShares(userId: UUID) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("recipient_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("📨 Fetched \(shares.count) received shares for user \(userId)")
        return shares
    }

    /// Get all shares sent by a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of shares ordered by most recent first
    func getSentShares(userId: UUID) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("📤 Fetched \(shares.count) sent shares for user \(userId)")
        return shares
    }

    /// Get recent recipients for smart suggestions
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - limit: Maximum number of recipients to return
    /// - Returns: Array of user IDs ordered by most recent sharing
    func getRecentRecipients(userId: UUID, limit: Int = 10) async throws -> [UUID] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("recipient_id")
            .eq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit * 2) // Get more to account for duplicates
            .execute()
            .value

        // Deduplicate while maintaining order
        var seen = Set<UUID>()
        var uniqueRecipients: [UUID] = []

        for share in shares {
            if !seen.contains(share.recipientId) {
                seen.insert(share.recipientId)
                uniqueRecipients.append(share.recipientId)
                if uniqueRecipients.count >= limit {
                    break
                }
            }
        }

        print("👥 Found \(uniqueRecipients.count) recent recipients for user \(userId)")
        return uniqueRecipients
    }

    /// Get network activity (shares sent by friends to anyone)
    /// - Parameter userId: The current user's ID
    /// - Returns: Array of shares from friends, ordered by most recent first
    func getNetworkActivity(userId: UUID) async throws -> [Share] {
        // First, get the user's friends
        let friendIds = try await UserService.shared.getFriends(for: userId).map { $0.id }

        guard !friendIds.isEmpty else {
            print("🌐 No friends found for network activity")
            return []
        }

        // Get all shares sent by friends (excluding shares sent TO the current user, as those are in inbox)
        let friendIdStrings = friendIds.map { $0.uuidString }

        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .in("sender_id", values: friendIdStrings)
            .neq("recipient_id", value: userId.uuidString) // Exclude shares sent to current user
            .order("created_at", ascending: false)
            .limit(50) // Limit to most recent 50 for performance
            .execute()
            .value

        print("🌐 Fetched \(shares.count) network activity shares for user \(userId)")
        return shares
    }

    // MARK: - Update Shares

    /// Update the status of a share
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - status: The new status
    func updateShareStatus(shareId: UUID, status: ShareStatus) async throws {
        try await supabase
            .from("shares")
            .update(["status": status.rawValue])
            .eq("id", value: shareId.uuidString)
            .execute()

        print("✅ Updated share \(shareId) status to: \(status.rawValue)")
    }

    /// Mark a share as played and record the engagement
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who played it
    func markAsPlayed(shareId: UUID, userId: UUID) async throws {
        // Update share status
        try await updateShareStatus(shareId: shareId, status: .played)

        // Record engagement
        try await recordEngagement(shareId: shareId, userId: userId, action: "played")
    }

    /// Mark a share as saved and record the engagement
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who saved it
    func markAsSaved(shareId: UUID, userId: UUID) async throws {
        // Update share status
        try await updateShareStatus(shareId: shareId, status: .saved)

        // Record engagement
        try await recordEngagement(shareId: shareId, userId: userId, action: "saved")
    }

    /// Mark a share as dismissed and record the engagement
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who dismissed it
    func markAsDismissed(shareId: UUID, userId: UUID) async throws {
        // Update share status
        try await updateShareStatus(shareId: shareId, status: .dismissed)

        // Record engagement
        try await recordEngagement(shareId: shareId, userId: userId, action: "dismissed")
    }

    // MARK: - Forward Shares

    /// Forward an existing share to new recipients
    /// - Parameters:
    ///   - shareId: The original share's ID
    ///   - newRecipients: Array of recipient user IDs
    ///   - forwarderId: ID of the user forwarding the share
    /// - Returns: Array of created share IDs
    func forwardShare(shareId: UUID, newRecipients: [UUID], forwarderId: UUID) async throws -> [UUID] {
        // Get the original share
        let originalShares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("id", value: shareId.uuidString)
            .execute()
            .value

        guard let originalShare = originalShares.first else {
            throw ShareServiceError.shareNotFound
        }

        // Create track object from share data
        let track = MusicItem(
            id: originalShare.trackId,
            name: originalShare.trackName,
            artistName: originalShare.artistName,
            previewUrl: nil,
            albumArtUrl: originalShare.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: nil,
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )

        // Create new shares with forwarded status
        let shareIds = try await createShare(
            track: track,
            recipients: newRecipients,
            message: originalShare.message,
            senderId: forwarderId
        )

        // Record engagement for forwarding
        try await recordEngagement(shareId: shareId, userId: forwarderId, action: "forwarded")

        // Update original share status
        try await updateShareStatus(shareId: shareId, status: .forwarded)

        print("📨 Forwarded share \(shareId) to \(newRecipients.count) recipients")
        return shareIds
    }

    // MARK: - Engagements

    /// Record a user's engagement with a share
    /// - Parameters:
    ///   - shareId: The share's ID
    ///   - userId: The user who engaged
    ///   - action: The action taken (played, saved, forwarded, dismissed)
    private func recordEngagement(shareId: UUID, userId: UUID, action: String) async throws {
        let engagementData: [String: String] = [
            "share_id": shareId.uuidString,
            "user_id": userId.uuidString,
            "action": action
        ]

        try await supabase
            .from("engagements")
            .insert(engagementData)
            .execute()

        print("📊 Recorded \(action) engagement for share \(shareId)")
    }

    /// Get engagement rate for shares sent by a user to a specific recipient
    /// - Parameters:
    ///   - senderId: The sender's ID
    ///   - recipientId: The recipient's ID
    /// - Returns: Engagement rate as a percentage (0-100)
    func getEngagementRate(senderId: UUID, recipientId: UUID) async throws -> Double {
        // Get all shares sent to this recipient
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: senderId.uuidString)
            .eq("recipient_id", value: recipientId.uuidString)
            .execute()
            .value

        guard !shares.isEmpty else {
            return 0.0
        }

        // Count how many were played or saved
        let engagedShares = shares.filter { share in
            share.status == .played || share.status == .saved || share.status == .forwarded
        }

        let rate = (Double(engagedShares.count) / Double(shares.count)) * 100
        print("📊 Engagement rate for \(senderId) → \(recipientId): \(String(format: "%.1f", rate))%")
        return rate
    }

    /// Get all shares sent by a user (for batch processing in ranking engine)
    /// - Parameter senderId: The sender's ID
    /// - Returns: Array of all shares sent by this user
    func getAllSharesForSender(senderId: UUID) async throws -> [Share] {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: senderId.uuidString)
            .order("created_at", ascending: false)
            .limit(200) // Limit to recent 200 shares for performance
            .execute()
            .value

        return shares
    }

    // MARK: - Counts

    /// Get count of unplayed shares for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Number of unplayed shares
    func getUnplayedShareCount(userId: UUID) async throws -> Int {
        let shares: [Share] = try await supabase
            .from("shares")
            .select("id")
            .eq("recipient_id", value: userId.uuidString)
            .eq("status", value: ShareStatus.sent.rawValue)
            .execute()
            .value

        return shares.count
    }
}

// MARK: - Errors

enum ShareServiceError: LocalizedError {
    case shareNotFound
    case invalidTrackData
    case noRecipients

    var errorDescription: String? {
        switch self {
        case .shareNotFound:
            return "Share not found"
        case .invalidTrackData:
            return "Invalid track data"
        case .noRecipients:
            return "No recipients specified"
        }
    }
}
