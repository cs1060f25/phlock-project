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
    var formattedDate: String {
        guard let date = selectedDate else { return "" }
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        recipientId = try container.decode(UUID.self, forKey: .recipientId)
        trackId = try container.decode(String.self, forKey: .trackId)
        trackName = try container.decode(String.self, forKey: .trackName)
        artistName = try container.decode(String.self, forKey: .artistName)
        albumArtUrl = try container.decodeIfPresent(String.self, forKey: .albumArtUrl)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        status = try container.decode(ShareStatus.self, forKey: .status)
        isDailySong = try container.decode(Bool.self, forKey: .isDailySong)
        previewUrl = try container.decodeIfPresent(String.self, forKey: .previewUrl)

        // Custom date decoding to handle various formats
        // Note: For date-only strings (yyyy-MM-dd), we use local timezone to ensure
        // the date displays correctly regardless of user's location
        let dateStrategies: [(String) -> Date?] = [
            { ISO8601DateFormatter().date(from: $0) },
            {
                // Date-only format - use LOCAL timezone so "2025-11-27" means
                // "November 27 in the user's timezone", not "November 27 UTC"
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone.current // Local timezone
                return formatter.date(from: $0)
            },
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return formatter.date(from: $0)
            },
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter.date(from: $0)
            }
        ]

        func decodeDate(forKey key: CodingKeys) throws -> Date? {
            if let dateString = try? container.decode(String.self, forKey: key) {
                for strategy in dateStrategies {
                    if let date = strategy(dateString) {
                        return date
                    }
                }
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid date format: \(dateString)")
            }
            return nil
        }
        
        func decodeDateRequired(forKey key: CodingKeys) throws -> Date {
             if let date = try decodeDate(forKey: key) {
                 return date
             }
             throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Missing or invalid required date")
        }

        createdAt = try decodeDateRequired(forKey: .createdAt)
        updatedAt = try decodeDate(forKey: .updatedAt)
        playedAt = try decodeDate(forKey: .playedAt)
        savedAt = try decodeDate(forKey: .savedAt)
        selectedDate = try decodeDate(forKey: .selectedDate)
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

// Convenience initializer for manually constructing demo shares without decoding
extension Share {
    init(
        id: UUID = UUID(),
        senderId: UUID,
        recipientId: UUID,
        trackId: String,
        trackName: String,
        artistName: String,
        albumArtUrl: String? = nil,
        message: String? = nil,
        status: ShareStatus = .sent,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        playedAt: Date? = nil,
        savedAt: Date? = nil,
        isDailySong: Bool = false,
        selectedDate: Date? = nil,
        previewUrl: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.trackId = trackId
        self.trackName = trackName
        self.artistName = artistName
        self.albumArtUrl = albumArtUrl
        self.message = message
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.playedAt = playedAt
        self.savedAt = savedAt
        self.isDailySong = isDailySong
        self.selectedDate = selectedDate
        self.previewUrl = previewUrl
    }
}
