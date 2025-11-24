import SwiftUI
import Supabase

struct FullScreenPlayerView: View {
    @ObservedObject var playbackService: PlaybackService
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isTrackSaved: Bool = false
    @State private var showShareSheet = false
    @State private var shareTrack: MusicItem? = nil

    var body: some View {
        ZStack {
            // Background gradient with album art blur
            backgroundLayer

            // Main content
            VStack(spacing: 0) {
                // Top bar with dismiss and menu
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 50) // Account for status bar

                // Album artwork
                albumArtwork
                    .padding(.horizontal, 30)
                    .padding(.top, 30)

                // Track info section
                trackInfoSection
                    .padding(.horizontal, 30)
                    .padding(.top, 30)

                // Progress bar
                progressBar
                    .padding(.horizontal, 30)
                    .padding(.top, 20)

                // Playback controls
                playbackControlsSection
                    .padding(.top, 30)

                Spacer(minLength: 20)

                // Bottom action buttons
                bottomActions
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark) // Force dark mode for player
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
        .onAppear {
            refreshSavedState()
        }
        .onChange(of: playbackService.currentTrack?.id) { _ in
            refreshSavedState()
        }
        .overlay(alignment: .bottom) {
            if showShareSheet, let track = shareTrack {
                QuickSendBar(
                    track: track,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showShareSheet = false
                            shareTrack = nil
                        }
                    },
                    onSendComplete: { _ in
                        showShareSheet = false
                        shareTrack = nil
                    },
                    additionalBottomInset: QuickSendBar.Layout.embeddedInset
                )
                .environmentObject(authState)
                .environmentObject(playbackService)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            // Base color
            Color.black

            // Blurred album art background
            if let artworkUrl = playbackService.currentTrack?.albumArtUrl,
               let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                } placeholder: {
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.3),
                            Color.blue.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.3),
                        Color.blue.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Dismiss button
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            // Now Playing label
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 4) {
                    Image(systemName: platformIconName)
                        .font(.system(size: 10))
                    Text(platformName)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Menu button
            Menu {
                Button {
                    if let track = playbackService.currentTrack {
                        openInNativeApp(track: track)
                    }
                } label: {
                    Label("Open in \(platformName)", systemImage: "arrow.up.right.square")
                }

                Button {
                    if let track = playbackService.currentTrack {
                        shareTrack = track
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showShareSheet = true
                        }
                    }
                } label: {
                    Label("Share with Friends", systemImage: "paperplane")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Album Artwork

    private var albumArtwork: some View {
        Group {
            if let track = playbackService.currentTrack {
                RemoteImage(
                    url: track.albumArtUrl,
                    spotifyId: track.spotifyId,
                    trackName: track.name,
                    width: UIScreen.main.bounds.width - 60,
                    height: UIScreen.main.bounds.width - 60,
                    cornerRadius: 8
                )
                .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Track Info Section

    private var trackInfoSection: some View {
        HStack {
            if let track = playbackService.currentTrack {
                VStack(alignment: .leading, spacing: 6) {
                    // Track name
                    Text(track.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Artist name
                    Text(track.artistName ?? "Unknown Artist")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Like button
                Button {
                    if let track = playbackService.currentTrack {
                        Task {
                            if isTrackSaved {
                                await handleUnsaveFromLibrary(track: track)
                            } else {
                                await handleSaveToLibrary(track: track)
                            }
                        }
                    }
                } label: {
                    Image(systemName: isTrackSaved ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(isTrackSaved ? .pink : .white.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No track playing")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            // Slider
            Slider(
                value: Binding(
                    get: {
                        isDraggingSlider ? sliderValue : currentTimeSafe
                    },
                    set: { newValue in
                        sliderValue = newValue
                    }
                ),
                in: 0...max(durationSafe, 1),
                onEditingChanged: { editing in
                    if editing {
                        sliderValue = currentTimeSafe
                        isDraggingSlider = true
                    } else {
                        seek(to: sliderValue)
                        DispatchQueue.main.async {
                            isDraggingSlider = false
                        }
                    }
                }
            )
            .tint(.white)

            // Time labels
            HStack {
                Text(formatTime(isDraggingSlider ? sliderValue : currentTimeSafe))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Text(formatTime(durationSafe))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControlsSection: some View {
        HStack(spacing: 50) {
            // Previous/Rewind button
            Button {
                seek(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

            // Play/Pause button
            Button {
                if playbackService.isPlaying {
                    playbackService.pause()
                } else {
                    playbackService.resume()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)

                    Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.black)
                        .offset(x: playbackService.isPlaying ? 0 : 3)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            // Next/Forward button
            Button {
                seek(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: 50) {
            // Share button
            Button {
                if let track = playbackService.currentTrack {
                    shareTrack = track
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showShareSheet = true
                    }
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20))
                    Text("Share")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
            }

            // Save to library button
            Button {
                if let track = playbackService.currentTrack {
                    Task {
                        if isTrackSaved {
                            await handleUnsaveFromLibrary(track: track)
                        } else {
                            await handleSaveToLibrary(track: track)
                        }
                    }
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: isTrackSaved ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20))
                    Text(isTrackSaved ? "Saved" : "Library")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(isTrackSaved ? .green : .white.opacity(0.7))
            }

            // Open in app button
            Button {
                if let track = playbackService.currentTrack {
                    openInNativeApp(track: track)
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 20))
                    Text("Open")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Helper Properties

    private var platformName: String {
        switch authState.currentUser?.resolvedPlatformType {
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        case .none:
            return ""
        }
    }

    private var platformIconName: String {
        switch authState.currentUser?.resolvedPlatformType {
        case .spotify:
            return "music.note"
        case .appleMusic:
            return "applelogo"
        case .none:
            return "music.note"
        }
    }

    private var durationSafe: Double {
        let duration = playbackService.duration
        if duration.isNaN || duration.isInfinite || duration < 0 {
            return 0
        }
        return duration
    }

    private var currentTimeSafe: Double {
        let time = playbackService.currentTime
        if time.isNaN || time.isInfinite || time < 0 {
            return 0
        }
        return time
    }

    // MARK: - Helper Methods

    private func refreshSavedState() {
        guard let track = playbackService.currentTrack else {
            isTrackSaved = false
            return
        }

        Task {
            await checkIfTrackSaved(track: track)
        }
    }

    private func seek(by seconds: Double) {
        let base = isDraggingSlider ? sliderValue : currentTimeSafe
        let target = base + seconds
        seek(to: target)

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func seek(to time: Double) {
        guard durationSafe > 0 else {
            playbackService.seek(to: 0)
            return
        }

        let clamped = min(max(time, 0), durationSafe)
        playbackService.seek(to: clamped)
        sliderValue = clamped
    }

    private func formatTime(_ timeInSeconds: Double) -> String {
        guard !timeInSeconds.isNaN && !timeInSeconds.isInfinite else { return "0:00" }
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func openInNativeApp(track: MusicItem) {
        guard let platformType = authState.currentUser?.resolvedPlatformType else { return }
        DeepLinkService.shared.openInNativeApp(track: track, platform: platformType)
    }

    @MainActor
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }

    // MARK: - Track Save State

    private func checkIfTrackSaved(track: MusicItem) async {
        guard let currentUser = authState.currentUser else { return }
        guard let platformType = currentUser.resolvedPlatformType else { return }

        do {
            let token = try await getAccessToken(for: currentUser)
            var isSaved = false

            switch platformType {
            case .spotify:
                guard let spotifyId = track.spotifyId ?? track.id as String? else { return }
                isSaved = try await SpotifyService.shared.isTrackSaved(trackId: spotifyId, accessToken: token)
            case .appleMusic:
                // For Apple Music, check if we have a self-share that's saved
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
        } catch {
            print("Failed to check saved status: \(error)")
        }
    }

    private func handleSaveToLibrary(track: MusicItem) async {
        guard let currentUser = authState.currentUser else { return }
        guard let platformType = currentUser.resolvedPlatformType else { return }

        do {
            let token = try await getAccessToken(for: currentUser)

            switch platformType {
            case .spotify:
                guard let spotifyId = track.spotifyId ?? track.id as String? else { return }
                try await SpotifyService.shared.saveTrackToLibrary(trackId: spotifyId, accessToken: token)
            case .appleMusic:
                guard let appleMusicId = track.appleMusicId ?? track.id as String? else { return }
                try await AppleMusicService.shared.saveTrackToLibrary(trackId: appleMusicId)
            }

            // Track the save
            try await ShareService.shared.trackLibrarySave(trackId: track.id, userId: currentUser.id, platformType: platformType)

            // Create self-share for tracking
            _ = try await ShareService.shared.createShare(
                track: track,
                recipients: [currentUser.id],
                message: nil,
                senderId: currentUser.id
            )

            await MainActor.run {
                isTrackSaved = true
                showToastMessage("Added to your library!")
            }
        } catch {
            print("Failed to save track: \(error)")
            await MainActor.run {
                showToastMessage("Failed to add to library")
            }
        }
    }

    private func handleUnsaveFromLibrary(track: MusicItem) async {
        guard let currentUser = authState.currentUser else { return }
        guard let platformType = currentUser.resolvedPlatformType else { return }

        do {
            let token = try await getAccessToken(for: currentUser)

            switch platformType {
            case .spotify:
                guard let spotifyId = track.spotifyId ?? track.id as String? else { return }
                try await SpotifyService.shared.removeTrackFromLibrary(trackId: spotifyId, accessToken: token)
            case .appleMusic:
                // Apple Music doesn't support removing via API
                await MainActor.run {
                    showToastMessage("Open Apple Music to remove")
                }
                return
            }

            // Remove self-share if exists
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

            await MainActor.run {
                isTrackSaved = false
                showToastMessage("Removed from library")
            }
        } catch {
            print("Failed to remove track: \(error)")
            await MainActor.run {
                showToastMessage("Failed to remove")
            }
        }
    }

    private func getAccessToken(for user: User) async throws -> String {
        guard let platformType = user.resolvedPlatformType else {
            throw NSError(domain: "FullScreenPlayerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No platform type"])
        }

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
}