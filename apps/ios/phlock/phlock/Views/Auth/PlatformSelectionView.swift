import SwiftUI

struct PlatformSelectionView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("connect your music")
                    .font(.lora(size: 32, weight: .bold))

                Text("choose your streaming platform to get started")
                    .font(.lora(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)

            Spacer()

            // Platform Cards
            VStack(spacing: 20) {
                PlatformCard(
                    platform: "Spotify",
                    logo: "SpotifyLogo",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33)
                ) {
                    await signInWithSpotify()
                }

                PlatformCard(
                    platform: "Apple Music",
                    logo: "AppleMusicLogo",
                    color: Color(red: 0.98, green: 0.26, blue: 0.42)
                ) {
                    await signInWithAppleMusic()
                }
            }
            .padding(.horizontal, 24)

            Spacer()
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
    let action: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        Button {
            Task {
                isProcessing = true
                await action()
                isProcessing = false
            }
        } label: {
            HStack(spacing: 16) {
                Image(logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .padding(9)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())

                Text("continue with \(platform)")
                    .font(.lora(size: 17, weight: .semiBold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                if isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 2)
            )
        }
        .disabled(isProcessing)
    }
}

#Preview {
    NavigationStack {
        PlatformSelectionView()
            .environmentObject(AuthenticationState())
    }
}
