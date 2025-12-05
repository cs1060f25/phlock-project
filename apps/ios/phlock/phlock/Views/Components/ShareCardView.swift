import SwiftUI

/// Data structure for a song row in the share card
struct ShareCardSong: Identifiable {
    let id: UUID
    let trackName: String
    let artistName: String
    let image: UIImage?
    let pickerLabel: String  // "my pick" or "@username"
    let isMyPick: Bool

    init(share: Share, image: UIImage?, pickerLabel: String, isMyPick: Bool = false) {
        self.id = share.id
        self.trackName = share.trackName
        self.artistName = share.artistName
        self.image = image
        self.pickerLabel = pickerLabel
        self.isMyPick = isMyPick
    }
}

/// A shareable card view showing the user's phlock playlist
/// Designed for Instagram Stories (9:16 aspect ratio)
struct ShareCardView: View {
    let songs: [ShareCardSong]
    let gradientColors: [Color]
    let instagramHandle: String

    init(
        songs: [ShareCardSong],
        gradientColors: [Color],
        instagramHandle: String = "@myphlock"
    ) {
        self.songs = songs
        self.gradientColors = gradientColors.isEmpty ? [Color.gray] : gradientColors
        self.instagramHandle = instagramHandle
    }

    var body: some View {
        ZStack {
            // Dynamic gradient background from album art colors
            backgroundGradient

            // Dark overlay for text legibility
            Color.black.opacity(0.55)

            // Content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Header
                Text("my phlock today")
                    .font(.lora(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 32)

                // Song rows
                VStack(spacing: 16) {
                    ForEach(songs) { song in
                        songRow(song)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Footer
                Text(instagramHandle)
                    .font(.lora(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 48)
            }
        }
        .frame(width: 360, height: 640)  // Base size, will be scaled 3x for export
    }

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Song Row

    private func songRow(_ song: ShareCardSong) -> some View {
        HStack(spacing: 14) {
            // Album art
            if let image = song.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 24))
                    )
            }

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.trackName)
                    .font(.lora(size: 17, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(song.artistName) • \(song.pickerLabel)")
                    .font(.lora(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            // Highlight for "my pick" row
            song.isMyPick
                ? RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                : nil
        )
    }
}

// MARK: - Share Card Sheet

/// Bottom sheet for sharing the generated card
struct ShareCardSheet: View {
    let image: UIImage
    let onShareToInstagram: () -> Void
    let onShareGeneral: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showActivitySheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Card preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                Spacer()

                // Share buttons
                VStack(spacing: 12) {
                    // Instagram Stories button
                    if ShareCardGenerator.isInstagramInstalled {
                        Button(action: onShareToInstagram) {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 22))
                                Text("Share to Instagram Stories")
                                    .font(.lora(size: 17, weight: .semiBold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                    }

                    // General share button
                    Button {
                        showActivitySheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                            Text("More Options")
                                .font(.lora(size: 17, weight: .medium))
                        }
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Share Your Phlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivityViewController(activityItems: [image])
            }
        }
        .presentationDetents([.large])
    }
}

/// UIKit wrapper for UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ShareCardView(
        songs: [
            ShareCardSong(
                share: Share(
                    senderId: UUID(),
                    recipientId: UUID(),
                    trackId: "1",
                    trackName: "Espresso",
                    artistName: "Sabrina Carpenter",
                    isDailySong: true
                ),
                image: nil,
                pickerLabel: "my pick",
                isMyPick: true
            ),
            ShareCardSong(
                share: Share(
                    senderId: UUID(),
                    recipientId: UUID(),
                    trackId: "2",
                    trackName: "Birds of a Feather",
                    artistName: "Billie Eilish",
                    isDailySong: true
                ),
                image: nil,
                pickerLabel: "@sarah"
            ),
            ShareCardSong(
                share: Share(
                    senderId: UUID(),
                    recipientId: UUID(),
                    trackId: "3",
                    trackName: "Good Luck, Babe!",
                    artistName: "Chappell Roan",
                    isDailySong: true
                ),
                image: nil,
                pickerLabel: "@mike"
            )
        ],
        gradientColors: [.purple, .blue, .pink]
    )
}
