import SwiftUI
import Supabase
import UIKit

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
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isSkipping: Bool = false
    @State private var isSeeking: Bool = false
    @State private var activeGesture: ActiveGesture = .none

    // Displayed track for artwork - controlled separately during skip animations
    @State private var displayedTrack: MusicItem? = nil

    private enum ActiveGesture {
        case none
        case vertical
        case horizontal
    }

    var body: some View {
        ZStack {
            // Background gradient with album art blur
            backgroundLayer
                .opacity(backgroundOpacity)

            // Main content
            VStack(spacing: 0) {
                // Top bar with dismiss and menu
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 50) // Account for status bar

                Spacer(minLength: 20)

                // Album artwork
                albumArtwork
                    .padding(.horizontal, 30)

                // Track info section
                trackInfoSection
                    .padding(.horizontal, 30)
                    .padding(.top, 24)

                // Progress bar
                progressBar
                    .padding(.horizontal, 30)
                    .padding(.top, 24)

                // Playback controls
                playbackControlsSection
                    .padding(.top, 20)

                Spacer(minLength: 20)

                // Bottom action buttons
                bottomActions
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
            }
        }
        .offset(y: max(0, dragOffset)) // Only allow downward drag
        .ignoresSafeArea()
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // Determine gesture direction if not yet determined
                    if activeGesture == .none {
                        let horizontalAmount = abs(gesture.translation.width)
                        let verticalAmount = abs(gesture.translation.height)

                        // Need significant movement to determine direction
                        if horizontalAmount > 15 || verticalAmount > 15 {
                            if verticalAmount > horizontalAmount && gesture.translation.height > 0 {
                                activeGesture = .vertical
                            } else if horizontalAmount > verticalAmount {
                                activeGesture = .horizontal
                            }
                        }
                    }

                    // Only handle vertical dismiss gesture
                    if activeGesture == .vertical && gesture.translation.height > 0 {
                        dragOffset = gesture.translation.height
                    }
                }
                .onEnded { gesture in
                    if activeGesture == .vertical {
                        let dismissThreshold: CGFloat = 150

                        if gesture.translation.height > dismissThreshold {
                            // Animate dismissal
                            withAnimation(.easeOut(duration: 0.25)) {
                                dragOffset = UIScreen.main.bounds.height
                            }

                            // Dismiss after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                isPresented = false
                                dragOffset = 0 // Reset for next time
                                activeGesture = .none
                            }
                        } else {
                            // Spring back to original position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                            activeGesture = .none
                        }
                    } else {
                        activeGesture = .none
                    }
                }
        )
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
        .onAppear {
            refreshSavedState()
            displayedTrack = playbackService.currentTrack
        }
        .onChange(of: playbackService.currentTrack?.id) { _ in
            refreshSavedState()
            // Only sync displayed track if not skipping (skip animation handles it)
            if !isSkipping {
                displayedTrack = playbackService.currentTrack
            }
        }
        .onChange(of: playbackService.currentTrack?.albumArtUrl) { _ in
            // Sync when album art URL changes (e.g., fetched from API)
            if !isSkipping {
                displayedTrack = playbackService.currentTrack
            }
        }
        .overlay(alignment: .bottom) {
            if showShareSheet, let track = shareTrack {
                VStack {
                    Spacer()
                    ShareOptionsSheet(
                        track: track,
                        shareURL: ShareLinkBuilder.url(for: track),
                        context: .fullPlayer,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showShareSheet = false
                                shareTrack = nil
                            }
                        },
                        onCopy: { url in
                            UIPasteboard.general.string = url.absoluteString
                            showToastMessage("Link copied")
                        },
                        onOpen: { url in
                            UIApplication.shared.open(url)
                        },
                        onFallback: { message in
                            showToastMessage(message)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(Double(dragOffset / 220), 0), 1)
        return 1 - progress
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            // Base color
            Color(.systemBackground)

            // Blurred album art background
            if let artworkUrl = playbackService.currentTrack?.albumArtUrl,
               let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .blur(radius: 60)
                        .overlay(
                            Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06)
                        )
                } placeholder: {
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(colorScheme == .dark ? 0.22 : 0.08),
                            Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                LinearGradient(
                    colors: [
                        Color.purple.opacity(colorScheme == .dark ? 0.22 : 0.08),
                        Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.08)
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
                    .font(.lora(size: 10))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 4) {
                    Image(systemName: platformIconName)
                        .font(.lora(size: 10))
                    Text(platformName)
                        .font(.lora(size: 10))
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
            if let track = displayedTrack {
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
        .offset(x: horizontalDragOffset)
        .opacity(1 - Double(abs(horizontalDragOffset)) / 300)
        .rotation3DEffect(
            .degrees(Double(horizontalDragOffset) / 20),
            axis: (x: 0, y: 1, z: 0)
        )
        .contentShape(Rectangle()) // Ensure the entire area is tappable/draggable
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { gesture in
                    // Don't handle if vertical gesture is active
                    guard activeGesture != .vertical else { return }

                    // Only handle horizontal drags (ignore if vertical is dominant)
                    let horizontalAmount = abs(gesture.translation.width)
                    let verticalAmount = abs(gesture.translation.height)

                    if horizontalAmount > verticalAmount && !isSkipping {
                        // Mark as horizontal gesture
                        if activeGesture == .none {
                            activeGesture = .horizontal
                        }

                        // Check if we can skip in this direction
                        let canSwipe = (gesture.translation.width > 0 && canSkipBackward) ||
                                       (gesture.translation.width < 0 && canSkipForward)

                        if canSwipe {
                            horizontalDragOffset = gesture.translation.width
                        } else {
                            // Add resistance when can't skip
                            horizontalDragOffset = gesture.translation.width * 0.2
                        }
                    }
                }
                .onEnded { gesture in
                    // Don't process if vertical gesture was active
                    guard activeGesture != .vertical else { return }

                    let swipeThreshold: CGFloat = 80
                    let velocityThreshold: CGFloat = 300

                    let shouldTrigger = abs(gesture.translation.width) > swipeThreshold ||
                                       abs(gesture.velocity.width) > velocityThreshold

                    if shouldTrigger && !isSkipping {
                        if gesture.translation.width > 0 && canSkipBackward {
                            // Swipe right - go to previous track
                            triggerSkipBackward()
                        } else if gesture.translation.width < 0 && canSkipForward {
                            // Swipe left - go to next track
                            triggerSkipForward()
                        } else {
                            // Can't skip, spring back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                horizontalDragOffset = 0
                            }
                        }
                    } else {
                        // Spring back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            horizontalDragOffset = 0
                        }
                    }

                    // Reset gesture state if this was horizontal
                    if activeGesture == .horizontal {
                        activeGesture = .none
                    }
                }
        )
    }

    private func triggerSkipForward() {
        isSkipping = true
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Pre-calculate next track for seamless transition
        let nextTrack = getNextTrack()

        // Animate out to the left
        withAnimation(.easeOut(duration: 0.2)) {
            horizontalDragOffset = -UIScreen.main.bounds.width
        }

        // Skip and animate back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Change the track in playback service
            playbackService.skipForward()

            // Reposition off-screen to the right (entry position) WITHOUT animation
            horizontalDragOffset = UIScreen.main.bounds.width

            // NOW update displayed track - use our pre-calculated one first to be instant
            if let next = nextTrack {
                displayedTrack = next
            } else {
                displayedTrack = playbackService.currentTrack
            }

            // Animate from entry position to center
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                horizontalDragOffset = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isSkipping = false
                // Final sync to ensure we have the authoritative state
                displayedTrack = playbackService.currentTrack
            }
        }
    }

    private func triggerSkipBackward() {
        isSkipping = true
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Pre-calculate previous track for seamless transition
        let prevTrack = getPreviousTrack()

        // Animate out to the right
        withAnimation(.easeOut(duration: 0.2)) {
            horizontalDragOffset = UIScreen.main.bounds.width
        }

        // Skip and animate back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Change the track in playback service (always go to previous, not restart)
            playbackService.skipToPreviousTrack()

            // Reposition off-screen to the left (entry position) WITHOUT animation
            horizontalDragOffset = -UIScreen.main.bounds.width

            // NOW update displayed track - use our pre-calculated one first to be instant
            if let prev = prevTrack {
                displayedTrack = prev
            } else {
                displayedTrack = playbackService.currentTrack
            }

            // Animate from entry position to center
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                horizontalDragOffset = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isSkipping = false
                // Final sync to ensure we have the authoritative state
                displayedTrack = playbackService.currentTrack
            }
        }
    }

    private func getNextTrack() -> MusicItem? {
        guard !playbackService.queue.isEmpty else { return nil }
        let index = playbackService.currentQueueIndex ?? 0
        let nextIndex = (index + 1) % playbackService.queue.count
        return playbackService.queue[nextIndex].track
    }

    private func getPreviousTrack() -> MusicItem? {
        guard !playbackService.queue.isEmpty else { return nil }
        let index = playbackService.currentQueueIndex ?? 0
        let prevIndex = index == 0 ? (playbackService.queue.count - 1) : (index - 1)
        return playbackService.queue[prevIndex].track
    }

    // MARK: - Track Info Section

    private var trackInfoSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Track info (left side) with gradient fade on right edge
            VStack(alignment: .leading, spacing: 6) {
                if let track = playbackService.currentTrack {
                    // Track name (Marquee)
                    MarqueeText(
                        text: track.name,
                        font: .lora(size: 24, weight: .bold),
                        leftFade: 16,
                        rightFade: 16,
                        startDelay: 2.0,
                        alignment: .leading
                    )
                    .frame(height: 34) // Fixed height for track name area
                    .foregroundColor(.white)

                    // Artist name
                    Text(track.artistName ?? "Unknown Artist")
                        .font(.lora(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text("No track playing")
                        .font(.lora(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .mask(
                HStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 24)
                }
            )

            // Add to library button (right side)
            if playbackService.currentTrack != nil {
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
                    Image(systemName: isTrackSaved ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(isTrackSaved ? .green : .white.opacity(0.7))
                }
                .padding(.leading, 12)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            // Custom scrubbable progress bar
            GeometryReader { geometry in
                let progress = (isDraggingSlider || isSeeking)
                    ? sliderValue / max(durationSafe, 1)
                    : currentTimeSafe / max(durationSafe, 1)

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: 4)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDraggingSlider ? 16 : 12, height: isDraggingSlider ? 16 : 12)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(geometry.size.width - 12, geometry.size.width * CGFloat(progress) - 6)))
                        .animation(.easeOut(duration: 0.1), value: isDraggingSlider)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingSlider {
                                isDraggingSlider = true
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            sliderValue = Double(progress) * durationSafe
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            let seekTime = Double(progress) * durationSafe
                            
                            // Set seeking state to prevent jump back
                            isSeeking = true
                            seek(to: seekTime)
                            isDraggingSlider = false

                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            // Reset seeking state after a delay to allow playback service to catch up
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isSeeking = false
                            }
                        }
                )
            }
            .frame(height: 20)

            // Time labels
            HStack {
                Text(formatTime(isDraggingSlider ? sliderValue : currentTimeSafe))
                    .font(.lora(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Text(formatTime(durationSafe))
                    .font(.lora(size: 10))
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
                    .font(.lora(size: 20, weight: .bold))
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
                        .offset(x: playbackService.isPlaying ? 0 : 1)
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
                    .font(.lora(size: 20, weight: .bold))
                    .foregroundColor(canSkipForward ? .white : .white.opacity(0.3))
            }
            .disabled(!canSkipForward)
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        // Open in streaming app button (centered)
        Button {
            if let track = playbackService.currentTrack {
                openInNativeApp(track: track)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                    .font(.lora(size: 20, weight: .semiBold))
                Text("Open in \(platformName)")
                    .font(.lora(size: 10))
            }
            .foregroundColor(.white.opacity(0.7))
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
        playbackService.currentTrack != nil
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
        // First check if the track is in the saved set from the playback context
        // This handles tracks that PhlockView already knows are saved
        if playbackService.savedTrackIds.contains(track.id) {
            await MainActor.run {
                isTrackSaved = true
                print("✅ Track saved status: true (from playback context)")
            }
            return
        }

        guard let currentUser = authState.currentUser else { return }
        guard let platformType = currentUser.resolvedPlatformType else { return }

        do {
            var isSaved = false

            switch platformType {
            case .spotify:
                let spotifyId = sanitizeSpotifyId(track.spotifyId ?? track.id)
                let token = try await getAccessToken(for: currentUser)
                isSaved = try await SpotifyService.shared.isTrackSaved(trackId: spotifyId, accessToken: token)

            case .appleMusic:
                // For Apple Music, check if we have any share with this track that's been saved
                // This includes self-shares and shares received from others
                let shares: [Share] = try await PhlockSupabaseClient.shared.client
                    .from("shares")
                    .select("*")
                    .eq("recipient_id", value: currentUser.id.uuidString)
                    .eq("track_id", value: track.id)
                    .not("saved_at", operator: .is, value: "null")
                    .execute()
                    .value
                isSaved = !shares.isEmpty
            }

            await MainActor.run {
                isTrackSaved = isSaved
                print("✅ Track saved status: \(isSaved)")
            }
        } catch {
            print("❌ Failed to check saved status: \(error)")
            // Default to false if we can't check
            await MainActor.run {
                isTrackSaved = false
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
