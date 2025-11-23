import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int

    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var friends: [User] = []
    @State private var pendingRequests: [FriendshipWithUser] = []
    @State private var contactMatches: [ContactMatch] = []
    @State private var isSearching = false
    @State private var isLoading = true
    @State private var isFetchingContacts = false
    @State private var hasFetchedContacts = false
    @State private var contactError: String?
    @State private var showError = false
    @State private var errorMessage = ""

    private var filteredFriends: [User] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                // Background
                (colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground))
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // Search Bar (Non-sticky, part of content)
                            searchBar
                                .id("friends-top")
                                .padding(.top, 8)

                            if !pendingRequests.isEmpty {
                                requestsSection
                            }

                            if !searchText.isEmpty {
                                peopleSection
                            }

                            friendsSection

                            contactsSection
                                .padding(.bottom, 100) // Extra padding at bottom
                        }
                    }
                    .refreshable {
                        await loadData()
                        if !searchText.isEmpty {
                            await performSearch()
                        }
                        if hasFetchedContacts {
                            await fetchContacts()
                        }
                    }
                    .onChange(of: scrollToTopTrigger) { _ in
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("friends-top", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("friends") // Standard navigation title
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: User.self) { user in
                UserProfileView(user: user)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: refreshTrigger) { _ in
                Task { await loadData() }
            }
            .onChange(of: searchText) { _ in
                Task { await performSearch() }
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search friends...", text: $searchText)
                    .font(.lora(size: 16))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("requests")
                .font(.lora(size: 20, weight: .bold))
                .padding(.horizontal)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pendingRequests) { friendship in
                        FriendRequestCard(
                            friendshipWithUser: friendship,
                            onAccept: { Task { await acceptRequest(friendship) } },
                            onReject: { Task { await rejectRequest(friendship) } }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("people on phlock")
                .font(.lora(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(32)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No matches found")
                        .font(.lora(size: 20, weight: .semiBold))

                    Text("Try searching for a different name.")
                        .font(.lora(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults.filter { $0.id != authState.currentUser?.id }) { user in
                        NavigationLink(value: user) {
                            UserRow(user: user)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemBackground))
                        }
                        Divider().padding(.leading, 70)
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var friendsSection: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(32)
                } else if filteredFriends.isEmpty {
                    if searchText.isEmpty {
                        // Empty state for no friends
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No friends yet")
                                .font(.lora(size: 20, weight: .semiBold))
                            Text("Your crew starts here. Add friends to share music.")
                                .font(.lora(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFriends) { friend in
                            NavigationLink(value: friend) {
                                UserRow(user: friend)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .background(Color(uiColor: .systemBackground))
                            }
                            Divider().padding(.leading, 74)
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            } header: {
                HStack {
                    Text("your friends")
                        .font(.lora(size: 20, weight: .bold))
                    Spacer()
                    Text("\(filteredFriends.count)")
                        .font(.lora(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    (colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground))
                        .opacity(0.95)
                )
            }
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("from contacts")
                .font(.lora(size: 20, weight: .bold))
                .padding(.horizontal)

            if isFetchingContacts {
                HStack {
                    ProgressView()
                    Text("Syncing contacts...")
                        .font(.lora(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let contactError {
                VStack(spacing: 8) {
                    Text("Could not access contacts")
                        .font(.lora(size: 15, weight: .medium))
                    Text(contactError)
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await fetchContacts() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else if !contactMatches.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(contactMatches) { match in
                        NavigationLink(value: match.user) {
                            HStack(spacing: 12) {
                                UserRow(user: match.user)
                                Spacer()
                                Text("as \(match.contactName)")
                                    .font(.lora(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .systemBackground))
                        }
                        Divider().padding(.leading, 74)
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                ContactsBanner {
                    Task { await fetchContacts() }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Data Loading

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

    private func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            searchResults = try await UserService.shared.searchUsers(query: query)
        } catch {
            print("Search error: \(error)")
        }
        isSearching = false
    }

    private func fetchContacts() async {
        isFetchingContacts = true
        contactError = nil
        hasFetchedContacts = true
        do {
            contactMatches = try await ContactsService.shared.findPhlockUsersInContacts()
        } catch ContactsServiceError.accessDenied {
            contactError = "Enable Contacts access in Settings to find friends."
        } catch {
            contactError = error.localizedDescription
        }
        isFetchingContacts = false
    }

    private func acceptRequest(_ friendshipWithUser: FriendshipWithUser) async {
        guard let currentUser = authState.currentUser else { return }
        do {
            try await UserService.shared.acceptFriendRequest(
                friendshipId: friendshipWithUser.friendship.id,
                currentUserId: currentUser.id
            )
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
            UserService.shared.clearCache(for: currentUser.id)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Subcomponents

struct FriendRequestCard: View {
    let friendshipWithUser: FriendshipWithUser
    let onAccept: () -> Void
    let onReject: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            if let photoUrl = friendshipWithUser.user.profilePhotoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProfilePhotoPlaceholder(displayName: friendshipWithUser.user.displayName)
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .shadow(radius: 2)
            } else {
                ProfilePhotoPlaceholder(displayName: friendshipWithUser.user.displayName)
                    .frame(width: 60, height: 60)
            }

            VStack(spacing: 2) {
                Text(friendshipWithUser.user.displayName)
                    .font(.lora(size: 16, weight: .bold))
                    .lineLimit(1)
                Text("wants to connect")
                    .font(.lora(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .frame(width: 160)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct ContactsBanner: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("find friends")
                        .font(.lora(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Sync contacts to find people you know")
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 16) {
            if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProfilePhotoPlaceholder(displayName: user.displayName)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                ProfilePhotoPlaceholder(displayName: user.displayName)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.lora(size: 17, weight: .medium))
                    .foregroundColor(.primary)

                if let username = user.username {
                    Text("@\(username)")
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: user.platformType == .spotify ? "music.note" : "applelogo")
                            .font(.system(size: 10))
                        Text(user.platformType == .spotify ? "Spotify" : "Apple Music")
                            .font(.lora(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    FriendsView(
        navigationPath: .constant(NavigationPath()),
        refreshTrigger: .constant(0),
        scrollToTopTrigger: .constant(0)
    )
    .environmentObject(AuthenticationState())
}
