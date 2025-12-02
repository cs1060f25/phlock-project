import SwiftUI

struct ArtistDetailView: View {
    let artist: MusicItem
    let platformType: PlatformType

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
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

    // Daily song selection state
    @State private var todaysDailySong: Share?
    @State private var selectedDailyTrackId: String?
    @State private var pendingDailySong: MusicItem?
    @State private var dailySongNote = ""
    @State private var isSubmittingDailySong = false
    @State private var showDailySongToast = false
    @State private var dailySongToastMessage = ""
    @FocusState private var isNoteFieldFocused: Bool

    // Store observer tokens to properly remove them later
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?

    var displayedTracks: [MusicItem] {
        searchText.isEmpty ? topTracks : searchResults
    }

    private func isCommittedAsDaily(_ track: MusicItem) -> Bool {
        todaysDailySong?.trackId == track.id
    }

    private func isPendingSelection(_ track: MusicItem) -> Bool {
        selectedDailyTrackId == track.id && !isCommittedAsDaily(track)
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
                                            .font(.lora(size: 60, weight: .bold))
                                            .foregroundColor(.gray)
                                    )
                            }

                            // Artist Name
                            Text(artist.name)
                                .font(.lora(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Tracks Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(searchText.isEmpty ? "Top Tracks" : "Search Results")
                                .font(.lora(size: 20, weight: .semiBold))
                                .padding(.horizontal)

                            if displayedTracks.isEmpty {
                                Text(searchText.isEmpty ? "No tracks available" : "No tracks found")
                                    .font(.lora(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(Array(displayedTracks.enumerated()), id: \.element.id) { index, track in
                                    let isCurrentTrack = playbackService.currentTrack?.id == track.id
                                    let isPlaying = isCurrentTrack && playbackService.isPlaying

                                    VStack(spacing: 0) {
                                        HStack(spacing: 12) {
                                        // Playing indicator bar
                                        if isCurrentTrack {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.primary)
                                                .frame(width: 4, height: 40)
                                        }

                                        // Track Number
                                        Text("\(index + 1)")
                                            .font(.lora(size: 10))
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
                                        Text(track.name)
                                            .font(.lora(size: 16))
                                            .lineLimit(1)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        // Daily Song Selection Button
                                        Button {
                                            selectDailySong(track)
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill((isCommittedAsDaily(track) || isPendingSelection(track)) ? Color.accentColor : Color.white.opacity(0.65))
                                                    .overlay(
                                                        Circle()
                                                            .stroke((isCommittedAsDaily(track) || isPendingSelection(track)) ? Color.accentColor : Color.secondary, lineWidth: 2)
                                                    )
                                                    .frame(width: 24, height: 24)
                                                if isCommittedAsDaily(track) || isPendingSelection(track) {
                                                    Image(systemName: "checkmark")
                                                        .font(.lora(size: 10))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.borderless)

                                        // Play Button
                                        Button {
                                            if isPlaying {
                                                playbackService.pause()
                                            } else {
                                                playbackService.play(track: track)
                                            }
                                        } label: {
                                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                .font(.lora(size: 20, weight: .bold))
                                                .foregroundColor(isCurrentTrack ? .primary : .secondary)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.horizontal, isCurrentTrack ? 12 : 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        isCurrentTrack
                                            ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                                            : Color.clear
                                    )
                                    .cornerRadius(8)

                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100) // Space for mini player
                    }
                    .scrollDismissesKeyboard(.interactively)
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
                                    .font(.lora(size: 10))
                                    .foregroundColor(.gray)

                                TextField("search \(artist.name) tracks...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.lora(size: 10))
                                    .autocorrectionDisabled()
                                    .focused($isSearchFieldFocused)
                                    .onChange(of: searchText) { newValue in
                                        performDebouncedSearch()
                                    }

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        searchResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.lora(size: 10))
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
                                        .font(.lora(size: 10))
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
                                        .font(.lora(size: 10))
                                    Text(artist.name)
                                        .font(.lora(size: 10))
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

            // Pending Selection Bar
            if let pendingTrack = pendingDailySong {
                VStack {
                    Spacer()
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
                }
                .zIndex(100)
            }
        }
        .toast(isPresented: $showDailySongToast, message: dailySongToastMessage, type: .success, duration: 3.0)
        .navigationTitle("Artist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.lora(size: 20, weight: .semiBold))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenSwipeBack()
        .onAppear {
            loadTopTracks()
            loadTodaysDailySong()
            // Subscribe to keyboard notifications and store observers for proper cleanup
            keyboardShowObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }

            keyboardHideObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                keyboardHeight = 0
            }
        }
        .onDisappear {
            // Properly clean up keyboard observers using tokens
            if let showObserver = keyboardShowObserver {
                NotificationCenter.default.removeObserver(showObserver)
                keyboardShowObserver = nil
            }
            if let hideObserver = keyboardHideObserver {
                NotificationCenter.default.removeObserver(hideObserver)
                keyboardHideObserver = nil
            }
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
                    artistName: artist.name,
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

    private func loadTodaysDailySong() {
        guard let userId = authState.currentUser?.id else { return }

        Task {
            do {
                todaysDailySong = try await ShareService.shared.getTodaysDailySong(for: userId)
                selectedDailyTrackId = todaysDailySong?.trackId
            } catch {
                print("Failed to load daily song: \(error)")
            }
        }
    }

    private func selectDailySong(_ track: MusicItem) {
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
                dailySongNote = ""
            }
        }
    }

    private func submitDailySong(track: MusicItem, note: String) {
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

                dailySongToastMessage = "🔥 \(track.name) is your song today!"
                showDailySongToast = true

                await MainActor.run {
                    selectedDailyTrackId = share.trackId
                    pendingDailySong = nil
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
