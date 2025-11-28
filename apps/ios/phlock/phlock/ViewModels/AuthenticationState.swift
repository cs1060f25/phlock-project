import Foundation
import SwiftUI
import Combine

/// Observable authentication state for the entire app
@MainActor
class AuthenticationState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var error: Error?
    @Published var isOnboardingComplete = false

    // New onboarding state flags for V3 auth flow
    @Published var needsUsernameSetup = false
    @Published var needsMusicPlatform = false

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Auth Status

    func checkAuthStatus() async {
        print("🔍 checkAuthStatus() called")
        isLoading = true

        // Check onboarding status from UserDefaults
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        print("   UserDefaults isOnboardingComplete: \(isOnboardingComplete)")

        do {
            // Try V3 first (new auth), fall back to V2 for existing sessions
            if let user = try await AuthServiceV3.shared.currentUser {
                print("   Found V3 user: \(user.displayName), username: \(user.username ?? "nil"), musicPlatform: \(user.musicPlatform ?? "nil")")
                currentUser = user
                isAuthenticated = true

                // Check if user needs to complete onboarding steps
                if user.username == nil {
                    needsUsernameSetup = true
                    isOnboardingComplete = false
                } else if user.musicPlatform == nil {
                    needsMusicPlatform = true
                    isOnboardingComplete = false
                } else {
                    // User has completed all required steps - mark onboarding as complete
                    needsUsernameSetup = false
                    needsMusicPlatform = false
                    isOnboardingComplete = true
                    UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
                }
                print("   After V3 check: needsUsernameSetup=\(needsUsernameSetup), needsMusicPlatform=\(needsMusicPlatform), isOnboardingComplete=\(isOnboardingComplete)")
            } else if let user = try await AuthServiceV2.shared.currentUser {
                // Legacy session - user already completed old flow
                print("   Found V2 user (legacy): \(user.displayName)")
                currentUser = user
                isAuthenticated = true
                needsUsernameSetup = false
                needsMusicPlatform = false
            } else {
                print("   No user found")
                isAuthenticated = false
                currentUser = nil
            }
        } catch {
            print("   Error: \(error)")
            self.error = error
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        needsUsernameSetup = false
        needsMusicPlatform = false
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
    }

    // MARK: - Sign In (Legacy V2 - kept for backwards compatibility)

    func signInWithSpotify() async {
        isLoading = true
        error = nil

        do {
            let user = try await AuthServiceV2.shared.signInWithSpotify()
            currentUser = user
            isAuthenticated = true
        } catch {
            self.error = error
            isAuthenticated = false
        }

        isLoading = false
    }

    func signInWithAppleMusic() async {
        isLoading = true
        error = nil

        do {
            let user = try await AuthServiceV2.shared.signInWithApple()
            currentUser = user
            isAuthenticated = true
        } catch {
            self.error = error
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - Profile Update

    func updateProfile(displayName: String, bio: String?, profilePhotoUrl: String?) async {
        guard let userId = currentUser?.id else { return }

        isLoading = true
        error = nil

        do {
            // Use V3 for profile updates
            try await AuthServiceV3.shared.updateUserProfile(
                userId: userId,
                displayName: displayName,
                bio: bio,
                profilePhotoUrl: profilePhotoUrl
            )

            // Refresh user data
            currentUser = try await AuthServiceV3.shared.getUserById(userId)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func uploadProfilePhoto(imageData: Data) async -> String? {
        guard let userId = currentUser?.id else { return nil }

        do {
            return try await AuthServiceV3.shared.uploadProfilePhoto(userId: userId, imageData: imageData)
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Refresh Music Data

    func refreshMusicData() async {
        print("🔄 AuthenticationState.refreshMusicData() called")
        do {
            if let updatedUser = try await AuthServiceV2.shared.refreshMusicData() {
                print("✅ Music data refreshed, updating currentUser")
                currentUser = updatedUser
            } else {
                print("⚠️ refreshMusicData returned nil")
            }
        } catch {
            print("❌ Failed to refresh music data: \(error)")
            self.error = error
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        // Sign out from both services (ignore errors)
        try? await AuthServiceV3.shared.signOut()
        try? await AuthServiceV2.shared.signOut()

        currentUser = nil
        isAuthenticated = false
        isOnboardingComplete = false
        needsUsernameSetup = false
        needsMusicPlatform = false
        UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
    }
}
