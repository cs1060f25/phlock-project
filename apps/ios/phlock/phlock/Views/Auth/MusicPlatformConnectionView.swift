import SwiftUI

struct MusicPlatformConnectionView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("connect your music")
                    .font(.lora(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("link your streaming service to search, share, and play music")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)

            Spacer()

            // Platform Options
            VStack(spacing: 16) {
                MusicPlatformButton(
                    platform: "Spotify",
                    logo: "SpotifyLogo",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33),
                    description: "Connect your Spotify account",
                    isConnecting: isConnecting
                ) {
                    await connectSpotify()
                }

                MusicPlatformButton(
                    platform: "Apple Music",
                    logo: "AppleMusicLogo",
                    color: Color(red: 0.98, green: 0.26, blue: 0.42),
                    description: "Connect your Apple Music library",
                    isConnecting: isConnecting
                ) {
                    await connectAppleMusic()
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Required notice
            Text("A music service is required to use Phlock")
                .font(.lora(size: 13))
                .foregroundColor(.secondary)
                .padding(.bottom, 32)
        }
        .overlay {
            if isConnecting {
                LoadingView(message: "Connecting...")
            }
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Connect Spotify

    private func connectSpotify() async {
        isConnecting = true

        do {
            // Trigger Spotify OAuth
            let spotifyAuth = try await SpotifyService.shared.authenticate()

            // Store the connection
            try await AuthServiceV3.shared.connectSpotify(
                accessToken: spotifyAuth.accessToken,
                refreshToken: spotifyAuth.refreshToken,
                expiresIn: spotifyAuth.expiresIn,
                scope: spotifyAuth.scope
            )

            // Fetch updated user with music platform set
            let updatedUser = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = updatedUser
                print("✅ Spotify connected - user.musicPlatform: \(updatedUser?.musicPlatform ?? "nil")")
                completeOnboarding()
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        await MainActor.run {
            isConnecting = false
        }
    }

    // MARK: - Connect Apple Music

    private func connectAppleMusic() async {
        isConnecting = true

        do {
            // Trigger Apple Music authorization
            let appleMusicAuth = try await AppleMusicService.shared.authenticate()

            // Store the connection
            try await AuthServiceV3.shared.connectAppleMusic(userToken: appleMusicAuth.userToken)

            // Fetch updated user with music platform set
            let updatedUser = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = updatedUser
                print("✅ Apple Music connected - user.musicPlatform: \(updatedUser?.musicPlatform ?? "nil")")
                completeOnboarding()
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        await MainActor.run {
            isConnecting = false
        }
    }

    private func completeOnboarding() {
        authState.needsMusicPlatform = false
        authState.completeOnboarding()
    }
}

// MARK: - Music Platform Button

struct MusicPlatformButton: View {
    let platform: String
    let logo: String
    let color: Color
    let description: String
    let isConnecting: Bool
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
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
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
        .buttonStyle(ScaleButtonStyle())
        .disabled(isConnecting || isProcessing)
    }
}

#Preview {
    NavigationStack {
        MusicPlatformConnectionView()
            .environmentObject(AuthenticationState())
    }
}
