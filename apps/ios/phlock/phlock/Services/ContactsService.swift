import Foundation
import Contacts

struct ContactMatch: Identifiable, Hashable {
    let id: UUID
    let contactName: String
    let user: User
}

private struct ContactCandidate {
    let name: String
    let phone: String
}

enum ContactsServiceError: Error {
    case accessDenied
}

/// Handles contact permissions and matching contacts to existing Phlock users.
final class ContactsService {
    static let shared = ContactsService()

    private let store = CNContactStore()

    private init() {}

    func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccessIfNeeded() async throws -> Bool {
        let status = authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        default:
            return false
        }
    }

    func findPhlockUsersInContacts() async throws -> [ContactMatch] {
        let granted = try await requestAccessIfNeeded()
        guard granted else { throw ContactsServiceError.accessDenied }

        let contacts = try fetchContactCandidates()
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

    // MARK: - Helpers

    private func fetchContactCandidates() throws -> [ContactCandidate] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [ContactCandidate] = []

        try store.enumerateContacts(with: request) { contact, _ in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

            for number in contact.phoneNumbers {
                let normalized = ContactsService.normalizePhone(number.value.stringValue)
                guard !normalized.isEmpty else { continue }
                contacts.append(ContactCandidate(name: fullName, phone: normalized))
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
}
