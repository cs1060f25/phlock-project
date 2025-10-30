import SwiftUI

/// A horizontal scrollable bar of friend avatars for ultra-fast song sharing
/// Friends are smartly ordered based on music taste, recent sharing, and engagement
struct QuickSendBar: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    let track: MusicItem
    let onSendComplete: ([User]) -> Void

    @State private var rankedFriends: [User] = []
    @State private var isLoading = true
    @State private var selectedFriends: Set<UUID> = []
    @State private var showFullFriendPicker = false
    @State private var allFriends: [User] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("send to")
                .font(.nunitoSans(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.leading, 16)

            if isLoading {
                // Loading state
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, 16)
            } else if rankedFriends.isEmpty {
                // Empty state
                Text("Add friends to start sharing")
                    .font(.nunitoSans(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                // Friend avatars scrollable bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Ranked friends
                        ForEach(rankedFriends, id: \.id) { friend in
                            FriendAvatarButton(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                showMusicMatch: shouldHighlightMusicMatch(friend: friend)
                            ) {
                                toggleFriendSelection(friend)
                            }
                        }

                        // "More" button to show full friend picker
                        if allFriends.count > rankedFriends.count {
                            MoreFriendsButton {
                                showFullFriendPicker = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Send button (only show if friends are selected)
            if !selectedFriends.isEmpty {
                Button {
                    sendToSelectedFriends()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("send to \(selectedFriends.count) friend\(selectedFriends.count == 1 ? "" : "s")")
                            .font(.nunitoSans(size: 15, weight: .semiBold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .task {
            await loadRankedFriends()
        }
        .sheet(isPresented: $showFullFriendPicker) {
            FullFriendPickerSheet(
                friends: allFriends,
                selectedFriends: $selectedFriends,
                onDone: { selected in
                    showFullFriendPicker = false
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func loadRankedFriends() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            // Get all friends first
            allFriends = try await UserService.shared.getFriends(for: currentUser.id)

            // Get ranked suggestions (top 5)
            rankedFriends = await FriendRankingEngine.getQuickSuggestions(
                currentUser: currentUser,
                track: track,
                limit: 5
            )

            isLoading = false
        } catch {
            print("❌ Failed to load ranked friends: \(error)")
            isLoading = false
        }
    }

    private func toggleFriendSelection(_ friend: User) {
        if selectedFriends.contains(friend.id) {
            selectedFriends.remove(friend.id)
        } else {
            selectedFriends.insert(friend.id)
        }
    }

    private func shouldHighlightMusicMatch(friend: User) -> Bool {
        // Check if friend's top artists include the track's artist
        guard let trackArtist = track.artistName,
              let friendPlatformData = friend.platformData,
              let friendTopArtists = friendPlatformData.topArtists else {
            return false
        }

        return friendTopArtists.contains { artist in
            artist.name.lowercased() == trackArtist.lowercased()
        }
    }

    private func sendToSelectedFriends() {
        guard let currentUser = authState.currentUser else { return }

        let selectedFriendUsers = allFriends.filter { selectedFriends.contains($0.id) }

        Task {
            do {
                _ = try await ShareService.shared.createShare(
                    track: track,
                    recipients: Array(selectedFriends),
                    message: nil,
                    senderId: currentUser.id
                )

                // Call completion handler
                await MainActor.run {
                    onSendComplete(selectedFriendUsers)
                    // Reset selection
                    selectedFriends.removeAll()
                }
            } catch {
                print("❌ Failed to send shares: \(error)")
            }
        }
    }
}

// MARK: - Friend Avatar Button

struct FriendAvatarButton: View {
    let friend: User
    let isSelected: Bool
    let showMusicMatch: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Avatar
                    if let photoUrl = friend.profilePhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            FriendInitialsView(displayName: friend.displayName)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        FriendInitialsView(displayName: friend.displayName)
                            .frame(width: 50, height: 50)
                    }

                    // Selection indicator
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 2, y: -2)
                    }

                    // Music match indicator
                    if showMusicMatch && !isSelected {
                        Circle()
                            .fill(Color.purple.opacity(0.9))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2.5)
                )

                // Name
                Text(friend.displayName)
                    .font(.nunitoSans(size: 11))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friend Initials View

struct FriendInitialsView: View {
    let displayName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))

            Text(displayName.prefix(1).uppercased())
                .font(.nunitoSans(size: 20, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - More Friends Button

struct MoreFriendsButton: View {
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Text("more")
                    .font(.nunitoSans(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full Friend Picker Sheet

struct FullFriendPickerSheet: View {
    let friends: [User]
    @Binding var selectedFriends: Set<UUID>
    let onDone: (Set<UUID>) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            List {
                ForEach(friends, id: \.id) { friend in
                    Button {
                        if selectedFriends.contains(friend.id) {
                            selectedFriends.remove(friend.id)
                        } else {
                            selectedFriends.insert(friend.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Avatar
                            if let photoUrl = friend.profilePhotoUrl, let url = URL(string: photoUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    FriendInitialsView(displayName: friend.displayName)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                FriendInitialsView(displayName: friend.displayName)
                                    .frame(width: 40, height: 40)
                            }

                            // Name
                            Text(friend.displayName)
                                .font(.nunitoSans(size: 16))
                                .foregroundColor(.primary)

                            Spacer()

                            // Checkmark
                            if selectedFriends.contains(friend.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 22))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone(selectedFriends)
                        dismiss()
                    }
                    .disabled(selectedFriends.isEmpty)
                }
            }
        }
    }
}

#Preview {
    QuickSendBar(
        track: MusicItem(
            id: "123",
            name: "Test Track",
            artistName: "Test Artist",
            previewUrl: nil,
            albumArtUrl: nil,
            isrc: nil,
            playedAt: nil,
            spotifyId: nil,
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        ),
        onSendComplete: { _ in }
    )
    .environmentObject(AuthenticationState())
}
