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

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Auth Status

    func checkAuthStatus() async {
        isLoading = true

        // Check onboarding status from UserDefaults
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")

        do {
            currentUser = try await AuthServiceV2.shared.currentUser
            isAuthenticated = currentUser != nil
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }
    
    func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
    }

    // MARK: - Sign In

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
            try await AuthServiceV2.shared.updateUserProfile(
                userId: userId,
                displayName: displayName,
                bio: bio,
                profilePhotoUrl: profilePhotoUrl
            )

            // Refresh user data by fetching directly
            currentUser = try await AuthServiceV2.shared.getUserById(userId)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func uploadProfilePhoto(imageData: Data) async -> String? {
        guard let userId = currentUser?.id else { return nil }

        do {
            return try await AuthServiceV2.shared.uploadProfilePhoto(userId: userId, imageData: imageData)
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Refresh Music Data

    func refreshMusicData() async {
        do {
            if let updatedUser = try await AuthServiceV2.shared.refreshMusicData() {
                currentUser = updatedUser
            }
        } catch {
            print("❌ Failed to refresh music data: \(error)")
            self.error = error
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await AuthServiceV2.shared.signOut()
            currentUser = nil
            isAuthenticated = false
            isOnboardingComplete = false
            UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
        } catch {
            self.error = error
        }
    }
}
