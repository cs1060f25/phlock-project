import SwiftUI

/// Full-screen expanded view of the user's own daily song pick
/// Shows how the song appears to others in their phlock feeds
struct ExpandedDailySongView: View {
    let share: Share
    @Binding var isExpanded: Bool
    let namespace: Namespace.ID

    // Callbacks for share card generation and playback
    var onSendTapped: (() -> Void)?
    var onPlayTapped: ((Share) -> Void)?

    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @StateObject private var socialService = SocialEngagementService.shared

    // Sheet states
    @State private var showCommentSheet = false
    @State private var showLikersSheet = false
    @State private var showMessageEditor = false

    // UI states
    @State private var isGeneratingShareCard = false
    @State private var backgroundImageLoaded = false
    @State private var backgroundImageIsBright = false
    @State private var localMessage: String?
    @State private var showPlayPauseIndicator = false

    @Environment(\.colorScheme) private var colorScheme

    // Check if this track is currently playing
    private var isPlaying: Bool {
        playbackService.isPlaying && playbackService.currentTrack?.id == share.trackId
    }

    // Dynamic text colors based on background brightness
    private var useDarkText: Bool {
        backgroundImageLoaded ? backgroundImageIsBright : colorScheme == .light
    }

    private var primaryTextColor: Color {
        useDarkText ? .black : .white
    }

    private var secondaryTextColor: Color {
        useDarkText ? .black.opacity(0.7) : .white.opacity(0.75)
    }

    private var tertiaryTextColor: Color {
        useDarkText ? .black.opacity(0.5) : .white.opacity(0.6)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred album art background (ignore safe area to fill screen)
                backgroundLayer(size: geometry.size)
                    .ignoresSafeArea()

                // Dark overlay for legibility (ignore safe area to fill screen)
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                // Full-screen tap area for play/pause
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePlayPause()
                    }
                    .ignoresSafeArea()

