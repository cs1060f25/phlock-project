import Foundation

/// Represents a recipient of a shared song with their engagement status
/// Used in PhlockDetailView to show who received a specific track
struct PhlockRecipient: Identifiable {
    let user: User
    let shareId: UUID
    let status: ShareStatus
    let sentAt: Date
    let playedAt: Date?
    let savedAt: Date?
    let message: String?

    var id: UUID { shareId }

    /// Status icon for display
    var statusIcon: String {
        switch status {
        case .sent, .received:
            return "paperplane"
        case .played:
            return "play.circle.fill"
        case .saved:
            return "bookmark.fill"
        case .dismissed:
            return "xmark.circle"
        case .forwarded:
            return "arrow.turn.up.right"
        }
    }

    /// Status color for display
    var statusColor: String {
        switch status {
        case .sent, .received:
            return "gray"
        case .played:
            return "green"
        case .saved:
            return "purple"
        case .dismissed:
            return "red"
        case .forwarded:
            return "blue"
        }
    }

    /// Human-readable status text
    var statusText: String {
        switch status {
        case .sent, .received:
            return "Sent"
        case .played:
            if let playedAt = playedAt {
                return "Played \(timeAgo(from: playedAt))"
            }
            return "Played"
        case .saved:
            if let savedAt = savedAt {
                return "Saved \(timeAgo(from: savedAt))"
            }
            return "Saved"
        case .dismissed:
            return "Dismissed"
        case .forwarded:
            return "Forwarded"
        }
    }

    /// Format time ago helper
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if seconds < 60 {
            return "just now"
        } else if minutes < 60 {
            return "\(Int(minutes))m ago"
        } else if hours < 24 {
            return "\(Int(hours))h ago"
        } else if days < 7 {
            return "\(Int(days))d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}
