import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var showPlatformSelection = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App Icon/Logo
                Image(systemName: "music.note.list")
                    .font(.system(size: 80))
                    .foregroundColor(.black)

                // Title
                VStack(spacing: 12) {
                    Text("Welcome to Phlock")
                        .font(.system(size: 34, weight: .bold))

                    Text("Discover music through your friends")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Features
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(icon: "person.2.fill", title: "Connect with friends", description: "See what your friends are listening to")
                    FeatureRow(icon: "music.note", title: "Share music", description: "Send songs and discover new tracks")
                    FeatureRow(icon: "square.stack.3d.up.fill", title: "The Crate", description: "Your personalized music feed")
                }
                .padding(.horizontal, 24)

                Spacer()

                // Get Started Button
                NavigationLink(destination: PlatformSelectionView()) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthenticationState())
}
