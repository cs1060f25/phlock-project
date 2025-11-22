import Foundation

/// Represents a music share transaction between two users
/// Maps to the 'shares' table in Supabase
/// Extended to support daily song curation
struct Share: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let trackId: String
    let trackName: String
    let artistName: String
    let albumArtUrl: String?
    let message: String?
    var status: ShareStatus
    let createdAt: Date
    let updatedAt: Date?
    let playedAt: Date?
    let savedAt: Date?

    // Daily curation fields
    let isDailySong: Bool
    let selectedDate: Date?
    let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case trackId = "track_id"
        case trackName = "track_name"
        case artistName = "artist_name"
        case albumArtUrl = "album_art_url"
        case message
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case playedAt = "played_at"
        case savedAt = "saved_at"
        case isDailySong = "is_daily_song"
        case selectedDate = "selected_date"
        case previewUrl = "preview_url"
    }

    // Helper: Check if this is today's daily song
    var isToday: Bool {
        guard let date = selectedDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

    // Helper: Format selected date for display
    var formattedDate: String? {
        guard let date = selectedDate else { return nil }
        let formatter = DateFormatter()
        if isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

/// Status of a share transaction
enum ShareStatus: String, Codable {
    case sent
    case received
    case played
    case saved
    case forwarded
    case dismissed
}
