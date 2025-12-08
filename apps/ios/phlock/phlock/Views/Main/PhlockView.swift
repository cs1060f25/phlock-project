import SwiftUI
import AVFoundation
import Supabase
import Contacts

// MARK: - Scrollable Message Text Component

/// A horizontally scrollable text view with fade gradient that disappears when scrolled to end
struct ScrollableMessageText: View {
    let message: String

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    private var needsScroll: Bool {
        textWidth > containerWidth
    }

    private var isAtEnd: Bool {
        // Consider "at end" when scrolled within 5 points of the end
        scrollOffset >= (textWidth - containerWidth - 5)
    }

    var body: some View {
        GeometryReader { containerGeo in
            ScrollView(.horizontal, showsIndicators: false) {
                Text("— \"\(message)\"")
                    .font(.lora(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                    .italic()
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeo.size.width
                                }
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                           value: containerGeo.frame(in: .global).minX - textGeo.frame(in: .global).minX)
                        }
                    )
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .onAppear {
                containerWidth = containerGeo.size.width
            }
            .mask(
                HStack(spacing: 0) {
                    Color.black
                    if needsScroll && !isAtEnd {
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20)
                    }
                }
            )
        }
        .frame(height: 16) // Fixed height for the text line
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Navigation destination types for Phlock
enum PhlockDestination: Hashable {
    case profile
    case userProfile(User)
    case conversation(User)
}

// MARK: - Daily Playlist View

