import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState
    @StateObject private var playbackService = PlaybackService.shared
    @StateObject private var navigationState = NavigationState()
    @Environment(\.colorScheme) var colorScheme
    @State private var showMiniPlayerShareSheet = false
    @State private var miniPlayerTrackToShare: MusicItem? = nil
    @State private var recognitionTrackToShare: MusicItem? = nil
    @State private var showRecognitionQuickSend = false

    var body: some View {
        let miniPlayerInset = playbackService.currentTrack != nil && playbackService.shouldShowMiniPlayer
            ? MiniPlayerView.Layout.height
            : 0

        ZStack {
            // Base layer - tabs and content
            ZStack(alignment: .bottom) {
                CustomTabBarView(
                    selectedTab: $navigationState.selectedTab,
                    feedNavigationPath: $navigationState.feedNavigationPath,
                    friendsNavigationPath: $navigationState.friendsNavigationPath,
                    notificationsNavigationPath: $navigationState.notificationsNavigationPath,
                    profileNavigationPath: $navigationState.profileNavigationPath,
                    refreshFeedTrigger: $navigationState.refreshFeedTrigger,
                    refreshFriendsTrigger: $navigationState.refreshFriendsTrigger,
                    refreshNotificationsTrigger: $navigationState.refreshNotificationsTrigger,
                    scrollFeedToTopTrigger: $navigationState.scrollFeedToTopTrigger,
                    scrollFriendsToTopTrigger: $navigationState.scrollFriendsToTopTrigger,
                    scrollNotificationsToTopTrigger: $navigationState.scrollNotificationsToTopTrigger,
                    feedView: AnyView(
                        FeedView(navigationPath: $navigationState.feedNavigationPath, refreshTrigger: $navigationState.refreshFeedTrigger, scrollToTopTrigger: $navigationState.scrollFeedToTopTrigger)
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                            .environmentObject(navigationState)
                            .environment(\.colorScheme, colorScheme)
                    ),
                    friendsView: AnyView(
                        FriendsView(
                            navigationPath: $navigationState.friendsNavigationPath,
                            refreshTrigger: $navigationState.refreshFriendsTrigger,
                            scrollToTopTrigger: $navigationState.scrollFriendsToTopTrigger
                        )
                        .environmentObject(authState)
                        .environmentObject(navigationState)
                        .environment(\.colorScheme, colorScheme)
                    ),
                    notificationsView: AnyView(
                        NotificationsView(
                            navigationPath: $navigationState.notificationsNavigationPath,
                            refreshTrigger: $navigationState.refreshNotificationsTrigger,
                            scrollToTopTrigger: $navigationState.scrollNotificationsToTopTrigger
                        )
                        .environmentObject(authState)
                        .environmentObject(navigationState)
                    ),
                    profileView: AnyView(
                        ProfileView()
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                    )
                )
                .onAppear {
                    // Navigation state handles storage automatically via init()
                }

                // Mini Player sits above tab bar (only show if shouldShowMiniPlayer is true)
                if playbackService.currentTrack != nil && playbackService.shouldShowMiniPlayer && !playbackService.isShareOverlayPresented {
                    VStack(spacing: 0) {
                        Spacer()
                        MiniPlayerView(
                            playbackService: playbackService,
                            showFullPlayer: $navigationState.showFullPlayer,
                            showShareSheet: $showMiniPlayerShareSheet,
                            trackToShare: $miniPlayerTrackToShare
                        )
                        .environmentObject(authState)
                        .padding(.bottom, MiniPlayerView.Layout.tabBarOffset)
                    }
                    .zIndex(playbackService.isShareOverlayPresented ? 1 : 2)
                }
            }
            .zIndex(playbackService.isShareOverlayPresented ? 2 : 0)

            if !navigationState.isFabHidden && !playbackService.isShareOverlayPresented {
                SongRecognitionFab(
                    bottomInset: miniPlayerInset
                ) { track in
                    recognitionTrackToShare = track
                    showRecognitionQuickSend = true
                }
                .opacity(showMiniPlayerShareSheet || showRecognitionQuickSend ? 0 : 1)
                .zIndex(10)
            }

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
                    onSendComplete: { _ in
                        showMiniPlayerShareSheet = false
                        miniPlayerTrackToShare = nil
                    },
                    additionalBottomInset: QuickSendBar.Layout.overlayInset
                )
                .environmentObject(authState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMiniPlayerShareSheet)
            }

            if showRecognitionQuickSend, let track = recognitionTrackToShare {
                QuickSendBar(
                    track: track,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRecognitionQuickSend = false
                            recognitionTrackToShare = nil
                        }
                    },
                    onSendComplete: { _ in
                        showRecognitionQuickSend = false
                        recognitionTrackToShare = nil
                    },
                    additionalBottomInset: QuickSendBar.Layout.overlayInset
                )
                .environmentObject(authState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showRecognitionQuickSend)
            }

            // Share sheet presented at top level above tab bar
            if navigationState.showShareSheet, let track = navigationState.shareTrack {
                QuickSendBar(
                    track: track,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            navigationState.showShareSheet = false
                            navigationState.shareTrack = nil
                        }
                    },
                    onSendComplete: { _ in
                        navigationState.showShareSheet = false
                        navigationState.shareTrack = nil
                    },
                    additionalBottomInset: QuickSendBar.Layout.overlayInset
                )
                .environmentObject(authState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ + 100) // Higher z-index to ensure it's above tab bar
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: navigationState.showShareSheet)
            }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .environment(\.miniPlayerBottomInset, miniPlayerInset)
        .environmentObject(playbackService)
        .environmentObject(navigationState)
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
