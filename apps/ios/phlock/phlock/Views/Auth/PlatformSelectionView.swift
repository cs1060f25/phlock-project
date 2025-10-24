import SwiftUI

struct PlatformSelectionView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var showProfileSetup = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("Connect Your Music")
                    .font(.system(size: 32, weight: .bold))

                Text("Choose your streaming platform to get started")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)

            Spacer()

            // Platform Cards
            VStack(spacing: 20) {
                PlatformCard(
                    platform: "Spotify",
                    icon: "music.note",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33)
                ) {
                    await signInWithSpotify()
                }

                PlatformCard(
                    platform: "Apple Music",
                    icon: "applelogo",
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
        .navigationDestination(isPresented: $showProfileSetup) {
            ProfileSetupView()
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
            print("✅ Successfully authenticated, showing profile setup")
            showProfileSetup = true
        } else {
            print("⚠️ Sign-in completed but not authenticated and no error?")
        }
    }

    private func signInWithAppleMusic() async {
        await authState.signInWithAppleMusic()

        if let error = authState.error {
            errorMessage = error.localizedDescription
            showError = true
        } else if authState.isAuthenticated {
            showProfileSetup = true
        }
    }
}

struct PlatformCard: View {
    let platform: String
    let icon: String
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
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue with \(platform)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Connect and sync your music")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

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
