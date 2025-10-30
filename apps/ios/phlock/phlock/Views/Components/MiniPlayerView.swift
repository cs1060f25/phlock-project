import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playbackService: PlaybackService
    @Binding var showFullPlayer: Bool
    @EnvironmentObject var authState: AuthenticationState
    @State private var showShareSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    var body: some View {
        if let track = playbackService.currentTrack {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 2)

                        Rectangle()
                            .fill(Color.primary)
                            .frame(
                                width: playbackService.duration > 0
                                    ? geometry.size.width * CGFloat(playbackService.currentTime / playbackService.duration)
                                    : 0,
                                height: 2
                            )
                    }
                    .animation(.linear(duration: 0.5), value: playbackService.currentTime)
                }
                .frame(height: 2)
                .drawingGroup() // Optimize rendering

                // Player content
                Button {
                    showFullPlayer = true
                } label: {
                    HStack(spacing: 12) {
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
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.gray)
                                )
                        }

                        // Track Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.name)
                                .font(.nunitoSans(size: 14, weight: .semiBold))
                                .lineLimit(1)
                                .foregroundColor(.primary)

                            if let artistName = track.artistName {
                                Text(artistName)
                                    .font(.nunitoSans(size: 12))
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Share Button
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        // Play/Pause Button
                        Button {
                            if playbackService.isPlaying {
                                playbackService.pause()
                            } else {
                                playbackService.resume()
                            }
                        } label: {
                            Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        // Close Button
                        Button {
                            playbackService.stopPlayback()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            .padding(.horizontal, 8)
            .sheet(isPresented: $showShareSheet) {
                if let track = playbackService.currentTrack {
                    NavigationStack {
                        VStack(spacing: 0) {
                            // Track preview at top
                            HStack(spacing: 12) {
                                if let albumArtUrl = track.albumArtUrl, let url = URL(string: albumArtUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.name)
                                        .font(.nunitoSans(size: 16, weight: .bold))
                                        .lineLimit(1)

                                    if let artistName = track.artistName {
                                        Text(artistName)
                                            .font(.nunitoSans(size: 14))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(16)

                            Divider()

                            // QuickSendBar
                            QuickSendBar(track: track) { sentToFriends in
                                handleShareComplete(sentToFriends: sentToFriends)
                            }
                            .environmentObject(authState)
                            .padding(.top, 16)

                            Spacer()
                        }
                        .navigationTitle("Share Song")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showShareSheet = false
                                }
                            }
                        }
                    }
                }
            }
            .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
            .confetti(trigger: $showConfetti)
        }
    }

    private func handleShareComplete(sentToFriends: [User]) {
        showShareSheet = false

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

#Preview {
    VStack {
        Spacer()
        MiniPlayerView(
            playbackService: PlaybackService.shared,
            showFullPlayer: .constant(false)
        )
    }
}
