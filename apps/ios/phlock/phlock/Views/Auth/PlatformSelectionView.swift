import SwiftUI

struct PlatformSelectionView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Text("connect your music")
                    .font(.lora(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("choose your streaming platform to get started")
                    .font(.lora(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 60)

            Spacer()

            // Platform Cards
            VStack(spacing: 20) {
                PlatformCard(
                    platform: "Spotify",
                    logo: "SpotifyLogo",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33),
                    description: "Connect your Spotify account"
                ) {
                    await signInWithSpotify()
                }

                PlatformCard(
                    platform: "Apple Music",
                    logo: "AppleMusicLogo",
                    color: Color(red: 0.98, green: 0.26, blue: 0.42),
                    description: "Connect your Apple Music library"
                ) {
                    await signInWithAppleMusic()
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            
            // Disclaimer
            Text("by continuing, you agree to our terms of service and privacy policy")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if authState.isLoading {
                LoadingView(message: "Connecting...")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func signInWithSpotify() async {
        print("🎵 Starting Spotify sign-in...")
        await authState.signInWithSpotify()

        print("🎵 Sign-in completed. isAuthenticated: \(authState.isAuthenticated), error: \(String(describing: authState.error))")

        if let error = authState.error {
            print("❌ Spotify sign-in error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        } else if authState.isAuthenticated {
            print("✅ Successfully authenticated with Spotify!")
        }
    }

    private func signInWithAppleMusic() async {
        print("🍎 Starting Apple Music sign-in...")
        await authState.signInWithAppleMusic()

        print("🍎 Sign-in completed. isAuthenticated: \(authState.isAuthenticated), error: \(String(describing: authState.error))")

        if let error = authState.error {
            print("❌ Apple Music sign-in error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        } else if authState.isAuthenticated {
            print("✅ Successfully authenticated with Apple Music!")
        }
    }
}

struct PlatformCard: View {
    let platform: String
    let logo: String
    let color: Color
    let description: String
    let action: () async -> Void

    @State private var isProcessing = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            Task {
                isProcessing = true
                await action()
                isProcessing = false
            }
        } label: {
            HStack(spacing: 16) {
                // Logo Container
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(platform)
                        .font(.lora(size: 18, weight: .semiBold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlatformCardButtonStyle())
        .disabled(isProcessing)
    }
}

struct PlatformCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        PlatformSelectionView()
            .environmentObject(AuthenticationState())
    }
}
