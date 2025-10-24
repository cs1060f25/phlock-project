import Foundation
import Supabase
import KeychainAccess

/// Singleton Supabase client for the entire app
class PhlockSupabaseClient {
    static let shared = PhlockSupabaseClient()

    let client: Supabase.Client
    private let keychain = Keychain(service: "com.phlock.app")

    private init() {
        // Initialize Supabase client with secure session storage
        self.client = Supabase.Client(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: AuthClientOptions(
                    storage: KeychainAuthStorage(keychain: keychain),
                    autoRefreshToken: true,
                    persistSession: true
                )
            )
        )
    }

    // MARK: - Helper Methods

    /// Check if user is currently authenticated
    var isAuthenticated: Bool {
        get async {
            do {
                let session = try await client.auth.session
                return session.user != nil
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
}

// MARK: - Keychain Storage for Auth Tokens

/// Custom auth storage implementation using Keychain
class KeychainAuthStorage: AuthStorage {
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
