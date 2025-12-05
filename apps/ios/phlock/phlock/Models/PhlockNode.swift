import Foundation

/// Represents a single node in the phlock network visualization
/// Maps to the 'phlock_nodes' table in Supabase
struct PhlockNode: Codable, Identifiable, @unchecked Sendable {
    let id: UUID
    let phlockId: UUID
    let shareId: UUID?
    let userId: UUID
    let depth: Int
    let parentNodeId: UUID?
    var forwarded: Bool
    var saved: Bool
    var played: Bool
    let createdAt: Date

    // Transient properties (not stored in DB, populated when fetching)
    var user: User?
    var children: [PhlockNode] = []

    enum CodingKeys: String, CodingKey {
        case id
        case phlockId = "phlock_id"
        case shareId = "share_id"
        case userId = "user_id"
        case depth
        case parentNodeId = "parent_node_id"
        case forwarded
        case saved
        case played
        case createdAt = "created_at"
    }
}

// MARK: - Visualization Data Structures

/// Complete data structure for D3.js visualization
/// This is what gets passed to the WebView as JSON
struct PhlockVisualizationData: Codable, @unchecked Sendable {
    let phlock: PhlockBasicInfo
    let nodes: [VisualizationNode]
    let links: [VisualizationLink]
    let metrics: PhlockMetrics

    struct PhlockBasicInfo: Codable, @unchecked Sendable {
        let id: String
        let trackName: String
        let artistName: String
        let albumArtUrl: String?
    }
}

/// A node in the D3 force-directed graph
struct VisualizationNode: Codable, @unchecked Sendable {
    let id: String  // UUID as string
    let userId: String
    let name: String
    let profilePhotoUrl: String?
    let depth: Int
    let saved: Bool
    let forwarded: Bool
    let played: Bool
    let isRoot: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case profilePhotoUrl = "profile_photo_url"
        case depth
        case saved
        case forwarded
        case played
        case isRoot = "is_root"
    }
}

/// A link/edge between nodes in the graph
struct VisualizationLink: Codable, @unchecked Sendable {
    let source: String  // Node ID
    let target: String  // Node ID
    let timestamp: String  // ISO8601 date string
}

/// Calculated metrics for the phlock
struct PhlockMetrics: Codable, @unchecked Sendable {
    let totalReach: Int
    let generations: Int
    let saveRate: Double
    let forwardRate: Double
    let viralityScore: Double

    enum CodingKeys: String, CodingKey {
        case totalReach = "total_reach"
        case generations
        case saveRate = "save_rate"
        case forwardRate = "forward_rate"
        case viralityScore = "virality_score"
    }
}

// MARK: - Preview Data for Gallery Cards

/// Simplified phlock data for displaying in the gallery view
struct PhlockPreview: Identifiable, @unchecked Sendable {
    let id: UUID
    let trackName: String
    let artistName: String
    let albumArtUrl: String?
    let totalReach: Int
    let maxDepth: Int
    let saveRate: Double
    let createdAt: Date

    init(from phlock: Phlock, metrics: PhlockMetrics) {
        self.id = phlock.id
        self.trackName = phlock.trackName
        self.artistName = phlock.artistName
        self.albumArtUrl = phlock.albumArtUrl
        self.totalReach = phlock.totalReach
        self.maxDepth = phlock.maxDepth
        self.saveRate = metrics.saveRate
        self.createdAt = phlock.createdAt
    }
}
