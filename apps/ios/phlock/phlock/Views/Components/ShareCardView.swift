import SwiftUI

/// Card format for different sharing destinations
enum ShareCardFormat: CaseIterable {
    case story      // 9:16 - Stories, Reels, DMs (1080x1920)
    case post       // 4:5 - Feed posts (1080x1350) - optimal for IG feed

    var baseSize: CGSize {
        switch self {
        case .story: return CGSize(width: 360, height: 640)
        case .post: return CGSize(width: 360, height: 450)  // 4:5 ratio
        }
    }

    var exportSize: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .post: return CGSize(width: 1080, height: 1350)  // 4:5 ratio
        }
    }

    var displayName: String {
        switch self {
        case .story: return "Story"
        case .post: return "Post"
        }
    }
}

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
/// Supports multiple formats for different Instagram destinations
struct ShareCardView: View {
    let songs: [ShareCardSong]
    let gradientColors: [Color]
    let instagramHandle: String
    let format: ShareCardFormat

    init(
        songs: [ShareCardSong],
        gradientColors: [Color],
        instagramHandle: String = "@myphlock",
        format: ShareCardFormat = .story
    ) {
        self.songs = songs
        self.gradientColors = gradientColors.isEmpty ? [Color.gray] : gradientColors
        self.instagramHandle = instagramHandle
        self.format = format
    }

    var body: some View {
        ZStack {
            // Dynamic gradient background from album art colors
            backgroundGradient

            // Dark overlay for text legibility
            Color.black.opacity(0.55)

            // Content - different layouts per format
            switch format {
            case .story:
                storyLayout
            case .post:
                postLayout
            }
        }
        .frame(width: format.baseSize.width, height: format.baseSize.height)
    }

    // MARK: - Story Layout (9:16)

    private var storyLayout: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 48)

            // Header
            Text("my phlock today")
                .font(.lora(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            // Song rows
            VStack(spacing: 12) {
                ForEach(songs) { song in
                    songRow(song, compact: false)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Footer
            Text(instagramHandle)
                .font(.lora(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 40)
        }
    }

    // MARK: - Post Layout (4:5 ratio for Instagram feed)

    private var postLayout: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 36)

            // Header
            Text("my phlock today")
                .font(.lora(size: 26, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            // Song rows - same styling as story, fits well in 4:5
            VStack(spacing: 10) {
                ForEach(songs.prefix(6)) { song in
                    songRow(song, compact: false)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            // Footer
            Text(instagramHandle)
                .font(.lora(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 32)
        }
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

    private func songRow(_ song: ShareCardSong, compact: Bool) -> some View {
        let artSize: CGFloat = compact ? 44 : 56
        let titleSize: CGFloat = compact ? 14 : 16
        let subtitleSize: CGFloat = compact ? 11 : 13
        let spacing: CGFloat = compact ? 10 : 12
        let hPadding: CGFloat = compact ? 8 : 10
        let vPadding: CGFloat = compact ? 6 : 8

        return HStack(spacing: spacing) {
            // Album art
            if let image = song.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: artSize, height: artSize)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8))
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: compact ? 6 : 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: artSize, height: artSize)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: compact ? 16 : 22))
                    )
            }

            // Track info
            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                Text(song.trackName)
                    .font(.lora(size: titleSize, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(song.artistName) • \(song.pickerLabel)")
                    .font(.lora(size: subtitleSize, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(
            // Highlight for "my pick" row
            song.isMyPick
                ? RoundedRectangle(cornerRadius: compact ? 8 : 10)
                    .fill(Color.white.opacity(0.1))
                : nil
        )
    }
}

// MARK: - Share Card Sheet

/// Bottom sheet for sharing the generated card with format selection
struct ShareCardSheet: View {
    let images: [ShareCardFormat: UIImage]
    let onShareToInstagram: (UIImage) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedFormat: ShareCardFormat = .story
    @State private var showActivitySheet = false

    private var currentImage: UIImage? {
        images[selectedFormat]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Format picker
                formatPicker
                    .padding(.top, 8)

                // Card preview
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: selectedFormat == .story ? 360 : 280)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut(duration: 0.2), value: selectedFormat)
                }

                Spacer()

                // Share buttons
                VStack(spacing: 12) {
                    // Instagram button with context-aware label
                    if ShareCardGenerator.isInstagramInstalled, let image = currentImage {
                        Button {
                            onShareToInstagram(image)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: instagramIcon)
                                    .font(.system(size: 22))
                                Text(instagramButtonLabel)
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
                if let image = currentImage {
                    ActivityViewController(activityItems: [image])
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        HStack(spacing: 0) {
            ForEach(ShareCardFormat.allCases, id: \.self) { format in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFormat = format
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: formatIcon(for: format))
                            .font(.system(size: 20))
                        Text(format.displayName)
                            .font(.lora(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedFormat == format ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedFormat == format
                            ? RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                            : nil
                    )
                }
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    private func formatIcon(for format: ShareCardFormat) -> String {
        switch format {
        case .story: return "rectangle.portrait"
        case .post: return "square"
        }
    }

    private var instagramIcon: String {
        switch selectedFormat {
        case .story: return "camera.circle.fill"
        case .post: return "square.grid.2x2.fill"
        }
    }

    private var instagramButtonLabel: String {
        switch selectedFormat {
        case .story: return "Share to Stories"
        case .post: return "Share to Feed"
        }
    }
}

/// Legacy single-image sheet for backward compatibility
struct ShareCardSheetLegacy: View {
    let image: UIImage
    let onShareToInstagram: () -> Void

    var body: some View {
        ShareCardSheet(
            images: [.story: image],
            onShareToInstagram: { _ in onShareToInstagram() }
        )
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