                // Main content - matches songCardContent layout exactly
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 160) // Space for top area - moved down from songCardContent's 100

                    // Album art + song info
                    songContent(size: geometry.size)

                    Spacer()
                        .frame(height: 20)

                    // Message section with edit capability (matches songCardContent's .padding(.top, 16))
                    messageSection
                        .padding(.top, 16)

                    Spacer()
                        .frame(height: 140) // Room for collapse button + tab bar (matches songCardContent)
                }

                // Right side: VerticalActionBar
                actionBarOverlay

                // Bottom overlay: Collapse button (matches ProfileIndicatorBar position)
                VStack {
                    Spacer()
                    collapseButton
                        .padding(.bottom, 30) // Above tab bar
                }
            }
        }
        .gesture(swipeUpGesture)
        .sheet(isPresented: $showCommentSheet) {
            CommentSheetView(share: share, isPresented: $showCommentSheet)
        }
        .sheet(isPresented: $showLikersSheet) {
            LikersListSheet(shareId: share.id, isPresented: $showLikersSheet)
        }
        .sheet(isPresented: $showMessageEditor) {
            MessageEditorSheet(
                initialMessage: currentMessage,
                shareId: share.id,
                onSave: { newMessage in
                    localMessage = newMessage.isEmpty ? nil : newMessage
                }
            )
        }
        .task {
            localMessage = share.message
            try? await socialService.fetchLikeStatus(for: [share.id])
        }
    }

    // Current message (local override or original)
    private var currentMessage: String {
        localMessage ?? share.message ?? ""
    }

    // MARK: - Collapse Button (Bottom - matches ProfileIndicatorBar position)

    private var collapseButton: some View {
        Button {
            collapse()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
            }
        }
    }

    private func collapse() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Pause playback when collapsing
        playbackService.pause()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }

    // MARK: - Play/Pause

    private func togglePlayPause() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Show indicator
        withAnimation(.easeOut(duration: 0.1)) {
            showPlayPauseIndicator = true
        }

        // Hide indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.2)) {
                showPlayPauseIndicator = false
            }
        }

        // Toggle playback
        if isPlaying {
            playbackService.pause()
        } else {
            // If track is already loaded, just resume
            if playbackService.currentTrack?.id == share.trackId {
                playbackService.resume()
            } else {
                // Load and play the track
                onPlayTapped?(share)
            }
        }
    }

    // MARK: - Background Layer

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        if let url = highQualityAlbumArtUrl(share.albumArtUrl) {
            AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .blur(radius: 50)
                        .onAppear {
                            backgroundImageLoaded = true
                            if let cached = ImageBrightnessCache.shared.get(url.absoluteString) {
                                backgroundImageIsBright = cached
                            } else {
                                analyzeBrightness(for: share.albumArtUrl)
                            }
                        }
                case .failure:
                    gradientBackground
                        .onAppear {
                            backgroundImageLoaded = false
                        }
                case .empty:
                    Color(white: 0.1)
                @unknown default:
                    gradientBackground
                }
            }
        } else {
            gradientBackground
        }
    }

    private var gradientBackground: some View {
        LinearGradient(
            colors: [Color(white: 0.15), Color(white: 0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func analyzeBrightness(for albumArtUrl: String?) {
        guard let urlString = albumArtUrl,
              let highQualityUrl = highQualityAlbumArtUrl(urlString) else { return }

        let cacheKey = highQualityUrl.absoluteString
        if ImageBrightnessCache.shared.get(cacheKey) != nil { return }

        // Use smallest thumbnail for fast analysis
        let thumbnailUrlString: String
        if urlString.contains("i.scdn.co/image/ab67616d") {
            thumbnailUrlString = urlString
                .replacingOccurrences(of: "ab67616d0000b273", with: "ab67616d00004851")
                .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d00004851")
        } else {
            thumbnailUrlString = urlString
        }

        guard let thumbnailUrl = URL(string: thumbnailUrlString) else { return }

        Task.detached(priority: .utility) {
            do {
                let (data, _) = try await URLSession.shared.data(from: thumbnailUrl)
                guard let image = UIImage(data: data) else { return }

                let brightness = image.fastBrightness()
                let isBright = brightness > 0.55

                ImageBrightnessCache.shared.set(cacheKey, isBright: isBright)

                await MainActor.run {
                    self.backgroundImageIsBright = isBright
                }
            } catch {
                // Silently fail
            }
        }
    }

    // MARK: - Song Content

    @ViewBuilder
    private func songContent(size: CGSize) -> some View {
        let artSize = min(size.width - 80, 320)

        VStack(spacing: 0) {
            // Album art with play/pause indicator
            ZStack {
                if let url = highQualityAlbumArtUrl(share.albumArtUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            albumArtPlaceholder
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .overlay(ProgressView().tint(.white))
                        @unknown default:
                            albumArtPlaceholder
                        }
                    }
                } else {
                    albumArtPlaceholder
                }

                // Play/pause indicator centered on album art
                if showPlayPauseIndicator {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: artSize, height: artSize)
            .cornerRadius(12)
            .clipped()
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            .allowsHitTesting(false) // Let tap pass through to background

            Spacer()
                .frame(height: 28) // Matches songCardContent spacing

            // Song info
            VStack(spacing: 6) {
                Text(share.trackName)
                    .font(.lora(size: 24, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(share.artistName)
                    .font(.lora(size: 17))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 30)
            .allowsHitTesting(false) // Let tap pass through to background
        }
    }

    private var albumArtPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
            )
    }

    // MARK: - Message Section

    private var messageSection: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            showMessageEditor = true
        } label: {
            HStack(spacing: 8) {
                if !currentMessage.isEmpty {
                    Text("\"\(currentMessage)\"")
                        .font(.lora(size: 14))
                        .italic()
                        .foregroundColor(tertiaryTextColor)
                        .lineLimit(2)
                } else {
                    Text("write an optional message")
                        .font(.lora(size: 14))
                        .italic()
                        .foregroundColor(tertiaryTextColor.opacity(0.7))
                }

                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(tertiaryTextColor.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.5))
            .cornerRadius(20)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Action Bar

    private var actionBarOverlay: some View {
        let isLiked = socialService.likedShareIds.contains(share.id)
        let adjustedLikeCount = socialService.adjustedLikeCount(for: share.id, originalCount: share.likeCount)
        let adjustedCommentCount = socialService.adjustedCommentCount(for: share.id, originalCount: share.commentCount)

        return VStack {
            Spacer()
            HStack {
                Spacer()
                VerticalActionBar(
                    likeCount: adjustedLikeCount,
                    commentCount: adjustedCommentCount,
                    sendCount: share.sendCount,
                    isLiked: isLiked,
                    isSendLoading: isGeneratingShareCard,
                    onLikeTapped: {
                        Task {
                            try? await socialService.toggleLike(share.id)
                        }
                    },
                    onCommentTapped: {
                        showCommentSheet = true
                    },
                    onSendTapped: {
                        onSendTapped?()
                    },
                    onOpenTapped: {
                        openInStreamingApp()
                    },
                    onLikeCountTapped: {
                        showLikersSheet = true
                    },
                    platformType: authState.currentUser?.resolvedPlatformType
                )
                .padding(.trailing, 16)
            }
            // Align Open button with profile carousel circles (matches PhlockImmersiveLayout)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Gestures

    private var swipeUpGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                // Swipe up to collapse (matches chevron.up direction)
                if value.translation.height < -50 {
                    collapse()
                }
            }
    }

    // MARK: - Actions

    private func openInStreamingApp() {
        // Try Spotify URL first using trackId
        let spotifyId = share.trackId
        if let url = URL(string: "spotify:track:\(spotifyId)") {
            UIApplication.shared.open(url)
            return
        }

        // Fallback: search on Spotify
        let searchQuery = "\(share.trackName) \(share.artistName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "spotify:search:\(searchQuery)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

struct ExpandedDailySongPreview: View {
    @Namespace private var animation

    var body: some View {
        ExpandedDailySongView(
            share: Share(
                senderId: UUID(),
                recipientId: UUID(),
                trackId: "test",
                trackName: "Espresso",
                artistName: "Sabrina Carpenter",
                message: "This song is stuck in my head!",
                isDailySong: true,
                selectedDate: Date(),
                likeCount: 42,
                commentCount: 7,
                sendCount: 3
            ),
            isExpanded: .constant(true),
            namespace: animation
        )
    }
}

#Preview {
    ExpandedDailySongPreview()
}
