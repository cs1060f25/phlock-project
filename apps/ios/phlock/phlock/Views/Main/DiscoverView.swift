import SwiftUI

// Navigation destination types
enum DiscoverDestination: Hashable {
    case artist(MusicItem, PlatformType)
    case profile
}

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case tracks = "Tracks"
    case artists = "Artists"

    var searchType: SearchType {
        switch self {
        case .all: return .tracks // We'll search tracks but show both
        case .tracks: return .tracks
        case .artists: return .artists
        }
    }
}

enum BrowseTab: String, CaseIterable {
    case suggested = "Suggested"
    case recent = "Recent"
    case viral = "Viral"
    case new = "New"
    case charts = "Charts"
}

struct DiscoverView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject var clipboardService: ClipboardService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var navigationPath: NavigationPath
    @Binding var clearSearchTrigger: Int
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int

    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var searchResults: SearchResult?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0

    // Browse tab state
    @State private var selectedBrowseTab: BrowseTab = .recent

    // Recently played tracks state
    @State private var recentlyPlayedTracks: [MusicItem] = []
    @State private var isLoadingRecentTracks = false
    @State private var recentTracksError: String?

    // Curated playlist tracks state
    @State private var viralTracks: [MusicItem] = []
    @State private var newReleaseTracks: [MusicItem] = []
    @State private var chartsTracks: [MusicItem] = []
    @State private var isLoadingCuratedPlaylists = false
    @State private var curatedPlaylistsError: String?

    // Daily song state
    @State private var todaysDailySong: Share?
    @State private var isLoadingDailySong = false
    @State private var dailySongError: String?
    @State private var showDailySongToast = false
    @State private var dailySongToastMessage = ""
    @State private var selectedDailyTrackId: String?

    // Pending daily song state
    @State private var pendingDailySong: MusicItem?
    @State private var dailySongNote = ""
    @State private var isSubmittingDailySong = false // Prevent double-tap
    @FocusState private var isNoteFieldFocused: Bool

    // Check if user has a streaming platform with API access (not Spotify preference-only)
    private var hasStreamingPlatformWithAPI: Bool {
        guard let user = authState.currentUser else { return false }
        // User has a platform set AND is not a Spotify preference-only user
        return user.musicPlatform != nil && !user.isSpotifyPreferenceOnly
    }

    // Available tabs based on whether streaming platform with API access is connected
    private var availableTabs: [BrowseTab] {
        var tabs: [BrowseTab] = []

        // Add Suggested tab first if clipboard track exists
        if clipboardService.detectedTrack != nil {
            tabs.append(.suggested)
        }

        // Add platform-specific tabs
        if hasStreamingPlatformWithAPI {
            tabs.append(contentsOf: [.recent, .viral, .new, .charts])
        } else {
            tabs.append(contentsOf: [.viral, .new, .charts])
        }

        return tabs
    }

    // Default tab based on clipboard/streaming platform
    private var defaultTab: BrowseTab {
        if clipboardService.detectedTrack != nil {
            return .suggested
        }
        return hasStreamingPlatformWithAPI ? .recent : .viral
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Daily Song Streak Banner
                    if let user = authState.currentUser, user.dailySongStreak > 0 || !user.hasSelectedToday {
                        DailySongStreakBanner(
                            user: user,
                            todaysDailySong: todaysDailySong
                        )
                    }

                    // Search Bar - overlay ensures immediate tap response without layout issues
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("search for music...", text: $searchText)
                            .font(.lora(size: 14))
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .focused($isSearchFieldFocused)
                            .onChange(of: searchText) { newValue in
                                if newValue.isEmpty {
                                    // Clear search results when text is empty to return to browse view
                                    searchResults = nil
                                    searchTask?.cancel()
                                } else {
                                    performDebouncedSearch()
                                }
                            }
                            .onSubmit {
                                isSearchFieldFocused = false
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Invisible tap layer when not focused - uses overlay to match HStack size
                        Group {
                            if !isSearchFieldFocused {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isSearchFieldFocused = true
                                    }
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top)

                    // Filter Tabs for search results - only shown when searching
                    if !searchText.isEmpty || searchResults != nil {
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(SearchFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .onChange(of: selectedFilter) { newValue in
                            if !searchText.isEmpty {
                                performSearch()
                            }
                        }

                        Divider()
                    }

                    // Browse Tabs - shown when not searching
                    if searchText.isEmpty && searchResults == nil {
                        browseTabsView
                    }

                    resultsSection
                }
                
                // Pending Selection Bar
                if let pendingTrack = pendingDailySong {
                    DailySongSelectionBar(
                        track: pendingTrack,
                        note: $dailySongNote,
                        isFocused: _isNoteFieldFocused,
                        onSend: {
                            submitDailySong(track: pendingTrack, note: dailySongNote)
                        },
                        onCancel: {
                            withAnimation {
                                pendingDailySong = nil
                                dailySongNote = ""
                                selectedDailyTrackId = todaysDailySong?.trackId
                            }
                        }
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("browse")
                        .font(.lora(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationDestination(for: DiscoverDestination.self) { destination in
                switch destination {
                case .artist(let artist, let platformType):
                    ArtistDetailView(artist: artist, platformType: platformType)
                        .environmentObject(PlaybackService.shared)
                        .environmentObject(authState)
                case .profile:
                    ProfileView(scrollToTopTrigger: .constant(0))
                }
            }
            .onChange(of: clearSearchTrigger) { newValue in
                // Clear search and focus field when trigger changes
                searchText = ""
                searchResults = nil
                isSearchFieldFocused = true
            }
            .onChange(of: navigationState.showShareSheet) { newValue in
                // Dismiss keyboard when share sheet appears
                if newValue {
                    isSearchFieldFocused = false
                }
            }
            .task {
                // Set default tab based on streaming platform
                selectedBrowseTab = defaultTab

                // Load data on view appear
                loadRecentlyPlayedTracks()
                loadTodaysDailySong()
                loadCuratedPlaylists()
            }
            .onChange(of: authState.currentUser?.musicPlatform) { _ in
                // Reload when user's music platform changes (e.g., after connecting)
                selectedBrowseTab = defaultTab
                loadRecentlyPlayedTracks()
            }
            .onChange(of: clipboardService.detectedTrack) { newTrack in
                // Auto-select Suggested tab when clipboard track is detected
                if newTrack != nil {
                    withAnimation {
                        selectedBrowseTab = .suggested
                    }
                }
            }
            .onChange(of: refreshTrigger) { newValue in
                Task {
                    // Scroll to top and reload data
                    withAnimation {
                        scrollToTopTrigger += 1
                    }
                    isRefreshing = true
                    await refreshContent()
                    isRefreshing = false
                }
            }
        }
        .toast(isPresented: $showDailySongToast, message: dailySongToastMessage, type: .success, duration: 3.0)
    }

    private func refreshContent() async {
        // Clear search results and reload recent tracks
        searchText = ""
        searchResults = nil
        loadRecentlyPlayedTracks()
        loadTodaysDailySong()
        loadCuratedPlaylists(forceRefresh: true) // Force refresh on pull-to-refresh
    }

    private func loadCuratedPlaylists(forceRefresh: Bool = false) {
        Task {
            isLoadingCuratedPlaylists = true
            curatedPlaylistsError = nil

            // Load all playlist tracks in parallel with retry logic
            async let viralResult: [MusicItem] = {
                do {
                    return try await withTimeoutAndRetry(timeoutSeconds: 10) {
                        try await SearchService.shared.getViralTracks(forceRefresh: forceRefresh)
                    }
                } catch {
                    print("❌ Failed to load viral tracks after retries: \(error)")
                    return []
                }
            }()

            async let newReleaseResult: [MusicItem] = {
                do {
                    return try await withTimeoutAndRetry(timeoutSeconds: 10) {
                        try await SearchService.shared.getNewReleases(forceRefresh: forceRefresh)
                    }
                } catch {
                    print("❌ Failed to load new releases after retries: \(error)")
                    return []
                }
            }()

            async let chartsResult: [MusicItem] = {
                do {
                    return try await withTimeoutAndRetry(timeoutSeconds: 10) {
                        try await SearchService.shared.getChartsTracks(forceRefresh: forceRefresh)
                    }
                } catch {
                    print("❌ Failed to load charts after retries: \(error)")
                    return []
                }
            }()

            // Await all results in parallel
            let (viral, newReleases, charts) = await (viralResult, newReleaseResult, chartsResult)
            viralTracks = viral
            newReleaseTracks = newReleases
            chartsTracks = charts

            // Show error only if all failed
            if viralTracks.isEmpty && newReleaseTracks.isEmpty && chartsTracks.isEmpty {
                curatedPlaylistsError = "Unable to load music. Check your connection and try again."
            }

            isLoadingCuratedPlaylists = false
        }
    }

    private func performDebouncedSearch() {
        // Cancel previous search task
        searchTask?.cancel()

        // Debounce: wait 300ms before searching
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if !Task.isCancelled {
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        Task {
            isSearching = true
            errorMessage = nil

            do {
                if selectedFilter == .all {
                    // Fetch both tracks and artists for "All" tab
                    async let tracksResult = SearchService.shared.search(
                        query: searchText,
                        type: .tracks,
                        platformType: authState.currentUser?.resolvedPlatformType ?? .spotify
                    )
                    async let artistsResult = SearchService.shared.search(
                        query: searchText,
                        type: .artists,
                        platformType: authState.currentUser?.resolvedPlatformType ?? .spotify
                    )

                    let (tracks, artists) = try await (tracksResult, artistsResult)
                    searchResults = SearchResult(
                        tracks: tracks.tracks,
                        artists: artists.artists
                    )
                } else {
                    searchResults = try await SearchService.shared.search(
                        query: searchText,
                        type: selectedFilter.searchType,
                        platformType: authState.currentUser?.resolvedPlatformType ?? .spotify
                    )
                }
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
            }

            isSearching = false
        }
    }

    private func loadRecentlyPlayedTracks() {
        guard let user = authState.currentUser else { return }
        guard let platformType = user.resolvedPlatformType else { return }

        Task {
            isLoadingRecentTracks = true
            recentTracksError = nil

            do {
                recentlyPlayedTracks = try await SearchService.shared.getRecentlyPlayed(
                    userId: user.id,
                    platformType: platformType
                )
            } catch {
                recentTracksError = "Failed to load recently played tracks"
            }

            isLoadingRecentTracks = false
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if isSearching {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            ErrorView(message: error) {
                performSearch()
            }
        } else if searchText.isEmpty && searchResults == nil {
            browseContentSection
        } else if let results = searchResults {
            SearchResultsList(
                results: results,
                filter: selectedFilter,
                platformType: authState.currentUser?.resolvedPlatformType ?? .spotify,
                searchQuery: searchText,
                navigationPath: $navigationPath,
                onSelectDailySong: { track in selectDailySong(track) },
                todaysDailySong: todaysDailySong,
                selectedDailyTrackId: $selectedDailyTrackId,
                scrollToTopTrigger: $scrollToTopTrigger,
                isRefreshing: $isRefreshing,
                pullProgress: $pullProgress,
                onRefresh: { await refreshContent() }
            )
            .environmentObject(PlaybackService.shared)
            .environmentObject(authState)
            .environmentObject(navigationState)
        }
    }

    // MARK: - Browse Tabs View

    @ViewBuilder
    private var browseTabsView: some View {
        if availableTabs.count > 3 {
            // Scrollable pill selector for 4 tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Button {
                            selectedBrowseTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.lora(size: 14, weight: selectedBrowseTab == tab ? .semiBold : .regular))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedBrowseTab == tab ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(selectedBrowseTab == tab ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
        } else {
            // Segmented control for 3 tabs
            Picker("Browse", selection: $selectedBrowseTab) {
                ForEach(availableTabs, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Browse Content Section

    @ViewBuilder
    private var browseContentSection: some View {
        TabView(selection: $selectedBrowseTab) {
            ForEach(availableTabs, id: \.self) { tab in
                browseContentForTab(tab)
                    .tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: selectedBrowseTab)
    }

    @ViewBuilder
    private func browseContentForTab(_ tab: BrowseTab) -> some View {
        switch tab {
        case .suggested:
            suggestedTrackSection
        case .recent:
            recentlyPlayedSection
        case .viral:
            curatedPlaylistSection(tracks: viralTracks, title: "viral hits", isLoading: isLoadingCuratedPlaylists)
        case .new:
            curatedPlaylistSection(tracks: newReleaseTracks, title: "what's new", isLoading: isLoadingCuratedPlaylists)
        case .charts:
            curatedPlaylistSection(tracks: chartsTracks, title: "today's top hits", isLoading: isLoadingCuratedPlaylists)
        }
    }

    // MARK: - Suggested Track Section (from clipboard)

    @ViewBuilder
    private var suggestedTrackSection: some View {
        if let track = clipboardService.detectedTrack {
            VStack(spacing: 20) {
                Text("from your clipboard")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 20)

                // Large track card
                Button {
                    selectDailySong(track)
                } label: {
                    VStack(spacing: 16) {
                        // Album Art
                        if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                        }

                        // Track info
                        VStack(spacing: 6) {
                            Text(track.name)
                                .font(.lora(size: 20, weight: .semiBold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Text(track.artistName ?? "Unknown Artist")
                                .font(.lora(size: 16))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        // Selection indicator
                        if selectedDailyTrackId == track.id {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("selected")
                                    .font(.lora(size: 14, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        } else {
                            Text("tap to select")
                                .font(.lora(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Dismiss button
                Button {
                    clipboardService.clearDetectedTrack()
                    // Switch to next available tab
                    if let firstNonSuggested = availableTabs.first(where: { $0 != .suggested }) {
                        selectedBrowseTab = firstNonSuggested
                    }
                } label: {
                    Text("dismiss suggestion")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            // Fallback - should not happen but handle gracefully
            Text("No suggested track")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func curatedPlaylistSection(tracks: [MusicItem], title: String, isLoading: Bool) -> some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = curatedPlaylistsError {
            ErrorView(message: error) {
                loadCuratedPlaylists()
            }
        } else if tracks.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("No tracks available")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.lora(size: 20, weight: .semiBold))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                RecentlyPlayedGridView(
                    tracks: tracks,
                    platformType: .spotify, // Curated playlists are always from Spotify
                    onSelectDailySong: { track in selectDailySong(track) },
                    todaysDailySong: todaysDailySong,
                    selectedDailyTrackId: $selectedDailyTrackId
                )
                .environmentObject(PlaybackService.shared)
                .environmentObject(navigationState)
            }
        }
    }

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        if isLoadingRecentTracks {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = recentTracksError {
            ErrorView(message: error) {
                loadRecentlyPlayedTracks()
            }
        } else if recentlyPlayedTracks.isEmpty {
            EmptySearchView(isSearchFieldFocused: $isSearchFieldFocused)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("recently played")
                    .font(.lora(size: 20, weight: .semiBold))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                RecentlyPlayedGridView(
                    tracks: recentlyPlayedTracks,
                    platformType: authState.currentUser?.resolvedPlatformType ?? .spotify,
                    onSelectDailySong: { track in selectDailySong(track) },
                    todaysDailySong: todaysDailySong,
                    selectedDailyTrackId: $selectedDailyTrackId
                )
                .environmentObject(PlaybackService.shared)
                .environmentObject(navigationState)
            }
        }
    }

    private func loadTodaysDailySong() {
        guard let userId = authState.currentUser?.id else { return }

        Task {
            isLoadingDailySong = true
            dailySongError = nil

            do {
                todaysDailySong = try await ShareService.shared.getTodaysDailySong(for: userId)
                selectedDailyTrackId = todaysDailySong?.trackId
            } catch {
                dailySongError = "Failed to load daily song"
            }

            isLoadingDailySong = false
        }
    }

    func selectDailySong(_ track: MusicItem) {
        // Toggle selection: if already selected, deselect
        if pendingDailySong?.id == track.id {
            withAnimation {
                pendingDailySong = nil
                selectedDailyTrackId = todaysDailySong?.trackId
                dailySongNote = ""
            }
        } else {
            // Otherwise select new track
            withAnimation {
                pendingDailySong = track
                selectedDailyTrackId = track.id
                dailySongNote = "" // Reset note
            }
        }
    }

    func submitDailySong(track: MusicItem, note: String) {
        guard let userId = authState.currentUser?.id else { return }

        // Prevent double-submission
        guard !isSubmittingDailySong else {
            print("⚠️ Already submitting daily song, ignoring duplicate tap")
            return
        }

        isSubmittingDailySong = true

        Task {
            defer {
                Task { @MainActor in
                    isSubmittingDailySong = false
                }
            }

            do {
                let share = try await ShareService.shared.selectDailySong(track: track, note: note.isEmpty ? nil : note, userId: userId)
                todaysDailySong = share

                // Update user in authState to reflect streak change
                if var updatedUser = authState.currentUser {
                    updatedUser = try await UserService.shared.getUser(userId: userId) ?? updatedUser
                    authState.currentUser = updatedUser
                }

                dailySongToastMessage = "🔥 \(track.name) is your song today!"
                showDailySongToast = true

                await MainActor.run {
                    selectedDailyTrackId = share.trackId
                    pendingDailySong = nil // Clear pending
                    dailySongNote = ""
                    dismiss()
                }
            } catch {
                dailySongToastMessage = "❌ \(error.localizedDescription)"
                showDailySongToast = true
            }
        }
    }
}

// MARK: - Daily Song Selection Bar

struct DailySongSelectionBar: View {
    let track: MusicItem
    @Binding var note: String
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .center, spacing: 14) {
                // Album Art
                if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Color.gray.opacity(0.2)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Track Info & Input
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.name)
                        .font(.lora(size: 17, weight: .semiBold))
                        .lineLimit(1)

                    Text(track.artistName ?? "Unknown Artist")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    TextField("add optional message...", text: $note)
                        .font(.lora(size: 13))
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .submitLabel(.send)
                        .padding(.top, 4)
                        .onChange(of: note) { newValue in
                            // Limit to 80 characters for brief one-sentence messages
                            if newValue.count > 80 {
                                note = String(newValue.prefix(80))
                            }
                        }
                        .onSubmit {
                            onSend()
                        }
                }

                Spacer()

                // Close Button
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(12)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }

                // Send Button
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                        .padding(10)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(uiColor: .systemBackground))
        }
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Profile Icon Component

struct ProfileIconView: View {
    let user: User?

    var body: some View {
        if let profilePhotoUrl = user?.profilePhotoUrl,
           let url = URL(string: profilePhotoUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.lora(size: 20, weight: .semiBold))
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.circle")
                .font(.lora(size: 20, weight: .semiBold))
        }
    }
}

// MARK: - Daily Song Streak Banner

struct DailySongStreakBanner: View {
    let user: User
    let todaysDailySong: Share?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Status text with inline streak
            VStack(alignment: .leading, spacing: 2) {
                if let dailySong = todaysDailySong {
                    Text("Today's song:")
                        .font(.lora(size: 10))
                        .foregroundColor(.secondary)
                    Text(dailySong.trackName)
                        .font(.lora(size: 10))
                        .lineLimit(1)
                } else {
                    HStack(spacing: 6) {
                        Text("select your song for today")
                            .font(.lora(size: 20))
                            .foregroundColor(.primary)
                        if user.dailySongStreak > 0 {
                            Text("(\(user.streakEmoji) \(user.dailySongStreak))")
                                .font(.lora(size: 20))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            user.hasSelectedToday
                ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
                : Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.1)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
}

#Preview {
    DiscoverView(
        navigationPath: .constant(NavigationPath()),
        clearSearchTrigger: .constant(0),
        refreshTrigger: .constant(0),
        scrollToTopTrigger: .constant(0)
    )
        .environmentObject(AuthenticationState())
        .environmentObject(PlaybackService.shared)
}
