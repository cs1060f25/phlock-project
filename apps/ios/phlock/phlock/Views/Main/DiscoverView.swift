import SwiftUI

// Navigation destination types
enum DiscoverDestination: Hashable {
    case artist(MusicItem, PlatformType)
    case profile
}

struct DiscoverView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var navigationState: NavigationState
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

    // Recently played tracks state
    @State private var recentlyPlayedTracks: [MusicItem] = []
    @State private var isLoadingRecentTracks = false
    @State private var recentTracksError: String?

    // Daily song state
    @State private var todaysDailySong: Share?
    @State private var isLoadingDailySong = false
    @State private var dailySongError: String?
    @State private var showDailySongToast = false
    @State private var dailySongToastMessage = ""

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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Daily Song Streak Banner
                if let user = authState.currentUser, user.dailySongStreak > 0 || !user.hasSelectedToday {
                    DailySongStreakBanner(
                        user: user,
                        todaysDailySong: todaysDailySong
                    )
                }

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("search for music...", text: $searchText)
                        .font(.lora(size: 16, weight: .regular))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                        .onChange(of: searchText) { oldValue, newValue in
                            performDebouncedSearch()
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
                .padding(.horizontal)
                .padding(.top)

                // Filter Tabs - always allocated to prevent layout shift
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .opacity(!searchText.isEmpty || searchResults != nil ? 1 : 0)
                .disabled(searchText.isEmpty && searchResults == nil)
                .allowsHitTesting(!searchText.isEmpty || searchResults != nil)
                .onChange(of: selectedFilter) { oldValue, newValue in
                    if !searchText.isEmpty {
                        performSearch()
                    }
                }

                if !searchText.isEmpty || searchResults != nil {
                    Divider()
                }

                // Results
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        performSearch()
                    }
                } else if searchText.isEmpty && searchResults == nil {
                    // Show recently played grid when no search
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
                                .font(.lora(size: 20, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            RecentlyPlayedGridView(
                                tracks: recentlyPlayedTracks,
                                platformType: authState.currentUser?.platformType ?? .spotify,
                                onSelectDailySong: { track in selectDailySong(track, note: nil) },
                                todaysDailySong: todaysDailySong
                            )
                            .environmentObject(PlaybackService.shared)
                            .environmentObject(navigationState)
                        }
                    }
                } else if let results = searchResults {
                    SearchResultsList(
                        results: results,
                        filter: selectedFilter,
                        platformType: authState.currentUser?.platformType ?? .spotify,
                        searchQuery: searchText,
                        navigationPath: $navigationPath,
                        onSelectDailySong: { track in selectDailySong(track, note: nil) },
                        todaysDailySong: todaysDailySong
                    )
                    .environmentObject(navigationState)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere
                isSearchFieldFocused = false
            }
            .navigationTitle("discover")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: DiscoverDestination.self) { destination in
                switch destination {
                case .artist(let artist, let platformType):
                    ArtistDetailView(artist: artist, platformType: platformType)
                case .profile:
                    ProfileView()
                }
            }
            .onChange(of: clearSearchTrigger) { oldValue, newValue in
                // Clear search and focus field when trigger changes
                searchText = ""
                searchResults = nil
                isSearchFieldFocused = true
            }
            .onChange(of: navigationState.showShareSheet) { oldValue, newValue in
                // Dismiss keyboard when share sheet appears
                if newValue {
                    isSearchFieldFocused = false
                }
            }
            .task {
                // Load recently played tracks and daily song on view appear
                loadRecentlyPlayedTracks()
                loadTodaysDailySong()
            }
            .onChange(of: refreshTrigger) { oldValue, newValue in
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
        .fullScreenSwipeBack()
        .toast(isPresented: $showDailySongToast, message: dailySongToastMessage, type: .success, duration: 3.0)
    }

    private func refreshContent() async {
        // Clear search results and reload recent tracks
        searchText = ""
        searchResults = nil
        loadRecentlyPlayedTracks()
        loadTodaysDailySong()
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
        guard !searchText.isEmpty,
              let platformType = authState.currentUser?.platformType else {
            return
        }

        Task {
            isSearching = true
            errorMessage = nil

            do {
                if selectedFilter == .all {
                    // Fetch both tracks and artists for "All" tab
                    async let tracksResult = SearchService.shared.search(
                        query: searchText,
                        type: .tracks,
                        platformType: platformType
                    )
                    async let artistsResult = SearchService.shared.search(
                        query: searchText,
                        type: .artists,
                        platformType: platformType
                    )

                    let (tracks, artists) = try await (tracksResult, artistsResult)
                    searchResults = SearchResult(
                        tracks: tracks.tracks,
                        artists: artists.artists
                    )
                } else {
                    let results = try await SearchService.shared.search(
                        query: searchText,
                        type: selectedFilter.searchType,
                        platformType: platformType
                    )
                    searchResults = results
                }
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                print("Search error: \(error)")
            }

            isSearching = false
        }
    }

    private func loadRecentlyPlayedTracks() {
        guard let user = authState.currentUser,
              let platformType = user.platformType else {
            return
        }

        Task {
            isLoadingRecentTracks = true
            recentTracksError = nil

            do {
                recentlyPlayedTracks = try await SearchService.shared.getRecentlyPlayed(
                    userId: user.id,
                    platformType: platformType
                )
                print("✅ Loaded \(recentlyPlayedTracks.count) recently played tracks")
            } catch {
                recentTracksError = "Failed to load recently played tracks"
                print("❌ Error loading recently played: \(error)")
            }

            isLoadingRecentTracks = false
        }
    }

    private func loadTodaysDailySong() {
        guard let userId = authState.currentUser?.id else { return }

        Task {
            isLoadingDailySong = true
            dailySongError = nil

            do {
                todaysDailySong = try await ShareService.shared.getTodaysDailySong(for: userId)
                print("✅ Loaded today's daily song: \(todaysDailySong?.trackName ?? "none")")
            } catch {
                dailySongError = "Failed to load daily song"
                print("❌ Error loading daily song: \(error)")
            }

            isLoadingDailySong = false
        }
    }

    func selectDailySong(_ track: MusicItem, note: String? = nil) {
        guard let userId = authState.currentUser?.id else { return }

        Task {
            do {
                let share = try await ShareService.shared.selectDailySong(track: track, note: note, userId: userId)
                todaysDailySong = share

                // Update user in authState to reflect streak change
                if var updatedUser = authState.currentUser {
                    updatedUser = try await UserService.shared.getUser(userId: userId) ?? updatedUser
                    authState.currentUser = updatedUser
                }

                dailySongToastMessage = "🔥 \(track.name) is your song today!"
                showDailySongToast = true
                print("✅ Selected daily song: \(track.name)")
            } catch {
                dailySongToastMessage = "❌ \(error.localizedDescription)"
                showDailySongToast = true
                print("❌ Error selecting daily song: \(error)")
            }
        }
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
                    .font(.system(size: 22))
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.circle")
                .font(.system(size: 22))
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
            // Streak indicator
            if user.dailySongStreak > 0 {
                HStack(spacing: 4) {
                    Text(user.streakEmoji)
                        .font(.system(size: 20))
                    Text("\(user.dailySongStreak)")
                        .font(.lora(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
            }

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                if let dailySong = todaysDailySong {
                    Text("Today's song:")
                        .font(.lora(size: 12, weight: .semiBold))
                        .foregroundColor(.secondary)
                    Text(dailySong.trackName)
                        .font(.lora(size: 14, weight: .bold))
                        .lineLimit(1)
                } else {
                    Text("Select your song for today")
                        .font(.lora(size: 14, weight: .semiBold))
                        .foregroundColor(.primary)
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
