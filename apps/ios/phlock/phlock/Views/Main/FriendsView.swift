import SwiftUI
import Contacts
import MessageUI

struct FriendsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int

    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var pendingRequests: [FriendshipWithUser] = []
    @State private var contactMatches: [ContactMatch] = []
    @State private var suggestedUsers: [RecommendedFriend] = []
    @State private var isSearching = false
    @State private var isLoading = true
    @State private var isLoadingSuggestions = true
    @State private var isFetchingContacts = false
    @State private var hasFetchedContacts = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSettingsAlert = false
    @State private var searchTask: Task<Void, Never>?

    // Invite contacts state
    @State private var invitableContacts: [InvitableContact] = []
    @State private var invitedContacts: Set<String> = []  // Track by phone number
    @State private var inviteTarget: InviteContactTarget?
    @State private var isLoadingInvitableContacts = false
    @State private var inviteSearchText = ""  // Search within contacts to invite

    // Wrapper for .sheet(item:) to avoid SwiftUI timing issues
    struct InviteContactTarget: Identifiable {
        let id = UUID()
        let phone: String
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                // Background
                Color.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Search Bar
                            searchBar
                                .id("discover-top")
                                .padding(.top, 8)

                            // Follow Requests Section
                            if !pendingRequests.isEmpty {
                                requestsSection
                            }

                            // Search Results (when searching)
                            if !searchText.isEmpty {
                                searchResultsSection
                            } else {
                                // Find Friends Banner (contacts) - shown if not yet authorized
                                if ContactsService.shared.authorizationStatus() != .authorized {
                                    findFriendsBanner
                                }

                                // Suggested For You Section
                                suggestedForYouSection

                                // Invite Your Contacts Section (when contacts authorized)
                                inviteContactsSection
                            }

                            Spacer(minLength: 100)
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
                        await loadSuggestions()
                    }
                    .onChange(of: scrollToTopTrigger) { _ in
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("discover-top", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("discover")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: User.self) { user in
                UserProfileView(user: user)
                    .environmentObject(authState)
                    .environmentObject(PlaybackService.shared)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Enable Contacts Access", isPresented: $showSettingsAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To find friends on phlock, go to:\nSettings → Apps → phlock → Contacts → Full Access")
            }
            .sheet(item: $inviteTarget) { target in
                DiscoverMessageComposeView(
                    recipients: [target.phone],
                    body: "hey cutie - I have a song for you https://phlock.app",
                    onFinished: { result in
                        if result == .sent {
                            invitedContacts.insert(target.phone)
                        }
                        inviteTarget = nil
                    }
                )
            }
            .onChange(of: refreshTrigger) { _ in
                Task { await loadData() }
            }
            .onChange(of: searchText) { _ in
                performDebouncedSearch()
            }
            .task {
                // Check contacts access first and set loading state immediately
                let status = ContactsService.shared.authorizationStatus()
                var hasAccess = status == .authorized
                if #available(iOS 18.0, *), status == .limited {
                    hasAccess = true
                }

                // Set loading state before any async work so UI shows spinner immediately
                if hasAccess {
                    isLoadingInvitableContacts = true
                }

                await loadData()

                if hasAccess {
                    await fetchContacts()
                } else {
                    await loadSuggestions()
                }
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

                TextField("Search by name or @username", text: $searchText)
                    .font(.lora(size: 16))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

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
                .font(.lora(size: 20, weight: .semiBold))
                .padding(.horizontal)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pendingRequests) { friendship in
                        FollowRequestCard(
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
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("people on phlock")
                .font(.lora(size: 14))
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
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)

                    Text("No matches found")
                        .font(.lora(size: 20, weight: .semiBold))

                    Text("Try searching for a different name.")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults.filter { $0.id != authState.currentUser?.id }) { user in
                        SearchResultRow(
                            user: user,
                            onFollow: { Task { await followUser(user) } },
                            onTap: { navigationPath.append(user) }
                        )
                        Divider().padding(.leading, 74)
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
    private var suggestedForYouSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("suggested for you")
                .font(.lora(size: 20, weight: .semiBold))
                .padding(.horizontal)
                .padding(.top, 8)

            if isLoadingSuggestions {
                HStack {
                    ProgressView()
                    Text("finding people you may know...")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if suggestedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)

                    Text("no suggestions yet")
                        .font(.lora(size: 18, weight: .semiBold))

                    Text("follow more people to get\npersonalized suggestions.")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                // Flat list with per-row context labels (BeReal-style)
                LazyVStack(spacing: 0) {
                    ForEach(suggestedUsers) { suggestion in
                        SuggestedUserRow(
                            suggestion: suggestion,
                            onFollow: { Task { await followUser(suggestion.user) } },
                            onDismiss: { dismissSuggestion(suggestion) },
                            onTap: { navigationPath.append(suggestion.user) }
                        )

                        if suggestion.id != suggestedUsers.last?.id {
                            Divider().padding(.leading, 74)
                        }
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
    private var findFriendsBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isFetchingContacts {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("syncing contacts...")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                Button {
                    Task { await fetchContacts() }
                } label: {
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        // Text content - left aligned
                        VStack(alignment: .leading, spacing: 2) {
                            Text("find friends")
                                .font(.lora(size: 16, weight: .semiBold))
                                .foregroundColor(.primary)
                            Text("see who's already on phlock")
                                .font(.lora(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // CTA button on right
                        Text("sync")
                            .font(.lora(size: 14, weight: .semiBold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // Filtered contacts based on search
    private var filteredInvitableContacts: [InvitableContact] {
        if inviteSearchText.isEmpty {
            return invitableContacts
        }
        return invitableContacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(inviteSearchText)
        }
    }

    @ViewBuilder
    private var inviteContactsSection: some View {
        // Check if contacts are authorized
        let status = ContactsService.shared.authorizationStatus()
        let hasAccess: Bool = {
            if status == .authorized { return true }
            if #available(iOS 18.0, *), status == .limited { return true }
            return false
        }()

        // Show section if: authorized AND (loading OR has contacts)
        if hasAccess && (isLoadingInvitableContacts || !invitableContacts.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                Text("invite your contacts")
                    .font(.lora(size: 20, weight: .semiBold))
                    .padding(.horizontal)

                if isLoadingInvitableContacts && invitableContacts.isEmpty {
                    // Initial loading state - show spinner in a card
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("loading your contacts...")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                } else {
                    // Search bar for contacts
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))

                        TextField("search contacts", text: $inviteSearchText)
                            .font(.lora(size: 15))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        if !inviteSearchText.isEmpty {
                            Button {
                                inviteSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    if filteredInvitableContacts.isEmpty {
                        // No results message
                        Text("no contacts found")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        // Show more results when searching, limit to 10 when not searching
                        let contactsToShow = inviteSearchText.isEmpty
                            ? Array(filteredInvitableContacts.prefix(10))
                            : Array(filteredInvitableContacts.prefix(20))

                        LazyVStack(spacing: 0) {
                            ForEach(Array(contactsToShow.enumerated()), id: \.element.id) { index, contact in
                                DiscoverInviteContactRow(
                                    name: contact.name,
                                    phone: contact.phone,
                                    friendCount: contact.friendCount,
                                    imageData: contact.imageData,
                                    isInvited: invitedContacts.contains(contact.phone),
                                    onInvite: { inviteTarget = InviteContactTarget(phone: contact.phone) }
                                )

                                if index < contactsToShow.count - 1 {
                                    Divider().padding(.leading, 74)
                                }
                            }
                        }
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let currentUser = authState.currentUser else { return }
        isLoading = true
        do {
            pendingRequests = try await UserService.shared.getPendingRequests(for: currentUser.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func loadSuggestions() async {
        guard let currentUser = authState.currentUser else { return }
        isLoadingSuggestions = true
        do {
            // Use retry logic for network resilience
            suggestedUsers = try await withTimeoutAndRetry(timeoutSeconds: 10) {
                try await FollowService.shared.getRecommendedFriends(
                    for: currentUser.id,
                    contactMatches: self.contactMatches
                )
            }
        } catch {
            print("⚠️ Failed to load suggestions after retries: \(error)")
            // Don't show error to user - suggestions are non-critical
        }
        isLoadingSuggestions = false
    }

    private func performDebouncedSearch() {
        // Cancel any existing search task
        searchTask?.cancel()

        // Debounce: wait 300ms before searching
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }
            await performSearch()
        }
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
        print("📇 fetchContacts() called")

        // Check authorization status first
        let status = ContactsService.shared.authorizationStatus()
        print("📇 Current authorization status: \(status.rawValue)")

        // If denied or restricted, show alert to guide user to Settings
        if status == .denied || status == .restricted {
            await MainActor.run {
                showSettingsAlert = true
            }
            return
        }

        isFetchingContacts = true
        hasFetchedContacts = true
        do {
            // Find users already on Phlock
            contactMatches = try await ContactsService.shared.findPhlockUsersInContacts()
            print("📇 Found \(contactMatches.count) contact matches")

            // Sync contacts to server (for "X friends on phlock" feature)
            try await ContactsService.shared.syncContactsToServer()

            // Load invitable contacts with friend counts
            await loadInvitableContacts()

            await loadSuggestions()
        } catch ContactsServiceError.accessDenied {
            print("📇 Access denied")
            // Show settings alert instead of error state - banner stays visible
            await MainActor.run {
                showSettingsAlert = true
            }
        } catch {
            print("📇 Error: \(error)")
            // For other errors, just log and keep banner visible
        }
        isFetchingContacts = false
    }

    private func loadInvitableContacts() async {
        isLoadingInvitableContacts = true
        do {
            // Get phone numbers of users already on Phlock
            let matchedPhones = Set(contactMatches.compactMap { match -> String? in
                // The contactMatches are based on phone matching, so we can use the user's phone
                return match.user.phone.flatMap { ContactsService.normalizePhone($0) }
            })

            invitableContacts = try await ContactsService.shared.fetchContactsWithFriendCounts(excludingPhones: matchedPhones)
            print("📇 Found \(invitableContacts.count) invitable contacts")
        } catch {
            print("📇 Error loading invitable contacts: \(error)")
        }
        isLoadingInvitableContacts = false
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

    private func followUser(_ user: User) async {
        guard let currentUser = authState.currentUser else { return }
        do {
            try await FollowService.shared.followOrRequest(
                userId: user.id,
                currentUserId: currentUser.id,
                targetUser: user
            )
            // Remove from suggestions
            withAnimation {
                suggestedUsers.removeAll { $0.user.id == user.id }
            }
            FollowService.shared.clearCache(for: currentUser.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func dismissSuggestion(_ suggestion: RecommendedFriend) {
        withAnimation {
            suggestedUsers.removeAll { $0.id == suggestion.id }
        }
    }
}

// MARK: - Suggested User Row (BeReal-style list item)

struct SuggestedUserRow: View {
    let suggestion: RecommendedFriend
    let onFollow: () -> Void
    let onDismiss: () -> Void
    let onTap: () -> Void

    @State private var isFollowing = false

    /// Context label text - kept concise to fit on one line
    private var contextText: String {
        switch suggestion.context {
        case .inContacts:
            return "in your contacts"
        case .recentActivity:
            return "recent activity"
        case .youMayKnow:
            return "you may know"
        case .mutualFriends:
            if let count = suggestion.mutualCount, count > 0 {
                return "\(count) mutual"
            }
            return "mutual friends"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo with streak badge - tappable
            Button(action: onTap) {
                VStack(spacing: 0) {
                    if let photoUrl = suggestion.user.profilePhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProfilePhotoPlaceholder(displayName: suggestion.user.displayName)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        ProfilePhotoPlaceholder(displayName: suggestion.user.displayName)
                            .frame(width: 50, height: 50)
                    }

                    if suggestion.user.effectiveStreak > 0 {
                        StreakBadge(streak: suggestion.user.effectiveStreak, size: .small)
                            .offset(y: -8)
                    }
                }
            }
            .buttonStyle(.plain)

            // Name, username, and context - tappable
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.user.displayName)
                        .font(.lora(size: 16, weight: .semiBold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let username = suggestion.user.username {
                        Text("@\(username)")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Context label (BeReal-style, under username)
                    HStack(spacing: 4) {
                        Image(systemName: suggestion.context.iconName)
                            .font(.system(size: 10))
                        Text(contextText)
                            .font(.lora(size: 12))
                    }
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Follow button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isFollowing = true
                }
                onFollow()
            } label: {
                Text(isFollowing ? "following" : "follow")
                    .font(.lora(size: 14, weight: .semiBold))
                    .foregroundColor(isFollowing ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isFollowing)

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: User
    let onFollow: () -> Void
    let onTap: () -> Void

    @State private var isFollowing = false
    @State private var alreadyFollowing = false

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo with streak badge - tappable
            Button(action: onTap) {
                VStack(spacing: 0) {
                    if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProfilePhotoPlaceholder(displayName: user.displayName)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        ProfilePhotoPlaceholder(displayName: user.displayName)
                            .frame(width: 50, height: 50)
                    }

                    if user.effectiveStreak > 0 {
                        StreakBadge(streak: user.effectiveStreak, size: .small)
                            .offset(y: -8)
                    }
                }
            }
            .buttonStyle(.plain)

            // Name and username - tappable
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(.lora(size: 16, weight: .semiBold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let username = user.username {
                        Text("@\(username)")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Follow button (hidden if already following)
            if !alreadyFollowing {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isFollowing = true
                    }
                    onFollow()
                } label: {
                    Text(isFollowing ? "following" : "follow")
                        .font(.lora(size: 14, weight: .semiBold))
                        .foregroundColor(isFollowing ? .secondary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.black)
                        .cornerRadius(8)
                }
                .disabled(isFollowing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Follow Request Card

struct FollowRequestCard: View {
    let friendshipWithUser: FriendshipWithUser
    let onAccept: () -> Void
    let onReject: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Profile photo with streak badge
            VStack(spacing: 0) {
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

                if friendshipWithUser.user.effectiveStreak > 0 {
                    StreakBadge(streak: friendshipWithUser.user.effectiveStreak, size: .small)
                        .offset(y: -8)
                }
            }

            VStack(spacing: 2) {
                Text(friendshipWithUser.user.displayName)
                    .font(.lora(size: 16))
                    .lineLimit(1)
                Text("wants to follow you")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
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

// MARK: - Supporting Views

struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
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

                if user.effectiveStreak > 0 {
                    StreakBadge(streak: user.effectiveStreak, size: .small)
                        .offset(y: -8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.lora(size: 16))
                    .foregroundColor(.primary)

                if let username = user.username {
                    Text("@\(username)")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                } else if let platform = user.resolvedPlatformType {
                    HStack(spacing: 4) {
                        Image(systemName: platform == .spotify ? "music.note" : "applelogo")
                            .font(.system(size: 10))
                        Text(platform == .spotify ? "Spotify" : "Apple Music")
                            .font(.lora(size: 14))
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Discover Invite Contact Row

struct DiscoverInviteContactRow: View {
    let name: String
    let phone: String
    let friendCount: Int
    let imageData: Data?
    let isInvited: Bool
    let onInvite: () -> Void

    private var avatarColor: Color {
        let colors: [Color] = [.orange, .green, .blue, .purple, .pink, .red, .teal, .indigo]
        return colors[abs(phone.hashValue) % colors.count]
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var contextText: String {
        if friendCount > 0 {
            return friendCount == 1 ? "1 friend on phlock" : "\(friendCount) friends on phlock"
        }
        return "not on phlock yet"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar - show contact photo if available, otherwise initials
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }

            // Name and context
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.lora(size: 16, weight: .semiBold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(contextText)
                    .font(.lora(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Invite button
            Button(action: onInvite) {
                Text(isInvited ? "invited" : "invite")
                    .font(.lora(size: 14, weight: .semiBold))
                    .foregroundColor(isInvited ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isInvited ? Color.gray.opacity(0.2) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isInvited)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Discover Message Compose View

struct DiscoverMessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinished: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: (MessageComposeResult) -> Void

        init(onFinished: @escaping (MessageComposeResult) -> Void) {
            self.onFinished = onFinished
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.onFinished(result)
            }
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
