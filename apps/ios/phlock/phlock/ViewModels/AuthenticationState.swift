import Foundation
import SwiftUI

/// Observable authentication state for the entire app
@MainActor
class AuthenticationState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var error: Error?

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Auth Status

    func checkAuthStatus() async {
        isLoading = true

        do {
            currentUser = try await AuthService.shared.getCurrentUser()
            isAuthenticated = currentUser != nil
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }

    // MARK: - Sign In

    func signInWithSpotify() async {
        isLoading = true
        error = nil

        do {
            let user = try await AuthService.shared.signInWithSpotify()
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
            let user = try await AuthService.shared.signInWithAppleMusic()
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
            try await AuthService.shared.updateUserProfile(
                userId: userId,
                displayName: displayName,
                bio: bio,
                profilePhotoUrl: profilePhotoUrl
            )

            // Refresh user data
            await checkAuthStatus()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func uploadProfilePhoto(imageData: Data) async -> String? {
        guard let userId = currentUser?.id else { return nil }

        do {
            return try await AuthService.shared.uploadProfilePhoto(userId: userId, imageData: imageData)
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await AuthService.shared.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            self.error = error
        }
    }
}
