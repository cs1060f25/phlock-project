import SwiftUI

// Storage for selected tracks per conversation
class ConversationSelectionStore {
    static let shared = ConversationSelectionStore()
    private var selections: [UUID: (track: MusicItem, message: String)] = [:]

    func store(track: MusicItem?, message: String, for userId: UUID) {
        if let track = track {
            selections[userId] = (track, message)
        } else {
            selections.removeValue(forKey: userId)
        }
    }

    func retrieve(for userId: UUID) -> (track: MusicItem, message: String)? {
        return selections[userId]
    }

    func clear(for userId: UUID) {
        selections.removeValue(forKey: userId)
    }
}

struct ConversationView: View {
    let otherUser: User

    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var shares: [Share] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedShareId: UUID?
    @State private var commentText: String = ""
    @State private var isAddingComment = false

    // Search and send functionality
    @State private var searchQuery: String = ""
    @State private var searchResults: [MusicItem] = []
    @State private var selectedTrack: MusicItem?
    @State private var messageText: String = ""
    @State private var isSearching = false
    @State private var isSending = false
    @State private var searchResultsFrame: CGRect? = nil

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 12) {
                    WaveformLoadingView(barCount: 5, color: .blue)
                    Text("Loading conversation...")
                        .font(.lora(size: 15))
                }
                .frame(maxHeight: .infinity)
            } else if let error = errorMessage {
                ConversationErrorView(message: error) {
                    Task { await loadConversation() }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if shares.isEmpty {
                            VStack(spacing: 12) {
                                Text("No messages yet")
                                    .font(.lora(size: 18, weight: .semiBold))
                                Text("Search for a song below to start the conversation!")
                                    .font(.lora(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(shares) { share in
                                HStack(alignment: .bottom, spacing: 8) {
                                    if share.senderId != authState.currentUser?.id {
                                        if let profilePhotoUrl = otherUser.profilePhotoUrl,
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
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                                .frame(width: 32, height: 32)
                                        }

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
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7)

                                        Spacer(minLength: 0)
                                    } else {
                                        Spacer(minLength: 0)

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
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 100) // Space for mini player
                }
                .scrollDismissesKeyboard(.never)
            }
        }
        .disableGlobalKeyboardDismiss(shouldKeepKeyboardActive)
        .coordinateSpace(name: "ConversationRoot")
        .safeAreaInset(edge: .bottom) {
            ConversationSearchBar(
                searchQuery: $searchQuery,
                searchResults: $searchResults,
                selectedTrack: $selectedTrack,
                messageText: $messageText,
                isSearching: $isSearching,
                isSending: $isSending,
                otherUser: otherUser,
                onSend: { track, message in
                    await sendTrack(track: track, message: message)
                }
            )
            .environmentObject(authState)
            .environmentObject(playbackService)
            .background(
                Color(UIColor.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .navigationTitle(otherUser.displayName)
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("ConversationRoot"))
                .onEnded { value in
                    guard shouldKeepKeyboardActive else { return }
                    if shouldDismissKeyboard(at: value.startLocation) {
                        hideKeyboard()
                    }
                }
        )
        .task {
            await loadConversation()
        }
        .refreshable {
            await loadConversation()
        }
        .onAppear {
            // Restore any saved selection for this conversation
            if let saved = ConversationSelectionStore.shared.retrieve(for: otherUser.id) {
                selectedTrack = saved.track
                messageText = saved.message
            }
        }
        .onDisappear {
            if !playbackService.shouldShowMiniPlayer && playbackService.isPlaying {
                playbackService.pause()
            }

            ConversationSelectionStore.shared.store(
                track: selectedTrack,
                message: messageText,
                for: otherUser.id
            )

            navigationState.isFabHidden = false
        }
        .onPreferenceChange(SearchResultsFramePreferenceKey.self) { frame in
            searchResultsFrame = frame
        }
        .onAppear {
            navigationState.isFabHidden = true
        }
        .onChange(of: searchResults.count) { newCount in
            if newCount == 0 {
                searchResultsFrame = nil
            }
        }
    }

    private var shouldKeepKeyboardActive: Bool {
        !searchResults.isEmpty && searchQuery.count >= 2 && selectedTrack == nil
    }

    private func shouldDismissKeyboard(at point: CGPoint) -> Bool {
        if shouldKeepKeyboardActive {
            guard let frame = searchResultsFrame else { return false }
            return !frame.contains(point)
        }
        return true
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    private func sendTrack(track: MusicItem, message: String?) async {
        guard let currentUserId = authState.currentUser?.id else { return }

        isSending = true

        // Stop any playing preview
        await MainActor.run {
            playbackService.stopPlayback()
        }

        do {
            _ = try await ShareService.shared.createShare(
                track: track,
                recipients: [otherUser.id],
                message: message?.isEmpty == false ? message : nil,
                senderId: currentUserId
            )

            // Reload conversation to show the new message
            await loadConversation()

            // Clear the search state
            await MainActor.run {
                selectedTrack = nil
                messageText = ""
                searchQuery = ""
                searchResults = []
            }

            // Clear saved selection since we've sent it
            ConversationSelectionStore.shared.clear(for: otherUser.id)

            print("✅ Sent track to \(otherUser.displayName)")
        } catch {
            print("❌ Error sending track: \(error)")
        }

        isSending = false
    }
}

// MARK: - Conversation Search Bar

struct ConversationSearchBar: View {
    @Binding var searchQuery: String
    @Binding var searchResults: [MusicItem]
    @Binding var selectedTrack: MusicItem?
    @Binding var messageText: String
    @Binding var isSearching: Bool
    @Binding var isSending: Bool
    let otherUser: User
    let onSend: (MusicItem, String?) async -> Void

    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search results dropdown
            if !searchResults.isEmpty && searchQuery.count >= 2 && selectedTrack == nil {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchResults.prefix(5)), id: \.id) { track in
                            HStack(spacing: 12) {
                                // Album art
                                if let albumArtUrl = track.albumArtUrl, let url = URL(string: albumArtUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(4)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.name)
                                        .font(.lora(size: 14, weight: .semiBold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(track.artistName ?? "Unknown")
                                        .font(.lora(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                // Play button
                                PlayPauseButton(isPlaying: isTrackPlaying(track)) {
                                    handlePlayPreview(track: track)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.05))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Stop any playing preview
                                playbackService.stopPlayback()
                                selectedTrack = track
                                searchQuery = ""
                                searchResults = []
                                isSearchFocused = false
                            }

                            if track.id != searchResults.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SearchResultsFramePreferenceKey.self,
                            value: proxy.frame(in: .named("ConversationRoot"))
                        )
                    }
                )
                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .scrollDismissesKeyboard(.never)
            }

            Divider()

            // Selected track preview (if any)
            if let track = selectedTrack {
                HStack(spacing: 12) {
                    // Album art
                    if let albumArtUrl = track.albumArtUrl, let url = URL(string: albumArtUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.name)
                            .font(.lora(size: 14, weight: .semiBold))
                            .lineLimit(1)
                        Text(track.artistName ?? "Unknown")
                            .font(.lora(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    PlayPauseButton(isPlaying: isTrackPlaying(track)) {
                        handlePlayPreview(track: track)
                    }

                    Button {
                        selectedTrack = nil
                        messageText = ""
                        // Clear saved selection when user cancels
                        ConversationSelectionStore.shared.clear(for: otherUser.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))

                Divider()
            }

            // Search / Message input bar
            HStack(spacing: 12) {
                if selectedTrack == nil {
                    // Search mode
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))

                        TextField("search for music...", text: $searchQuery)
                            .font(.lora(size: 15))
                            .focused($isSearchFocused)
                            .onChange(of: searchQuery) { newValue in
                                if newValue.count >= 2 {
                                    Task { await performSearch(query: newValue) }
                                } else {
                                    searchResults = []
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .cornerRadius(20)

                    // Greyed out send button when no track
                    Image(systemName: "paperplane")
                        .foregroundColor(.gray.opacity(0.3))
                        .font(.system(size: 20))
                } else {
                    // Message mode (track selected)
                    TextField("add a message (optional)...", text: $messageText, axis: .vertical)
                        .font(.lora(size: 15))
                        .lineLimit(1...3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(20)

                    // Active send button
                    Button {
                        Task {
                            await onSend(selectedTrack!, messageText.isEmpty ? nil : messageText)
                        }
                    } label: {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }

    private func performSearch(query: String) async {
        guard query.count >= 2 else { return }

        isSearching = true

        do {
            let result = try await SearchService.shared.search(
                query: query,
                type: .tracks,
                platformType: authState.currentUser?.resolvedPlatformType ?? .spotify
            )
            await MainActor.run {
                searchResults = result.tracks
            }
        } catch {
            print("❌ Search error: \(error)")
        }

        isSearching = false
    }

    private func isTrackPlaying(_ track: MusicItem) -> Bool {
        return playbackService.currentTrack?.id == track.id && playbackService.isPlaying
    }

    private func handlePlayPreview(track: MusicItem) {
        // Check if this is the same track that's currently loaded
        let isSameTrack = playbackService.currentTrack?.id == track.id

        if isSameTrack && playbackService.isPlaying {
            // Same track is playing -> pause it
            playbackService.pause()
        } else if isSameTrack && !playbackService.isPlaying {
            // Same track is paused -> ensure mini player stays hidden and resume
            playbackService.shouldShowMiniPlayer = false
            playbackService.resume()
        } else {
            // Different track or no track loaded -> play fresh
            playbackService.play(track: track, showMiniPlayer: false)
        }
    }
}

private struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(isPlaying ? .blue : .secondary)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    action()
                }
            )
            .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")
            .accessibilityAddTraits(.isButton)
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
                        .font(.lora(size: 15, weight: .semiBold))
                        .lineLimit(1)

                    Text(share.artistName)
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Timestamp
                    Text(timeAgo(from: share.createdAt))
                        .font(.lora(size: 11))
                        .foregroundColor(.secondary)
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
                Text(message)
                    .font(.lora(size: 14))
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
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                    Text("Comments")
                        .font(.lora(size: 14))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
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
                            .font(.lora(size: 13))
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
                            .font(.lora(size: 14))
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
        .background(
            isSentByCurrentUser
                ? Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.15)
                : Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSentByCurrentUser
                        ? Color.blue.opacity(0.3)
                        : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
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

        let isSameTrack = playbackService.currentTrack?.id == track.id

        if isSameTrack && playbackService.isPlaying {
            playbackService.pause()
        } else if isSameTrack && !playbackService.isPlaying {
            // Same track is paused -> show mini player on resume for sent tracks
            playbackService.shouldShowMiniPlayer = true
            playbackService.resume()
        } else {
            // Playing sent tracks should show the mini player
            playbackService.play(track: track, showMiniPlayer: true)
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

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if seconds < 60 {
            return "now"
        } else if minutes < 60 {
            return "\(Int(minutes))m ago"
        } else if hours < 24 {
            return "\(Int(hours))h ago"
        } else if days < 7 {
            return "\(Int(days))d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
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
                        .font(.lora(size: 14, weight: .semiBold))

                    Text(timeAgo(from: comment.createdAt))
                        .font(.lora(size: 12))
                        .foregroundColor(.secondary)
                }

                Text(comment.commentText)
                    .font(.lora(size: 14))
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
                    .font(.lora(size: 28, weight: .bold))

                Text("Start sharing music with \(otherUserName)\nto begin your conversation!")
                    .font(.lora(size: 15))
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

// Preview removed due to complex User model initialization

private struct SearchResultsFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}
