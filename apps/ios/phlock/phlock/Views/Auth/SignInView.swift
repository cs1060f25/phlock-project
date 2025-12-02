import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct SignInView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and tagline
            VStack(spacing: 12) {
                Text("phlock")
                    .font(.lora(size: 42, weight: .bold))
                    .foregroundColor(.primary)

                Text("share one song. every day.")
                    .font(.lora(size: 18))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 60)

            Spacer()

            // Sign in buttons
            VStack(spacing: 16) {
                // Sign in with Apple - custom button to avoid gesture conflicts
                Button {
                    print("🍎 Apple Sign-In button tapped")
                    signInWithApple()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                        Text("Sign in with Apple")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(Color.background(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.primaryColor(for: colorScheme))
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
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
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
                .font(.lora(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .overlay {
            if isLoading {
                LoadingView(message: "Signing in...")
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
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
                    let (_, isNewUser) = try await AuthServiceV3.shared.signInWithApple(credential: appleIDCredential)

                    // Fetch the user to update currentUser
                    let user = try await AuthServiceV3.shared.currentUser

                    await MainActor.run {
                        authState.currentUser = user

                        print("🍎 Apple Sign-In complete:")
                        print("   isNewUser: \(isNewUser)")
                        print("   user.username: \(user?.username ?? "nil")")
                        print("   user.musicPlatform: \(user?.musicPlatform ?? "nil")")

                        // Check what onboarding steps are needed
                        let needsUsername = user?.username == nil
                        let needsMusic = user?.musicPlatform == nil

                        authState.needsUsernameSetup = needsUsername
                        authState.needsMusicPlatform = !needsUsername && needsMusic
                        authState.isOnboardingComplete = !needsUsername && !needsMusic

                        // Also update UserDefaults to match
                        if !authState.isOnboardingComplete {
                            UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
                        }

                        print("   Setting: needsUsernameSetup=\(authState.needsUsernameSetup), needsMusicPlatform=\(authState.needsMusicPlatform), isOnboardingComplete=\(authState.isOnboardingComplete)")

                        authState.isAuthenticated = true
                    }

                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
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

            let (_, isNewUser) = try await AuthServiceV3.shared.signInWithGoogle(
                idToken: idToken,
                accessToken: accessToken
            )

            // Fetch the user to update currentUser
            let user = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = user

                print("🔵 Google Sign-In complete:")
                print("   isNewUser: \(isNewUser)")
                print("   user.username: \(user?.username ?? "nil")")
                print("   user.musicPlatform: \(user?.musicPlatform ?? "nil")")

                // Check what onboarding steps are needed
                let needsUsername = user?.username == nil
                let needsMusic = user?.musicPlatform == nil

                authState.needsUsernameSetup = needsUsername
                authState.needsMusicPlatform = !needsUsername && needsMusic
                authState.isOnboardingComplete = !needsUsername && !needsMusic

                // Also update UserDefaults to match
                if !authState.isOnboardingComplete {
                    UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
                }

                print("   Setting: needsUsernameSetup=\(authState.needsUsernameSetup), needsMusicPlatform=\(authState.needsMusicPlatform), isOnboardingComplete=\(authState.isOnboardingComplete)")

                authState.isAuthenticated = true
            }

        } catch let error as GIDSignInError where error.code == .canceled {
            // User cancelled - don't show error
            print("Google Sign-In cancelled by user")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environmentObject(AuthenticationState())
    }
}

// MARK: - Apple Sign In Coordinator

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        super.init()
    }

    func startSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
