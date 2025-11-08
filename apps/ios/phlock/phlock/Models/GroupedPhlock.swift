import Foundation

/// Represents a song (track) that a user has sent to multiple people
/// Groups individual Share objects by track_id to show aggregated metrics
struct GroupedPhlock: Identifiable {
    let trackId: String
    let trackName: String
    let artistName: String
    let albumArtUrl: String?

    // Metrics
    let recipientCount: Int  // Number of people sent to
    let totalReach: Int  // Including viral forwards
    let generations: Int  // Depth of viral spread
    let playedCount: Int  // How many listened
    let savedCount: Int  // How many saved
    let forwardedCount: Int  // How many forwarded it

    // Rates
    let listenRate: Double  // Percentage who played
    let saveRate: Double  // Percentage who saved

    // Timing
    let lastSentAt: Date  // Most recent send

    // Underlying shares
    let shares: [Share]

    var id: String { trackId }

    /// Format metrics for display
    var reachText: String {
        "\(totalReach) reached"
    }

    var generationsText: String {
        "\(generations) generation\(generations == 1 ? "" : "s")"
    }

    var saveRateText: String {
        String(format: "%.0f%% saved", saveRate * 100)
    }

    var listenRateText: String {
        String(format: "%.0f%% listened", listenRate * 100)
    }
}
