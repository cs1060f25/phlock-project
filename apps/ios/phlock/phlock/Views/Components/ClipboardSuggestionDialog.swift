//
//  ClipboardSuggestionDialog.swift
//  phlock
//
//  Modal dialog for sharing a track detected from clipboard
//

import SwiftUI

struct ClipboardSuggestionDialog: View {
    let track: MusicItem
    let onShare: (String) -> Void  // Passes the note
    let onDismiss: () -> Void

    @State private var note: String = ""
    @FocusState private var isNoteFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("share this song?")
                    .font(.lora(size: 18, weight: .semiBold))

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Album Art
            if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        albumArtPlaceholder
                    case .empty:
                        albumArtPlaceholder
                            .overlay(ProgressView())
                    @unknown default:
                        albumArtPlaceholder
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
            } else {
                albumArtPlaceholder
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Track Info
            VStack(spacing: 6) {
                Text(track.name)
                    .font(.lora(size: 20, weight: .semiBold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(track.artistName ?? "Unknown Artist")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Note Field
            VStack(alignment: .leading, spacing: 8) {
                TextField("add optional message...", text: $note)
                    .font(.lora(size: 15))
                    .textFieldStyle(.plain)
                    .focused($isNoteFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.08))
                    .cornerRadius(12)
                    .submitLabel(.done)
                    .onSubmit {
                        isNoteFocused = false
                    }
                    .onChange(of: note) { newValue in
                        // Limit to 80 characters
                        if newValue.count > 80 {
                            note = String(newValue.prefix(80))
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Action Buttons
            VStack(spacing: 12) {
                Button(action: { onShare(note) }) {
                    Text("share as today's song")
                        .font(.lora(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .cornerRadius(14)
                }

                // Hide "not now" when keyboard is shown to save space
                if !isNoteFocused {
                    Button(action: onDismiss) {
                        Text("not now")
                            .font(.lora(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var albumArtPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

// MARK: - Preview

#Preview {
    ClipboardSuggestionDialog(
        track: MusicItem(
            id: "123",
            name: "Levitating",
            artistName: "Dua Lipa",
            albumArtUrl: "https://i.scdn.co/image/ab67616d0000b2734052427d2913ab1a40c3b3c8"
        ),
        onShare: { note in print("Sharing with note: \(note)") },
        onDismiss: { print("Dismissed") }
    )
}
