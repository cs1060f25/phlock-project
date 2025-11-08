import Foundation
import Supabase

/// Service for phlock-related operations (fetching, building visualizations, etc.)
class PhlockService {
    static let shared = PhlockService()

    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    // MARK: - Fetch User's Phlocks

    /// Fetch all phlocks created by the current user
    func fetchUserPhlocks(userId: UUID) async throws -> [Phlock] {
        let userIdString = userId.uuidString.lowercased()
        print("🔍 PhlockService: Fetching phlocks for userId: \(userIdString)")

        let phlocks: [Phlock] = try await supabase
            .from("phlocks")
            .select("*")
            .eq("created_by", value: userIdString)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("🔍 PhlockService: Fetched \(phlocks.count) phlocks from database")
        return phlocks
    }

    /// Fetch a single phlock by ID
    func fetchPhlock(phlockId: UUID) async throws -> Phlock? {
        let phlocks: [Phlock] = try await supabase
            .from("phlocks")
            .select("*")
            .eq("id", value: phlockId.uuidString)
            .execute()
            .value

        return phlocks.first
    }

    // MARK: - Fetch Phlock Nodes

    /// Fetch all nodes for a specific phlock with user information
    func fetchPhlockNodes(phlockId: UUID) async throws -> [PhlockNode] {
        // Fetch nodes
        var nodes: [PhlockNode] = try await supabase
            .from("phlock_nodes")
            .select("*")
            .eq("phlock_id", value: phlockId.uuidString)
            .order("depth", ascending: true)
            .execute()
            .value

        // Fetch user data for all nodes
        let userIds = nodes.map { $0.userId }
        let users: [User] = try await fetchUsers(userIds: userIds)

        // Create user dictionary for quick lookup
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        // Attach user info to nodes
        for i in 0..<nodes.count {
            nodes[i].user = userDict[nodes[i].userId]
        }

        return nodes
    }

    /// Fetch multiple users by IDs
    private func fetchUsers(userIds: [UUID]) async throws -> [User] {
        guard !userIds.isEmpty else { return [] }

        let uuidStrings = userIds.map { $0.uuidString }

        let users: [User] = try await supabase
            .from("users")
            .select("*")
            .in("id", values: uuidStrings)
            .execute()
            .value

        return users
    }

    // MARK: - Build Visualization Data

    /// Fetch complete phlock data and transform into visualization format
    func fetchPhlockVisualization(phlockId: UUID) async throws -> PhlockVisualizationData {
        print("🎨 Fetching visualization for phlock: \(phlockId)")

        // Fetch phlock metadata
        guard let phlock = try await fetchPhlock(phlockId: phlockId) else {
            print("❌ Phlock not found: \(phlockId)")
            throw PhlockServiceError.phlockNotFound
        }

        print("✅ Found phlock: \(phlock.trackName)")

        // Fetch all nodes
        let nodes = try await fetchPhlockNodes(phlockId: phlockId)
        print("📊 Fetched \(nodes.count) nodes for visualization")

        // Build visualization nodes
        let visualizationNodes = nodes.map { node -> VisualizationNode in
            VisualizationNode(
                id: node.id.uuidString,
                userId: node.userId.uuidString,
                name: node.user?.displayName ?? "Unknown",
                profilePhotoUrl: node.user?.profilePhotoUrl,
                depth: node.depth,
                saved: node.saved,
                forwarded: node.forwarded,
                played: node.played,
                isRoot: node.depth == 0
            )
        }

        // Build links between nodes
        var links: [VisualizationLink] = []
        for node in nodes where node.parentNodeId != nil {
            links.append(
                VisualizationLink(
                    source: node.parentNodeId!.uuidString,
                    target: node.id.uuidString,
                    timestamp: ISO8601DateFormatter().string(from: node.createdAt)
                )
            )
        }

        // Calculate metrics
        let metrics = calculateMetrics(nodes: nodes, phlock: phlock)

        // Assemble final visualization data
        return PhlockVisualizationData(
            phlock: PhlockVisualizationData.PhlockBasicInfo(
                id: phlock.id.uuidString,
                trackName: phlock.trackName,
                artistName: phlock.artistName,
                albumArtUrl: phlock.albumArtUrl
            ),
            nodes: visualizationNodes,
            links: links,
            metrics: metrics
        )
    }

    // MARK: - Metrics Calculation

    /// Calculate engagement metrics for a phlock
    func calculateMetrics(nodes: [PhlockNode], phlock: Phlock) -> PhlockMetrics {
        let totalReach = phlock.totalReach
        let generations = phlock.maxDepth

        // Calculate save rate (% of people who saved the track)
        let nodesWithEngagement = nodes.filter { $0.depth > 0 } // Exclude root
        let savedCount = nodesWithEngagement.filter { $0.saved }.count
        let saveRate = nodesWithEngagement.isEmpty ? 0.0 : Double(savedCount) / Double(nodesWithEngagement.count)

        // Calculate forward rate (% of people who forwarded)
        let forwardedCount = nodesWithEngagement.filter { $0.forwarded }.count
        let forwardRate = nodesWithEngagement.isEmpty ? 0.0 : Double(forwardedCount) / Double(nodesWithEngagement.count)

        // Calculate virality score (custom formula)
        // Factors: reach, generations, save rate, forward rate
        // Score out of 10
        let reachScore = min(Double(totalReach) / 50.0, 1.0) * 3.0 // Max 3 points for reach
        let depthScore = min(Double(generations) / 5.0, 1.0) * 3.0  // Max 3 points for depth
        let engagementScore = (saveRate + forwardRate) / 2.0 * 4.0  // Max 4 points for engagement

        let viralityScore = reachScore + depthScore + engagementScore

        return PhlockMetrics(
            totalReach: totalReach,
            generations: generations,
            saveRate: saveRate,
            forwardRate: forwardRate,
            viralityScore: viralityScore
        )
    }

