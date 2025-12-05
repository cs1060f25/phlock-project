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
    @Published var needsNameSetup = false
    @Published var needsUsernameSetup = false
    @Published var needsContactsPermission = false
    @Published var needsAddFriends = false
    @Published var needsInviteFriends = false
    @Published var needsNotificationPermission = false
    @Published var needsMusicPlatform = false

    // Onboarding contact data
    @Published var onboardingContactMatches: [ContactMatch] = []
    @Published var onboardingInvitableContacts: [InvitableContact] = []

    // Profile photo cache busting
    @Published var profilePhotoVersion: Int = 0

    // Session health tracking
    @Published var sessionCorrupted = false
    private var authCheckAttempts = 0
    private let maxAuthCheckAttempts = 3

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Session Recovery

    /// Attempts to recover from a corrupted session
    func attemptSessionRecovery() async {
        print("🔧 Attempting session recovery...")
        sessionCorrupted = false
        authCheckAttempts = 0

        // Clear any corrupted local state
        await signOut()

        // Reset error state
        error = nil

        print("✅ Session recovery complete - user can now sign in again")
    }

    /// Force clear all auth state (use when nothing else works)
    func forceReset() async {
        print("🚨 Force resetting all auth state...")

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")

        // Sign out from services (ignore errors)
        try? await AuthServiceV3.shared.signOut()
        try? await AuthServiceV2.shared.signOut()

        // Reset all state
        currentUser = nil
        isAuthenticated = false
        isOnboardingComplete = false
        sessionCorrupted = false
        authCheckAttempts = 0
        error = nil
        needsNameSetup = false
        needsUsernameSetup = false
        needsContactsPermission = false
        needsAddFriends = false
        needsInviteFriends = false
        needsNotificationPermission = false
        needsMusicPlatform = false
        onboardingContactMatches = []
        onboardingInvitableContacts = []

        isLoading = false
        print("✅ Force reset complete")
    }

    // MARK: - Auth Status

    func checkAuthStatus() async {
        print("🔍 checkAuthStatus() called (attempt \(authCheckAttempts + 1)/\(maxAuthCheckAttempts))")
        isLoading = true
        authCheckAttempts += 1

        // Check onboarding status from UserDefaults
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        print("   UserDefaults isOnboardingComplete: \(isOnboardingComplete)")

        do {
            // Use timeout to prevent hanging on keychain/network issues
            try await withTimeout(seconds: 10) { [self] in
                // Try V3 first (new auth), fall back to V2 for existing sessions
                if let user = try await AuthServiceV3.shared.currentUser {
                    print("   Found V3 user: \(user.displayName), username: \(user.username ?? "nil"), musicPlatform: \(user.musicPlatform ?? "nil")")
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.sessionCorrupted = false
                        self.authCheckAttempts = 0 // Reset on success

                        // Check if user needs to complete onboarding steps
                        if user.username == nil {
                            self.needsUsernameSetup = true
                            self.isOnboardingComplete = false
                        } else if user.musicPlatform == nil {
                            self.needsMusicPlatform = true
                            self.isOnboardingComplete = false
                        } else {
                            // User has completed all required steps - mark onboarding as complete
                            self.needsUsernameSetup = false
                            self.needsMusicPlatform = false
                            self.isOnboardingComplete = true
                            UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
                        }
                    }
                    print("   After V3 check: username=\(user.username ?? "nil"), musicPlatform=\(user.musicPlatform ?? "nil")")
                } else if let user = try await AuthServiceV2.shared.currentUser {
                    // Legacy session - user already completed old flow
                    print("   Found V2 user (legacy): \(user.displayName)")
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.needsUsernameSetup = false
                        self.needsMusicPlatform = false
                        self.sessionCorrupted = false
                        self.authCheckAttempts = 0
                    }
                } else {
                    print("   No user found")
                    await MainActor.run {
                        self.isAuthenticated = false
                        self.currentUser = nil
                        self.authCheckAttempts = 0
                    }
                }
            }
        } catch is TimeoutError {
            print("⚠️ Auth check timed out after 10 seconds")
            handleAuthCheckFailure(error: AppError.timeout)
        } catch {
            print("   Error: \(error)")
            handleAuthCheckFailure(error: error)
        }

        isLoading = false
    }

    private func handleAuthCheckFailure(error: Error) {
        if authCheckAttempts >= maxAuthCheckAttempts {
            // Multiple failures - likely corrupted session
            print("🚨 Auth check failed \(authCheckAttempts) times - marking session as corrupted")
            sessionCorrupted = true
            self.error = AppError.sessionCorrupted
        } else {
            // First failure - set error but allow retry
            self.error = error
        }
        isAuthenticated = false
        currentUser = nil
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        needsNameSetup = false
        needsUsernameSetup = false
        needsContactsPermission = false
        needsAddFriends = false
        needsInviteFriends = false
        needsNotificationPermission = false
        needsMusicPlatform = false
        onboardingContactMatches = []
        onboardingInvitableContacts = []
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")

        // Auto-follow @woon after onboarding completion
        if let userId = currentUser?.id {
            Task {
                do {
                    try await FollowService.shared.autoFollowWoon(currentUserId: userId)
                } catch {
                    print("⚠️ Failed to auto-follow @woon: \(error)")
                }
            }
        }
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

    func updateProfile(displayName: String, username: String? = nil, bio: String?, profilePhotoUrl: String?) async {
        guard let userId = currentUser?.id else { return }

        isLoading = true
        error = nil

        do {
            // Use V3 for profile updates
            try await AuthServiceV3.shared.updateUserProfile(
                userId: userId,
                displayName: displayName,
                username: username,
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
        // Stop any playing audio before signing out
        PlaybackService.shared.stopPlayback()

        // Sign out from both services (ignore errors)
        try? await AuthServiceV3.shared.signOut()
        try? await AuthServiceV2.shared.signOut()

        currentUser = nil
        isAuthenticated = false
        isOnboardingComplete = false
        needsNameSetup = false
        needsUsernameSetup = false
        needsContactsPermission = false
        needsAddFriends = false
        needsInviteFriends = false
        needsNotificationPermission = false
        needsMusicPlatform = false
        onboardingContactMatches = []
        onboardingInvitableContacts = []
        UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
    }
}
