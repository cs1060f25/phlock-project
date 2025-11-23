import SwiftUI

// MARK: - Search Results Components

struct SearchResultsList: View {
    let results: SearchResult
    let filter: DiscoverView.SearchFilter
    let platformType: PlatformType
    let searchQuery: String
    @Binding var navigationPath: NavigationPath
    let onSelectDailySong: ((MusicItem) -> Void)?
    let todaysDailySong: Share?
    @Binding var selectedDailyTrackId: String?
    @Binding var scrollToTopTrigger: Int
    @Binding var isRefreshing: Bool
    @Binding var pullProgress: CGFloat
    let onRefresh: () async -> Void
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.colorScheme) var colorScheme

    init(
        results: SearchResult,
        filter: DiscoverView.SearchFilter,
        platformType: PlatformType,
        searchQuery: String,
        navigationPath: Binding<NavigationPath>,
        onSelectDailySong: ((MusicItem) -> Void)? = nil,
        todaysDailySong: Share? = nil,
        selectedDailyTrackId: Binding<String?> = .constant(nil),
        scrollToTopTrigger: Binding<Int>,
        isRefreshing: Binding<Bool>,
        pullProgress: Binding<CGFloat>,
        onRefresh: @escaping () async -> Void
    ) {
        self.results = results
        self.filter = filter
        self.platformType = platformType
        self.searchQuery = searchQuery
        self._navigationPath = navigationPath
        self.onSelectDailySong = onSelectDailySong
        self.todaysDailySong = todaysDailySong
        self._selectedDailyTrackId = selectedDailyTrackId
        self._scrollToTopTrigger = scrollToTopTrigger
        self._isRefreshing = isRefreshing
        self._pullProgress = pullProgress
        self.onRefresh = onRefresh
    }

    var displayedTracks: [MusicItem] {
        filter == .artists ? [] : results.tracks
    }

    var displayedArtists: [MusicItem] {
        filter == .tracks ? [] : results.artists
    }

    // For "All" tab, rank results using Spotify's API position + popularity + name matching
    // Respects Spotify's search relevance while boosting exact/close name matches
    var allResults: [(item: MusicItem, type: String)] {
        // Helper to calculate name match score
        func nameMatchScore(itemName: String, query: String) -> Double {
            let itemLower = itemName.lowercased().trimmingCharacters(in: .whitespaces)
            let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)

            // Exact match
            if itemLower == queryLower {
                return 100.0
            }

            // Contains as whole word
            if itemLower.contains(queryLower) {
                return 50.0
            }

            // Starts with query
            if itemLower.hasPrefix(queryLower) {
                return 30.0
            }

            return 0.0
        }

        // Helper to calculate unified relevance score
        func calculateScore(item: MusicItem, index: Int, isArtist: Bool) -> Double {
            // Position score: Spotify's API ordering is the primary signal
            // Index 0 = 200 points, index 1 = 190, index 2 = 180, etc.
            let positionScore = Double(200 - (index * 10))

            // Popularity score: 0-100 from Spotify (secondary factor)
            let popularityScore = Double(item.popularity ?? 0)

            // Name matching score: Heavy boost for names that match query
            let matchScore = nameMatchScore(itemName: item.name, query: searchQuery)

            // Combined score: 50% position, 30% name match, 20% popularity
            var finalScore = (positionScore * 0.5) + (matchScore * 0.3) + (popularityScore * 0.2)

            // Additional boost for artists with name matches (canonical entities)
            if isArtist && matchScore > 0 {
                finalScore += 50.0
            }

            return finalScore
        }

        // Create scored items with stable sort key
        var scoredItems: [(item: MusicItem, type: String, score: Double, originalIndex: Int)] = []

        // Add tracks with scores
        for (index, track) in results.tracks.enumerated() {
            let score = calculateScore(item: track, index: index, isArtist: false)
            scoredItems.append((track, "Track", score, index))
        }

        // Add artists with scores (offset index to ensure uniqueness)
        for (index, artist) in results.artists.enumerated() {
            let score = calculateScore(item: artist, index: index, isArtist: true)
            scoredItems.append((artist, "Artist", score, results.tracks.count + index))
        }

        // Sort by score descending, then by original index for stability
        scoredItems.sort {
            if $0.score == $1.score {
                return $0.originalIndex < $1.originalIndex
            }
            return $0.score > $1.score
        }

    // Return without scores
        return scoredItems.map { ($0.item, $0.type) }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .id("discoverTop")

                if filter == .all {
                    // All tab - show combined results
                    ForEach(Array(allResults.enumerated()), id: \.offset) { index, result in
                        if result.type == "Track" {
                                TrackResultRow(
                                    track: result.item,
                                    platformType: platformType,
                                    showType: true,
                                    onSelectDailySong: onSelectDailySong,
                                    todaysDailySong: todaysDailySong,
                                    selectedDailyTrackId: $selectedDailyTrackId
                                )
                            .environmentObject(authState)
                            .environmentObject(navigationState)
                        } else {
                            Button {
                                navigationPath.append(DiscoverDestination.artist(result.item, platformType))
                            } label: {
                                ArtistResultRow(artist: result.item, showType: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    // Tracks Section
                    if !displayedTracks.isEmpty {
                        ForEach(displayedTracks, id: \.id) { track in
                            TrackResultRow(
                                track: track,
                                platformType: platformType,
                                showType: false,
                                onSelectDailySong: onSelectDailySong,
                                todaysDailySong: todaysDailySong,
                                selectedDailyTrackId: $selectedDailyTrackId
                            )
                            .environmentObject(authState)
                            .environmentObject(navigationState)
                        }
                    }

                    // Artists Section
                    if !displayedArtists.isEmpty {
                        ForEach(displayedArtists, id: \.id) { artist in
                            Button {
                                navigationPath.append(DiscoverDestination.artist(artist, platformType))
                            } label: {
                                ArtistResultRow(artist: artist, showType: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // No Results
                if displayedTracks.isEmpty && displayedArtists.isEmpty {
                    NoResultsView()
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .pullToRefreshWithSpinner(
                isRefreshing: $isRefreshing,
                pullProgress: $pullProgress,
                colorScheme: colorScheme
            ) {
                isRefreshing = true
                await onRefresh()
                await MainActor.run {
                    isRefreshing = false
                }
            }
            .onChange(of: scrollToTopTrigger) { _ in
                withAnimation {
                    scrollProxy.scrollTo("discoverTop", anchor: .top)
                }
            }
        }
    }

    private func playTrack(_ track: MusicItem) {
        PlaybackService.shared.play(track: track)
    }
}

struct TrackResultRow: View {
    let track: MusicItem
    let platformType: PlatformType
    let showType: Bool
    let onSelectDailySong: ((MusicItem) -> Void)?
    let todaysDailySong: Share?
    @Binding var selectedDailyTrackId: String?
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showDailyConfirm = false

    init(
        track: MusicItem,
        platformType: PlatformType,
        showType: Bool,
        onSelectDailySong: ((MusicItem) -> Void)? = nil,
        todaysDailySong: Share? = nil,
        selectedDailyTrackId: Binding<String?> = .constant(nil)
    ) {
        self.track = track
        self.platformType = platformType
        self.showType = showType
        self.onSelectDailySong = onSelectDailySong
        self.todaysDailySong = todaysDailySong
        self._selectedDailyTrackId = selectedDailyTrackId
    }

    var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == track.id
    }

    var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var isCommittedAsDaily: Bool {
        todaysDailySong?.trackId == track.id
    }

    var isPendingSelection: Bool {
        selectedDailyTrackId == track.id
    }

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 12) {
            // Playing indicator bar
            if isCurrentTrack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: 4, height: 40)
            }

            // Album Art
            if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isCurrentTrack ? Color.primary : (isCommittedAsDaily ? Color.green : Color.clear), lineWidth: 2.5)
                )
            } else {
                Color.gray.opacity(0.2)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Track Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.lora(size: 16, weight: isCurrentTrack ? .bold : .semiBold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if showType {
                    Text("Track")
                        .font(.lora(size: 13, weight: isCurrentTrack ? .semiBold : .regular))
                        .foregroundColor(.secondary)
                } else if let artist = track.artistName {
                    Text(artist)
                        .font(.lora(size: 14, weight: isCurrentTrack ? .semiBold : .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Daily Song Button (only show if handler provided)
            if let _ = onSelectDailySong {
                Button {
                    selectedDailyTrackId = track.id
                    showDailyConfirm = true
                } label: {
                    ZStack {
                        Circle()
                            .fill((isCommittedAsDaily || isPendingSelection) ? Color.accentColor : Color.white.opacity(0.65))
                            .overlay(
                                Circle()
                                    .stroke((isCommittedAsDaily || isPendingSelection) ? Color.accentColor : Color.secondary, lineWidth: 2)
                            )
                            .frame(width: 24, height: 24)
                        if isCommittedAsDaily || isPendingSelection {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Share Button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    navigationState.shareTrack = track
                    navigationState.showShareSheet = true
                }
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // Play Button
            Button {
                if isPlaying {
                    playbackService.pause()
                } else {
                    playbackService.play(track: track)
                }
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isCurrentTrack ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isCurrentTrack ? 8 : 12)
        .background(
            isCurrentTrack
                ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                : Color.clear
        )
        .cornerRadius(8)
        }
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if onSelectDailySong != nil {
                selectedDailyTrackId = track.id
                showDailyConfirm = true
            }
        }
        .confirmationDialog(
            "Select \"\(track.name)\" as your daily song?",
            isPresented: $showDailyConfirm,
            titleVisibility: .visible
        ) {
            if let selectHandler = onSelectDailySong {
                Button("Confirm") { selectHandler(track) }
            }
            Button("Cancel", role: .cancel) {
                selectedDailyTrackId = todaysDailySong?.trackId
            }
        }
    }
}

struct ArtistResultRow: View {
    let artist: MusicItem
    let showType: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Artist Image
            if let artworkUrl = artist.albumArtUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Color.gray.opacity(0.2)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }

            // Artist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.lora(size: 16, weight: .semiBold))
                    .lineLimit(1)

                if showType {
                    Text("Artist")
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty States

struct EmptySearchView: View {
    @FocusState.Binding var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("search for music")
                .font(.lora(size: 20, weight: .semiBold))

            Text("find tracks and artists to send")
                .font(.lora(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = false
        }
    }
}

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("no results found")
                .font(.lora(size: 20, weight: .semiBold))

            Text("try a different search term")
                .font(.lora(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("search error")
                .font(.lora(size: 20, weight: .semiBold))

            Text(message)
                .font(.lora(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                retry()
            }
            .font(.lora(size: 16, weight: .semiBold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recently Played Grid

struct RecentlyPlayedGridView: View {
    let tracks: [MusicItem]
    let platformType: PlatformType
    let onSelectDailySong: ((MusicItem) -> Void)?
    let todaysDailySong: Share?
    @Binding var selectedDailyTrackId: String?
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.colorScheme) var colorScheme

    init(
        tracks: [MusicItem],
        platformType: PlatformType,
        onSelectDailySong: ((MusicItem) -> Void)? = nil,
        todaysDailySong: Share? = nil,
        selectedDailyTrackId: Binding<String?> = .constant(nil)
    ) {
        self.tracks = tracks
        self.platformType = platformType
        self.onSelectDailySong = onSelectDailySong
        self.todaysDailySong = todaysDailySong
        self._selectedDailyTrackId = selectedDailyTrackId
    }

    // 3 columns grid
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12, pinnedViews: []) {
                ForEach(tracks, id: \.id) { track in
                    RecentTrackCard(
                        track: track,
                        onSelectDailySong: onSelectDailySong,
                        todaysDailySong: todaysDailySong,
                        selectedDailyTrackId: $selectedDailyTrackId
                    )
                    .environmentObject(playbackService)
                    .environmentObject(navigationState)
                    .id(track.id) // Ensure stable view identity
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.visible)
    }
}

struct RecentTrackCard: View {
    let track: MusicItem
    let onSelectDailySong: ((MusicItem) -> Void)?
    let todaysDailySong: Share?
    @Binding var selectedDailyTrackId: String?
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.colorScheme) var colorScheme
    @State private var showDailyConfirm = false

    init(
        track: MusicItem,
        onSelectDailySong: ((MusicItem) -> Void)? = nil,
        todaysDailySong: Share? = nil,
        selectedDailyTrackId: Binding<String?> = .constant(nil)
    ) {
        self.track = track
        self.onSelectDailySong = onSelectDailySong
        self.todaysDailySong = todaysDailySong
        self._selectedDailyTrackId = selectedDailyTrackId
    }

    var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == track.id
    }

    var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var isCommittedAsDaily: Bool {
        todaysDailySong?.trackId == track.id
    }

    var isPendingSelection: Bool {
        selectedDailyTrackId == track.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Album Art with Play Overlay and Send Button
            ZStack {
                if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure(_):
                            Color.gray.opacity(0.2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .empty:
                            Color.gray.opacity(0.2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        @unknown default:
                            Color.gray.opacity(0.2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color.gray.opacity(0.2)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Action buttons (top corners)
                VStack {
                    HStack {
                        Spacer()

                        // Top-right action: daily select button when in daily flow, otherwise share
                        if let _ = onSelectDailySong {
                            Button {
                                selectedDailyTrackId = track.id
                                showDailyConfirm = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill((isCommittedAsDaily || isPendingSelection) ? Color.accentColor : Color.white.opacity(0.65))
                                        .overlay(
                                            Circle()
                                                .stroke((isCommittedAsDaily || isPendingSelection) ? Color.accentColor : Color.secondary, lineWidth: 2)
                                        )
                                        .frame(width: 26, height: 26)
                                    if isCommittedAsDaily || isPendingSelection {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                            .padding(.top, 4)
                        } else if onSelectDailySong == nil {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    navigationState.shareTrack = track
                                    navigationState.showShareSheet = true
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.65))
                                        .frame(width: 26, height: 26)

                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                            .padding(.top, 4)
                        }
                    }
                    Spacer()
                }

                // Play button overlay (center)
                Button {
                    if isPlaying {
                        playbackService.pause()
                    } else {
                        playbackService.play(track: track)
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 3)
                        .padding(20)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }

            // Track Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.lora(size: 13, weight: .semiBold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let artist = track.artistName {
                    Text(artist)
                        .font(.lora(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if onSelectDailySong != nil {
                selectedDailyTrackId = track.id
                showDailyConfirm = true
            }
        }
        .confirmationDialog(
            "Select \"\(track.name)\" as your daily song?",
            isPresented: $showDailyConfirm,
            titleVisibility: .visible
        ) {
            if let selectHandler = onSelectDailySong {
                Button("Confirm") { selectHandler(track) }
            }
            Button("Cancel", role: .cancel) {
                selectedDailyTrackId = todaysDailySong?.trackId
            }
        }
    }
}
