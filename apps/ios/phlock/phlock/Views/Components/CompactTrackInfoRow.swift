import SwiftUI

/// Compact track display with album art, title/artist, and save button
/// Similar to Spotify's now playing bar design
struct CompactTrackInfoRow: View {
    let track: MusicItem
    let onSave: () async -> Void
    let onUnsave: () async -> Void
    let initialSavedState: Bool

    @State private var isSaved: Bool = false
    @State private var isSaving: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Small album artwork (left)
            RemoteImage(
                url: track.albumArtUrl,
                spotifyId: track.spotifyId,
                trackName: track.name,
                width: 50,
                height: 50,
                cornerRadius: 8
            )

            // Track info (middle - takes available space)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.nunitoSans(size: 16, weight: .semiBold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if let artistName = track.artistName {
                    Text(artistName)
                        .font(.nunitoSans(size: 14))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Save button (right)
            Button {
                Task {
                    await handleToggleSave()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isSaved ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)

                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSaved ? .green : .primary)
                    }
                }
            }
            .disabled(isSaving)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
        .onAppear {
            isSaved = initialSavedState
        }
    }

    private func handleToggleSave() async {
        guard !isSaving else { return }

        await MainActor.run {
            isSaving = true
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if isSaved {
            // Unsave
            await onUnsave()
            await MainActor.run {
                isSaving = false
                isSaved = false
            }
        } else {
            // Save
            await onSave()
            await MainActor.run {
                isSaving = false
                isSaved = true

                // Success haptic
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CompactTrackInfoRow(
            track: MusicItem(
                id: "123",
                name: "Jealous Type",
                artistName: "Doja Cat",
                previewUrl: nil,
                albumArtUrl: "https://i.scdn.co/image/ab67616d0000b273example",
                isrc: nil,
                playedAt: nil,
                spotifyId: nil,
                appleMusicId: nil,
                popularity: nil,
                followerCount: nil
            ),
            onSave: {
                print("Save tapped")
            },
            onUnsave: {
                print("Unsave tapped")
            },
            initialSavedState: false
        )

        CompactTrackInfoRow(
            track: MusicItem(
                id: "124",
                name: "Super Long Track Title That Should Get Truncated With Ellipsis",
                artistName: "Artist Name That Is Also Very Long",
                previewUrl: nil,
                albumArtUrl: nil,
                isrc: nil,
                playedAt: nil,
                spotifyId: nil,
                appleMusicId: nil,
                popularity: nil,
                followerCount: nil
            ),
            onSave: {
                print("Save tapped")
            },
            onUnsave: {
                print("Unsave tapped")
            },
            initialSavedState: true
        )
    }
    .padding()
}
