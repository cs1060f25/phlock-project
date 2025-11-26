import SwiftUI
import UIKit

/// Context-aware share sheet with a limited set of third-party options
struct ShareOptionsSheet: View {
    enum Context {
        case fullPlayer
        case miniPlayer
        case overlay
    }

    let track: MusicItem
    let shareURL: URL?
    let context: Context
    let onDismiss: () -> Void
    let onCopy: (URL) -> Void
    let onOpen: (URL) -> Void
    let onFallback: (String) -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.miniPlayerBottomInset) private var miniPlayerBottomInset
    @State private var dragOffset: CGFloat = 0

    struct Option: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let systemImage: String
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 6)

            Text("Share")
                .font(.lora(size: 10, weight: .medium))
                .foregroundColor(.primary)

            VStack(spacing: 10) {
                ForEach(options) { option in
                    Button(action: option.action) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(chipFill)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: option.systemImage)
                                        .font(.lora(size: 10, weight: .medium))
                                        .foregroundColor(.primary)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.lora(size: 10))
                                    .foregroundColor(.primary)
                                if let subtitle = option.subtitle {
                                    Text(subtitle)
                                        .font(.lora(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.lora(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(surfaceStroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onDismiss) {
                Text("Close")
                    .font(.lora(size: 10))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(surfaceStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
        .padding(.top, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(surfaceStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 18, x: 0, y: -8)
        )
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private var horizontalPadding: CGFloat {
        switch context {
        case .fullPlayer: return 14
        case .miniPlayer: return 10
        case .overlay: return 14
        }
    }

    private var bottomPadding: CGFloat {
        let base: CGFloat
        switch context {
        case .fullPlayer: base = 6
        case .miniPlayer: base = 6
        case .overlay: base = 8
        }
        let inset = max(0, miniPlayerBottomInset)
        // Keep sheet above mini player when present
        return base + inset
    }

    private var surface: Color {
        Color(.systemBackground)
    }

    private var surfaceStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.1)
    }

    private var chipFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08)
    }

    private var options: [Option] {
        [
            Option(title: "Copy Link", subtitle: nil, systemImage: "link") { copyLink() },
            Option(title: "Messages", subtitle: "Share via SMS/iMessage", systemImage: "message.fill") { openMessages() },
            Option(title: "WhatsApp", subtitle: nil, systemImage: "bubble.left.and.bubble.right.fill") { openWhatsApp() },
            Option(title: "Instagram", subtitle: "Share with friends", systemImage: "camera.fill") { openInstagram() },
            Option(title: "Add to Story", subtitle: "Instagram stories", systemImage: "sparkles.rectangle.stack") { openInstagramStory() }
        ]
    }

    private func copyLink() {
        guard let shareURL else {
            onFallback("No shareable link available")
            return
        }
        onCopy(shareURL)
    }

    private func openMessages() {
        guard let shareURL else {
            onFallback("No shareable link available")
            return
        }
        if let url = URL(string: "sms:&body=\(shareURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            onOpen(url)
        } else {
            onFallback("Unable to open Messages")
        }
    }

    private func openWhatsApp() {
        guard let shareURL else {
            onFallback("No shareable link available")
            return
        }
        if let url = URL(string: "whatsapp://send?text=\(shareURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            onOpen(url)
        } else {
            onFallback("WhatsApp not available")
        }
    }

    private func openInstagram() {
        guard let shareURL else {
            onFallback("No shareable link available")
            return
        }
        if let url = URL(string: "instagram://share?text=\(shareURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            onOpen(url)
        } else {
            onFallback("Instagram not available")
        }
    }

    private func openInstagramStory() {
        guard let shareURL else {
            onFallback("No shareable link available")
            return
        }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.contentURL": shareURL.absoluteString
        ]
        UIPasteboard.general.setItems([pasteboardItems], options: [:])

        if let url = URL(string: "instagram-stories://share") {
            onOpen(url)
        } else {
            onFallback("Instagram Stories not available")
        }
    }
}

// MARK: - Share Link Helper

enum ShareLinkBuilder {
    static func url(for track: MusicItem) -> URL? {
        if let spotifyId = track.spotifyId ?? track.id.nonEmptyID() {
            return URL(string: "https://open.spotify.com/track/\(spotifyId)")
        }

        if let appleId = track.appleMusicId {
            return URL(string: "https://music.apple.com/song/\(appleId)")
        }

        if let preview = track.previewUrl, let url = URL(string: preview) {
            return url
        }

        return nil
    }
}

private extension String {
    func nonEmptyID() -> String? {
        isEmpty ? nil : self
    }
}
