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
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing: Bool = false

    // Spotify-like animation constants
    private let screenHeight = UIScreen.main.bounds.height
    private let dismissThreshold: CGFloat = 120
    private let velocityThreshold: CGFloat = 800

    // Computed properties for Spotify-like effects
    private var dragProgress: CGFloat {
        min(max(dragOffset / screenHeight, 0), 1)
    }

    private var scaleEffect: CGFloat {
        1 - (dragProgress * 0.1) // Scale down to 0.9 at max drag
    }

    private var cornerRadiusEffect: CGFloat {
        dragProgress * 40 // Round corners as you drag
    }

    private var opacityEffect: CGFloat {
        1 - (dragProgress * 0.3) // Slightly fade as you drag
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background that shows through during drag
                Color.black.opacity(0.5 * (1 - dragProgress))
                    .ignoresSafeArea()

                // Main player card
                ZStack {
                    // Background gradient with album art blur
                    backgroundLayer

                    // Main content
                    VStack(spacing: 0) {
                        // Drag indicator pill (like Spotify)
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)

                        // Top bar with dismiss and menu
                        headerBar
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        // Album artwork
                        albumArtwork
                            .padding(.horizontal, 30)
                            .padding(.top, 24)

                        // Track info section
                        trackInfoSection
                            .padding(.horizontal, 30)
                            .padding(.top, 24)

                        // Progress bar
                        progressBar
                            .padding(.horizontal, 30)
                            .padding(.top, 20)

                        // Playback controls
                        playbackControlsSection
                            .padding(.top, 24)

                        Spacer(minLength: 16)

                        // Bottom action buttons
                        bottomActions
                            .padding(.horizontal, 30)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadiusEffect, style: .continuous))
                .scaleEffect(scaleEffect)
                .offset(y: dragOffset)
                .opacity(opacityEffect)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            guard !isDismissing else { return }
                            // Only allow dragging down
                            if gesture.translation.height > 0 {
                                // Add slight resistance as you drag further
                                let resistance: CGFloat = 0.7
                                dragOffset = gesture.translation.height * resistance
                            }
                        }
                        .onEnded { gesture in
                            guard !isDismissing else { return }

                            let velocity = gesture.predictedEndLocation.y - gesture.location.y
                            let translation = gesture.translation.height

                            // Dismiss if dragged past threshold OR flicked with high velocity
                            let shouldDismiss = translation > dismissThreshold || velocity > velocityThreshold

                            if shouldDismiss {
                                dismissPlayer()
                            } else {
                                // Spring back
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
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

    private func dismissPlayer() {
        isDismissing = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            dragOffset = screenHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
            // Reset state for next presentation
            dragOffset = 0
            isDismissing = false
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
                dismissPlayer()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.lora(size: 20, weight: .semiBold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            // Now Playing label
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.lora(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 4) {
                    Image(systemName: platformIconName)
                        .font(.lora(size: 10))
                    Text(platformName)
                        .font(.lora(size: 11, weight: .semiBold))
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
                    .font(.lora(size: 20, weight: .semiBold))
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
        VStack(alignment: .leading, spacing: 6) {
            if let track = playbackService.currentTrack {
                // Track name
                Text(track.name)
                    .font(.lora(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Artist name
                Text(track.artistName ?? "Unknown Artist")
                    .font(.lora(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                Text("No track playing")
                    .font(.lora(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.lora(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Text(formatTime(durationSafe))
                    .font(.lora(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControlsSection: some View {
        HStack(spacing: 50) {
            // Previous track button
            Button {
                playbackService.skipBackward()
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.lora(size: 28))
                    .foregroundColor(canSkipBackward ? .white : .white.opacity(0.3))
            }
            .disabled(!canSkipBackward)

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
                        .font(.lora(size: 30, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: playbackService.isPlaying ? 0 : 1.5)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            // Next track button
            Button {
                playbackService.skipForward()
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.lora(size: 28))
                    .foregroundColor(canSkipForward ? .white : .white.opacity(0.3))
            }
            .disabled(!canSkipForward)
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
                        .font(.lora(size: 20))
                    Text("Share")
                        .font(.lora(size: 10, weight: .medium))
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
                        .font(.lora(size: 20))
                    Text(isTrackSaved ? "Saved" : "Library")
                        .font(.lora(size: 10, weight: .medium))
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
                        .font(.lora(size: 20))
                    Text("Open")
                        .font(.lora(size: 10, weight: .medium))
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

    private var canSkipBackward: Bool {
        playbackService.canGoToPreviousTrack
    }

    private var canSkipForward: Bool {
        playbackService.canGoToNextTrack
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

    private func sanitizeSpotifyId(_ rawId: String) -> String {
        if rawId.contains("/") || rawId.contains(":") {
            if let last = rawId.split(whereSeparator: { $0 == "/" || $0 == ":" }).last {
                return String(last)
            }
        }
        return rawId
    }

    private func trackCacheKey(for track: MusicItem, platform: PlatformType) -> String {
        switch platform {
        case .spotify:
            return sanitizeSpotifyId(track.spotifyId ?? track.id)
        case .appleMusic:
            return track.appleMusicId ?? track.id
        }
    }

    private func resolveAppleMusicTrackId(for track: MusicItem) async throws -> String {
        if let appleMusicId = track.appleMusicId, !appleMusicId.isEmpty {
            return appleMusicId
        }

        if !track.id.isEmpty,
           CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: track.id)) {
            return track.id
        }

        if let url = URL(string: track.id),
           let lastComponent = url.pathComponents.last,
           CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: lastComponent)) {
            return lastComponent
        }

        if let isrc = track.isrc,
           let match = try? await AppleMusicService.shared.searchTrack(
               name: track.name,
               artist: track.artistName ?? "",
               isrc: isrc
           ) {
            return match.id
        }

        if let match = try? await AppleMusicService.shared.searchTrack(
            name: track.name,
            artist: track.artistName ?? "",
            isrc: nil
        ) {
            return match.id
        }

        throw AppleMusicError.apiError("Could not find Apple Music ID for \(track.name)")
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

        let cacheKey = trackCacheKey(for: track, platform: platformType)
        let cachedSaved = SavedTrackCache.shared.contains(trackId: cacheKey, userId: currentUser.id)

        await MainActor.run {
            isTrackSaved = cachedSaved
        }

        do {
            var isSaved = false

            switch platformType {
            case .spotify:
                let spotifyId = sanitizeSpotifyId(track.spotifyId ?? track.id)
                let token = try await getAccessToken(for: currentUser)
                isSaved = try await SpotifyService.shared.isTrackSaved(trackId: spotifyId, accessToken: token)

            case .appleMusic:
                // For Apple Music, check if we have a self-share that's saved
                // This is a workaround since Apple Music doesn't provide API to check library status
                let shares: [Share] = try await PhlockSupabaseClient.shared.client
                    .from("shares")
                    .select("*")
                    .eq("sender_id", value: currentUser.id.uuidString)
                    .eq("recipient_id", value: currentUser.id.uuidString)
                    .eq("track_id", value: track.id)
                    .neq("saved_at", value: "null")
                    .execute()
                    .value
                isSaved = cachedSaved || !shares.isEmpty
            }

            await MainActor.run {
                isTrackSaved = isSaved
            }

            SavedTrackCache.shared.set(trackId: cacheKey, userId: currentUser.id, isSaved: isSaved)
        } catch {
            print("❌ Failed to check saved status: \(error)")
            // Default to false if we can't check
            await MainActor.run {
                isTrackSaved = cachedSaved
            }
        }
    }

    private func handleSaveToLibrary(track: MusicItem) async {
        guard let currentUser = authState.currentUser else {
            await MainActor.run {
                showToastMessage("Please sign in to save tracks")
            }
            return
        }
        guard let platformType = currentUser.resolvedPlatformType else {
            await MainActor.run {
                showToastMessage("Platform type not found")
            }
            return
        }

        do {
            switch platformType {
            case .spotify:
                // Get the Spotify ID - it might be stored as the main ID or in spotifyId field
                let spotifyId = sanitizeSpotifyId(track.spotifyId ?? track.id)
                print("🎵 Attempting to save Spotify track with ID: \(spotifyId)")

                let token = try await getAccessToken(for: currentUser)
                try await SpotifyService.shared.saveTrackToLibrary(trackId: spotifyId, accessToken: token)

            case .appleMusic:
                // For Apple Music, we need the Apple Music ID
                let appleMusicId = try await resolveAppleMusicTrackId(for: track)
                print("🎵 Attempting to save Apple Music track with ID: \(appleMusicId)")

                try await AppleMusicService.shared.saveTrackToLibrary(trackId: appleMusicId)
            }

            // Track the save in our database
            try await ShareService.shared.trackLibrarySave(trackId: track.id, userId: currentUser.id, platformType: platformType)

            // Create self-share for tracking (optional)
            _ = try await ShareService.shared.createShare(
                track: track,
                recipients: [currentUser.id],
                message: nil,
                senderId: currentUser.id
            )

            await MainActor.run {
                isTrackSaved = true
                showToastMessage("Added to your library!")

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }

            let cacheKey = trackCacheKey(for: track, platform: platformType)
            SavedTrackCache.shared.set(trackId: cacheKey, userId: currentUser.id, isSaved: true)
        } catch {
            print("❌ Failed to save track: \(error)")
            await MainActor.run {
                // More specific error messages
                if error.localizedDescription.contains("401") || error.localizedDescription.contains("unauthorized") {
                    showToastMessage("Please re-login to save tracks")
                } else if error.localizedDescription.contains("network") {
                    showToastMessage("Network error. Please try again")
                } else {
                    showToastMessage("Failed to add to library")
                }
            }
        }
    }

    private func handleUnsaveFromLibrary(track: MusicItem) async {
        guard let currentUser = authState.currentUser else { return }
        guard let platformType = currentUser.resolvedPlatformType else { return }

        do {
            switch platformType {
            case .spotify:
                let spotifyId = sanitizeSpotifyId(track.spotifyId ?? track.id)
                print("🗑️ Attempting to remove Spotify track with ID: \(spotifyId)")

                let token = try await getAccessToken(for: currentUser)
                try await SpotifyService.shared.removeTrackFromLibrary(trackId: spotifyId, accessToken: token)

            case .appleMusic:
                // Apple Music doesn't support removing via API
                await MainActor.run {
                    showToastMessage("Open Apple Music to remove")
                    isTrackSaved = false
                }
                let cacheKey = trackCacheKey(for: track, platform: platformType)
                SavedTrackCache.shared.set(trackId: cacheKey, userId: currentUser.id, isSaved: false)
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

            let cacheKey = trackCacheKey(for: track, platform: platformType)
            SavedTrackCache.shared.set(trackId: cacheKey, userId: currentUser.id, isSaved: false)
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

        let supabase = PhlockSupabaseClient.shared.client

        let tokens: [PlatformToken] = try await supabase
            .from("platform_tokens")
            .select("*")
            .eq("user_id", value: user.id.uuidString)
            .eq("platform_type", value: platformType.rawValue as String)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard var token = tokens.first else {
            throw NSError(domain: "FullScreenPlayerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No platform token found"])
        }

        if platformType == .spotify {
            // Refresh slightly early to avoid expiry mid-request
            let refreshThreshold = token.tokenExpiresAt.addingTimeInterval(-120)
            if Date() >= refreshThreshold {
                guard let refreshToken = token.refreshToken else {
                    throw NSError(domain: "FullScreenPlayerView", code: -2, userInfo: [NSLocalizedDescriptionKey: "No Spotify refresh token; please relink."])
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
}

// Simple per-user cache to remember saved tracks across player sessions (helps Apple Music and avoids UI flicker)
private final class SavedTrackCache {
    static let shared = SavedTrackCache()
    private let defaults = UserDefaults.standard

    private init() {}

    private func storageKey(for userId: UUID) -> String {
        "saved_tracks_\(userId.uuidString.lowercased())"
    }

    private func load(userId: UUID) -> Set<String> {
        let key = storageKey(for: userId)
        let values = defaults.stringArray(forKey: key) ?? []
        return Set(values)
    }

    func contains(trackId: String, userId: UUID) -> Bool {
        load(userId: userId).contains(trackId)
    }

    func set(trackId: String, userId: UUID, isSaved: Bool) {
        let key = storageKey(for: userId)
        var current = load(userId: userId)
        if isSaved {
            current.insert(trackId)
        } else {
            current.remove(trackId)
        }
        defaults.set(Array(current), forKey: key)
    }
}
