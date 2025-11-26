import SwiftUI

/// Horizontal friend selector bar with search and smart ranking
/// Displayed at the top of the full-screen player
struct FriendSelectorBar: View {
    @EnvironmentObject var authState: AuthenticationState
    let track: MusicItem
    @Binding var selectedFriends: Set<UUID>
    let onSelectionChange: (Set<UUID>) -> Void

    @State private var allFriends: [User] = []
    @State private var rankedFriends: [User] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    @Environment(\.colorScheme) var colorScheme

    // Computed properties
    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return rankedFriends
        } else {
            return allFriends.filter { friend in
                friend.displayName.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.dmSans(size: 10))

                TextField("Search friends", text: $searchText)
                    .font(.dmSans(size: 10))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.dmSans(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
            )
            .padding(.horizontal, 16)

            // Friends horizontal scroll
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.vertical, 20)
            } else if filteredFriends.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                        .font(.dmSans(size: 20, weight: .semiBold))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No friends yet" : "No friends found")
                        .font(.dmSans(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(filteredFriends, id: \.id) { friend in
                            FriendSelectorItem(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id)
                            ) {
                                toggleFriendSelection(friend)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 90)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .task {
            await loadAndRankFriends()
        }
    }

    private func loadAndRankFriends() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            // Load all friends
            allFriends = try await UserService.shared.getFriends(for: currentUser.id)

            // Rank friends using FriendRankingEngine
            let rankedFriendIds = await FriendRankingEngine.rankFriends(
                friends: allFriends,
                currentUser: currentUser,
                track: track,
                limit: allFriends.count // Get all ranked
            )

            // Reorder friends based on ranking
            rankedFriends = rankedFriendIds.compactMap { friendId in
                allFriends.first { $0.id == friendId }
            }

            isLoading = false
        } catch {
            print("❌ Failed to load friends: \(error)")
            isLoading = false
        }
    }

    private func toggleFriendSelection(_ friend: User) {
        // Haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedFriends.contains(friend.id) {
                selectedFriends.remove(friend.id)
            } else {
                selectedFriends.insert(friend.id)
            }
        }

        // Notify parent of selection change
        onSelectionChange(selectedFriends)
    }
}

// MARK: - Friend Selector Item

struct FriendSelectorItem: View {
    let friend: User
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isPressing = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar
                Group {
                    if let photoUrl = friend.profilePhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            FriendInitialsView(displayName: friend.displayName)
                        }
                        .frame(width: 55, height: 55)
                        .clipShape(Circle())
                    } else {
                        FriendInitialsView(displayName: friend.displayName)
                            .frame(width: 55, height: 55)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )

                // Selection checkmark
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.dmSans(size: 10))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Name
            Text(friend.displayName)
                .font(.dmSans(size: 10))
                .lineLimit(1)
                .foregroundColor(.primary)
                .frame(width: 60)
        }
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressing)
        .onTapGesture {
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressing {
                        isPressing = true
                    }
                }
                .onEnded { _ in
                    isPressing = false
                }
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedFriends: Set<UUID> = []

        var body: some View {
            VStack {
                FriendSelectorBar(
                    track: MusicItem(
                        id: "123",
                        name: "Jealous Type",
                        artistName: "Doja Cat",
                        previewUrl: nil,
                        albumArtUrl: nil,
                        isrc: nil,
                        playedAt: nil,
                        spotifyId: nil,
                        appleMusicId: nil,
                        popularity: nil,
                        followerCount: nil
                    ),
                    selectedFriends: $selectedFriends,
                    onSelectionChange: { selected in
                        print("Selected friends: \(selected.count)")
                    }
                )
                .environmentObject(AuthenticationState())

                Spacer()
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
