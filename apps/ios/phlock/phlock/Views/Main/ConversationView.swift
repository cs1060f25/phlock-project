import SwiftUI

struct ConversationView: View {
    let otherUser: User

    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme

    @State private var shares: [Share] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedShareId: UUID?
    @State private var commentText: String = ""
    @State private var isAddingComment = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading conversation...")
                    .font(.nunitoSans(size: 15))
            } else if let error = errorMessage {
                ConversationErrorView(message: error) {
                    Task { await loadConversation() }
                }
            } else if shares.isEmpty {
                EmptyConversationView(otherUserName: otherUser.displayName)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(shares) { share in
                            ConversationShareCard(
                                share: share,
                                otherUser: otherUser,
                                isExpanded: expandedShareId == share.id,
                                onToggleExpand: {
                                    withAnimation {
                                        expandedShareId = expandedShareId == share.id ? nil : share.id
                                    }
                                }
                            )
                            .environmentObject(authState)
                            .environmentObject(playbackService)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 100) // Space for mini player
                }
            }
        }
        .navigationTitle(otherUser.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConversation()
        }
        .refreshable {
            await loadConversation()
        }
    }

    private func loadConversation() async {
        guard let currentUserId = authState.currentUser?.id else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            shares = try await ShareService.shared.getConversation(
                userId1: currentUserId,
                userId2: otherUser.id
            )
            print("✅ Loaded \(shares.count) shares in conversation")
        } catch {
            errorMessage = "Failed to load conversation: \(error.localizedDescription)"
            print("❌ Error loading conversation: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Conversation Share Card

struct ConversationShareCard: View {
    let share: Share
    let otherUser: User
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme

    @State private var comments: [ShareComment] = []
    @State private var commentText: String = ""
    @State private var isLoadingComments = false
    @State private var isAddingComment = false

    private var isSentByCurrentUser: Bool {
        share.senderId == authState.currentUser?.id
    }

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == share.trackId
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Share Card Header
            HStack(spacing: 12) {
                // Album Art
                if let albumArtUrl = share.albumArtUrl, let url = URL(string: albumArtUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                }

                // Track Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(share.trackName)
                        .font(.nunitoSans(size: 15, weight: .semiBold))
                        .lineLimit(1)

                    Text(share.artistName)
                        .font(.nunitoSans(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Direction indicator
                    HStack(spacing: 4) {
                        Image(systemName: isSentByCurrentUser ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text(isSentByCurrentUser ? "You sent" : "You received")
                            .font(.nunitoSans(size: 12))
                    }
                    .foregroundColor(isSentByCurrentUser ? .blue : .green)
                }

                Spacer()

                // Play Button
                Button {
                    handlePlayTap()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isCurrentTrack ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            // Message if present
            if let message = share.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(.nunitoSans(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            Divider()

            // Comments Toggle
            Button {
                onToggleExpand()
                if isExpanded && comments.isEmpty {
                    Task { await loadComments() }
                }
            } label: {
                HStack {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                    Text("Comments")
                        .font(.nunitoSans(size: 14))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded Comments Section
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()

                    if isLoadingComments {
                        ProgressView()
                            .padding()
                    } else if comments.isEmpty {
                        Text("No comments yet")
                            .font(.nunitoSans(size: 13))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(comments) { comment in
                            CommentRowView(comment: comment)
                            if comment.id != comments.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }

                    Divider()

                    // Add Comment Input
                    HStack(spacing: 8) {
                        TextField("Add a comment (280 char max)...", text: $commentText, axis: .vertical)
                            .font(.nunitoSans(size: 14))
                            .lineLimit(1...3)
                            .textFieldStyle(.plain)
                            .disabled(isAddingComment)

                        Button {
                            Task { await addComment() }
                        } label: {
                            if isAddingComment {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(commentText.isEmpty ? .gray : .blue)
                            }
                        }
                        .disabled(commentText.isEmpty || isAddingComment)
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.05))
                }
            }
        }
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func handlePlayTap() {
        let track = MusicItem(
            id: share.trackId,
            name: share.trackName,
            artistName: share.artistName,
            previewUrl: nil,
            albumArtUrl: share.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: share.trackId,
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )

        if isPlaying {
            playbackService.pause()
        } else {
            playbackService.play(track: track)
        }
    }

    private func loadComments() async {
        isLoadingComments = true
        do {
            comments = try await ShareService.shared.getComments(shareId: share.id)
            print("✅ Loaded \(comments.count) comments for share")
        } catch {
            print("❌ Error loading comments: \(error)")
        }
        isLoadingComments = false
    }

    private func addComment() async {
        guard !commentText.isEmpty,
              commentText.count <= 280,
              let currentUserId = authState.currentUser?.id else {
            return
        }

        isAddingComment = true

        do {
            let commentId = try await ShareService.shared.addComment(
                shareId: share.id,
                userId: currentUserId,
                text: commentText
            )

            // Reload comments to show the new one
            await loadComments()

            // Clear input
            await MainActor.run {
                commentText = ""
            }

            print("✅ Added comment: \(commentId)")
        } catch {
            print("❌ Error adding comment: \(error)")
        }

        isAddingComment = false
    }
}

// MARK: - Comment Row

struct CommentRowView: View {
    let comment: ShareComment
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar (placeholder)
            Image(systemName: "person.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.user?.displayName ?? "Unknown")
                        .font(.nunitoSans(size: 14, weight: .semiBold))

                    Text(timeAgo(from: comment.createdAt))
                        .font(.nunitoSans(size: 12))
                        .foregroundColor(.secondary)
                }

                Text(comment.commentText)
                    .font(.nunitoSans(size: 14))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if seconds < 60 {
            return "now"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else if hours < 24 {
            return "\(Int(hours))h"
        } else if days < 7 {
            return "\(Int(days))d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Empty State

struct EmptyConversationView: View {
    let otherUserName: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("💬")
                    .font(.system(size: 64))

                Text("No conversation yet")
                    .font(.nunitoSans(size: 28, weight: .bold))

                Text("Start sharing music with \(otherUserName)\nto begin your conversation!")
                    .font(.nunitoSans(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(32)
            .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
            .cornerRadius(20)
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Error View

struct ConversationErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error")
                .font(.nunitoSans(size: 20, weight: .semiBold))

            Text(message)
                .font(.nunitoSans(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                retry()
            }
            .font(.nunitoSans(size: 16, weight: .semiBold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// Preview removed due to complex User model initialization
