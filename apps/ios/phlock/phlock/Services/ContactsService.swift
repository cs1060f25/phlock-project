import Foundation
import Contacts
import Supabase
import CommonCrypto

// MARK: - String+Emoji Extension

private extension String {
    /// Returns true if the string contains any emoji characters
    var containsEmoji: Bool {
        for scalar in unicodeScalars {
            if scalar.properties.isEmoji && scalar.properties.isEmojiPresentation {
                return true
            }
            // Also check for emoji modifiers and sequences
            if scalar.value >= 0x1F600 && scalar.value <= 0x1F64F { return true }  // Emoticons
            if scalar.value >= 0x1F300 && scalar.value <= 0x1F5FF { return true }  // Misc Symbols
            if scalar.value >= 0x1F680 && scalar.value <= 0x1F6FF { return true }  // Transport
            if scalar.value >= 0x1F1E0 && scalar.value <= 0x1F1FF { return true }  // Flags
            if scalar.value >= 0x2600 && scalar.value <= 0x26FF { return true }    // Misc symbols
            if scalar.value >= 0x2700 && scalar.value <= 0x27BF { return true }    // Dingbats
        }
        return false
    }
}

struct ContactMatch: Identifiable, Hashable {
    let id: UUID
    let contactName: String
    let user: User
}

/// A contact that can be invited to Phlock (not yet on the platform)
struct InvitableContact: Identifiable {
    let id: String  // phone number as ID
    let name: String
    let phone: String
    let phoneHash: String
    let friendCount: Int  // How many Phlock users have this phone in their contacts
    let imageData: Data?  // Contact's thumbnail image from address book
    let closenessScore: Int  // Score based on contact completeness (photo, birthday, notes, etc.)
}

private struct ContactCandidate {
    let name: String
    let phone: String
    let imageData: Data?
    let closenessScore: Int  // Score based on contact completeness (photo, birthday, etc.)
}

enum ContactsServiceError: Error {
    case accessDenied
}

/// Handles contact permissions and matching contacts to existing Phlock users.
final class ContactsService {
    static let shared = ContactsService()

    private let store = CNContactStore()
    private let supabase = PhlockSupabaseClient.shared.client

    private init() {}