    // MARK: - Preview Data for Gallery

    /// Fetch phlock previews for gallery display
    func fetchPhlockPreviews(userId: UUID) async throws -> [PhlockPreview] {
        let phlocks = try await fetchUserPhlocks(userId: userId)

        var previews: [PhlockPreview] = []

        for phlock in phlocks {
            // Fetch nodes to calculate metrics
            let nodes = try await fetchPhlockNodes(phlockId: phlock.id)
            let metrics = calculateMetrics(nodes: nodes, phlock: phlock)

            let preview = PhlockPreview(from: phlock, metrics: metrics)
            previews.append(preview)
        }

        return previews
    }

    // MARK: - Shares-Based Phlocks (New Approach)

    /// Group user's sent shares by track to show songs they've shared
    /// - Parameter userId: The user's ID
    /// - Returns: Array of grouped phlocks with aggregated metrics
    func getPhlocksGroupedByTrack(userId: UUID) async throws -> [GroupedPhlock] {
        // Fetch all shares sent by this user
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("📊 Found \(shares.count) total shares sent by user")

        // Group shares by track_id
        let grouped = Dictionary(grouping: shares) { $0.trackId }

        // Convert to GroupedPhlock objects with metrics
        var groupedPhlocks: [GroupedPhlock] = []

        for (trackId, trackShares) in grouped {
            // Use the most recent share for track metadata
            guard let latestShare = trackShares.first else { continue }

            // Calculate metrics
            let recipientCount = trackShares.count
            let playedCount = trackShares.filter { $0.status == .played || $0.status == .saved }.count
            let savedCount = trackShares.filter { $0.status == .saved }.count
            let forwardedCount = 0 // TODO: Track forwards in future

            let listenRate = recipientCount > 0 ? Double(playedCount) / Double(recipientCount) : 0.0
            let saveRate = recipientCount > 0 ? Double(savedCount) / Double(recipientCount) : 0.0

            let groupedPhlock = GroupedPhlock(
                trackId: trackId,
                trackName: latestShare.trackName,
                artistName: latestShare.artistName,
                albumArtUrl: latestShare.albumArtUrl,
                recipientCount: recipientCount,
                totalReach: recipientCount, // Base reach, viral spread not yet implemented
                generations: 1, // Placeholder for viral depth
                playedCount: playedCount,
                savedCount: savedCount,
                forwardedCount: forwardedCount,
                listenRate: listenRate,
                saveRate: saveRate,
                lastSentAt: latestShare.createdAt,
                shares: trackShares
            )

            groupedPhlocks.append(groupedPhlock)
        }

        // Sort by most recent send date
        groupedPhlocks.sort { $0.lastSentAt > $1.lastSentAt }

        print("🎵 Grouped into \(groupedPhlocks.count) unique tracks")
        return groupedPhlocks
    }

    /// Get all recipients for a specific track a user has sent
    /// - Parameters:
    ///   - trackId: The Spotify/Apple Music track ID
    ///   - userId: The user who sent the shares
    /// - Returns: Array of recipients with share metadata
    func getPhlockRecipients(trackId: String, userId: UUID) async throws -> [PhlockRecipient] {
        // Get all shares for this track sent by this user
        let shares: [Share] = try await supabase
            .from("shares")
            .select("*")
            .eq("sender_id", value: userId.uuidString)
            .eq("track_id", value: trackId)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("📨 Found \(shares.count) shares of track \(trackId)")

        // Fetch recipient user data
        let recipientIds = shares.map { $0.recipientId }
        let recipients = try await fetchUsers(userIds: recipientIds)
        let recipientDict = Dictionary(uniqueKeysWithValues: recipients.map { ($0.id, $0) })

        // Create PhlockRecipient objects with share status
        var phlockRecipients: [PhlockRecipient] = []

        for share in shares {
            guard let user = recipientDict[share.recipientId] else { continue }

            let recipient = PhlockRecipient(
                user: user,
                shareId: share.id,
                status: share.status,
                sentAt: share.createdAt,
                playedAt: share.playedAt,
                savedAt: share.savedAt,
                message: share.message
            )

            phlockRecipients.append(recipient)
        }

        return phlockRecipients
    }
}

// MARK: - Errors

enum PhlockServiceError: LocalizedError {
    case phlockNotFound
    case nodesNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .phlockNotFound:
            return "Phlock not found"
        case .nodesNotFound:
            return "No nodes found for this phlock"
        case .invalidData:
            return "Invalid phlock data"
        }
    }
}
