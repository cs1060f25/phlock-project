import SwiftUI

struct ArtistDetailView: View {
    let artist: MusicItem
    let platformType: PlatformType

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService
    @State private var topTracks: [MusicItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var searchResults: [MusicItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchBarExpanded = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isSearchFieldFocused: Bool

    var displayedTracks: [MusicItem] {
        searchText.isEmpty ? topTracks : searchResults
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                ErrorView(message: error) {
                    loadTopTracks()
                }
            } else {
                GeometryReader { scrollGeometry in
                    ScrollView {
                        VStack(spacing: 24) {
                            // Artist Header
                            VStack(spacing: 16) {
                                // Artist Image
                                if let artworkUrl = artist.albumArtUrl, let url = URL(string: artworkUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 200, height: 200)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        Image(systemName: "music.mic")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray)
                                    )
                            }

                            // Artist Name
                            Text(artist.name)
                                .font(.nunitoSans(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Tracks Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(searchText.isEmpty ? "Top Tracks" : "Search Results")
                                .font(.nunitoSans(size: 22, weight: .bold))
                                .padding(.horizontal)

                            if displayedTracks.isEmpty {
                                Text(searchText.isEmpty ? "No tracks available" : "No tracks found")
                                    .font(.nunitoSans(size: 15))
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(Array(displayedTracks.enumerated()), id: \.element.id) { index, track in
                                    let isCurrentTrack = playbackService.currentTrack?.id == track.id
                                    let isPlaying = isCurrentTrack && playbackService.isPlaying

                                    HStack(spacing: 12) {
                                        // Playing indicator bar
                                        if isCurrentTrack {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.primary)
                                                .frame(width: 4, height: 40)
                                        }

                                        // Track Number
                                        Text("\(index + 1)")
                                            .font(.nunitoSans(size: 16, weight: .semiBold))
                                            .foregroundColor(.secondary)
                                            .frame(width: 30)

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
                                            .cornerRadius(4)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(isCurrentTrack ? Color.primary : Color.clear, lineWidth: 2.5)
                                            )
                                        } else {
                                            Color.gray.opacity(0.2)
                                                .frame(width: 50, height: 50)
                                                .cornerRadius(4)
                                        }

                                        // Track Info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(track.name)
                                                .font(.nunitoSans(size: 16, weight: isCurrentTrack ? .bold : .semiBold))
                                                .lineLimit(1)
                                                .foregroundColor(.primary)

                                            if let artistName = track.artistName {
                                                Text(artistName)
                                                    .font(.nunitoSans(size: 14, weight: isCurrentTrack ? .semiBold : .regular))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        // Play Button
                                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(isCurrentTrack ? .primary : .secondary)
                                    }
                                    .padding(.horizontal, isCurrentTrack ? 12 : 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        isCurrentTrack
                                            ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                                            : Color.clear
                                    )
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        playTrack(track)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100) // Space for mini player
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .frame(width: scrollGeometry.size.width, height: scrollGeometry.size.height)
                }
            }

            // Floating Search Button / Bar - Dynamic position based on mini player
            GeometryReader { geometry in
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        if isSearchBarExpanded {
                            // Expanded Search Bar
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)

                                TextField("search \(artist.name) tracks...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.nunitoSans(size: 14))
                                    .autocorrectionDisabled()
                                    .focused($isSearchFieldFocused)
                                    .onChange(of: searchText) { oldValue, newValue in
                                        performDebouncedSearch()
                                    }

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        searchResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }

                                if isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }

                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        isSearchBarExpanded = false
                                        searchText = ""
                                        searchResults = []
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            // Collapsed FAB
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    isSearchBarExpanded = true
                                }
                                // Focus search field immediately
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFieldFocused = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(artist.name)
                                        .font(.nunitoSans(size: 14, weight: .semiBold))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, {
                        // If keyboard is visible, position right above it
                        if keyboardHeight > 0 {
                            return 8
                        }
                        // Otherwise use normal positioning with mini player adjustment
                        return playbackService.currentTrack != nil ? 77 : 16
                    }())
                    .animation(.easeInOut(duration: 0.3), value: playbackService.currentTrack != nil)
                    .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
                }
            }
            .allowsHitTesting(true)
        }
        .navigationTitle("Artist")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTopTracks()
            // Subscribe to keyboard notifications
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }

            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                keyboardHeight = 0
            }
        }
        .onDisappear {
            // Clean up keyboard observers
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
    }

    private func performDebouncedSearch() {
        // Cancel previous search task
        searchTask?.cancel()

        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        // Debounce: wait 300ms before searching
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if !Task.isCancelled {
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        Task {
            isSearching = true

            do {
                // Search for tracks and filter by this artist
                let results = try await SearchService.shared.search(
                    query: "\(artist.name) \(searchText)",
                    type: .tracks,
                    platformType: platformType
                )

                // Filter to only include tracks by this artist
                searchResults = results.tracks.filter { track in
                    track.artistName?.lowercased().contains(artist.name.lowercased()) ?? false
                }
            } catch {
                print("Search error: \(error)")
                searchResults = []
            }

            isSearching = false
        }
    }

    private func loadTopTracks() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                topTracks = try await SearchService.shared.getArtistTopTracks(
                    artistId: artist.id,
                    platformType: platformType
                )
            } catch {
                errorMessage = "Failed to load top tracks: \(error.localizedDescription)"
                print("Error loading top tracks: \(error)")
            }

            isLoading = false
        }
    }

    private func playTrack(_ track: MusicItem) {
        PlaybackService.shared.play(track: track)
    }
}

#Preview {
    NavigationStack {
        ArtistDetailView(
            artist: MusicItem(
                id: "sample-id",
                name: "Sample Artist",
                artistName: nil,
                previewUrl: nil,
                albumArtUrl: nil,
                isrc: nil,
                playedAt: nil,
                spotifyId: "sample-id",
                appleMusicId: nil
            ),
            platformType: .spotify
        )
        .environmentObject(PlaybackService.shared)
    }
}