    func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccessIfNeeded() async throws -> Bool {
        let status = authorizationStatus()
        print("📇 requestAccessIfNeeded - status: \(status.rawValue)")
        switch status {
        case .authorized:
            print("📇 Already authorized (full access)")
            return true
        case .limited:
            // iOS 18+ limited access - still allows reading contacts
            print("📇 Limited access granted")
            return true
        case .denied, .restricted:
            print("📇 Denied or restricted")
            return false
        case .notDetermined:
            print("📇 Not determined - requesting access...")
            // Use the async version directly for iOS 18+
            if #available(iOS 18.0, *) {
                let granted = try await store.requestAccess(for: .contacts)
                print("📇 Request completed (iOS 18+) - granted: \(granted)")
                return granted
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    self.store.requestAccess(for: .contacts) { granted, error in
                        print("📇 Request completed - granted: \(granted), error: \(String(describing: error))")
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        @unknown default:
            print("📇 Unknown status")
            return false
        }
    }

    func findPhlockUsersInContacts() async throws -> [ContactMatch] {
        let granted = try await requestAccessIfNeeded()
        guard granted else { throw ContactsServiceError.accessDenied }

        // Fetch contacts on a background thread to avoid blocking main thread
        let contacts = try await Task.detached(priority: .userInitiated) {
            try self.fetchContactCandidates()
        }.value
        let phoneNumbers = Array(Set(contacts.map { $0.phone }.filter { !$0.isEmpty }))
        guard !phoneNumbers.isEmpty else { return [] }

        let matchedUsers = try await UserService.shared.findUsersByPhones(phoneNumbers: phoneNumbers)
        let userByPhone = Dictionary(uniqueKeysWithValues: matchedUsers.compactMap { user -> (String, User)? in
            guard let phone = user.phone else { return nil }
            let normalized = ContactsService.normalizePhone(phone)
            guard !normalized.isEmpty else { return nil }
            return (normalized, user)
        })

        var matches: [UUID: ContactMatch] = [:]
        for contact in contacts {
            if let user = userByPhone[contact.phone], matches[user.id] == nil {
                let name = contact.name.isEmpty ? user.displayName : contact.name
                matches[user.id] = ContactMatch(id: user.id, contactName: name, user: user)
            }
        }

        return matches
            .values
            .sorted { $0.contactName.localizedCaseInsensitiveCompare($1.contactName) == .orderedAscending }
    }

    /// Fetch all contacts for invite screen, excluding those already on Phlock
    func fetchAllContacts(excludingPhones matchedPhones: Set<String> = []) async throws -> [(name: String, phone: String)] {
        let granted = try await requestAccessIfNeeded()
        guard granted else { throw ContactsServiceError.accessDenied }

        let contacts = try await Task.detached(priority: .userInitiated) {
            try self.fetchContactCandidates()
        }.value

        // Deduplicate by phone number, keeping first occurrence (best name)
        var seen = Set<String>()
        var result: [(name: String, phone: String)] = []

        for contact in contacts {
            // Skip if already on Phlock or already seen
            guard !matchedPhones.contains(contact.phone),
                  !seen.contains(contact.phone),
                  !contact.name.isEmpty else { continue }

            seen.insert(contact.phone)
            result.append((name: contact.name, phone: contact.phone))
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Helpers

    private nonisolated func fetchContactCandidates() throws -> [ContactCandidate] {
        // Note: CNContactNoteKey requires special entitlement (com.apple.developer.contacts.notes)
        // so we don't include it here
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [ContactCandidate] = []

        // Create a local CNContactStore for this nonisolated context
        let localStore = CNContactStore()
        try localStore.enumerateContacts(with: request) { contact, _ in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let imageData = contact.thumbnailImageData

            // Calculate closeness score based on contact completeness
            var score = 0
            if imageData != nil { score += 5 }  // Has photo = strong indicator
            if !contact.emailAddresses.isEmpty { score += 2 }  // Has email
            if contact.birthday != nil { score += 3 }  // Has birthday = close relationship
            if contact.familyName.isEmpty && !contact.givenName.isEmpty { score += 2 }  // First name only = informal/friend
            if contact.phoneNumbers.count > 1 { score += 1 }  // Multiple phones
            if fullName.containsEmoji { score += 5 }  // Emoji in name = close friend

            for number in contact.phoneNumbers {
                let normalized = ContactsService.normalizePhone(number.value.stringValue)
                guard !normalized.isEmpty else { continue }
                contacts.append(ContactCandidate(name: fullName, phone: normalized, imageData: imageData, closenessScore: score))
            }
        }

        return contacts
    }

    static func normalizePhone(_ input: String) -> String {
        let allowed = CharacterSet(charactersIn: "+0123456789")
        return input
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
    }

    // MARK: - Server-side Contact Sync (for "X friends on phlock" feature)

    /// Hash a phone number using SHA256 for privacy-preserving server storage
    static func hashPhone(_ phone: String) -> String {
        let normalized = normalizePhone(phone)
        guard let data = normalized.data(using: .utf8) else { return "" }

        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        // Convert to hex string
        return buffer.map { String(format: "%02x", $0) }.joined()
    }

    /// Sync user's contacts to server (as hashed phone numbers)
    /// This enables the "X friends on phlock" feature
    func syncContactsToServer() async throws {
        let granted = try await requestAccessIfNeeded()
        guard granted else { throw ContactsServiceError.accessDenied }

        // Fetch contacts on background thread
        let contacts = try await Task.detached(priority: .userInitiated) {
            try self.fetchContactCandidates()
        }.value

        // Get unique phone numbers and hash them
        let phoneHashes = Array(Set(contacts.map { $0.phone }
            .filter { !$0.isEmpty }
            .map { ContactsService.hashPhone($0) }
            .filter { !$0.isEmpty }
        ))

        guard !phoneHashes.isEmpty else {
            print("📇 No contacts to sync")
            return
        }

        print("📇 Syncing \(phoneHashes.count) contact hashes to server...")

        // Call the RPC function to sync contacts
        try await supabase.rpc("sync_user_contacts", params: ["p_phone_hashes": phoneHashes]).execute()

        print("📇 Contact sync complete")
    }

    /// Fetch contacts with friend counts (how many Phlock users have each contact in their contacts)
    /// Excludes contacts already on Phlock
    func fetchContactsWithFriendCounts(excludingPhones matchedPhones: Set<String> = []) async throws -> [InvitableContact] {
        let granted = try await requestAccessIfNeeded()
        guard granted else { throw ContactsServiceError.accessDenied }

        // Fetch contacts on background thread
        let contacts = try await Task.detached(priority: .userInitiated) {
            try self.fetchContactCandidates()
        }.value

        // Deduplicate by phone number, keeping first occurrence (best name) and highest closeness score
        var seen = Set<String>()
        var uniqueContacts: [(name: String, phone: String, phoneHash: String, imageData: Data?, closenessScore: Int)] = []

        for contact in contacts {
            guard !matchedPhones.contains(contact.phone),
                  !seen.contains(contact.phone),
                  !contact.name.isEmpty else { continue }

            let hash = ContactsService.hashPhone(contact.phone)
            guard !hash.isEmpty else { continue }

            seen.insert(contact.phone)
            uniqueContacts.append((name: contact.name, phone: contact.phone, phoneHash: hash, imageData: contact.imageData, closenessScore: contact.closenessScore))
        }

        guard !uniqueContacts.isEmpty else { return [] }

        // Get friend counts from server
        let phoneHashes = uniqueContacts.map { $0.phoneHash }
        let friendCounts = try await getFriendCounts(phoneHashes: phoneHashes)

        // Build result with friend counts, sorted by: friend count > closeness score > has photo > name
        let result = uniqueContacts.map { contact in
            InvitableContact(
                id: contact.phone,
                name: contact.name,
                phone: contact.phone,
                phoneHash: contact.phoneHash,
                friendCount: friendCounts[contact.phoneHash] ?? 0,
                imageData: contact.imageData,
                closenessScore: contact.closenessScore
            )
        }
        .sorted { lhs, rhs in
            // Primary: friend count (higher first)
            if lhs.friendCount != rhs.friendCount {
                return lhs.friendCount > rhs.friendCount
            }
            // Secondary: closeness score (higher first)
            if lhs.closenessScore != rhs.closenessScore {
                return lhs.closenessScore > rhs.closenessScore
            }
            // Tertiary: has photo (photo first)
            if (lhs.imageData != nil) != (rhs.imageData != nil) {
                return lhs.imageData != nil
            }
            // Final: alphabetical
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return result
    }

    /// Get friend counts for a list of phone hashes from the server
    private func getFriendCounts(phoneHashes: [String]) async throws -> [String: Int] {
        guard !phoneHashes.isEmpty else { return [:] }

        struct FriendCountResult: Decodable {
            let phone_hash: String
            let friend_count: Int
        }

        let response: [FriendCountResult] = try await supabase
            .rpc("get_friend_counts", params: ["phone_hashes": phoneHashes])
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: response.map { ($0.phone_hash, $0.friend_count) })
    }
}
