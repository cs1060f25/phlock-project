import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct WelcomeView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var isRotating = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            Image("PhlockLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 234, height: 234)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: isRotating)
                .onAppear {
                    isRotating = true
                }

            // Brand Name & Tagline
            VStack(spacing: 8) {
                Text("phlock")
                    .font(.lora(size: 42, weight: .bold))
                    .foregroundColor(.primary)

                Text("heard together")
                    .font(.lora(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)

            Spacer()

            // Sign in buttons
            VStack(spacing: 16) {
                // Sign in with Apple
                Button {
                    signInWithApple()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                        Text("Sign in with Apple")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
                }
                .disabled(isLoading)

                // Sign in with Google
                Button {
                    Task {
                        await signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image("GoogleLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text("Sign in with Google")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // Terms
            Text("By continuing, you agree to our\nTerms of Service and Privacy Policy")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .background(Color.white)
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Apple Sign In

    private func signInWithApple() {
        isLoading = true

        let coordinator = AppleSignInCoordinator { result in
            Task {
                await handleAppleSignInResult(result)
            }
        }
        self.appleSignInCoordinator = coordinator
        coordinator.startSignIn()
    }

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                do {
                    // Use timeout and retry for resilience against network issues
                    let (_, isNewUser) = try await withTimeoutAndRetry(
                        timeoutSeconds: 30,
                        retryConfig: RetryConfiguration(
                            maxAttempts: 2,
                            baseDelay: 1.0,
                            maxDelay: 5.0,
                            shouldRetry: { error in
                                // Retry on timeout and network errors, not on auth errors
                                if error is TimeoutError { return true }
                                let nsError = error as NSError
                                return nsError.domain == NSURLErrorDomain &&
                                    (nsError.code == NSURLErrorTimedOut ||
                                     nsError.code == NSURLErrorNetworkConnectionLost ||
                                     nsError.code == NSURLErrorNotConnectedToInternet)
                            }
                        )
                    ) {
                        try await AuthServiceV3.shared.signInWithApple(credential: appleIDCredential)
                    }

                    // Fetch the user to update currentUser
                    let user = try await AuthServiceV3.shared.currentUser

                    await MainActor.run {
                        authState.currentUser = user

                        print("🍎 Apple Sign-In complete:")
                        print("   isNewUser: \(isNewUser)")
                        print("   user.displayName: \(user?.displayName ?? "nil")")
                        print("   user.username: \(user?.username ?? "nil")")
                        print("   user.musicPlatform: \(user?.musicPlatform ?? "nil")")

                        if isNewUser {
                            // New user - start onboarding flow
                            authState.needsNameSetup = true
                            authState.needsUsernameSetup = false // Will be set after name
                            authState.needsContactsPermission = false // Will be set after username
                            authState.needsAddFriends = false
                            authState.needsInviteFriends = false
                            authState.needsNotificationPermission = false
                            authState.needsMusicPlatform = false // Will be set after contacts
                            authState.isOnboardingComplete = false
                            UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
                            print("   🆕 New user - starting onboarding")
                        } else {
                            // Returning user - skip onboarding, go straight to main app
                            authState.needsNameSetup = false
                            authState.needsUsernameSetup = false
                            authState.needsContactsPermission = false
                            authState.needsAddFriends = false
                            authState.needsInviteFriends = false
                            authState.needsNotificationPermission = false
                            authState.needsMusicPlatform = false
                            authState.isOnboardingComplete = true
                            UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
                            print("   ✅ Returning user - skipping onboarding")
                        }

                        authState.isAuthenticated = true
                    }

                } catch is TimeoutError {
                    await MainActor.run {
                        errorMessage = "Request timed out. Please try again."
                        showError = true
                    }
                } catch {
                    await MainActor.run {
                        // Convert to AppError for better error messages
                        let appError = AppError.from(error)
                        errorMessage = appError.localizedDescription
                        showError = true
                    }
                }
            }

        case .failure(let error):
            // Don't show error for user cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }

        await MainActor.run {
            isLoading = false
            appleSignInCoordinator = nil
        }
    }

    // MARK: - Google Sign In

    private func signInWithGoogle() async {
        isLoading = true

        // Check if Google Client ID is configured
        guard let clientID = Config.googleClientId else {
            await MainActor.run {
                errorMessage = "Google Sign-In is not configured. Please use Sign in with Apple."
                showError = true
                isLoading = false
            }
            return
        }

        // Configure GIDSignIn
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the root view controller on main thread
        guard let windowScene = await MainActor.run(body: { UIApplication.shared.connectedScenes.first as? UIWindowScene }),
              let rootViewController = await MainActor.run(body: { windowScene.windows.first?.rootViewController }) else {
            await MainActor.run {
                errorMessage = "Unable to present sign-in screen."
                showError = true
                isLoading = false
            }
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredential
            }
            let accessToken = result.user.accessToken.tokenString

            // Use timeout and retry for resilience against network issues
            let (_, isNewUser) = try await withTimeoutAndRetry(
                timeoutSeconds: 30,
                retryConfig: RetryConfiguration(
                    maxAttempts: 2,
                    baseDelay: 1.0,
                    maxDelay: 5.0,
                    shouldRetry: { error in
                        // Retry on timeout and network errors, not on auth errors
                        if error is TimeoutError { return true }
                        let nsError = error as NSError
                        return nsError.domain == NSURLErrorDomain &&
                            (nsError.code == NSURLErrorTimedOut ||
                             nsError.code == NSURLErrorNetworkConnectionLost ||
                             nsError.code == NSURLErrorNotConnectedToInternet)
                    }
                )
            ) {
                try await AuthServiceV3.shared.signInWithGoogle(
                    idToken: idToken,
                    accessToken: accessToken
                )
            }

            // Fetch the user to update currentUser
            let user = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = user

                print("🔵 Google Sign-In complete:")
                print("   isNewUser: \(isNewUser)")
                print("   user.displayName: \(user?.displayName ?? "nil")")
                print("   user.username: \(user?.username ?? "nil")")
                print("   user.musicPlatform: \(user?.musicPlatform ?? "nil")")

                if isNewUser {
                    // New user - start onboarding flow
                    authState.needsNameSetup = true
                    authState.needsUsernameSetup = false // Will be set after name
                    authState.needsContactsPermission = false // Will be set after username
                    authState.needsAddFriends = false
                    authState.needsInviteFriends = false
                    authState.needsNotificationPermission = false
                    authState.needsMusicPlatform = false // Will be set after contacts
                    authState.isOnboardingComplete = false
                    UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
                    print("   🆕 New user - starting onboarding")
                } else {
                    // Returning user - skip onboarding, go straight to main app
                    authState.needsNameSetup = false
                    authState.needsUsernameSetup = false
                    authState.needsContactsPermission = false
                    authState.needsAddFriends = false
                    authState.needsInviteFriends = false
                    authState.needsNotificationPermission = false
                    authState.needsMusicPlatform = false
                    authState.isOnboardingComplete = true
                    UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
                    print("   ✅ Returning user - skipping onboarding")
                }

                authState.isAuthenticated = true
            }

        } catch let error as GIDSignInError where error.code == .canceled {
            // User cancelled - don't show error
            print("Google Sign-In cancelled by user")
        } catch is TimeoutError {
            await MainActor.run {
                errorMessage = "Request timed out. Please try again."
                showError = true
            }
        } catch {
            await MainActor.run {
                // Convert to AppError for better error messages
                let appError = AppError.from(error)
                errorMessage = appError.localizedDescription
                showError = true
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthenticationState())
}
