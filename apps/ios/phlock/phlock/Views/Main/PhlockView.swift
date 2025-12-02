import SwiftUI
import AVFoundation
import Supabase

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
    @State private var savedTrackIds: Set<String> = []
    @State private var myDailySong: Share?
    @State private var showDailySongSheet = false
    @State private var myDailySongNavPath = NavigationPath()
    @State private var myDailySongClearTrigger = 0
    @State private var myDailySongRefreshTrigger = 0
    @State private var myDailySongScrollToTopTrigger = 0
    @State private var hasLoadedPhlockOnce = false

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
        let currentCount = items.count
        if currentCount < 5 {
            for _ in 0..<(5 - currentCount) {
                items.append(PhlockItem(id: UUID(), member: nil, song: nil, type: .empty))
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
                        savedTrackIds: savedTrackIds,
                        nudgedUserIds: nudgedUserIds,
                        currentlyPlayingId: playbackService.currentTrack?.id,
                        isPlaying: playbackService.isPlaying,
                        onPlayTapped: { song, shouldAutoPlay, savedPosition in
                            playTrack(song: song, autoPlay: shouldAutoPlay, fromPosition: savedPosition)
                        },
                        onSwapTapped: { member in
                            selectedMemberToSwap = member
                            showSwapSheet = true
                        },
                        onAddToLibrary: { song in
                            addToLibrary(song)
                        },
                        onRemoveFromLibrary: { song in
                            removeFromLibrary(song)
                        },
                        onProfileTapped: { user in
                            navigationPath.append(PhlockDestination.userProfile(user))
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
                        }
                    )
                    .ignoresSafeArea(edges: .top)
                }
            }
            .navigationDestination(for: PhlockDestination.self) { destination in
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
                AddMemberView(
                    phlockMembers: phlockMembers,
                    onAddCompleted: { user in
                        // Find first available position
                        let usedPositions = Set(phlockMembers.map { $0.position })
                        for pos in 1...5 {
                            if !usedPositions.contains(pos) {
                                handleAddMember(user: user, position: pos)
                                break
                            }
                        }
                    }
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
        }
        .toast(isPresented: $showToast, message: toastMessage, type: toastType)
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
                playbackService.skipForward(wrap: false)
            }
        }
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
                                isSaved: savedTrackIds.contains(song.trackId),
                                hasSongToday: true,
                                onPlayTapped: {
                                    // Find index in dailySongs for playback context
                                    if let songIndex = dailySongs.firstIndex(where: { $0.id == song.id }) {
                                        playTrackAtIndex(songIndex)
                                    }
                                },
                                onSwapTapped: {
                                    selectedMemberToSwap = member
                                    showSwapSheet = true
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
                                    selectedMemberToSwap = member
                                    showSwapSheet = true
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
            // Get phlock members
            phlockMembers = try await UserService.shared.getPhlockMembers(for: userId)
            nudgedUserIds = nudgedUserIds.intersection(Set(phlockMembers.map { $0.user.id }))
            
            if phlockMembers.isEmpty {
                // No phlock members - show empty state (no demo data)
                dailySongs = []
                isLoading = false
                hasLoadedPhlockOnce = true
                return
            }

            // Get their daily songs
            let memberIds = phlockMembers.map { $0.user.id }
            dailySongs = try await ShareService.shared.getDailySongs(from: memberIds) 
            
            // Sort daily songs by time (earliest first)
            dailySongs.sort { $0.createdAt < $1.createdAt }

            // Initial saved state from database
            savedTrackIds = Set(dailySongs.compactMap { share in
                share.savedAt != nil ? share.trackId : nil
            })

            // If no songs today, just show waiting state (no demo data)
            if dailySongs.isEmpty {
                print("ℹ️ No daily songs found for \(phlockMembers.count) phlock members")
            }

            hasLoadedPhlockOnce = true
            print("✅ Loaded \(dailySongs.count) daily songs from \(phlockMembers.count) phlock members")

            // Check actual Spotify library status (async, doesn't block UI)
            await checkSpotifyLibraryStatus(for: dailySongs)
        } catch is CancellationError {
            print("ℹ️ Daily playlist load cancelled")
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
        myDailySong = try? await ShareService.shared.getTodaysDailySong(for: userId)
        if let song = myDailySong {
            print("🎵 PhlockView: Found my daily song: \(song.trackName)")
        } else {
            print("🎵 PhlockView: No daily song found for me")
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

                try await ShareService.shared.trackLibrarySave(
                    trackId: song.trackId,
                    userId: currentUser.id,
                    platformType: platformType
                )

                _ = await MainActor.run {
                    savedTrackIds.insert(song.trackId)
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
                    _ = await MainActor.run {
                        savedTrackIds.remove(song.trackId)
                    }
                case .appleMusic:
                    toastMessage = "Open Apple Music to remove track"
                    toastType = .info
                    showToast = true
                    _ = await MainActor.run {
                        savedTrackIds.remove(song.trackId)
                    }
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
            savedTrackIds = Set(songs.compactMap { $0.savedAt != nil ? $0.trackId : nil })
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
            savedTrackIds = newSavedIds
        } catch {
            print("⚠️ Failed to check Spotify library status: \(error)")
            // Fall back to savedAt from database
            savedTrackIds = Set(songs.compactMap { $0.savedAt != nil ? $0.trackId : nil })
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
        showAddSheet = false
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

                // Refresh playlist
                await loadDailyPlaylist()
            } catch {
                toastMessage = "Failed to add member"
                toastType = .error
                showToast = true
                print("❌ Error adding member: \(error)")
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

        // Pass saved track IDs to PlaybackService for FullScreenPlayerView to use
        playbackService.savedTrackIds = savedTrackIds

        playbackService.startQueue(
            tracks: queueTracks,
            startAt: index,
            sourceIds: sourceIds,
            showMiniPlayer: true
        )
    }

    private func playTrack(song: Share, autoPlay: Bool = true, fromPosition: Double? = nil) {
        let track = musicItem(from: song)

        // Pass saved track IDs to PlaybackService for FullScreenPlayerView to use
        playbackService.savedTrackIds = savedTrackIds

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
                        Text("No available friends")
                            .font(.lora(size: 16, weight: .medium))
                        Text("All your friends are already in your phlock")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        HStack {
                            // Profile photo
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

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.lora(size: 16, weight: .medium))

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
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFriend = friend
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

            // Fetch today's song status in parallel
            var statusUpdates: [(UUID, Bool)] = []
            await withTaskGroup(of: (UUID, Bool).self) { group in
                for friend in friends {
                    group.addTask {
                        let hasSong = (try? await ShareService.shared.getTodaysDailySong(for: friend.id)) != nil
                        return (friend.id, hasSong)
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

// MARK: - Add Member View

struct AddMemberView: View {
    let phlockMembers: [FriendWithPosition]
    let onAddCompleted: (User) -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authState: AuthenticationState
    @State private var friends: [User] = []
    @State private var selectedFriend: User?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 12) {
                        Text("No available friends")
                            .font(.lora(size: 16, weight: .medium))
                        Text("Add more friends to build your phlock")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        HStack {
                            // Profile photo
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

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.lora(size: 16, weight: .medium))

                                if friend.username != nil {
                                    Text("@\(friend.username ?? "")")
                                        .font(.lora(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if selectedFriend?.id == friend.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFriend = friend
                        }
                    }
                }
            }
            .navigationTitle("Add to Phlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let friend = selectedFriend {
                            onAddCompleted(friend)
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

            print("✅ Found \(friends.count) friends available to add")
        } catch {
            print("❌ Error loading friends: \(error)")
            friends = []
        }

        isLoading = false
    }
}