struct PhlockView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var navigationState: NavigationState
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    @State private var phlockMembers: [FriendWithPosition] = []
    @State private var dailySongs: [Share] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showSwapSheet = false
    @State private var selectedMemberToSwap: User?
    @State private var showAddSheet = false
    @State private var selectedPositionToAdd: Int?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ShareToast.ToastType = .success

    @State private var nudgedUserIds: Set<UUID> = []
    @State private var nudgedResetDate = Calendar.current.startOfDay(for: Date())
    @State private var autoplayEnabled = true
    // savedTrackIds now lives in playbackService.savedTrackIds to persist across tab switches
    @State private var myDailySong: Share?
    @State private var showDailySongSheet = false
    @State private var myDailySongNavPath = NavigationPath()
    @State private var myDailySongClearTrigger = 0
    @State private var myDailySongRefreshTrigger = 0
    @State private var myDailySongScrollToTopTrigger = 0
    @State private var hasLoadedPhlockOnce = false

    // Edit mode state
    @State private var showFriendPicker = false
    @State private var editMemberToSwap: User?  // Member being replaced in edit mode
    @State private var availableFriendsForEdit: [User] = []
    @State private var isLoadingFriends = false
    @State private var showPhlockManagerSheet = false

    // Share card state
    @State private var isGeneratingShareCard = false
    @State private var generatedShareCardImages: [ShareCardFormat: UIImage] = [:]
    @State private var showShareSheet = false

    // Profile sheet state
    @State private var showProfileSheet = false
    @State private var selectedProfileUser: User?

    // Helper struct to organize phlock items
    struct PhlockItem: Identifiable {
        let id: UUID
        let member: User?
        let song: Share?
        let type: ItemType

        enum ItemType {
            case song
            case waiting
            case empty
        }

        // Stable UUIDs for empty slots to prevent view recreation
        // These are deterministic based on position (0-4)
        private static let emptySlotIds: [UUID] = [
            UUID(uuidString: "E0000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "E0000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "E0000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "E0000000-0000-0000-0000-000000000003")!,
            UUID(uuidString: "E0000000-0000-0000-0000-000000000004")!
        ]

        static func stableEmptySlotId(at position: Int) -> UUID {
            guard position >= 0 && position < emptySlotIds.count else {
                return UUID() // Fallback for unexpected positions
            }
            return emptySlotIds[position]
        }
    }

    private var sortedPhlockItems: [PhlockItem] {
        var items: [PhlockItem] = []

        // 1. Members with songs (sorted by streak count, highest first)
        let membersWithSongs = phlockMembers.compactMap { member -> (FriendWithPosition, Share)? in
            guard let song = dailySongs.first(where: { $0.senderId == member.user.id }) else { return nil }
            return (member, song)
        }.sorted { $0.0.user.dailySongStreak > $1.0.user.dailySongStreak }

        for (member, song) in membersWithSongs {
            items.append(PhlockItem(id: member.user.id, member: member.user, song: song, type: .song))
        }

        // 2. Members without songs (sorted by streak count, highest first)
        let membersWithoutSongs = phlockMembers.filter { member in
            !dailySongs.contains(where: { $0.senderId == member.user.id })
        }.sorted { $0.user.dailySongStreak > $1.user.dailySongStreak }

        for member in membersWithoutSongs {
            items.append(PhlockItem(id: member.user.id, member: member.user, song: nil, type: .waiting))
        }

        // 3. Empty slots (up to 5 total)
        // CRITICAL: Use stable UUIDs for empty slots to prevent SwiftUI from
        // recreating views on every recomputation of sortedPhlockItems.
        // Empty slots are always at the END of the list, so we use their
        // final position (0-4) as a stable identifier.
        let currentCount = items.count
        if currentCount < 5 {
            for i in 0..<(5 - currentCount) {
                // Use a deterministic UUID based on the empty slot's position in the full 5-slot array
                // Position = currentCount + i (e.g., if 3 members, empty slots are at positions 3, 4)
                let emptySlotPosition = currentCount + i
                let stableId = PhlockItem.stableEmptySlotId(at: emptySlotPosition)
                items.append(PhlockItem(id: stableId, member: nil, song: nil, type: .empty))
            }
        }

        return items
    }

    private var shouldGatePhlock: Bool {
        guard authState.currentUser != nil else { return false }
        let hasSongToday = myDailySong != nil || (authState.currentUser?.hasSelectedToday ?? false)
        return !hasSongToday
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    FeedErrorStateView(
                        error: error,
                        onRetry: {
                            Task { await loadDailyPlaylist() }
                        }
                    )
                } else {
                    // Use immersive layout as default
                    PhlockImmersiveLayout(
                        items: sortedPhlockItems,
                        dailySongs: dailySongs,
                        myDailySong: myDailySong,
                        savedTrackIds: playbackService.savedTrackIds,
                        nudgedUserIds: nudgedUserIds,
                        currentlyPlayingId: playbackService.currentTrack?.id,
                        isPlaying: playbackService.isPlaying,
                        onPlayTapped: { song, shouldAutoPlay, savedPosition in
                            playTrack(song: song, autoPlay: shouldAutoPlay, fromPosition: savedPosition)
                        },
                        onSwapTapped: { _ in
                            showPhlockManagerSheet = true
                        },
                        onAddToLibrary: { song in
                            addToLibrary(song)
                        },
                        onRemoveFromLibrary: { song in
                            removeFromLibrary(song)
                        },
                        onProfileTapped: { user in
                            selectedProfileUser = user
                            showProfileSheet = true
                        },
                        onNudgeTapped: { member in
                            nudgeMember(member)
                        },
                        onAddMemberTapped: {
                            showAddSheet = true
                        },
                        onSelectDailySong: {
                            showDailySongSheet = true
                        },
                        onPlayMyPick: {
                            if let mySong = myDailySong {
                                if playbackService.currentTrack?.id == mySong.trackId && playbackService.isPlaying {
                                    playbackService.pause()
                                } else {
                                    playTrack(song: mySong)
                                }
                            }
                        },
                        onOpenFullPlayer: {
                            navigationState.showFullPlayer = true
                        },
                        onEditSwapTapped: { member in
                            editMemberToSwap = member
                            Task { await loadAvailableFriendsForEdit() }
                            showFriendPicker = true
                        },
                        onEditRemoveTapped: { member in
                            Task { await handleRemoveMember(user: member) }
                        },
                        onEditAddTapped: {
                            editMemberToSwap = nil
                            Task { await loadAvailableFriendsForEdit() }
                            showFriendPicker = true
                        },
                        onMenuTapped: {
                            showPhlockManagerSheet = true
                        },
                        onShareTapped: {
                            generateAndShareCard()
                        }
                    )
                    .ignoresSafeArea(edges: .top)
                }
            }
            .navigationDestination(for: PhlockDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView(scrollToTopTrigger: .constant(0))
                case .userProfile(let user):
                    UserProfileView(user: user)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                case .conversation(let user):
                    ConversationView(otherUser: user)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                }
            }
            .sheet(isPresented: $showSwapSheet) {
                if let memberToSwap = selectedMemberToSwap {
                    SwapMemberView(
                        currentMember: memberToSwap,
                        phlockMembers: phlockMembers,
                        onSwapCompleted: { newMember in
                            handleSwapCompleted(oldMember: memberToSwap, newMember: newMember)
                        },
                        onProfileTapped: { user in
                            navigationPath.append(PhlockDestination.userProfile(user))
                        }
                    )
                    .environmentObject(authState)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                UnifiedPhlockSheet(
                    currentUserId: authState.currentUser?.id ?? UUID(),
                    currentPhlockMembers: $phlockMembers,
                    onMemberAdded: { user in
                        // Find first available position
                        let usedPositions = Set(phlockMembers.map { $0.position })
                        for pos in 1...5 {
                            if !usedPositions.contains(pos) {
                                handleAddMember(user: user, position: pos)
                                break
                            }
                        }
                    },
                    onMemberRemoved: { user in
                        Task { await handleRemoveMember(user: user) }
                    },
                    onScheduleRemoval: { user in
                        Task { await handleScheduleRemoval(user: user) }
                    },
                    onCancelScheduledRemoval: { user in
                        Task { await handleCancelScheduledRemoval(user: user) }
                    },
                    title: "add to phlock"
                )
                .environmentObject(authState)
            }
            .sheet(isPresented: $showDailySongSheet) {
                DiscoverView(
                    navigationPath: $myDailySongNavPath,
                    clearSearchTrigger: $myDailySongClearTrigger,
                    refreshTrigger: $myDailySongRefreshTrigger,
                    scrollToTopTrigger: $myDailySongScrollToTopTrigger
                )
                .environmentObject(authState)
                .environmentObject(playbackService)
                .environmentObject(navigationState)
                .onDisappear {
                    Task {
                        await loadMyDailySong()
                        await loadDailyPlaylist()
                    }
                }
            }
            .sheet(isPresented: $showPhlockManagerSheet) {
                UnifiedPhlockSheet(
                    currentUserId: authState.currentUser?.id ?? UUID(),
                    currentPhlockMembers: $phlockMembers,
                    onMemberAdded: { user in
                        // Find first available position
                        let usedPositions = Set(phlockMembers.map { $0.position })
                        for pos in 1...5 {
                            if !usedPositions.contains(pos) {
                                handleAddMember(user: user, position: pos)
                                break
                            }
                        }
                    },
                    onMemberRemoved: { user in
                        Task { await handleRemoveMember(user: user) }
                    },
                    onScheduleRemoval: { user in
                        Task { await handleScheduleRemoval(user: user) }
                    },
                    onCancelScheduledRemoval: { user in
                        Task { await handleCancelScheduledRemoval(user: user) }
                    },
                    title: "edit phlock"
                )
                .environmentObject(authState)
            }
            .overlay(alignment: .bottom) {
                // Friend picker panel for edit mode
                if showFriendPicker {
                    ZStack {
                        // Dimmed background
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showFriendPicker = false
                                    editMemberToSwap = nil
                                }
                            }

                        // Panel
                        VStack {
                            Spacer()
                            FriendPickerPanel(
                                availableFriends: availableFriendsForEdit,
                                isSwapMode: editMemberToSwap != nil,
                                memberBeingReplaced: editMemberToSwap,
                                onFriendSelected: { selectedFriend in
                                    Task {
                                        if let memberToReplace = editMemberToSwap {
                                            // Swap mode
                                            await handleEditSwap(oldMember: memberToReplace, newMember: selectedFriend)
                                        } else {
                                            // Add mode
                                            let usedPositions = Set(phlockMembers.map { $0.position })
                                            for pos in 1...5 {
                                                if !usedPositions.contains(pos) {
                                                    handleAddMember(user: selectedFriend, position: pos)
                                                    break
                                                }
                                            }
                                        }
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showFriendPicker = false
                                            editMemberToSwap = nil
                                        }
                                    }
                                },
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showFriendPicker = false
                                        editMemberToSwap = nil
                                    }
                                }
                            )
                            .padding(.bottom, 100) // Above tab bar
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showFriendPicker)
        }
        .toast(isPresented: $showToast, message: toastMessage, type: toastType)
        .fullScreenCover(isPresented: $showShareSheet) {
            if let image = generatedShareCardImages[.story] {
                let message = "hey cutie, this is my phlock today - join me so i can add you too https://phlock.app"
                ActivityViewController(image: image, message: message) {
                    showShareSheet = false
                }
                .background(ClearBackgroundView())
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            if let user = selectedProfileUser {
                NavigationStack {
                    UserProfileView(user: user)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                }
            }
        }
        .task {
            // Load phlock playlist and user's daily song in parallel
            async let playlistTask: () = loadDailyPlaylist()
            async let mySongTask: () = loadMyDailySong()
            await playlistTask
            await mySongTask
        }
        .onChange(of: refreshTrigger) { newValue in
            Task {
                // Scroll to top and reload data
                withAnimation {
                    scrollToTopTrigger += 1
                }
                isRefreshing = true
                // Reload both in parallel
                async let playlistTask: () = loadDailyPlaylist()
                async let mySongTask: () = loadMyDailySong()
                await playlistTask
                await mySongTask
                await MainActor.run {
                    isRefreshing = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            if autoplayEnabled {
                playbackService.skipForward(wrap: true)
            }
        }
        .onChange(of: navigationPath) { newPath in
            // When returning to root (empty path), override non-phlock playback with phlock track
            if newPath.isEmpty {
                resumePhlockPlaybackIfNeeded()
            }
        }
    }

    // MARK: - Phlock Playback Resume

    /// Resume phlock playback when returning to root view from a pushed profile
    private func resumePhlockPlaybackIfNeeded() {
        // Only act if a track is currently playing/loaded
        guard playbackService.currentTrack != nil else { return }

        // Check if the current track is from phlock
        let phlockTrackIds = Set(dailySongs.map { $0.trackId })
        let isPlayingPhlockTrack = phlockTrackIds.contains(playbackService.currentTrack?.id ?? "")

        // If already playing a phlock track, no need to override
        if isPlayingPhlockTrack { return }

        // Find the track at the saved carousel position
        // Use the same AppStorage key as PhlockCarouselView
        let savedIndex = UserDefaults.standard.integer(forKey: "phlockCarouselIndex")
        let phlockItems = sortedPhlockItems

        // savedIndex is the position in the full carousel (songs, waiting, empty)
        // Get the item at that position
        guard savedIndex < phlockItems.count else { return }
        let item = phlockItems[savedIndex]

        // Only override if the saved position has a song
        guard item.type == .song, let song = item.song else { return }

        // Get saved position for this track (for resume capability)
        let savedPosition = playbackService.getSavedPosition(for: song.trackId)

        // Override with the phlock track, maintaining current play state
        playTrack(song: song, autoPlay: playbackService.isPlaying, fromPosition: savedPosition)
    }


    // MARK: - Daily Playlist List

    private var dailyPlaylistList: some View {
        ScrollViewReader { scrollProxy in
            List {
                // Top anchor for scroll-to-top functionality
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .id("playlistTop")

                ForEach(Array(sortedPhlockItems.enumerated()), id: \.element.id) { index, item in
                    switch item.type {
                    case .song:
                        if let song = item.song, let member = item.member {
                            DailyPlaylistRow(
                                song: song,
                                member: member,
                                isCurrentlyPlaying: playbackService.currentTrack?.id == song.trackId && playbackService.isPlaying,
                                isSaved: playbackService.savedTrackIds.contains(song.trackId),
                                hasSongToday: true,
                                onPlayTapped: {
                                    // Find index in dailySongs for playback context
                                    if let songIndex = dailySongs.firstIndex(where: { $0.id == song.id }) {
                                        playTrackAtIndex(songIndex)
                                    }
                                },
                                onSwapTapped: {
                                    showPhlockManagerSheet = true
                                },
                                onAddToLibrary: {
                                    addToLibrary(song)
                                },
                                onRemoveFromLibrary: {
                                    removeFromLibrary(song)
                                },
                                onProfileTapped: {
                                    navigationPath.append(PhlockDestination.userProfile(member))
                                },
                                onNudgeTapped: {
                                    nudgeMember(member)
                                }
                            )
                            .environmentObject(playbackService)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                        
                    case .waiting:
                        if let member = item.member {
                            WaitingForSongRow(
                                member: member,
                                isNudged: nudgedUserIds.contains(member.id),
                                onSwapTapped: {
                                    showPhlockManagerSheet = true
                                },
                                onNudgeTapped: {
                                    nudgeMember(member)
                                },
                                onProfileTapped: {
                                    navigationPath.append(PhlockDestination.userProfile(member))
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }

                    case .empty:
                        EmptySlotRow(
                            onAddMemberTapped: {
                                showAddSheet = true
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }

                // Current user's daily song section
                if let mySong = myDailySong {
                    MyDailySongRow(
                        song: mySong,
                        isPlaying: playbackService.currentTrack?.id == mySong.trackId && playbackService.isPlaying
                    ) {
                        if playbackService.currentTrack?.id == mySong.trackId && playbackService.isPlaying {
                            playbackService.pause()
                        } else {
                            playTrack(song: mySong)
                        }
                    }
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                } else {
                    Button {
                        showDailySongSheet = true
                    } label: {
                        HStack(spacing: 14) {
                            // Placeholder art block to mirror a selected song row
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                    .cornerRadius(12)
                                Image(systemName: "sparkles")
                                    .font(.lora(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("select your song of the day")
                                    .font(.lora(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("share what you're feeling with your phlock")
                                    .font(.lora(size: 13))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap")
                                        .font(.lora(size: 12))
                                        .foregroundColor(.primary)
                                    Text("tap to pick")
                                        .font(.lora(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                        .textCase(.uppercase)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.lora(size: 16))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.18),
                                    Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            .instagramRefreshable {
                await MainActor.run { isRefreshing = true }
                // Reload both in parallel
                async let playlistTask: () = loadDailyPlaylist()
                async let mySongTask: () = loadMyDailySong()
                await playlistTask
                await mySongTask
                await MainActor.run { isRefreshing = false }
            }
            .onChange(of: scrollToTopTrigger) { _ in
                withAnimation {
                    scrollProxy.scrollTo("playlistTop", anchor: .top)
                }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadDailyPlaylist() async {
        guard let userId = authState.currentUser?.id else {
            isLoading = false
            errorMessage = "No user logged in"
            return
        }

        if dailySongs.isEmpty && phlockMembers.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        let todayStart = Calendar.current.startOfDay(for: Date())
        if todayStart != nudgedResetDate {
            nudgedUserIds.removeAll()
            nudgedResetDate = todayStart
        }

        do {
            // Use retry logic for network resilience
            try await withTimeoutAndRetry(
                timeoutSeconds: 15,
                retryConfig: RetryConfiguration(
                    maxAttempts: 3,
                    baseDelay: 1.0,
                    maxDelay: 5.0,
                    shouldRetry: { error in
                        // Retry on network errors, not on auth errors
                        if let appError = error as? AppError {
                            return appError.isRetryable
                        }
                        let nsError = error as NSError
                        return nsError.domain == NSURLErrorDomain
                    }
                )
            ) {
                // Get phlock members
                let members = try await UserService.shared.getPhlockMembers(for: userId)
                await MainActor.run {
                    self.phlockMembers = members
                    self.nudgedUserIds = self.nudgedUserIds.intersection(Set(members.map { $0.user.id }))
                }

                if members.isEmpty {
                    // No phlock members - show empty state (no demo data)
                    await MainActor.run {
                        self.dailySongs = []
                        self.isLoading = false
                        self.hasLoadedPhlockOnce = true
                    }
                    return
                }

                // Get their daily songs
                let memberIds = members.map { $0.user.id }
                let songs = try await ShareService.shared.getDailySongs(from: memberIds)
                    .sorted { $0.createdAt < $1.createdAt }

                await MainActor.run {
                    self.dailySongs = songs

                    // Use database savedAt as initial state
                    // checkSpotifyLibraryStatus will override with actual Spotify state
                    self.playbackService.savedTrackIds = Set(songs.compactMap { $0.savedAt != nil ? $0.trackId : nil })

                    // If no songs today, just show waiting state (no demo data)
                    if songs.isEmpty {
                        print("ℹ️ No daily songs found for \(members.count) phlock members")
                    }

                    self.hasLoadedPhlockOnce = true

                    // Pre-warm share card image cache in background
                    var allSongs = songs
                    if let myPick = self.myDailySong {
                        allSongs.insert(myPick, at: 0)
                    }
                    ShareCardGenerator.preWarmCache(for: allSongs)
                }
                print("✅ Loaded \(songs.count) daily songs from \(members.count) phlock members")
            }

            // Check actual Spotify library status (async, doesn't block UI)
            await checkSpotifyLibraryStatus(for: dailySongs)
        } catch is CancellationError {
            print("ℹ️ Daily playlist load cancelled")
        } catch is TimeoutError {
            print("⚠️ Daily playlist load timed out")
            errorMessage = "Loading took too long. Please check your connection and try again."
            isLoading = false
            return
        } catch {
            print("❌ Error loading daily playlist: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        isLoading = false
    }

    private func loadMyDailySong() async {
        guard let userId = authState.currentUser?.id else { return }
        do {
            myDailySong = try await ShareService.shared.getTodaysDailySong(for: userId)
            if let song = myDailySong {
                print("🎵 PhlockView: Found my daily song: \(song.trackName)")
                // Pre-warm share card cache for my pick
                ShareCardGenerator.preWarmCache(for: [song])
            } else {
                print("🎵 PhlockView: No daily song found for me")
            }
        } catch {
            // Log the error but don't block the UI - user can still see their phlock
            print("⚠️ PhlockView: Error loading my daily song: \(error.localizedDescription)")
            myDailySong = nil
        }
    }

    private func addToLibrary(_ song: Share) {
        Task {
            do {
                guard let currentUser = authState.currentUser else {
                    toastMessage = "Please sign in to save"
                    toastType = .error
                    showToast = true
                    return
                }

                guard let platformType = currentUser.platformType else {
                    toastMessage = "Link a streaming account first"
                    toastType = .error
                    showToast = true
                    return
                }

                switch platformType {
                case .spotify:
                    let accessToken = try await fetchAccessToken(for: currentUser, platform: platformType)
                    let spotifyId = sanitizeSpotifyId(song.trackId)
                    try await SpotifyService.shared.saveTrackToLibrary(
                        trackId: spotifyId,
                        accessToken: accessToken
                    )
                case .appleMusic:
                    let appleMusicId = try await resolveAppleMusicTrackId(for: song)
                    try await AppleMusicService.shared.saveTrackToLibrary(trackId: appleMusicId)
                }

                // Mark the specific share as saved (not just by track ID)
                try await ShareService.shared.markAsSaved(
                    shareId: song.id,
                    userId: currentUser.id
                )

                _ = await MainActor.run {
                    playbackService.savedTrackIds.insert(song.trackId)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Failed to add to library"
                toastMessage = message
                toastType = .error
                showToast = true
                print("❌ Error adding to library: \(error)")
            }
        }
    }

    private func removeFromLibrary(_ song: Share) {
        Task {
            do {
                guard let currentUser = authState.currentUser else {
                    toastMessage = "Please sign in"
                    toastType = .error
                    showToast = true
                    return
                }

                guard let platformType = currentUser.platformType else {
                    toastMessage = "Link a streaming account first"
                    toastType = .error
                    showToast = true
                    return
                }

                switch platformType {
                case .spotify:
                    let accessToken = try await fetchAccessToken(for: currentUser, platform: platformType)
                    let spotifyId = sanitizeSpotifyId(song.trackId)
                    try await SpotifyService.shared.removeTrackFromLibrary(
                        trackId: spotifyId,
                        accessToken: accessToken
                    )
                case .appleMusic:
                    toastMessage = "Open Apple Music to remove track"
                    toastType = .info
                    showToast = true
                }

                // Mark the share as unsaved (clear saved_at timestamp)
                try await ShareService.shared.markAsUnsaved(
                    shareId: song.id,
                    userId: currentUser.id
                )

                _ = await MainActor.run {
                    playbackService.savedTrackIds.remove(song.trackId)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Failed to remove from library"
                toastMessage = message
                toastType = .error
                showToast = true
                print("❌ Error removing from library: \(error)")
            }
        }
    }

    private func fetchAccessToken(for user: User, platform: PlatformType) async throws -> String {
        let supabase = PhlockSupabaseClient.shared.client

        let tokens: [PlatformToken] = try await supabase
            .from("platform_tokens")
            .select("*")
            .eq("user_id", value: user.id.uuidString)
            .eq("platform_type", value: platform.rawValue)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if var token = tokens.first {
            if platform == .spotify {
                // Refresh slightly early to avoid race on expiry
                let refreshThreshold = token.tokenExpiresAt.addingTimeInterval(-120)
                if Date() >= refreshThreshold {
                    guard let refreshToken = token.refreshToken else {
                        throw NSError(
                            domain: "PhlockView",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No Spotify refresh token; please relink."]
                        )
                    }

                    let refreshed = try await SpotifyService.shared.refreshAccessToken(refreshToken: refreshToken)
                    let now = Date()
                    let newExpiresAt = now.addingTimeInterval(TimeInterval(refreshed.expiresIn))

                    struct TokenUpdate: Encodable {
                        let access_token: String
                        let refresh_token: String
                        let token_expires_at: String
                        let updated_at: String
                    }

                    let updatePayload = TokenUpdate(
                        access_token: refreshed.accessToken,
                        refresh_token: refreshed.refreshToken ?? refreshToken,
                        token_expires_at: ISO8601DateFormatter().string(from: newExpiresAt),
                        updated_at: ISO8601DateFormatter().string(from: now)
                    )

                    try await supabase
                        .from("platform_tokens")
                        .update(updatePayload)
                        .eq("id", value: token.id.uuidString)
                        .execute()

                    token = PlatformToken(
                        id: token.id,
                        userId: token.userId,
                        platformType: token.platformType,
                        accessToken: refreshed.accessToken,
                        refreshToken: refreshed.refreshToken ?? refreshToken,
                        tokenExpiresAt: newExpiresAt,
                        scope: token.scope,
                        createdAt: token.createdAt,
                        updatedAt: now
                    )
                }
            }

            return token.accessToken
        }

        throw NSError(
            domain: "PhlockView",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No \(platform.rawValue) token found"]
        )
    }

    private func sanitizeSpotifyId(_ rawId: String) -> String {
        if rawId.contains("/") || rawId.contains(":") {
            if let last = rawId.split(whereSeparator: { $0 == "/" || $0 == ":" }).last {
                return String(last)
            }
        }
        return rawId
    }

    /// Check actual Spotify library status for tracks and update savedTrackIds
    private func checkSpotifyLibraryStatus(for songs: [Share]) async {
        guard let currentUser = authState.currentUser,
              currentUser.resolvedPlatformType == .spotify else {
            // For non-Spotify users or no user, use savedAt from database
            playbackService.savedTrackIds = Set(songs.compactMap { $0.savedAt != nil ? $0.trackId : nil })
            return
        }

        do {
            let accessToken = try await fetchAccessToken(for: currentUser, platform: .spotify)
            let trackIds = songs.map { sanitizeSpotifyId($0.trackId) }
            let savedStatus = try await SpotifyService.shared.areTracksSaved(trackIds: trackIds, accessToken: accessToken)

            // Build the set of saved track IDs
            var newSavedIds: Set<String> = []
            for song in songs {
                let sanitizedId = sanitizeSpotifyId(song.trackId)
                if savedStatus[sanitizedId] == true {
                    newSavedIds.insert(song.trackId)
                }
            }
            playbackService.savedTrackIds = newSavedIds
        } catch {
            print("⚠️ Failed to check Spotify library status: \(error)")
            // Fall back to savedAt from database
            playbackService.savedTrackIds = Set(songs.compactMap { $0.savedAt != nil ? $0.trackId : nil })
        }
    }

    private func resolveAppleMusicTrackId(for song: Share) async throws -> String {
        // If the trackId already looks like an Apple Music catalog ID, use it directly
        if !song.trackId.isEmpty,
           CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: song.trackId)) {
            return song.trackId
        }

        // Try parsing from a URL if one was stored
        if let url = URL(string: song.trackId),
           let lastComponent = url.pathComponents.last,
           CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: lastComponent)) {
            return lastComponent
        }

        // Fallback: search Apple Music by name/artist
        if let track = try? await AppleMusicService.shared.searchTrack(
            name: song.trackName,
            artist: song.artistName,
            isrc: nil
        ) {
            return track.id
        }

        throw AppleMusicError.apiError("Could not locate Apple Music track for \(song.trackName)")
    }

    private func handleSwapCompleted(oldMember: User, newMember: User) {
        showSwapSheet = false
        selectedMemberToSwap = nil

        Task {
            do {
                guard let userId = authState.currentUser?.id else { return }
                let swappedImmediately = try await UserService.shared.scheduleSwap(
                    oldMemberId: oldMember.id,
                    newMemberId: newMember.id,
                    for: userId
                )

                if swappedImmediately {
                    toastMessage = "Swapped \(oldMember.displayName) for \(newMember.displayName)"
                    toastType = .success
                } else {
                    toastMessage = "Swapping \(oldMember.displayName) for \(newMember.displayName) at midnight"
                    toastType = .info
                }
                showToast = true

                // Refresh to show immediate change or pending state
                await loadDailyPlaylist()
            } catch {
                toastMessage = "Failed to schedule swap"
                toastType = .error
                showToast = true
                print("❌ Error scheduling swap: \(error)")
            }
        }
    }

    // MARK: - Edit Mode Functions

    private func loadAvailableFriendsForEdit() async {
        guard let userId = authState.currentUser?.id else { return }

        isLoadingFriends = true
        do {
            let following = try await FollowService.shared.getFollowing(for: userId)
            let phlockMemberIds = Set(phlockMembers.map { $0.user.id })
            // Filter out users already in phlock
            await MainActor.run {
                availableFriendsForEdit = following.filter { !phlockMemberIds.contains($0.id) }
                isLoadingFriends = false
            }
        } catch {
            print("❌ Failed to load friends for edit: \(error)")
            await MainActor.run {
                availableFriendsForEdit = []
                isLoadingFriends = false
            }
        }
    }

    private func handleEditSwap(oldMember: User, newMember: User) async {
        // Store for potential rollback
        let oldMemberData = phlockMembers.first { $0.user.id == oldMember.id }

        do {
            guard let userId = authState.currentUser?.id else { return }
            let swappedImmediately = try await UserService.shared.scheduleSwap(
                oldMemberId: oldMember.id,
                newMemberId: newMember.id,
                for: userId
            )

            // Optimistic UI update only if swapped immediately
            if swappedImmediately, let oldPosition = oldMemberData?.position {
                await MainActor.run {
                    phlockMembers.removeAll { $0.user.id == oldMember.id }
                    phlockMembers.append(FriendWithPosition(user: newMember, position: oldPosition))
                }
            }

            await MainActor.run {
                if swappedImmediately {
                    toastMessage = "Swapped \(oldMember.displayName) for \(newMember.displayName)"
                    toastType = .success
                } else {
                    toastMessage = "Swap scheduled for midnight"
                    toastType = .info
                }
                showToast = true
            }

            // Refresh to get accurate data from server
            await loadDailyPlaylist()
        } catch {
            await MainActor.run {
                toastMessage = "Failed to swap"
                toastType = .error
                showToast = true
            }
            print("❌ Error in edit swap: \(error)")
        }
    }

    private func handleRemoveMember(user: User) async {
        // Store for potential rollback
        let removedMember = phlockMembers.first { $0.user.id == user.id }

        // Optimistic UI update - remove immediately
        await MainActor.run {
            phlockMembers.removeAll { $0.user.id == user.id }
        }

        do {
            guard let userId = authState.currentUser?.id else { return }
            try await UserService.shared.removeFromPhlock(friendId: user.id, for: userId)

            await MainActor.run {
                toastMessage = "Removed \(user.displayName) from phlock"
                toastType = .success
                showToast = true
            }

            // Refresh to get accurate data from server
            await loadDailyPlaylist()
        } catch {
            // Rollback optimistic update on failure
            if let removedMember = removedMember {
                await MainActor.run {
                    phlockMembers.append(removedMember)
                }
            }

            await MainActor.run {
                toastMessage = "Failed to remove"
                toastType = .error
                showToast = true
            }
            print("❌ Error removing member: \(error)")
        }
    }

    private func handleScheduleRemoval(user: User) async {
        do {
            guard let userId = authState.currentUser?.id else { return }
            try await UserService.shared.scheduleRemoval(memberId: user.id, for: userId)
            // No toast - button state change is the feedback
        } catch {
            print("❌ Error scheduling removal: \(error)")
        }
    }

    private func handleCancelScheduledRemoval(user: User) async {
        do {
            guard let userId = authState.currentUser?.id else { return }
            try await UserService.shared.cancelScheduledRemoval(memberId: user.id, for: userId)
            // No toast - button state change is the feedback
        } catch {
            print("❌ Error cancelling scheduled removal: \(error)")
        }
    }

    private func nudgeMember(_ member: User?) {
        guard let member = member else { return }
        guard let currentUser = authState.currentUser else {
            toastMessage = "Please sign in"
            toastType = .error
            showToast = true
            return
        }

        Task {
            print("👋 Nudging member: \(member.displayName) (ID: \(member.id))")
            do {
                try await NotificationService.shared.createNotification(
                    userId: member.id,
                    actorId: currentUser.id,
                    type: .dailyNudge,
                    message: "\(currentUser.displayName) nudged you to pick today's song"
                )
                _ = await MainActor.run {
                    nudgedUserIds.insert(member.id)
                }
                print("📣 Nudged \(member.id) to select daily song")
            } catch {
                await MainActor.run {
                    toastMessage = "Failed to send nudge"
                    toastType = .error
                    showToast = true
                }
                print("❌ Failed to send nudge notification: \(error)")
            }
        }
    }

    private func handleAddMember(user: User, position: Int) {
        // Optimistic UI update - add member immediately before closing sheet
        let newMember = FriendWithPosition(user: user, position: position)
        phlockMembers.append(newMember)

        showAddSheet = false
        showPhlockManagerSheet = false
        selectedPositionToAdd = nil

        Task {
            do {
                guard let userId = authState.currentUser?.id else { return }
                try await UserService.shared.addToPhlockAtPosition(
                    friendId: user.id,
                    position: position,
                    for: userId
                )

                toastMessage = "Added \(user.displayName) to phlock"
                toastType = .success
                showToast = true

                // Refresh playlist to get accurate data from server
                await loadDailyPlaylist()
            } catch {
                // Rollback optimistic update on failure
                phlockMembers.removeAll { $0.user.id == user.id }

                toastMessage = "Failed to add member"
                toastType = .error
                showToast = true
                print("❌ Error adding member: \(error)")
            }
        }
    }

    // MARK: - Share Card Generation

    private func generateAndShareCard() {
        // Need at least one song to share
        let hasContent = myDailySong != nil || !dailySongs.isEmpty
        guard hasContent else {
            toastMessage = "No songs to share yet"
            toastType = .info
            showToast = true
            return
        }

        isGeneratingShareCard = true

        Task {
            // Generate all formats at once (more efficient - loads images once)
            let images = await ShareCardGenerator.generateAllFormats(
                myPick: myDailySong,
                phlockSongs: dailySongs,
                members: phlockMembers
            )

            await MainActor.run {
                isGeneratingShareCard = false

                if !images.isEmpty {
                    generatedShareCardImages = images
                    showShareSheet = true
                } else {
                    toastMessage = "Failed to create share card"
                    toastType = .error
                    showToast = true
                }
            }
        }
    }

    // MARK: - Playback Methods

    private func playTrackAtIndex(_ index: Int) {
        guard index >= 0 && index < dailySongs.count else { return }

        let song = dailySongs[index]

        // Check if this track is already playing
        if playbackService.currentTrack?.id == song.trackId {
            if playbackService.isPlaying {
                playbackService.pause()
            } else {
                playbackService.resume()
            }
            return
        }

        let queueTracks = dailySongs.map { musicItem(from: $0) }
        let sourceIds = dailySongs.map { Optional($0.id.uuidString) }

        playbackService.startQueue(
            tracks: queueTracks,
            startAt: index,
            sourceIds: sourceIds,
            showMiniPlayer: true
        )
    }

    private func playTrack(song: Share, autoPlay: Bool = true, fromPosition: Double? = nil) {
        let track = musicItem(from: song)

        // Pass autoPlay and seekToPosition directly to startQueue
        // This ensures the track starts in the correct state without play-then-pause jitter
        playbackService.startQueue(
            tracks: [track],
            startAt: 0,
            sourceIds: [Optional(song.id.uuidString)],
            showMiniPlayer: false,  // Immersive layout has its own controls
            autoPlay: autoPlay,
            seekToPosition: fromPosition
        )
    }

    private func musicItem(from share: Share) -> MusicItem {
        MusicItem(
            id: share.trackId,
            name: share.trackName,
            artistName: share.artistName,
            previewUrl: share.previewUrl,
            albumArtUrl: share.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: share.trackId,  // track_id is the Spotify ID
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )
    }
}

// MARK: - Daily Song Gate

struct DailySongGateView: View {
    let onPickSong: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.black
                .opacity(colorScheme == .dark ? 0.45 : 0.25)

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.lora(size: 32, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.28),
                                Color.accentColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())

                VStack(spacing: 6) {
                    Text("unlock today's playlist")
                        .font(.lora(size: 20, weight: .semiBold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 6)

                PhlockButton(
                    title: "choose today's song",
                    action: onPickSong,
                    variant: .primary,
                    fullWidth: true,
                    fontSize: 17
                )

                Text("share your pick to unlock the feed.")
                    .font(.lora(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 16, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Daily Playlist Row

struct DailyPlaylistRow: View {
    let song: Share
    let member: User
    let isCurrentlyPlaying: Bool
    let isSaved: Bool
    let hasSongToday: Bool
    let onPlayTapped: () -> Void
    let onSwapTapped: () -> Void
    let onAddToLibrary: () -> Void
    let onRemoveFromLibrary: () -> Void
    let onProfileTapped: () -> Void
    let onNudgeTapped: () -> Void

    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onPlayTapped()
            } label: {
                HStack(spacing: 16) {
                    // Album artwork with play indicator
                    ZStack {
                        if let albumArtUrl = song.albumArtUrl,
                           let url = URL(string: albumArtUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 56, height: 56)
                            .cornerRadius(6)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.gray)
                                )
                                .frame(width: 56, height: 56)
                                .cornerRadius(6)
                        }

                        // Play/pause indicator (non-interactive; tap handled by parent button)
                        Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                            .font(.lora(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                            .opacity(song.previewUrl != nil ? 1.0 : 0.4)
                            .allowsHitTesting(false)
                    }

                    // Song info (Middle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.trackName)
                            .font(.lora(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(song.artistName)
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if let message = song.message, !message.isEmpty {
                            ScrollableMessageText(message: message)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(song.previewUrl == nil)
            .opacity(song.previewUrl != nil ? 1.0 : 0.5)

            // Actions (Right)
            HStack(spacing: 8) {
                Button {
                    onSwapTapped()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.lora(size: 20))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Button {
                    if isSaved {
                        onRemoveFromLibrary()
                    } else {
                        onAddToLibrary()
                    }
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .font(.lora(size: 22))
                        .foregroundColor(isSaved ? .green : .primary)
                }
                .buttonStyle(.plain)
                
                if hasSongToday {
                    Button {
                        onProfileTapped()
                    } label: {
                        avatarView(overlaySystemName: nil)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onNudgeTapped()
                    } label: {
                        Image(systemName: "hand.wave")
                            .font(.lora(size: 20))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }

    @ViewBuilder
    private func avatarView(overlaySystemName: String?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoUrl = member.profilePhotoUrl,
               let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(String(member.displayName.prefix(1)))
                                .font(.lora(size: 12, weight: .medium))
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.lora(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    )
                    .frame(width: 32, height: 32)
            }

            if let overlay = overlaySystemName {
                Image(systemName: overlay)
                    .font(.lora(size: 11))
                    .foregroundColor(.primary)
                    .padding(4)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(Circle())
                    .offset(x: 6, y: 6)
            }
        }
    }
}

struct WaitingForSongRow: View {
    let member: User
    let isNudged: Bool
    let onSwapTapped: () -> Void
    let onNudgeTapped: () -> Void
    let onProfileTapped: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onProfileTapped()
            } label: {
                if let photoUrl = member.profilePhotoUrl,
                   let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(String(member.displayName.prefix(1)))
                                    .font(.lora(size: 12, weight: .medium))
                            )
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                        .frame(width: 56, height: 56)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.lora(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text("Waiting for today's song...")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    onSwapTapped()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.lora(size: 20))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    onNudgeTapped()
                } label: {
                    Image(systemName: isNudged ? "hand.wave.fill" : "hand.wave")
                        .font(.lora(size: 22))
                        .foregroundColor(isNudged ? .green : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isNudged)
                .opacity(isNudged ? 0.7 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
}

struct MyDailySongRow: View {
    let song: Share
    let isPlaying: Bool
    let onPlayTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            // Playing indicator bar
            if isPlaying {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: 4, height: 64)
            }

            ZStack {
                if let albumArtUrl = song.albumArtUrl,
                   let url = URL(string: albumArtUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                }

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.lora(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .opacity(0.95)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(song.trackName)
                    .font(.lora(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.lora(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text("your daily pick")
                        .font(.lora(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .textCase(.uppercase)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color.gray.opacity(colorScheme == .dark ? 0.28 : 0.14),
                    Color.gray.opacity(colorScheme == .dark ? 0.18 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlayTapped()
        }
    }
}

// MARK: - Empty Slot Row

struct EmptySlotRow: View {
    let onAddMemberTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Empty slot indicator
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 56, height: 56)
                .cornerRadius(6)
                .overlay(
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                        .font(.lora(size: 20, weight: .semiBold))
                )

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Add a friend")
                    .font(.lora(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Add button
            Button {
                onAddMemberTapped()
            } label: {
                Text("Add")
                    .font(.lora(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Empty State

struct EmptyDailyPlaylistView: View {
    let phlockMembers: [FriendWithPosition]
    let myDailySong: Share?
    let isPlaying: Bool
    let onAddMemberTapped: (Int) -> Void
    let onSelectDailySong: () -> Void
    let onPlayMyPick: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Position 1
                emptySlotRow(for: 1)

                // Position 2
                emptySlotRow(for: 2)

                // Position 3
                emptySlotRow(for: 3)

                // Position 4
                emptySlotRow(for: 4)

                // Position 5
                emptySlotRow(for: 5)

                // Your pick section
                yourPickSection
                    .padding(.top, 16)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    @ViewBuilder
    private var yourPickSection: some View {
        if let mySong = myDailySong {
            MyDailySongRow(
                song: mySong,
                isPlaying: isPlaying
            ) {
                onPlayMyPick()
            }
            .padding(.horizontal, 16)
        } else {
            Button {
                onSelectDailySong()
            } label: {
                HStack(spacing: 14) {
                    // Placeholder art block to mirror a selected song row
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                        Image(systemName: "sparkles")
                            .font(.lora(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("select your song of the day")
                            .font(.lora(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                        Text("share what you're feeling with your phlock")
                            .font(.lora(size: 13))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap")
                                .font(.lora(size: 12))
                                .foregroundColor(.primary)
                            Text("tap to pick")
                                .font(.lora(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .textCase(.uppercase)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.lora(size: 16))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.18),
                            Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func emptySlotRow(for position: Int) -> some View {
        VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        if let member = phlockMembers.first(where: { $0.position == position })?.user {
                            // Existing Member (Waiting for song)
                            if let photoUrl = member.profilePhotoUrl,
                               let url = URL(string: photoUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                                    .frame(width: 56, height: 56)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.displayName)
                                    .font(.lora(size: 16, weight: .medium))
                                    .foregroundColor(.primary)

                                Text("Waiting for daily song...")
                                    .font(.lora(size: 14))
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                        } else {
                            // Empty Slot (Add Member)
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 56, height: 56)
                                .cornerRadius(6)
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(.gray)
                                        .font(.lora(size: 20, weight: .semiBold))
                                )

                            Text("Add a friend")
                                .font(.lora(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.lora(size: 24, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only allow adding if slot is empty
                        if !phlockMembers.contains(where: { $0.position == position }) {
                            onAddMemberTapped(position)
                        }
                    }
                    
                    if position < 5 {
                        Divider()
                            .padding(.leading, 88) // Align with text start
                    }
        }
    }
}

// MARK: - Error State

struct FeedErrorStateView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.lora(size: 50, weight: .bold))
                .foregroundColor(.orange)

            Text("Unable to load playlist")
                .font(.lora(size: 20, weight: .semiBold))

            Text(error)
                .font(.lora(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                onRetry()
            } label: {
                Text("Try Again")
                    .font(.lora(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Swap Member View

struct SwapMemberView: View {
    let currentMember: User
    let phlockMembers: [FriendWithPosition]
    let onSwapCompleted: (User) -> Void
    let onProfileTapped: (User) -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authState: AuthenticationState
    @State private var friends: [User] = []
    @State private var selectedFriend: User?
    @State private var isLoading = true
    @State private var dailySongStatus: [UUID: Bool] = [:] // friendId -> has song today

    var body: some View {
        NavigationStack {
            VStack {
                // Current member info
                HStack(spacing: 12) {
                    if let photoUrl = currentMember.profilePhotoUrl,
                       let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swap \(currentMember.displayName) with…")
                            .font(.lora(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))

                Divider()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 12) {
                        Text("no available friends")
                            .font(.lora(size: 16, weight: .medium))
                        Text("all your friends are already in your phlock")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        HStack {
                            // Profile photo - separate button for profile navigation
                            Button {
                                onProfileTapped(friend)
                            } label: {
                                if let photoUrl = friend.profilePhotoUrl,
                                   let url = URL(string: photoUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                }
                            }
                            .buttonStyle(.plain)

                            // Main selection area - covers name and status
                            Button {
                                selectedFriend = friend
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName)
                                            .font(.lora(size: 16, weight: .medium))
                                            .foregroundColor(.primary)

                                        if friend.username != nil {
                                            Text("@\(friend.username ?? "")")
                                                .font(.lora(size: 12, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if let hasSong = dailySongStatus[friend.id] {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(hasSong ? Color.green : Color.gray.opacity(0.4))
                                                .frame(width: 8, height: 8)

                                            Text(hasSong ? "has today's song" : "no song yet")
                                                .font(.lora(size: 11))
                                                .foregroundColor(hasSong ? .green : .secondary)
                                        }
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }

                                    if selectedFriend?.id == friend.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .padding(.leading, 8)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Swap Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm Swap") {
                        if let friend = selectedFriend {
                            onSwapCompleted(friend)
                            dismiss()
                        }
                    }
                    .disabled(selectedFriend == nil)
                    .font(.lora(size: 16, weight: .medium))
                }
            }
            .task {
                await loadAvailableFriends()
            }
        }
    }

    private func loadAvailableFriends() async {
        guard let userId = authState.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            // Get all friends
            let allFriends = try await UserService.shared.getFriends(for: userId)

            // Filter out current phlock members
            let phlockMemberIds = phlockMembers.map { $0.user.id }
            friends = allFriends.filter { friend in
                !phlockMemberIds.contains(friend.id)
            }

            // Fetch today's song status in parallel using RPC function (bypasses RLS)
            var statusUpdates: [(UUID, Bool)] = []
            await withTaskGroup(of: (UUID, Bool).self) { group in
                for friend in friends {
                    group.addTask {
                        do {
                            let hasSong = try await ShareService.shared.hasDailySongToday(for: friend.id)
                            return (friend.id, hasSong)
                        } catch {
                            print("⚠️ Failed to check daily song status for \(friend.id): \(error.localizedDescription)")
                            return (friend.id, false) // Default to false on error
                        }
                    }
                }

                for await (id, hasSong) in group {
                    statusUpdates.append((id, hasSong))
                }
            }

            await MainActor.run {
                for (id, hasSong) in statusUpdates {
                    dailySongStatus[id] = hasSong
                }
            }

            print("✅ Found \(friends.count) available friends for swapping")
        } catch {
            print("❌ Error loading friends: \(error)")
            friends = []
        }

        isLoading = false
    }
}

// MARK: - Unified Phlock Sheet

import MessageUI

/// Helper struct for invite target
struct PhlockInviteContactTarget: Identifiable {
    let id = UUID()
    let phone: String
}

/// Unified sheet for both "add to phlock" and "edit phlock"
struct UnifiedPhlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authState: AuthenticationState

    let currentUserId: UUID
    @Binding var currentPhlockMembers: [FriendWithPosition]
    let onMemberAdded: (User) -> Void
    let onMemberRemoved: (User) -> Void
    let onScheduleRemoval: (User) -> Void
    let onCancelScheduledRemoval: (User) -> Void
    let title: String  // "add to phlock" or "edit phlock"

    // Navigation
    @State private var navigationPath = NavigationPath()

    // Following state
    @State private var followingList: [User] = []
    @State private var isLoading = true
    @State private var searchText = ""

    // Discovery state
    @State private var suggestedUsers: [RecommendedFriend] = []
    @State private var isLoadingSuggestions = true
    @State private var invitableContacts: [InvitableContact] = []
    @State private var contactMatches: [ContactMatch] = []
    @State private var isLoadingContacts = false

    // Invite state
    @State private var inviteTarget: PhlockInviteContactTarget?
    @State private var invitedContacts: Set<String> = []

    // Daily song status tracking (userId -> hasSongToday)
    @State private var dailySongStatus: [UUID: Bool] = [:]
    @State private var isLoadingDailySongStatus = true

    // Scheduled removals tracking (member IDs scheduled to be removed at midnight)
    @State private var scheduledRemovals: Set<UUID> = []

    // Computed: users not in phlock
    private var availableUsers: [User] {
        let phlockMemberIds = Set(currentPhlockMembers.map { $0.user.id })
        return followingList.filter { !phlockMemberIds.contains($0.id) }
    }

    // Filter by search text and sort by: picked today first, then by streak count
    private var filteredUsers: [User] {
        let filtered: [User]
        if searchText.isEmpty {
            filtered = availableUsers
        } else {
            filtered = availableUsers.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort: picked today first (by streak), then not picked (by streak)
        return filtered.sorted { user1, user2 in
            let hasPicked1 = dailySongStatus[user1.id] ?? false
            let hasPicked2 = dailySongStatus[user2.id] ?? false

            if hasPicked1 != hasPicked2 {
                // Users who picked today come first
                return hasPicked1
            }
            // Within each group, sort by streak (highest first)
            return user1.dailySongStreak > user2.dailySongStreak
        }
    }

    private var hasAvailableFriends: Bool {
        !availableUsers.isEmpty
    }

    // Get sorted slots (members first sorted by streak, then empty slots)
    private var sortedSlots: [(position: Int, member: FriendWithPosition?)] {
        let filledSlots = currentPhlockMembers
            .sorted { $0.user.dailySongStreak > $1.user.dailySongStreak }
            .map { (position: $0.position, member: Optional($0)) }

        let filledPositions = Set(currentPhlockMembers.map { $0.position })
        let emptySlots = (1...5)
            .filter { !filledPositions.contains($0) }
            .map { (position: $0, member: nil as FriendWithPosition?) }

        return filledSlots + emptySlots
    }

    // Check if phlock is full
    private var isPhlockFull: Bool {
        currentPhlockMembers.count >= 5
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - My Phlock Section (5 slots)
                    myPhlockSection

                    // MARK: - Conditional Content
                    if isLoading {
                        loadingSection
                    } else if hasAvailableFriends {
                        addFromFollowingSection
                    } else {
                        suggestedForYouSection
                        inviteContactsSection
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                    .font(.lora(size: 16, weight: .medium))
                }
            }
            .navigationDestination(for: User.self) { user in
                UserProfileView(user: user)
            }
        }
        .sheet(item: $inviteTarget) { target in
            PhlockMessageComposeView(
                recipients: [target.phone],
                body: "hey cutie - I have a song for you https://phlock.app",
                onFinished: { result in
                    if result == .sent {
                        invitedContacts.insert(target.phone)
                    }
                    inviteTarget = nil
                }
            )
        }
        .task {
            await loadAllData()
        }
    }

    // MARK: - My Phlock Section

    @ViewBuilder
    private var myPhlockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("my phlock")
                .font(.lora(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            VStack(spacing: 0) {
                ForEach(sortedSlots, id: \.position) { slot in
                    if let member = slot.member {
                        filledSlotRow(member: member, position: slot.position)
                    } else {
                        emptySlotRow(position: slot.position)
                    }

                    if slot.position < 5 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.06))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func filledSlotRow(member: FriendWithPosition, position: Int) -> some View {
        HStack(spacing: 12) {
            // Tappable profile section
            Button {
                navigationPath.append(member.user)
            } label: {
                HStack(spacing: 12) {
                    ProfilePhotoWithStreak(
                        photoUrl: member.user.profilePhotoUrl,
                        displayName: member.user.displayName,
                        streak: member.user.dailySongStreak,
                        size: 44,
                        badgeSize: .small
                    )
                    .frame(width: 44, height: 54)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.user.displayName)
                            .font(.lora(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        if let username = member.user.username {
                            Text("@\(username)")
                                .font(.lora(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Show status/action based on member state (only after status is loaded)
            if !isLoadingDailySongStatus {
                let hasPicked = dailySongStatus[member.user.id] == true
                let isScheduledForRemoval = scheduledRemovals.contains(member.user.id)

                if isScheduledForRemoval {
                    // Member is scheduled for removal at midnight - show undo button
                    Button {
                        onCancelScheduledRemoval(member.user)
                        scheduledRemovals.remove(member.user.id)
                    } label: {
                        HStack(spacing: 6) {
                            Text("undo")
                                .font(.lora(size: 12, weight: .medium))
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 22))
                        }
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                } else if hasPicked {
                    // Member has picked today - show schedule removal button (grey)
                    Button {
                        onScheduleRemoval(member.user)
                        scheduledRemovals.insert(member.user.id)
                    } label: {
                        HStack(spacing: 6) {
                            Text("remove for tomorrow")
                                .font(.lora(size: 12, weight: .medium))
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                        }
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Member hasn't picked yet - show status indicator and immediate remove button
                    HStack(spacing: 4) {
                        Text("no pick yet today")
                            .font(.lora(size: 11))
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.orange)

                    Button {
                        onMemberRemoved(member.user)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func emptySlotRow(position: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .foregroundColor(.secondary.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.4))
            }

            Text("add member to phlock")
                .font(.lora(size: 15))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading Section

    @ViewBuilder
    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 40)
    }

    // MARK: - Add From Following Section

    @ViewBuilder
    private var addFromFollowingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("add from following")
                .font(.lora(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("search", text: $searchText)
                    .font(.lora(size: 16))
            }
            .padding(12)
            .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
            .cornerRadius(12)
            .padding(.horizontal, 16)

            if filteredUsers.isEmpty {
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "no friends available" : "no matches found")
                        .font(.lora(size: 14, weight: .medium))
                    if searchText.isEmpty {
                        Text("follow more people to add them")
                            .font(.lora(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredUsers, id: \.id) { user in
                        availableFriendRow(user: user)

                        if user.id != filteredUsers.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.06))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func availableFriendRow(user: User) -> some View {
        HStack(spacing: 12) {
            // Tappable profile section
            Button {
                navigationPath.append(user)
            } label: {
                HStack(spacing: 12) {
                    ProfilePhotoWithStreak(
                        photoUrl: user.profilePhotoUrl,
                        displayName: user.displayName,
                        streak: user.dailySongStreak,
                        size: 44,
                        badgeSize: .small
                    )
                    .frame(width: 44, height: 54)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.lora(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        if let username = user.username {
                            Text("@\(username)")
                                .font(.lora(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Daily pick status indicator (only show after status is loaded)
            if !isLoadingDailySongStatus {
                if dailySongStatus[user.id] == true {
                    HStack(spacing: 4) {
                        Text("picked today")
                            .font(.lora(size: 11))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.green)
                } else {
                    HStack(spacing: 4) {
                        Text("no pick yet today")
                            .font(.lora(size: 11))
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.orange)
                }
            }

            // Add button
            if !isPhlockFull {
                Button {
                    onMemberAdded(user)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            } else {
                Text("full")
                    .font(.lora(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(isPhlockFull ? 0.5 : 1.0)
    }

    // MARK: - Suggested For You Section

    @ViewBuilder
    private var suggestedForYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("suggested for you")
                .font(.lora(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            if isLoadingSuggestions {
                HStack {
                    ProgressView()
                    Text("finding people you may know...")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if suggestedUsers.isEmpty {
                Text("no suggestions yet")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(suggestedUsers) { suggestion in
                        PhlockSuggestionRow(
                            suggestion: suggestion,
                            onFollow: { await followUser(suggestion.user) },
                            onAddToPhlock: { user in onMemberAdded(user) },
                            onTap: { navigationPath.append(suggestion.user) },
                            isPhlockFull: isPhlockFull
                        )

                        if suggestion.id != suggestedUsers.last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.06))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Invite Contacts Section

    @ViewBuilder
    private var inviteContactsSection: some View {
        let status = ContactsService.shared.authorizationStatus()
        let hasAccess: Bool = {
            if status == .authorized { return true }
            if #available(iOS 18.0, *), status == .limited { return true }
            return false
        }()

        if hasAccess && (isLoadingContacts || !invitableContacts.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                Text("invite your contacts")
                    .font(.lora(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                if isLoadingContacts && invitableContacts.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("loading your contacts...")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(invitableContacts.prefix(10).enumerated()), id: \.element.id) { index, contact in
                            PhlockInviteRow(
                                contact: contact,
                                isInvited: invitedContacts.contains(contact.phone),
                                onInvite: { inviteTarget = PhlockInviteContactTarget(phone: contact.phone) }
                            )

                            if index < min(invitableContacts.count, 10) - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.06))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        // Load following first (needed for daily song status)
        await loadFollowing()

        // Then load everything else in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSuggestions() }
            group.addTask { await self.loadContacts() }
            group.addTask { await self.loadDailySongStatus() }
            group.addTask { await self.loadScheduledRemovals() }
        }
    }

    private func loadScheduledRemovals() async {
        do {
            let removals = try await UserService.shared.getScheduledRemovals(for: currentUserId)
            await MainActor.run {
                scheduledRemovals = removals
            }
        } catch {
            print("⚠️ Failed to load scheduled removals: \(error)")
        }
    }

    private func loadDailySongStatus() async {
        // Gather all user IDs we need to check (phlock members + following)
        var userIds = Set(currentPhlockMembers.map { $0.user.id })
        userIds.formUnion(followingList.map { $0.id })

        guard !userIds.isEmpty else { return }

        // Fetch status in parallel using RPC function (bypasses RLS)
        var statusUpdates: [(UUID, Bool)] = []
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for userId in userIds {
                group.addTask {
                    do {
                        let hasSong = try await ShareService.shared.hasDailySongToday(for: userId)
                        return (userId, hasSong)
                    } catch {
                        print("⚠️ Failed to check daily song status for \(userId): \(error.localizedDescription)")
                        return (userId, false) // Default to false on error
                    }
                }
            }

            for await result in group {
                statusUpdates.append(result)
            }
        }

        // Update state on main thread
        await MainActor.run {
            for (userId, hasSong) in statusUpdates {
                dailySongStatus[userId] = hasSong
            }
            isLoadingDailySongStatus = false
            print("🔍 UnifiedPhlockSheet loadDailySongStatus: updated \(statusUpdates.count) statuses")
        }
    }

    private func loadFollowing() async {
        do {
            followingList = try await FollowService.shared.getFollowing(for: currentUserId)
        } catch {
            print("❌ Failed to load following list: \(error)")
        }
        isLoading = false
    }

    private func loadSuggestions() async {
        guard let currentUser = authState.currentUser else {
            isLoadingSuggestions = false
            return
        }

        do {
            suggestedUsers = try await FollowService.shared.getRecommendedFriends(
                for: currentUser.id,
                contactMatches: contactMatches
            )
        } catch {
            print("Failed to load suggestions: \(error)")
        }
        isLoadingSuggestions = false
    }

    private func loadContacts() async {
        let status = ContactsService.shared.authorizationStatus()
        guard status == .authorized else {
            isLoadingContacts = false
            return
        }

        isLoadingContacts = true
        do {
            contactMatches = try await ContactsService.shared.findPhlockUsersInContacts()
            let matchedPhones = Set(contactMatches.compactMap { match -> String? in
                guard let phone = match.user.phone else { return nil }
                return ContactsService.normalizePhone(phone)
            })
            invitableContacts = try await ContactsService.shared.fetchContactsWithFriendCounts(excludingPhones: matchedPhones)
        } catch {
            print("Error loading contacts: \(error)")
        }
        isLoadingContacts = false
    }

    private func followUser(_ user: User) async -> Bool {
        guard let currentUserId = authState.currentUser?.id else { return false }
        do {
            try await FollowService.shared.followOrRequest(
                userId: user.id,
                currentUserId: currentUserId,
                targetUser: user
            )
            // Return true for public profiles (immediate follow), false for private (pending request)
            return !user.isPrivate
        } catch {
            print("Error following user: \(error)")
            return false
        }
    }
}

// MARK: - Phlock Suggestion Row

private struct PhlockSuggestionRow: View {
    let suggestion: RecommendedFriend
    let onFollow: () async -> Bool
    let onAddToPhlock: (User) -> Void
    let onTap: () -> Void
    let isPhlockFull: Bool

    @State private var buttonState: FollowButtonState = .notFollowing

    enum FollowButtonState {
        case notFollowing
        case requested
        case following
    }

    private var contextText: String {
        switch suggestion.context {
        case .inContacts: return "in your contacts"
        case .recentActivity: return "recent activity"
        case .youMayKnow: return "you may know"
        case .mutualFriends:
            if let count = suggestion.mutualCount, count > 0 {
                return "\(count) mutual"
            }
            return "mutual friends"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tappable profile photo
            Button(action: onTap) {
                if let photoUrl = suggestion.user.profilePhotoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(suggestion.user.displayName.prefix(1).uppercased())
                                .font(.lora(size: 18, weight: .semiBold))
                                .foregroundColor(.gray)
                        )
                }
            }
            .buttonStyle(.plain)

            // Tappable name/username
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.user.displayName)
                        .font(.lora(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text(contextText)
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Dynamic button based on state
            switch buttonState {
            case .notFollowing:
                Button {
                    Task {
                        let isImmediate = await onFollow()
                        withAnimation(.spring(response: 0.3)) {
                            buttonState = isImmediate ? .following : .requested
                        }
                    }
                } label: {
                    Text("follow")
                        .font(.lora(size: 14, weight: .semiBold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .cornerRadius(8)
                }

            case .requested:
                Text("requested")
                    .font(.lora(size: 14, weight: .semiBold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

            case .following:
                if !isPhlockFull {
                    Button {
                        onAddToPhlock(suggestion.user)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("full")
                        .font(.lora(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Phlock Invite Row

private struct PhlockInviteRow: View {
    let contact: InvitableContact
    let isInvited: Bool
    let onInvite: () -> Void

    private var avatarColor: Color {
        let colors: [Color] = [.orange, .green, .blue, .purple, .pink, .red, .teal, .indigo]
        return colors[abs(contact.phone.hashValue) % colors.count]
    }

    private var initials: String {
        let parts = contact.name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(contact.name.prefix(2)).uppercased()
    }

    private var contextText: String {
        if contact.friendCount > 0 {
            return contact.friendCount == 1 ? "1 friend on phlock" : "\(contact.friendCount) friends on phlock"
        }
        return "not on phlock yet"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.lora(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(contextText)
                    .font(.lora(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Invite button
            Button(action: onInvite) {
                Text(isInvited ? "invited" : "invite")
                    .font(.lora(size: 14, weight: .semiBold))
                    .foregroundColor(isInvited ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isInvited ? Color.gray.opacity(0.2) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isInvited)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Phlock Message Compose View

struct PhlockMessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinished: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: (MessageComposeResult) -> Void

        init(onFinished: @escaping (MessageComposeResult) -> Void) {
            self.onFinished = onFinished
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.onFinished(result)
            }
        }
    }
}
