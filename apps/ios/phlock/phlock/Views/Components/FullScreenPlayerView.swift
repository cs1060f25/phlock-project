import SwiftUI
import Supabase

struct FullScreenPlayerView: View {
    @ObservedObject var playbackService: PlaybackService
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthenticationState
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var selectedFriends: Set<UUID> = []
    @State private var shareMessage: String = ""
    @State private var isSending: Bool = false
    @FocusState private var isMessageFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if let track = playbackService.currentTrack {
                    VStack(spacing: 0) {
                        // Track info header
                        HStack(spacing: 12) {
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
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            // Track Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.name)
                                    .font(.nunitoSans(size: 16, weight: .bold))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                if let artist = track.artistName {
                                    Text(artist)
                                        .font(.nunitoSans(size: 14))
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                        // SECTION 1: Friend Selector Grid (independently scrollable at top)
                        VStack(spacing: 0) {
                            friendSelectorSection(track: track)
                        }
                        .background(Color(UIColor.systemBackground))

                        // Subtle separator
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 16)

                        // SECTION 2: Send UI (in the middle)
                        sendUISection

                        // Subtle separator
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 16)

                        Spacer()
                            .dismissKeyboardOnTouch()

                        // SECTION 3: Player controls (at bottom)
                        VStack(spacing: 20) {
                            // Progress Slider
                            VStack(spacing: 8) {
                                Slider(
                                    value: Binding(
                                        get: {
                                            isDraggingSlider ? sliderValue : playbackService.currentTime
                                        },
                                        set: { newValue in
                                            sliderValue = newValue
                                        }
                                    ),
                                    in: 0...max(playbackService.duration, 1),
                                    onEditingChanged: { editing in
                                        if editing {
                                            // Start dragging - capture current time
                                            sliderValue = playbackService.currentTime
                                            isDraggingSlider = true
                                        } else {
                                            // Finished dragging - seek to final position, then update flag after a brief delay
                                            playbackService.seek(to: sliderValue)
                                            // Keep isDraggingSlider true briefly to prevent visual jump
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isDraggingSlider = false
                                            }
                                        }
                                    }
                                )
                                .tint(.black)
                                .frame(height: 44) // Increase tap target
                                .contentShape(Rectangle()) // Make entire area tappable

                                // Time Labels
                                HStack {
                                    Text(formatTime(isDraggingSlider ? sliderValue : playbackService.currentTime))
                                        .font(.nunitoSans(size: 13))
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(formatTime(playbackService.duration))
                                        .font(.nunitoSans(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 32)

                            // Playback Controls
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    // Play on Platform Button (left side)
                                    Button {
                                        openInNativeApp(track: track)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Play on")
                                                .font(.nunitoSans(size: 12, weight: .semiBold))
                                            Text(platformName)
                                                .font(.nunitoSans(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(.primary)
                                    }
                                    .frame(width: geometry.size.width / 3, alignment: .leading)

                                    // Play/Pause Button (center)
                                    Button {
                                        if playbackService.isPlaying {
                                            playbackService.pause()
                                        } else {
                                            playbackService.resume()
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 70, height: 70)

                                            Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: geometry.size.width / 3, alignment: .center)

                                    // Spacer for balance (right side)
                                    Spacer()
                                        .frame(width: geometry.size.width / 3)
                                }
                            }
                            .frame(height: 70)
                            .padding(.horizontal, 32)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                        .background(Color(UIColor.systemBackground))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        playbackService.stopPlayback()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
            .task {
                if let track = playbackService.currentTrack {
                    await loadAndRankFriends(for: track)
                    await checkIfTrackSaved(track: track)
                }
            }
        }
    }

    // MARK: - Friend Selector Section

    @ViewBuilder
    private func friendSelectorSection(track: MusicItem) -> some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Search friends", text: $searchText)
                    .font(.nunitoSans(size: 14))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Friends grid (3 per row, vertically scrollable with fixed height)
            if isLoadingFriends {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(height: 200)
            } else if filteredFriends.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No friends yet" : "No friends found")
                        .font(.nunitoSans(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(filteredFriends, id: \.id) { friend in
                            FriendSelectorItem(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id)
                            ) {
                                toggleFriendSelection(friend)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .frame(height: 240)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    // MARK: - Send UI Section

    private var sendUISection: some View {
        VStack(spacing: 0) {
            // Message input field
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 15))
                    .foregroundColor(isMessageFieldFocused
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)))

                TextField("Write a message...", text: $shareMessage)
                    .font(.nunitoSans(size: 14, weight: .regular))
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .focused($isMessageFieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !isSending && !selectedFriends.isEmpty {
                            Task {
                                await sendToSelectedFriends()
                            }
                        }
                    }

                if !shareMessage.isEmpty {
                    Button {
                        shareMessage = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // Send button
            Button {
                Task {
                    if !isSending {
                        await sendToSelectedFriends()
                    }
                }
            } label: {
                HStack {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Text(selectedFriends.count > 1 ? "Send separately" : "Send")
                            .font(.nunitoSans(size: 16, weight: .semiBold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedFriends.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(PressedButtonStyle())
            .disabled(isSending || selectedFriends.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Friend Management State

    @State private var allFriends: [User] = []
    @State private var rankedFriends: [User] = []
    @State private var isLoadingFriends = true
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isTrackSaved: Bool = false

    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return rankedFriends
        } else {
            return allFriends.filter { friend in
                friend.displayName.lowercased().contains(searchText.lowercased())
            }
        }
    }

    // MARK: - Actions

    private var platformName: String {
        switch authState.currentUser?.platformType {
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        case .none:
            return "Streaming Service"
        }
    }

    private func toggleFriendSelection(_ friend: User) {
        // Haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedFriends.contains(friend.id) {
                selectedFriends.remove(friend.id)
            } else {
                selectedFriends.insert(friend.id)
            }
        }
    }

    private func loadAndRankFriends(for track: MusicItem) async {
        guard let currentUser = authState.currentUser else {
            await MainActor.run {
                isLoadingFriends = false
            }
            return
        }

        do {
            // Load all friends
            let friends = try await UserService.shared.getFriends(for: currentUser.id)

            await MainActor.run {
                allFriends = friends
            }

            // Rank friends using FriendRankingEngine
            let rankedFriendIds = await FriendRankingEngine.rankFriends(
                friends: friends,
                currentUser: currentUser,
                track: track,
                limit: friends.count // Get all ranked
            )

            // Reorder friends based on ranking
            let ranked = rankedFriendIds.compactMap { friendId in
                friends.first { $0.id == friendId }
            }

            await MainActor.run {
                rankedFriends = ranked
                isLoadingFriends = false
            }
        } catch {
            print("❌ Failed to load friends: \(error)")
            await MainActor.run {
                isLoadingFriends = false
            }
        }
    }

    private func checkIfTrackSaved(track: MusicItem) async {
        guard let currentUser = authState.currentUser else {
            print("❌ No current user")
            return
        }

        guard let platformType = currentUser.platformType else {
            print("❌ No platform type")
            return
        }

        do {
            // Get user's access token
            let token = try await getAccessToken(for: currentUser)

            var isSaved = false

            switch platformType {
            case .spotify:
                // Check if track is saved in Spotify library
                guard let spotifyId = track.spotifyId ?? track.id as String? else {
                    return
                }
                isSaved = try await SpotifyService.shared.isTrackSaved(
                    trackId: spotifyId,
                    accessToken: token
                )

            case .appleMusic:
                // Apple Music doesn't provide easy API to check saved status
                // For now, check if there's a saved share to self in database
                let shares: [Share] = try await PhlockSupabaseClient.shared.client
                    .from("shares")
                    .select("*")
                    .eq("sender_id", value: currentUser.id.uuidString)
                    .eq("recipient_id", value: currentUser.id.uuidString)
                    .eq("track_id", value: track.id)
                    .neq("saved_at", value: "null")
                    .execute()
                    .value

                isSaved = !shares.isEmpty
            }

            await MainActor.run {
                isTrackSaved = isSaved
            }

            print("✅ Track saved status: \(isSaved)")
        } catch {
            print("❌ Failed to check saved status: \(error)")
        }
    }

    private func handleSaveToLibrary(track: MusicItem) async {
        guard let currentUser = authState.currentUser else {
            print("❌ No current user")
            return
        }

        guard let platformType = currentUser.platformType else {
            print("❌ No platform type")
            return
        }

        do {
            // Get user's access token
            let token = try await getAccessToken(for: currentUser)

            switch platformType {
            case .spotify:
                // Save to Spotify library
                guard let spotifyId = track.spotifyId ?? track.id as String? else {
                    showToastMessage("Could not save to Spotify")
                    return
                }
                try await SpotifyService.shared.saveTrackToLibrary(
                    trackId: spotifyId,
                    accessToken: token
                )

            case .appleMusic:
                // Save to Apple Music library
                guard let appleMusicId = track.appleMusicId ?? track.id as String? else {
                    showToastMessage("Could not save to Apple Music")
                    return
                }
                try await AppleMusicService.shared.saveTrackToLibrary(trackId: appleMusicId)
            }

            // Track the library save
            try await ShareService.shared.trackLibrarySave(
                trackId: track.id,
                userId: currentUser.id,
                platformType: platformType
            )

            // Create a "saved" share to self for the shares tab
            _ = try await ShareService.shared.createShare(
                track: track,
                recipients: [currentUser.id], // Send to self
                message: nil,
                senderId: currentUser.id
            )

            // Update saved state
            await MainActor.run {
                isTrackSaved = true
            }

            // Show success feedback
            showToastMessage("Saved to your library!")

            print("✅ Track saved to library successfully")
        } catch {
            print("❌ Failed to save track: \(error)")
            showToastMessage("Failed to save track")
        }
    }

    private func handleUnsaveFromLibrary(track: MusicItem) async {
        guard let currentUser = authState.currentUser else {
            print("❌ No current user")
            return
        }

        guard let platformType = currentUser.platformType else {
            print("❌ No platform type")
            return
        }

        do {
            // Get user's access token
            let token = try await getAccessToken(for: currentUser)

            switch platformType {
            case .spotify:
                // Remove from Spotify library
                guard let spotifyId = track.spotifyId ?? track.id as String? else {
                    showToastMessage("Could not remove from Spotify")
                    return
                }
                try await SpotifyService.shared.removeTrackFromLibrary(
                    trackId: spotifyId,
                    accessToken: token
                )

            case .appleMusic:
                // Apple Music doesn't provide easy API to remove tracks
                // The save functionality opens the Music app, so unsave is manual
                showToastMessage("Open Apple Music to remove track")
                return
            }

            // Delete the saved share from database
            let shares: [Share] = try await PhlockSupabaseClient.shared.client
                .from("shares")
                .select("*")
                .eq("sender_id", value: currentUser.id.uuidString)
                .eq("recipient_id", value: currentUser.id.uuidString)
                .eq("track_id", value: track.id)
                .execute()
                .value

            if let savedShare = shares.first {
                try await PhlockSupabaseClient.shared.client
                    .from("shares")
                    .delete()
                    .eq("id", value: savedShare.id.uuidString)
                    .execute()
            }

            // Update saved state
            await MainActor.run {
                isTrackSaved = false
            }

            // Show success feedback
            showToastMessage("Removed from your library")

            print("✅ Track removed from library successfully")
        } catch {
            print("❌ Failed to remove track: \(error)")
            showToastMessage("Failed to remove track")
        }
    }

    private func getAccessToken(for user: User) async throws -> String {
        guard let platformType = user.platformType else {
            throw NSError(domain: "FullScreenPlayerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No platform type"])
        }

        // Fetch the platform token from database
        let tokens: [PlatformToken] = try await PhlockSupabaseClient.shared.client
            .from("platform_tokens")
            .select("*")
            .eq("user_id", value: user.id.uuidString)
            .eq("platform_type", value: platformType.rawValue as String)
            .limit(1)
            .execute()
            .value

        guard let token = tokens.first else {
            throw NSError(domain: "FullScreenPlayerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No platform token found"])
        }

        return token.accessToken
    }

    private func sendToSelectedFriends() async {
        guard let currentUser = authState.currentUser else { return }
        guard let track = playbackService.currentTrack else { return }

        // Dismiss keyboard
        await MainActor.run {
            isMessageFieldFocused = false
        }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        await MainActor.run {
            isSending = true
        }

        do {
            _ = try await ShareService.shared.createShare(
                track: track,
                recipients: Array(selectedFriends),
                message: shareMessage.isEmpty ? nil : shareMessage,
                senderId: currentUser.id
            )

            await MainActor.run {
                isSending = false

                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)

                // Show success feedback
                toastMessage = selectedFriends.count == 1
                    ? "Sent to 1 friend"
                    : "Sent to \(selectedFriends.count) friends"
                showToast = true

                // Clear selection and message
                selectedFriends.removeAll()
                shareMessage = ""
            }
        } catch {
            print("❌ Failed to send shares: \(error)")
            await MainActor.run {
                isSending = false

                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)

                toastMessage = "Failed to send"
                showToast = true
            }
        }
    }

    @MainActor
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }

    private func openInNativeApp(track: MusicItem) {
        guard let platformType = authState.currentUser?.platformType else {
            print("❌ No platform type found")
            return
        }

        print("🔗 Opening track in native app - Platform: \(platformType)")
        print("   Track: \(track.name) by \(track.artistName ?? "Unknown")")

        Task {
            do {
                switch platformType {
                case .spotify:
                    try await openInSpotify(track: track)
                case .appleMusic:
                    try await openInAppleMusic(track: track)
                }
            } catch {
                print("   ❌ Failed to open track: \(error)")
            }
        }
    }

    private func openInSpotify(track: MusicItem) async throws {
        print("🎵 Opening track in Spotify: '\(track.name)' by \(track.artistName ?? "Unknown")")
        print("   Track ID: \(track.id)")
        print("   Spotify ID: \(track.spotifyId ?? "nil")")

        // ALWAYS validate track ID to ensure we open the correct track
        let spotifyId: String

        // Validate the track ID using the validate-track edge function
        print("   🔍 Validating track ID with Spotify API...")
        print("   ISRC: \(track.isrc ?? "none")")
        let validatedTrack = try await validateTrack(
            name: track.name,
            artist: track.artistName ?? "Unknown",
            existingId: track.spotifyId,
            isrc: track.isrc
        )

        if let validated = validatedTrack {
            spotifyId = validated
            print("   ✅ Using validated Spotify ID: \(spotifyId)")
        } else {
            // Fallback: Search for the track
            print("   🔍 Validation failed, searching: \(track.name) - \(track.artistName ?? "")")

            let results = try await SearchService.shared.search(
                query: "\(track.name) \(track.artistName ?? "")",
                type: .tracks,
                platformType: .spotify
            )

            guard !results.tracks.isEmpty else {
                print("   ❌ No results found on Spotify")
                return
            }

            // Smart matching: find best match by comparing track name and artist
            guard let foundTrack = findBestMatch(
                searchResults: results.tracks,
                targetTrackName: track.name,
                targetArtistName: track.artistName
            ) else {
                print("   ❌ Could not find matching track on Spotify")
                print("   📊 Search returned \(results.tracks.count) results but none matched")
                return
            }

            spotifyId = foundTrack.spotifyId ?? foundTrack.id
            print("   ✅ Found match: \(foundTrack.name) (ID: \(spotifyId))")
        }

        let spotifyURL = URL(string: "spotify:track:\(spotifyId)")
        let webURL = URL(string: "https://open.spotify.com/track/\(spotifyId)")

        await MainActor.run {
            if let spotifyURL = spotifyURL, UIApplication.shared.canOpenURL(spotifyURL) {
                print("   ✅ Opening in Spotify app")
                UIApplication.shared.open(spotifyURL)
            } else if let webURL = webURL {
                print("   ✅ Opening in Spotify web player")
                UIApplication.shared.open(webURL)
            }
        }
    }

    /// Validate track ID using the validate-track edge function
    private func validateTrack(name: String, artist: String, existingId: String?, isrc: String?) async throws -> String? {
        struct ValidationRequest: Encodable {
            let trackId: String?
            let trackName: String
            let artistName: String
            let isrc: String?  // For exact version matching
        }

        struct ValidationResponse: Decodable {
            let success: Bool
            let method: String?
            let track: ValidatedTrack?

            struct ValidatedTrack: Decodable {
                let id: String
                let name: String
                let artistName: String
            }
        }

        do {
            let request = ValidationRequest(
                trackId: existingId,
                trackName: name,
                artistName: artist,
                isrc: isrc
            )

            let response: ValidationResponse = try await PhlockSupabaseClient.shared.client.functions.invoke(
                "validate-track",
                options: FunctionInvokeOptions(body: request)
            )

            if response.success, let track = response.track {
                print("   ✅ Track validated via \(response.method ?? "unknown"): \(track.id)")
                return track.id
            }

            return nil
        } catch {
            print("   ⚠️ Track validation failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func openInAppleMusic(track: MusicItem) async throws {
        // Search for the track to get the correct Apple Music ID
        print("   🔍 Searching Apple Music for: \(track.name) - \(track.artistName ?? "")")

        guard let artistName = track.artistName else {
            print("   ❌ No artist name available")
            return
        }

        guard let foundTrack = try await AppleMusicService.shared.searchTrack(
            name: track.name,
            artist: artistName,
            isrc: track.isrc
        ) else {
            print("   ❌ Could not find track on Apple Music")
            return
        }

        let appleMusicId = foundTrack.id
        let appleMusicURL = URL(string: "music://music.apple.com/song/\(appleMusicId)")
        let webURL = URL(string: "https://music.apple.com/song/\(appleMusicId)")

        print("   ✅ Found on Apple Music: \(foundTrack.title) (ID: \(appleMusicId))")

        await MainActor.run {
            if let appleMusicURL = appleMusicURL, UIApplication.shared.canOpenURL(appleMusicURL) {
                print("   ✅ Opening in Apple Music app")
                UIApplication.shared.open(appleMusicURL)
            } else if let webURL = webURL {
                print("   ✅ Opening in Apple Music web player")
                UIApplication.shared.open(webURL)
            }
        }
    }

    private func findBestMatch(
        searchResults: [MusicItem],
        targetTrackName: String,
        targetArtistName: String?
    ) -> MusicItem? {
        let normalizedTargetTrack = targetTrackName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTargetArtist = targetArtistName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        print("   🎯 Matching against: '\(normalizedTargetTrack)' by '\(normalizedTargetArtist ?? "Unknown")'")

        // Score each result
        var scoredResults: [(track: MusicItem, score: Int)] = []

        for result in searchResults {
            let normalizedResultTrack = result.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedResultArtist = result.artistName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            var score = 0

            // Track name matching (most important)
            if normalizedResultTrack == normalizedTargetTrack {
                score += 100 // Exact match
            } else if normalizedResultTrack.contains(normalizedTargetTrack) || normalizedTargetTrack.contains(normalizedResultTrack) {
                score += 50 // Partial match (handles "feat.", remixes, etc.)
            } else {
                continue // Skip if track name doesn't match at all
            }

            // Artist name matching
            if let targetArtist = normalizedTargetArtist, let resultArtist = normalizedResultArtist {
                if resultArtist == targetArtist {
                    score += 100 // Exact artist match
                } else if resultArtist.contains(targetArtist) || targetArtist.contains(resultArtist) {
                    score += 50 // Partial artist match (handles "feat.", "& The Band", etc.)
                } else {
                    score += 10 // Artist doesn't match but track does (could be cover)
                }
            } else {
                score += 20 // No artist to compare
            }

            // Popularity bonus (prefer more popular versions)
            if let popularity = result.popularity {
                score += popularity / 10 // Up to 10 points for popularity
            }

            scoredResults.append((track: result, score: score))
            print("      - '\(result.name)' by '\(result.artistName ?? "Unknown")': score \(score)")
        }

        // Sort by score descending and return best match
        let bestMatch = scoredResults.sorted { $0.score > $1.score }.first

        if let best = bestMatch {
            print("   🏆 Best match: '\(best.track.name)' by '\(best.track.artistName ?? "Unknown")' (score: \(best.score))")
        }

        return bestMatch?.track
    }

    private func formatTime(_ timeInSeconds: Double) -> String {
        guard !timeInSeconds.isNaN && !timeInSeconds.isInfinite else {
            return "0:00"
        }

        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    FullScreenPlayerView(
        playbackService: PlaybackService.shared,
        isPresented: .constant(true)
    )
}
