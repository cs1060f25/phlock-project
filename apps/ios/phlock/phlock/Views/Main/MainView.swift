import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState
    @StateObject private var playbackService = PlaybackService.shared
    @AppStorage("selectedTab") private var selectedTabStorage = 0
    @State private var selectedTab = 0
    @State private var showFullPlayer = false
    @State private var feedNavigationPath = NavigationPath()
    @State private var discoverNavigationPath = NavigationPath()
    @State private var inboxNavigationPath = NavigationPath()
    @State private var phlocksNavigationPath = NavigationPath()
    @State private var clearDiscoverSearchTrigger = 0
    @State private var refreshFeedTrigger = 0
    @State private var refreshInboxTrigger = 0
    @State private var scrollFeedToTopTrigger = 0
    @State private var scrollInboxToTopTrigger = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            CustomTabBarView(
                selectedTab: $selectedTab,
                feedNavigationPath: $feedNavigationPath,
                discoverNavigationPath: $discoverNavigationPath,
                inboxNavigationPath: $inboxNavigationPath,
                phlocksNavigationPath: $phlocksNavigationPath,
                clearDiscoverSearchTrigger: $clearDiscoverSearchTrigger,
                refreshFeedTrigger: $refreshFeedTrigger,
                refreshInboxTrigger: $refreshInboxTrigger,
                scrollFeedToTopTrigger: $scrollFeedToTopTrigger,
                scrollInboxToTopTrigger: $scrollInboxToTopTrigger,
                feedView: AnyView(
                    FeedView(navigationPath: $feedNavigationPath, refreshTrigger: $refreshFeedTrigger, scrollToTopTrigger: $scrollFeedToTopTrigger)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                        .environment(\.colorScheme, colorScheme)
                ),
                discoverView: AnyView(
                    DiscoverView(navigationPath: $discoverNavigationPath, clearSearchTrigger: $clearDiscoverSearchTrigger)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                ),
                inboxView: AnyView(
                    TheCrateView(navigationPath: $inboxNavigationPath, refreshTrigger: $refreshInboxTrigger, scrollToTopTrigger: $scrollInboxToTopTrigger)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                        .environment(\.colorScheme, colorScheme)
                ),
                phlocksView: AnyView(
                    MyPhlocksView(navigationPath: $phlocksNavigationPath)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                )
            )
            .ignoresSafeArea(.keyboard)
            .onAppear {
                // Initialize from storage
                selectedTab = selectedTabStorage
            }

            // Mini Player sits above tab bar
            if playbackService.currentTrack != nil {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerView(
                        playbackService: playbackService,
                        showFullPlayer: $showFullPlayer
                    )
                    .environmentObject(authState)
                    .padding(.bottom, 53) // Position directly on top of tab bar
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .environmentObject(playbackService)
        .sheet(isPresented: $showFullPlayer) {
            FullScreenPlayerView(
                playbackService: playbackService,
                isPresented: $showFullPlayer
            )
            .environmentObject(authState)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AuthenticationState())
}
