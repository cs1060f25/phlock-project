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

    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var searchResults: SearchResult?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    // Recently played tracks state
    @State private var recentlyPlayedTracks: [MusicItem] = []
    @State private var isLoadingRecentTracks = false
    @State private var recentTracksError: String?

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
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("search for music...", text: $searchText)
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
                                .font(.nunitoSans(size: 20, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            RecentlyPlayedGridView(
                                tracks: recentlyPlayedTracks,
                                platformType: authState.currentUser?.platformType ?? .spotify
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
                        navigationPath: $navigationPath
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
                // Load recently played tracks on view appear
                loadRecentlyPlayedTracks()
            }
        }
        .fullScreenSwipeBack()
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

#Preview {
    DiscoverView(navigationPath: .constant(NavigationPath()), clearSearchTrigger: .constant(0))
        .environmentObject(AuthenticationState())
        .environmentObject(PlaybackService.shared)
}
