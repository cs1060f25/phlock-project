import SwiftUI

struct FullScreenPlayerView: View {
    @ObservedObject var playbackService: PlaybackService
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthenticationState
    @State private var isDraggingSlider = false
    @State private var showShareBar = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if let track = playbackService.currentTrack {
                    VStack(spacing: 32) {
                        Spacer()

                        // Album Art
                        if let albumArtUrl = track.albumArtUrl, let url = URL(string: albumArtUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 300, height: 300)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 300, height: 300)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                )
                        }

                        // Track Info
                        VStack(spacing: 8) {
                            Text(track.name)
                                .font(.nunitoSans(size: 24, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if let artistName = track.artistName {
                                Text(artistName)
                                    .font(.nunitoSans(size: 18))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 32)

                        // Progress Slider
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: {
                                        isDraggingSlider ? playbackService.currentTime : playbackService.currentTime
                                    },
                                    set: { newValue in
                                        playbackService.seek(to: newValue)
                                    }
                                ),
                                in: 0...max(playbackService.duration, 1),
                                onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                }
                            )
                            .tint(.black)

                            // Time Labels
                            HStack {
                                Text(formatTime(playbackService.currentTime))
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
                        HStack(spacing: 60) {
                            // Share Button
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showShareBar.toggle()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(showShareBar ? Color.black : Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(showShareBar ? .white : .primary)
                                }
                            }

                            // Play/Pause Button
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

                            // Placeholder for future features (e.g., like button)
                            Color.clear
                                .frame(width: 60, height: 60)
                        }

                        // QuickSendBar
                        if showShareBar {
                            QuickSendBar(track: track) { sentToFriends in
                                handleShareComplete(sentToFriends: sentToFriends)
                            }
                            .environmentObject(authState)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.top, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

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
            .confetti(trigger: $showConfetti)
        }
    }

    private func handleShareComplete(sentToFriends: [User]) {
        showShareBar = false

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
