import Foundation
import Supabase
@preconcurrency import KeychainAccess

/// Singleton Supabase client for the entire app
class PhlockSupabaseClient {
    static let shared = PhlockSupabaseClient()

    let client: SupabaseClient
    private let keychain = Keychain(service: "com.phlock.app")

    private init() {
        // Create URLSession configuration with reasonable timeouts
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30  // 30 seconds for individual requests
        sessionConfig.timeoutIntervalForResource = 60 // 60 seconds total for a resource
        sessionConfig.waitsForConnectivity = true     // Wait for network to become available
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Initialize Supabase client with secure session storage and timeout configuration
        self.client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainAuthStorage(keychain: keychain),
                    autoRefreshToken: true
                ),
                global: .init(
                    session: URLSession(configuration: sessionConfig)
                )
            )
        )
    }

    // MARK: - Helper Methods

    /// Check if user is currently authenticated
    var isAuthenticated: Bool {
        get async {
            do {
                _ = try await client.auth.session
                return true
            } catch {
                return false
            }
        }
    }

    /// Get current user session
    func getCurrentSession() async throws -> Session? {
        return try await client.auth.session
    }

    /// Sign out current user
    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Force clear all auth data from keychain (for debugging/testing)
    func clearKeychainSession() {
        do {
            try keychain.removeAll()
            print("🗑️ Keychain session cleared")
        } catch {
            print("❌ Failed to clear keychain: \(error)")
        }
    }
}

// MARK: - Keychain Storage for Auth Tokens

/// Custom auth storage implementation using Keychain
final class KeychainAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let keychain: Keychain
    private let sessionKey = "supabase.session"

    init(keychain: Keychain) {
        self.keychain = keychain
    }

    func store(key: String, value: Data) throws {
        try keychain.set(value, key: key)
    }

    func retrieve(key: String) throws -> Data? {
        return try keychain.getData(key)
    }

    func remove(key: String) throws {
        try keychain.remove(key)
    }
}
