import Foundation

/// Represents OAuth tokens for music platform APIs
/// Maps to the 'platform_tokens' table in Supabase
struct PlatformToken: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let platformType: PlatformType
    let accessToken: String
    let refreshToken: String?
    let tokenExpiresAt: Date
    let scope: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case platformType = "platform_type"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiresAt = "token_expires_at"
        case scope
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
