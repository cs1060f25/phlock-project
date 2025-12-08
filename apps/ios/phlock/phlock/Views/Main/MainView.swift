import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var clipboardService: ClipboardService
    @StateObject private var playbackService = PlaybackService.shared
    @StateObject private var navigationState = NavigationState()
    @Environment(\.colorScheme) var colorScheme
    @State private var showMiniPlayerShareSheet = false
    @State private var miniPlayerTrackToShare: MusicItem? = nil
    @State private var recognitionTrackToShare: MusicItem? = nil
    @State private var showRecognitionQuickSend = false

    // Show mini player on all tabs except Phlock tab (which has its own playback UI)
    // We show the mini player whenever there's a track playing, regardless of how it was started
    private var shouldShowMiniPlayer: Bool {
        playbackService.currentTrack != nil && navigationState.selectedTab != 0
    }

    var body: some View {
        let miniPlayerInset = shouldShowMiniPlayer
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
                    scrollProfileToTopTrigger: $navigationState.scrollProfileToTopTrigger,
                    feedView: AnyView(
                        PhlockView(navigationPath: $navigationState.feedNavigationPath, refreshTrigger: $navigationState.refreshFeedTrigger, scrollToTopTrigger: $navigationState.scrollFeedToTopTrigger)
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
                        NavigationStack(path: $navigationState.profileNavigationPath) {
                            ProfileView(scrollToTopTrigger: $navigationState.scrollProfileToTopTrigger)
                        }
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                    )
                )
                .onAppear {
                    // Navigation state handles storage automatically via init()
                }

                // Mini Player sits above tab bar
                // Show on all tabs except Phlock tab (which has its own playback UI)
                if shouldShowMiniPlayer && !playbackService.isShareOverlayPresented {
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

            // MARK: - Commented out: Song Recognition FAB (may re-implement later)
            // if !navigationState.isFabHidden && !playbackService.isShareOverlayPresented {
            //     SongRecognitionFab(
            //         bottomInset: miniPlayerInset
            //     ) { track in
            //         recognitionTrackToShare = track
            //         showRecognitionQuickSend = true
            //     }
            //     .opacity(showMiniPlayerShareSheet || showRecognitionQuickSend ? 0 : 1)
            //     .zIndex(10)
            // }

            // QuickSendBar overlay - sits above everything including mini player
            if showMiniPlayerShareSheet, let track = miniPlayerTrackToShare {
                VStack {
                    Spacer()
                    ShareOptionsSheet(
                        track: track,
                        shareURL: ShareLinkBuilder.url(for: track),
                        context: .miniPlayer,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showMiniPlayerShareSheet = false
                                miniPlayerTrackToShare = nil
                            }
                        },
                        onCopy: { url in UIPasteboard.general.string = url.absoluteString },
                        onOpen: { url in UIApplication.shared.open(url) },
                        onFallback: { _ in }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMiniPlayerShareSheet)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }

            if showRecognitionQuickSend, let track = recognitionTrackToShare {
                VStack {
                    Spacer()
                    ShareOptionsSheet(
                        track: track,
                        shareURL: ShareLinkBuilder.url(for: track),
                        context: .miniPlayer,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showRecognitionQuickSend = false
                                recognitionTrackToShare = nil
                            }
                        },
                        onCopy: { url in UIPasteboard.general.string = url.absoluteString },
                        onOpen: { url in UIApplication.shared.open(url) },
                        onFallback: { _ in }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showRecognitionQuickSend)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }

            // Share sheet presented at top level above tab bar
            if navigationState.showShareSheet, let track = navigationState.shareTrack {
                VStack {
                    Spacer()
                    ShareOptionsSheet(
                        track: track,
                        shareURL: ShareLinkBuilder.url(for: track),
                        context: .overlay,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                navigationState.showShareSheet = false
                                navigationState.shareTrack = nil
                            }
                        },
                        onCopy: { url in UIPasteboard.general.string = url.absoluteString },
                        onOpen: { url in UIApplication.shared.open(url) },
                        onFallback: { _ in }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ + 100) // Higher z-index to ensure it's above tab bar
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: navigationState.showShareSheet)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            // Full Screen Player Overlay
            if navigationState.showFullPlayer {
                FullScreenPlayerView(
                    playbackService: playbackService,
                    isPresented: $navigationState.showFullPlayer
                )
                .environmentObject(authState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environment(\.miniPlayerBottomInset, miniPlayerInset)
        .environmentObject(playbackService)
        .environmentObject(navigationState)
        .environmentObject(clipboardService)
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: navigationState.showFullPlayer)
        .sheet(isPresented: $clipboardService.showSuggestionDialog) {
            if let track = clipboardService.detectedTrack {
                ClipboardSuggestionDialog(
                    track: track,
                    onShare: { note in
                        // Share the track as daily song
                        clipboardService.confirmSuggestion()
                        Task {
                            await shareDailySongFromClipboard(track: track, note: note)
                        }
                    },
                    onDismiss: {
                        clipboardService.dismissSuggestion()
                    }
                )
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    /// Share the clipboard track as today's daily song
    private func shareDailySongFromClipboard(track: MusicItem, note: String) async {
        do {
            guard let userId = authState.currentUser?.id else { return }

            _ = try await ShareService.shared.selectDailySong(
                track: track,
                note: note.isEmpty ? nil : note,
                userId: userId
            )

            // Mark as shared to avoid re-suggesting
            clipboardService.markAsShared(trackId: track.spotifyId ?? track.id)
            clipboardService.clearDetectedTrack()

            print("✅ Daily song shared from clipboard: \(track.name)")
        } catch {
            print("❌ Failed to share daily song from clipboard: \(error)")
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AuthenticationState())
        .environmentObject(ClipboardService())
}
