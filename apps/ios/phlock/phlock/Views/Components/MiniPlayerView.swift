import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playbackService: PlaybackService
    @Binding var showFullPlayer: Bool
    @Binding var showShareSheet: Bool
    @Binding var trackToShare: MusicItem?
    @EnvironmentObject var authState: AuthenticationState
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        if let track = playbackService.currentTrack {
            VStack(spacing: 0) {
                // Progress bar (display only)
                GeometryReader { geometry in
                    let duration = playbackService.duration
                    let currentTime = playbackService.currentTime
                    // Guard against NaN and invalid values
                    let safeDuration = (duration.isNaN || duration.isInfinite || duration <= 0) ? 1 : duration
                    let safeCurrentTime = (currentTime.isNaN || currentTime.isInfinite || currentTime < 0) ? 0 : currentTime
                    let progress = min(max(safeCurrentTime / safeDuration, 0), 1)
                    let safeWidth = geometry.size.width > 0 ? geometry.size.width : 1

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 2)

                        Rectangle()
                            .fill(Color.primary)
                            .frame(
                                width: safeWidth * CGFloat(progress),
                                height: 2
                            )
                    }
                    .animation(.linear(duration: 0.5), value: playbackService.currentTime)
                }
                .frame(height: 2)
                .drawingGroup() // Optimize rendering

                // Player content
                HStack(spacing: 12) {
                    // Album Art
                    // Use .id() to force SwiftUI to recreate AsyncImage when track changes
                    // This prevents showing stale cached artwork during track transitions
                    if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .cornerRadius(8)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 48, height: 48)
                                .cornerRadius(8)
                        }
                        .id(track.id)
                    } else {
                        // Fallback for missing album art
                        ZStack {
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "music.note")
                                .font(.lora(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                    }

                    // Track Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.lora(size: 15, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        if let artist = track.artistName {
                            Text(artist)
                                .font(.lora(size: 14))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Open in App Button
                    Button {
                        if let platformType = authState.currentUser?.resolvedPlatformType {
                            DeepLinkService.shared.openInNativeApp(track: track, platform: platformType)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.lora(size: 20, weight: .semiBold))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(abs(dragOffset) > 5)

                    // Play/Pause Button
                    Button {
                        if playbackService.isPlaying {
                            playbackService.pause()
                        } else {
                            playbackService.resume()
                        }
                    } label: {
                        Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.lora(size: 20, weight: .semiBold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(abs(dragOffset) > 5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 5)
            .padding(.horizontal, 8)
            .padding(.bottom, 4) // Lift slightly above tab bar
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow horizontal dragging
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        // Threshold for dismissal
                        let threshold: CGFloat = 100
                        if abs(value.translation.width) > threshold {
                            // Swipe away animation
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = value.translation.width > 0 ? 500 : -500
                            }
                            // Stop playback after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                playbackService.stopPlayback()
                                dragOffset = 0 // Reset for next time
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if abs(dragOffset) < 5 {
                    withAnimation(.spring()) {
                        showFullPlayer = true
                    }
                }
            }
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            .padding(.horizontal, 8)
            .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
            .confetti(trigger: $showConfetti)
        }
    }

    func handleShareComplete(sentToFriends: [User]) {
        showShareSheet = false
        trackToShare = nil

        // Show success feedback
        let friendNames = sentToFriends.map { $0.displayName }.joined(separator: ", ")
        toastMessage = sentToFriends.count == 1
            ? "Sent to \(friendNames)"
            : "Sent to \(sentToFriends.count) friends"

        showToast = true
        showConfetti = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

extension MiniPlayerView {
    enum Layout {
        /// Approximate visible height of the mini player including chrome
        static let height: CGFloat = 74
        /// Spacing used to sit above the custom tab bar
        static let tabBarOffset: CGFloat = 53
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView(
            playbackService: PlaybackService.shared,
            showFullPlayer: .constant(false),
            showShareSheet: .constant(false),
            trackToShare: .constant(nil)
        )
    }
}
