import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Welcome to Phlock!")
                    .font(.system(size: 32, weight: .bold))

                if let user = authState.currentUser {
                    Text("You're signed in as \(user.displayName)")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
            }

            // Placeholder
            VStack(spacing: 12) {
                Text("🎵")
                    .font(.system(size: 64))

                Text("Main app coming soon...")
                    .font(.system(size: 24, weight: .semibold))

                Text("This is where the music sharing, friend discovery, and Crate will live!")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(32)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(20)
            .padding(.horizontal, 24)

            Spacer()

            // Sign Out Button
            PhlockButton(
                title: "Sign Out",
                action: { Task { await authState.signOut() } },
                variant: .secondary,
                fullWidth: true
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AuthenticationState())
}
