import SwiftUI

/// A pill-shaped view showing the user's daily song selection
/// Displayed at the top of the Phlock feed as a quick reference
struct DailySongPillView: View {
    let albumArtUrl: String?
    let trackName: String
    let artistName: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            // Album artwork
            AsyncImage(url: URL(string: albumArtUrl ?? "")) { phase in
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
                Text(trackName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(artistName)
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

/// Container view that fetches and displays the user's daily song
struct DailySongPillContainer: View {
    let myDailySong: Share?

    var body: some View {
        if let song = myDailySong {
            DailySongPillView(
                albumArtUrl: song.albumArtUrl,
                trackName: song.trackName,
                artistName: song.artistName
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Dark background to show glass effect
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            DailySongPillView(
                albumArtUrl: nil,
                trackName: "Espresso",
                artistName: "Sabrina Carpenter"
            )

            Spacer()
        }
        .padding(.top, 60)
    }
}
