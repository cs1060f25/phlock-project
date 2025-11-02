import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSegment = 0
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var friends: [User] = []
    @State private var pendingRequests: [FriendshipWithUser] = []
    @State private var isSearching = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("View", selection: $selectedSegment) {
                    Text("friends").tag(0)
                    Text("search").tag(1)
                    Text("requests").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if selectedSegment == 0 {
                    // Friends List
                    FriendsListView(friends: friends, isLoading: isLoading)
                } else if selectedSegment == 1 {
                    // Search
                    SearchUsersView(
                        searchText: $searchText,
                        searchResults: $searchResults,
                        isSearching: $isSearching
                    )
                } else {
                    // Pending Requests
                    PendingRequestsView(
                        pendingRequests: pendingRequests,
                        isLoading: isLoading,
                        onAccept: { friendship in
                            Task { await acceptRequest(friendship) }
                        },
                        onReject: { friendship in
                            Task { await rejectRequest(friendship) }
                        }
                    )
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let currentUser = authState.currentUser else { return }

        isLoading = true

        do {
            async let friendsTask = UserService.shared.getFriends(for: currentUser.id)
            async let requestsTask = UserService.shared.getPendingRequests(for: currentUser.id)

            friends = try await friendsTask
            pendingRequests = try await requestsTask
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func acceptRequest(_ friendshipWithUser: FriendshipWithUser) async {
        guard let currentUser = authState.currentUser else { return }

        do {
            try await UserService.shared.acceptFriendRequest(friendshipId: friendshipWithUser.friendship.id)

            // Clear cache to ensure fresh data
            UserService.shared.clearCache(for: currentUser.id)

            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func rejectRequest(_ friendshipWithUser: FriendshipWithUser) async {
        guard let currentUser = authState.currentUser else { return }

        do {
            try await UserService.shared.rejectFriendRequest(friendshipId: friendshipWithUser.friendship.id)

            // Clear cache to ensure fresh data
            UserService.shared.clearCache(for: currentUser.id)

            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Friends List View

struct FriendsListView: View {
    let friends: [User]
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friends.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("no friends yet")
                        .font(.nunitoSans(size: 20, weight: .semiBold))

                    Text("search for users to add friends")
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(friends) { friend in
                    NavigationLink(destination: UserProfileView(user: friend)) {
                        UserRow(user: friend)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Search Users View

struct SearchUsersView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Binding var searchText: String
    @Binding var searchResults: [User]
    @Binding var isSearching: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("search users...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { oldValue, newValue in
                        Task {
                            await performSearch()
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
            .cornerRadius(12)
            .padding()

            // Results
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("search for friends")
                        .font(.nunitoSans(size: 20, weight: .semiBold))

                    Text("enter a name to find users")
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("no users found")
                        .font(.nunitoSans(size: 20, weight: .semiBold))

                    Text("try a different search")
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults.filter { $0.id != authState.currentUser?.id }) { user in
                    NavigationLink(destination: UserProfileView(user: user)) {
                        UserRow(user: user)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func performSearch() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            searchResults = try await UserService.shared.searchUsers(query: searchText)
        } catch {
            print("Search error: \(error)")
        }

        isSearching = false
    }
}

// MARK: - Pending Requests View

struct PendingRequestsView: View {
    let pendingRequests: [FriendshipWithUser]
    let isLoading: Bool
    let onAccept: (FriendshipWithUser) -> Void
    let onReject: (FriendshipWithUser) -> Void

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if pendingRequests.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "envelope")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("no pending requests")
                        .font(.nunitoSans(size: 20, weight: .semiBold))

                    Text("friend requests will appear here")
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(pendingRequests) { friendshipWithUser in
                    FriendRequestRow(
                        friendshipWithUser: friendshipWithUser,
                        onAccept: { onAccept(friendshipWithUser) },
                        onReject: { onReject(friendshipWithUser) }
                    )
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - User Row Component

struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            // Profile Photo
            if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProfilePhotoPlaceholder(displayName: user.displayName)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                ProfilePhotoPlaceholder(displayName: user.displayName)
                    .frame(width: 50, height: 50)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.nunitoSans(size: 17, weight: .semiBold))

                HStack(spacing: 4) {
                    Image(systemName: user.platformType == .spotify ? "music.note" : "applelogo")
                        .font(.system(size: 11))
                    Text(user.platformType == .spotify ? "spotify" : "apple music")
                        .font(.nunitoSans(size: 13))
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friend Request Row Component

struct FriendRequestRow: View {
    @Environment(\.colorScheme) var colorScheme
    let friendshipWithUser: FriendshipWithUser
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Profile Photo
                if let photoUrl = friendshipWithUser.user.profilePhotoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProfilePhotoPlaceholder(displayName: friendshipWithUser.user.displayName)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    ProfilePhotoPlaceholder(displayName: friendshipWithUser.user.displayName)
                        .frame(width: 50, height: 50)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(friendshipWithUser.user.displayName)
                        .font(.nunitoSans(size: 17, weight: .semiBold))

                    Text("wants to be friends")
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    onReject()
                } label: {
                    Text("reject")
                        .font(.nunitoSans(size: 15, weight: .semiBold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(8)
                }

                Button {
                    onAccept()
                } label: {
                    Text("accept")
                        .font(.nunitoSans(size: 15, weight: .semiBold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        FriendsView()
            .environmentObject(AuthenticationState())
    }
}
