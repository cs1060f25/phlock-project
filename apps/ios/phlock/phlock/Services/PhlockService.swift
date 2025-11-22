import Foundation
import Supabase

/// Service for phlock-related operations (fetching, building visualizations, etc.)
private struct GroupedPhlockResponse: Decodable {
    let trackId: String
    let trackName: String?
    let artistName: String?
    let albumArtUrl: String?
    let recipientCount: Int
    let playedCount: Int
    let savedCount: Int
    let lastSentAt: Date

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case trackName = "track_name"
        case artistName = "artist_name"
        case albumArtUrl = "album_art_url"
        case recipientCount = "recipient_count"
        case playedCount = "played_count"
        case savedCount = "saved_count"
        case lastSentAt = "last_sent_at"
    }
}

class PhlockService {
    static let shared = PhlockService()

    private let supabase = PhlockSupabaseClient.shared.client

    // Cache for grouped phlocks to prevent slow repeated loads
    private var phlocksCache: [UUID: (data: [GroupedPhlock], timestamp: Date)] = [:]
    private let cacheExpirationSeconds: TimeInterval = 30 // Cache expires after 30 seconds

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
    /// Optimized to use a single query with joins instead of N+1 queries
    func fetchPhlockNodes(phlockId: UUID) async throws -> [PhlockNode] {
        // Try to fetch nodes with user data in a single query using Supabase foreign key joins
        // This avoids the N+1 query problem where we fetch nodes then fetch users separately
        var nodes: [PhlockNode] = try await supabase
            .from("phlock_nodes")
            .select("*, users(*)")  // Join with users table
            .eq("phlock_id", value: phlockId.uuidString)
            .order("depth", ascending: true)
            .execute()
            .value

        // If the join didn't populate user data (backward compatibility), fallback to separate fetch
        if nodes.contains(where: { $0.user == nil }) {
            let userIds = nodes.map { $0.userId }
            let users: [User] = try await fetchUsers(userIds: userIds)

            // Create user dictionary for quick lookup
            let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

            // Attach user info to nodes
            for i in 0..<nodes.count {
                nodes[i].user = userDict[nodes[i].userId]
            }
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
        let metrics = PhlockService.calculateMetrics(nodes: nodes, phlock: phlock)

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
    nonisolated static func calculateMetrics(nodes: [PhlockNode], phlock: Phlock) -> PhlockMetrics {
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

        // Fetch node data concurrently to avoid sequential network calls
        let previews: [PhlockPreview] = try await withThrowingTaskGroup(of: (Int, PhlockPreview).self) { group in
            for (index, phlock) in phlocks.enumerated() {
                group.addTask {
                    let nodes = try await self.fetchPhlockNodes(phlockId: phlock.id)
                    // Calculate metrics (static helper)
                    let metrics = PhlockService.calculateMetrics(nodes: nodes, phlock: phlock)
                    
                    // PhlockPreview init might be isolated, so run on MainActor
                    return await MainActor.run {
                        (index, PhlockPreview(from: phlock, metrics: metrics))
                    }
                }
            }

            var results: [(Int, PhlockPreview)] = []
            for try await preview in group {
                results.append(preview)
            }

            // Preserve original ordering of phlocks
            return results
                .sorted { $0.0 < $1.0 }
                .map { $0.1 }
        }

        return previews
    }

    // MARK: - Shares-Based Phlocks (New Approach)

    /// Group user's sent shares by track to show songs they've shared
    /// - Parameter userId: The user's ID
    /// - Parameter forceRefresh: If true, bypasses cache and fetches fresh data
    /// - Returns: Array of grouped phlocks with aggregated metrics
    func getPhlocksGroupedByTrack(userId: UUID, forceRefresh: Bool = false) async throws -> [GroupedPhlock] {
        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = phlocksCache[userId] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheExpirationSeconds {
                print("✅ Using cached phlocks (\(Int(age))s old)")
                return cached.data
            } else {
                print("⏰ Cache expired (\(Int(age))s old), fetching fresh data")
            }
        }

        let startTime = Date()
        print("🔍 Fetching phlocks for user \(userId) (forceRefresh: \(forceRefresh))")

        let params = ["p_user_id": userId.uuidString]

        // Use the faster function without auth check for better performance
        // The auth check is already done at the Swift level via authState
        let queryTask = Task {
            try await supabase
                .rpc("get_user_phlocks_grouped_fast", params: params)
                .execute()
                .value as [GroupedPhlockResponse]
        }

        let summaries: [GroupedPhlockResponse]
        do {
            summaries = try await queryTask.value
        } catch {
            print("❌ Database query failed: \(error)")
            // If we have cached data, return it instead of failing
            if let cached = phlocksCache[userId] {
                print("⚠️ Using stale cache due to query error (age: \(Int(Date().timeIntervalSince(cached.timestamp)))s)")
                return cached.data
            } else {
                throw error
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        print("🎵 Grouped into \(summaries.count) unique tracks (took \(String(format: "%.2f", duration))s)")

        let result = summaries.map { summary in
            let recipientCount = summary.recipientCount
            let listenRate = recipientCount > 0 ? Double(summary.playedCount) / Double(recipientCount) : 0.0
            let saveRate = recipientCount > 0 ? Double(summary.savedCount) / Double(recipientCount) : 0.0

            return GroupedPhlock(
                trackId: summary.trackId,
                trackName: summary.trackName ?? "Unknown Track",
                artistName: summary.artistName ?? "Unknown Artist",
                albumArtUrl: summary.albumArtUrl,
                recipientCount: recipientCount,
                totalReach: recipientCount,
                generations: 1,
                playedCount: summary.playedCount,
                savedCount: summary.savedCount,
                forwardedCount: 0,
                listenRate: listenRate,
                saveRate: saveRate,
                lastSentAt: summary.lastSentAt
            )
        }

        // Cache the result
        phlocksCache[userId] = (data: result, timestamp: Date())

        return result
    }

    /// Clear the phlocks cache for a specific user or all users
    func clearCache(userId: UUID? = nil) {
        if let userId = userId {
            phlocksCache.removeValue(forKey: userId)
            print("🗑️ Cleared phlocks cache for user \(userId)")
        } else {
            phlocksCache.removeAll()
            print("🗑️ Cleared all phlocks cache")
        }
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
