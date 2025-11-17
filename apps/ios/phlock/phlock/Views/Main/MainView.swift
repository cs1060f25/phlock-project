import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState
    @StateObject private var playbackService = PlaybackService.shared
    @StateObject private var navigationState = NavigationState()
    @Environment(\.colorScheme) var colorScheme
    @State private var showMiniPlayerShareSheet = false
    @State private var miniPlayerTrackToShare: MusicItem? = nil

    var body: some View {
        ZStack {
            // Base layer - tabs and content
            ZStack(alignment: .bottom) {
                CustomTabBarView(
                    selectedTab: $navigationState.selectedTab,
                    feedNavigationPath: $navigationState.feedNavigationPath,
                    discoverNavigationPath: $navigationState.discoverNavigationPath,
                    inboxNavigationPath: $navigationState.inboxNavigationPath,
                    phlocksNavigationPath: $navigationState.phlocksNavigationPath,
                    clearDiscoverSearchTrigger: $navigationState.clearDiscoverSearchTrigger,
                    refreshFeedTrigger: $navigationState.refreshFeedTrigger,
                    refreshInboxTrigger: $navigationState.refreshInboxTrigger,
                    refreshPhlocksTrigger: $navigationState.refreshPhlocksTrigger,
                    scrollFeedToTopTrigger: $navigationState.scrollFeedToTopTrigger,
                    scrollInboxToTopTrigger: $navigationState.scrollInboxToTopTrigger,
                    scrollPhlocksToTopTrigger: $navigationState.scrollPhlocksToTopTrigger,
                    feedView: AnyView(
                        FeedView(navigationPath: $navigationState.feedNavigationPath, refreshTrigger: $navigationState.refreshFeedTrigger, scrollToTopTrigger: $navigationState.scrollFeedToTopTrigger)
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                            .environment(\.colorScheme, colorScheme)
                    ),
                    discoverView: AnyView(
                        DiscoverView(navigationPath: $navigationState.discoverNavigationPath, clearSearchTrigger: $navigationState.clearDiscoverSearchTrigger)
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                    ),
                    inboxView: AnyView(
                        TheCrateView(navigationPath: $navigationState.inboxNavigationPath, refreshTrigger: $navigationState.refreshInboxTrigger, scrollToTopTrigger: $navigationState.scrollInboxToTopTrigger)
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                            .environment(\.colorScheme, colorScheme)
                    ),
                    phlocksView: AnyView(
                        MyPhlocksView(navigationPath: $navigationState.phlocksNavigationPath, refreshTrigger: $navigationState.refreshPhlocksTrigger, scrollToTopTrigger: $navigationState.scrollPhlocksToTopTrigger)
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                    )
                )
                .ignoresSafeArea(.keyboard)
                .onAppear {
                    // Navigation state handles storage automatically via init()
                }

                // Mini Player sits above tab bar (only show if shouldShowMiniPlayer is true)
                if playbackService.currentTrack != nil && playbackService.shouldShowMiniPlayer {
                    VStack(spacing: 0) {
                        Spacer()
                        MiniPlayerView(
                            playbackService: playbackService,
                            showFullPlayer: $navigationState.showFullPlayer,
                            showShareSheet: $showMiniPlayerShareSheet,
                            trackToShare: $miniPlayerTrackToShare
                        )
                        .environmentObject(authState)
                        .padding(.bottom, 53) // Position directly on top of tab bar
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }
            .zIndex(0)

            // QuickSendBar overlay - sits above everything including mini player
            if showMiniPlayerShareSheet, let track = miniPlayerTrackToShare {
                QuickSendBar(
                    track: track,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showMiniPlayerShareSheet = false
                            miniPlayerTrackToShare = nil
                        }
                    },
                    onSendComplete: { sentToFriends in
                        showMiniPlayerShareSheet = false
                        miniPlayerTrackToShare = nil
                    },
                    additionalBottomInset: QuickSendBar.Layout.overlayInset
                )
                .environmentObject(authState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1000)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMiniPlayerShareSheet)
            }
        }
        .environmentObject(playbackService)
        .sheet(isPresented: $navigationState.showFullPlayer) {
            FullScreenPlayerView(
                playbackService: playbackService,
                isPresented: $navigationState.showFullPlayer
            )
            .environmentObject(authState)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AuthenticationState())
}
