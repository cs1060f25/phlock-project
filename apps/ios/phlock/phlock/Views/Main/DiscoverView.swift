import SwiftUI

// Navigation destination types
enum DiscoverDestination: Hashable {
    case artist(MusicItem, PlatformType)
    case profile
}

struct DiscoverView: View {
    @EnvironmentObject var authState: AuthenticationState
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
                .padding()

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
                    EmptySearchView(isSearchFieldFocused: $isSearchFieldFocused)
                } else if let results = searchResults {
                    SearchResultsList(
                        results: results,
                        filter: selectedFilter,
                        platformType: authState.currentUser?.platformType ?? .spotify,
                        searchQuery: searchText,
                        navigationPath: $navigationPath
                    )
                }
            }
            .navigationTitle("discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationPath.append(DiscoverDestination.profile)
                    } label: {
                        ProfileIconView(user: authState.currentUser)
                    }
                }
            }
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
