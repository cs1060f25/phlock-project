import SwiftUI

/// A pill-shaped view showing the user's daily song selection
/// Tapping expands into a full-screen preview of how the song appears to others
struct DailySongPillView: View {
    let share: Share
    @Binding var isExpanded: Bool

    // Callback for playback
    var onPlayTapped: ((Share) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        pillContent
            .onTapGesture {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                // Start playback when expanding
                onPlayTapped?(share)

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }
    }

    private var pillContent: some View {
        HStack(spacing: 10) {
            // Album artwork
            AsyncImage(url: URL(string: share.albumArtUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    albumArtPlaceholder
                case .empty:
                    albumArtPlaceholder
                @unknown default:
                    albumArtPlaceholder
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Track info
            VStack(alignment: .leading, spacing: 1) {
                Text(share.trackName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(share.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // "Your pick" label
            Text("Your pick")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }

    private var albumArtPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
    }
}

/// Container view that displays the pill (expanded view is handled separately)
struct DailySongPillContainer: View {
    let myDailySong: Share?
    @Binding var isExpanded: Bool

    // Callbacks
    var onSendTapped: (() -> Void)?
    var onPlayTapped: ((Share) -> Void)?

    var body: some View {
        if let song = myDailySong {
            DailySongPillView(
                share: song,
                isExpanded: $isExpanded,
                onPlayTapped: onPlayTapped
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

struct DailySongPillPreview: View {
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            // Dark background to show glass effect
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                DailySongPillContainer(
                    myDailySong: Share(
                        senderId: UUID(),
                        recipientId: UUID(),
                        trackId: "test",
                        trackName: "Espresso",
                        artistName: "Sabrina Carpenter",
                        isDailySong: true,
                        selectedDate: Date(),
                        likeCount: 12,
                        commentCount: 3,
                        sendCount: 1
                    ),
                    isExpanded: $isExpanded
                )

                Spacer()
            }
            .padding(.top, 60)
        }
    }
}

#Preview {
    DailySongPillPreview()
}
