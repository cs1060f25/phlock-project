import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var clipboardService: ClipboardService
    @StateObject private var playbackService = PlaybackService.shared
    @StateObject private var navigationState = NavigationState()
    @ObservedObject private var notificationService = NotificationService.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showMiniPlayerShareSheet = false
    @State private var miniPlayerTrackToShare: MusicItem? = nil
    @State private var recognitionTrackToShare: MusicItem? = nil
    @State private var showRecognitionQuickSend = false
    @State private var showPhonePrompt = false

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
                .task {
                    // Fetch unread notification count on app launch
                    if let userId = authState.currentUser?.id {
                        await notificationService.fetchUnreadCount(for: userId)
                    }

                    // Check if existing user needs phone number detection
                    // Only run if: user has synced contacts before AND doesn't have phone saved
                    await checkAndPromptForPhoneNumber()
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
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $navigationState.showFullPlayer) {
            FullScreenPlayerView(
                playbackService: playbackService,
                isPresented: $navigationState.showFullPlayer
            )
            .environmentObject(authState)
        }
        .environment(\.miniPlayerBottomInset, miniPlayerInset)
        .environmentObject(playbackService)
        .environmentObject(navigationState)
        .environmentObject(clipboardService)
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
        .sheet(isPresented: $showPhonePrompt) {
            PhoneNumberPromptSheet(
                isPresented: $showPhonePrompt,
                onSave: { phone in
                    Task {
                        if let userId = authState.currentUser?.id {
                            try? await UserService.shared.updateUserPhone(phone, for: userId)
                        }
                    }
                },
                onSkip: { }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.hidden)
        }
        // MARK: - Push Notification Navigation Handlers
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPhlock)) { _ in
            navigationState.selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToFriends)) { _ in
            navigationState.selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToNotifications)) { _ in
            navigationState.selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToProfile)) { _ in
            navigationState.selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToShare)) { notification in
            if let shareId = notification.userInfo?["shareId"] as? UUID,
               let sheetType = notification.userInfo?["sheetType"] as? String {
                // Navigate to phlock tab and set pending navigation
                let notificationSheetType: NotificationNavigation.NotificationSheetType
                switch sheetType {
                case "comments": notificationSheetType = .comments
                case "likers": notificationSheetType = .likers
                default: notificationSheetType = .none
                }
                navigationState.pendingNotificationNavigation = NotificationNavigation(
                    shareId: shareId,
                    sheetType: notificationSheetType,
                    isOwnPick: false
                )
                navigationState.selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSongPicker)) { _ in
            // Navigate to phlock tab - the song picker sheet will be shown by PhlockView
            // based on user not having picked today's song
            navigationState.selectedTab = 0
        }
    }

    /// Check if existing user needs phone number and prompt if necessary
    /// Runs silently on app launch for users who have synced contacts but don't have a phone saved
    private func checkAndPromptForPhoneNumber() async {
        // Only check if user has previously synced contacts
        let hasCompletedContactsStep = UserDefaults.standard.bool(forKey: "hasCompletedContactsStep")
        guard hasCompletedContactsStep else { return }

        // Check if user already has a phone number saved
        guard let currentUser = authState.currentUser, currentUser.phone == nil else { return }

        // Check if contacts access is still granted
        let status = ContactsService.shared.authorizationStatus()
        var hasAccess = status == .authorized
        if #available(iOS 18.0, *), status == .limited {
            hasAccess = true
        }
        guard hasAccess else { return }

        print("📱 Existing user without phone - attempting auto-detection...")

        // Try to auto-detect phone from Me card
        if let meCardPhone = await ContactsService.shared.getUserPhoneFromMeCard() {
            // Found! Save it silently
            try? await UserService.shared.updateUserPhone(meCardPhone, for: currentUser.id)
            print("📱 Auto-saved phone from Me card for existing user")
        } else {
            // Not found - show prompt
            await MainActor.run {
                showPhonePrompt = true
            }
            print("📱 No Me card found - showing phone prompt to existing user")
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

            // Refresh the current user to update hasSelectedToday and streak
            if let updatedUser = try? await UserService.shared.getUser(userId: userId, bypassCache: true) {
                await MainActor.run {
                    authState.currentUser = updatedUser
                }
            }

            // Trigger immediate refresh of PhlockView and switch to Phlock tab
            // This ensures the user sees their daily song and unlocked phlock content
            await MainActor.run {
                // Switch to Phlock tab (index 0) so user sees their shared song
                navigationState.selectedTab = 0
                // Trigger refresh to load the new daily song
                navigationState.refreshFeedTrigger += 1
            }
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
