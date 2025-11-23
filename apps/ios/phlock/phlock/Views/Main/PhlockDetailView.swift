import SwiftUI

struct PhlockDetailView: View {
    let phlock: GroupedPhlock
    @Binding var navigationPath: NavigationPath

    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var recipients: [PhlockRecipient] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading recipients...")
                    .font(.lora(size: 15))
            } else if let error = errorMessage {
                PhlockErrorView(message: error) {
                    Task { await loadRecipients() }
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        TrackHeaderView(phlock: phlock)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        SummaryMetricsView(phlock: phlock)
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recipients (\(recipients.count))")
                                .font(.lora(size: 20, weight: .bold))
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                ForEach(recipients) { recipient in
                                    RecipientRowView(recipient: recipient, navigationPath: $navigationPath)

                                    if recipient.id != recipients.last?.id {
                                        Divider()
                                            .padding(.leading, 76)
                                    }
                                }
                            }
                            .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 100) // Space for mini player
                }
            }
        }
        .navigationTitle("Phlock Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenSwipeBack()
        .task {
            await loadRecipients()
        }
        .refreshable {
            await loadRecipients()
        }
    }

    private func loadRecipients() async {
        guard let userId = authState.currentUser?.id else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Load recipients
            recipients = try await PhlockService.shared.getPhlockRecipients(trackId: phlock.trackId, userId: userId)

            print("✅ Loaded \(recipients.count) recipients for track \(phlock.trackId)")
        } catch {
            errorMessage = "Failed to load recipients: \(error.localizedDescription)"
            print("❌ Error loading recipients: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Track Header

struct TrackHeaderView: View {
    let phlock: GroupedPhlock
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Album Art
            if let albumArtUrl = phlock.albumArtUrl, let url = URL(string: albumArtUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 80, height: 80)
                .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                    )
            }

            // Track Info
            VStack(alignment: .leading, spacing: 6) {
                Text(phlock.trackName)
                    .font(.lora(size: 18, weight: .bold))
                    .lineLimit(2)

                Text(phlock.artistName)
                    .font(.lora(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("Last sent \(phlock.lastSentAt.shortRelativeTimeString())")
                    .font(.lora(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Summary Metrics

struct SummaryMetricsView: View {
    let phlock: GroupedPhlock
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Text("Engagement Summary")
                .font(.lora(size: 16, weight: .semiBold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                MetricBox(
                    icon: "paperplane.fill",
                    value: "\(phlock.recipientCount)",
                    label: "Sent to"
                )

                MetricBox(
                    icon: "play.circle.fill",
                    value: "\(Int(phlock.listenRate * 100))%",
                    label: "Listened"
                )

                MetricBox(
                    icon: "heart.fill",
                    value: "\(Int(phlock.saveRate * 100))%",
                    label: "Saved"
                )
            }
        }
        .padding(16)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
        .cornerRadius(16)
    }
}

struct MetricBox: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)

            Text(value)
                .font(.lora(size: 20, weight: .bold))

            Text(label)
                .font(.lora(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.08))
        .cornerRadius(12)
    }
}

// MARK: - Recipient Row

struct RecipientRowView: View {
    let recipient: PhlockRecipient
    @Binding var navigationPath: NavigationPath
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            navigationPath.append(PhlocksDestination.conversation(recipient.user))
        } label: {
            HStack(spacing: 12) {
                // Profile Photo
                if let profilePhotoUrl = recipient.user.profilePhotoUrl,
                   let url = URL(string: profilePhotoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                }

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipient.user.displayName)
                        .font(.lora(size: 16, weight: .semiBold))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Image(systemName: recipient.statusIcon)
                            .font(.system(size: 12))

                        Text(recipient.statusText)
                            .font(.lora(size: 13))
                    }
                    .foregroundColor(statusSwiftUIColor(recipient.statusColor))

                    if let message = recipient.message, !message.isEmpty {
                        Text("\"\(message)\"")
                            .font(.lora(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusSwiftUIColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Error View

struct PhlockErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error")
                .font(.lora(size: 20, weight: .semiBold))

            Text(message)
                .font(.lora(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                retry()
            }
            .font(.lora(size: 16, weight: .semiBold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// Preview removed due to complex navigationPath binding requirement
