import SwiftUI

// Navigation destination types for Feed
enum FeedDestination: Hashable {
    case profile
    case userProfile(User)
    case conversation(User)
}

// MARK: - Daily Playlist View (replaces Feed) - PLACEHOLDER

struct FeedView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var navigationState: NavigationState
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Spacer()

                // Placeholder icon
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("Daily Playlist")
                    .font(.nunitoSans(size: 28, weight: .bold))

                Text("Your daily playlist feature is coming soon!")
                    .font(.nunitoSans(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("This will show your 5 daily songs from your phlock members")
                    .font(.nunitoSans(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("today's playlist")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: FeedDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                case .userProfile(let user):
                    UserProfileView(user: user)
                case .conversation(let user):
                    ConversationView(otherUser: user)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                }
            }
        }
        .fullScreenSwipeBack()
        .onChange(of: refreshTrigger) { oldValue, newValue in
            print("🔄 Playlist refreshTrigger changed from \(oldValue) to \(newValue)")
            // Refresh will be implemented when phlock system is ready
        }
    }
}

#Preview {
    FeedView(navigationPath: .constant(NavigationPath()), refreshTrigger: .constant(0), scrollToTopTrigger: .constant(0))
        .environmentObject(AuthenticationState())
        .environmentObject(PlaybackService.shared)
        .environmentObject(NavigationState())
}