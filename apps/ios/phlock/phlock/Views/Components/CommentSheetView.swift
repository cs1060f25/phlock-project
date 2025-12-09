import SwiftUI

/// Bottom sheet for viewing and posting comments on a share
struct CommentSheetView: View {
    let share: Share
    @Binding var isPresented: Bool

    @EnvironmentObject private var authState: AuthenticationState
    @StateObject private var socialService = SocialEngagementService.shared
    @State private var comments: [ShareComment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var commentText = ""
    @State private var replyingTo: ShareComment?
    @State private var isSending = false
    @State private var currentUserId: UUID?
    @State private var showSendError = false
    @State private var sendErrorMessage = ""

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if comments.isEmpty {
                    emptyView
                } else {
                    commentsList
                }

                Divider()

                // Input field
                commentInputField
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            // Get current user ID from auth state
            currentUserId = authState.currentUser?.id
            await loadComments()
        }
        .alert("Unable to Send Comment", isPresented: $showSendError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendErrorMessage)
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading comments...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await loadComments() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No comments yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Be the first to comment!")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
    }

    private var commentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(rootComments) { comment in
                    // Root comment
                    ShareCommentRowView(
                        comment: comment,
                        isReply: false,
                        currentUserId: currentUserId,
                        onReply: {
                            replyingTo = comment
                            isInputFocused = true
                        },
                        onDelete: {
                            deleteComment(comment)
                        }
                    )

                    // Replies to this comment
                    let replies = getReplies(for: comment.id)
                    if !replies.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(replies) { reply in
                                ShareCommentRowView(
                                    comment: reply,
                                    isReply: true,
                                    currentUserId: currentUserId,
                                    onReply: {
                                        // Reply to parent comment, not the reply itself
                                        replyingTo = comment
                                        isInputFocused = true
                                    },
                                    onDelete: {
                                        deleteComment(reply)
                                    }
                                )
                            }
                        }
                        .padding(.leading, 48)
                    }
                }
            }
            .padding()
        }
    }

    private var commentInputField: some View {
        VStack(spacing: 8) {
            // Reply indicator
            if let replyingTo = replyingTo {
                HStack {
                    Text("Replying to \(replyingTo.user?.displayName ?? "comment")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        self.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(spacing: 12) {
                // Text field
                TextField("Add a comment...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                // Send button
                Button {
                    Task { await sendComment() }
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(canSend ? .blue : .secondary)
                            .frame(width: 32, height: 32)
                    }
                }
                .disabled(!canSend || isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Computed Properties

    private var rootComments: [ShareComment] {
        comments.filter { $0.parentCommentId == nil }
    }

    private func getReplies(for commentId: UUID) -> [ShareComment] {
        comments.filter { $0.parentCommentId == commentId }
    }

    private var canSend: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        errorMessage = nil

        do {
            comments = try await socialService.fetchComments(for: share.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func sendComment() async {
        guard canSend else { return }

        isSending = true
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var newComment = try await socialService.addComment(
                to: share.id,
                text: text,
                parentCommentId: replyingTo?.id
            )

            // Populate user data from current user (the DB response doesn't include it)
            if let currentUser = authState.currentUser {
                newComment.user = currentUser
            }

            // Add to local list
            comments.append(newComment)

            // Update comment count in the social service
            socialService.incrementCommentCount(for: share.id)

            // Clear input
            commentText = ""
            replyingTo = nil
            isInputFocused = false

            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()

        } catch {
            // Show error alert to user
            sendErrorMessage = error.localizedDescription
            showSendError = true
            print("Failed to send comment: \(error)")
        }

        isSending = false
    }

    private func deleteComment(_ comment: ShareComment) {
        Task {
            do {
                try await socialService.deleteComment(comment.id)
                comments.removeAll { $0.id == comment.id }

                // Update comment count in the social service
                socialService.decrementCommentCount(for: share.id)

                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } catch {
                sendErrorMessage = "Failed to delete comment: \(error.localizedDescription)"
                showSendError = true
                print("Failed to delete comment: \(error)")
            }
        }
    }
}

// MARK: - Share Comment Row View

private struct ShareCommentRowView: View {
    let comment: ShareComment
    let isReply: Bool
    let currentUserId: UUID?
    let onReply: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: comment.user?.profilePhotoUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Text(comment.user?.displayName.prefix(1).uppercased() ?? "?")
                            .font(.system(size: isReply ? 10 : 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: isReply ? 28 : 36, height: isReply ? 28 : 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                // Username and time
                HStack(spacing: 6) {
                    Text(comment.user?.displayName ?? "User")
                        .font(.system(size: isReply ? 13 : 14, weight: .semibold))

                    Text(comment.timeAgo)
                        .font(.system(size: isReply ? 11 : 12))
                        .foregroundColor(.secondary)
                }

                // Comment text
                Text(comment.commentText)
                    .font(.system(size: isReply ? 13 : 14))
                    .fixedSize(horizontal: false, vertical: true)

                // Action buttons
                HStack(spacing: 16) {
                    Button("Reply") {
                        onReply()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                    // Delete button (only for own comments)
                    if comment.userId == currentUserId {
                        Button("Delete") {
                            showDeleteAlert = true
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red.opacity(0.8))
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .alert("Delete Comment", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
}

// MARK: - Preview

#Preview {
    CommentSheetView(
        share: Share(
            id: UUID(),
            senderId: UUID(),
            recipientId: UUID(),
            trackId: "test",
            trackName: "Test Song",
            artistName: "Test Artist",
            isDailySong: true
        ),
        isPresented: .constant(true)
    )
}
