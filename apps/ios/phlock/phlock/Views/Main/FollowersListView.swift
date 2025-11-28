import SwiftUI

enum FollowListType: String, CaseIterable {
    case followers = "followers"
    case following = "following"
}

struct FollowersListView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    let userId: UUID
    let initialTab: FollowListType

    @State private var selectedTab: FollowListType
    @State private var followers: [User] = []
    @State private var following: [User] = []
    @State private var isLoadingFollowers = false
    @State private var isLoadingFollowing = false
    @State private var selectedUserForProfile: User?

    // Dynamic counts derived from actual data
    private var followerCount: Int { followers.count }
    private var followingCount: Int { following.count }

    init(userId: UUID, initialTab: FollowListType, followerCount: Int, followingCount: Int) {
        self.userId = userId
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
        // Initial counts are now ignored - we use dynamic counts from loaded data
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                tabButton(for: .followers, count: followerCount)
                tabButton(for: .following, count: followingCount)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Divider()
                .padding(.top, 12)

            // Swipeable content
            TabView(selection: $selectedTab) {
                // Followers tab
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoadingFollowers {
                            loadingView
                        } else if followers.isEmpty {
                            emptyStateView(for: .followers)
                        } else {
                            ForEach(followers) { user in
                                userRow(user: user)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .tag(FollowListType.followers)

                // Following tab
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoadingFollowing {
                            loadingView
                        } else if following.isEmpty {
                            emptyStateView(for: .following)
                        } else {
                            ForEach(following) { user in
                                userRow(user: user)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .tag(FollowListType.following)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.lora(size: 18, weight: .semiBold))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedUserForProfile) { user in
            NavigationStack {
                UserProfileView(user: user)
                    .environmentObject(authState)
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedTab) { _ in
            Task {
                await loadDataForTab(selectedTab)
            }
        }
    }

    // MARK: - Tab Button

    private func tabButton(for type: FollowListType, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = type
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.lora(size: 18, weight: .bold))
                    .foregroundColor(selectedTab == type ? .primary : .secondary)

                Text(type.rawValue)
                    .font(.lora(size: 14))
                    .foregroundColor(selectedTab == type ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .fill(selectedTab == type ? Color.primary : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - User Row

    private func userRow(user: User) -> some View {
        Button {
            // Don't navigate to own profile
            if user.id != authState.currentUser?.id {
                selectedUserForProfile = user
            }
        } label: {
            HStack(spacing: 12) {
                // Profile photo with streak badge
                VStack(spacing: 0) {
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

                    // Streak badge
                    if user.dailySongStreak > 0 {
                        StreakBadge(streak: user.dailySongStreak, size: .small)
                            .offset(y: -8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.lora(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    if let username = user.username {
                        Text("@\(username)")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Show follow button if not viewing own followers/following and not self
                if user.id != authState.currentUser?.id {
                    FollowButtonSmall(user: user) {
                        // Refresh lists when follow status changes
                        Task {
                            await refreshLists()
                        }
                    }
                    .environmentObject(authState)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding(.top, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private func emptyStateView(for type: FollowListType) -> some View {
        VStack(spacing: 12) {
            Image(systemName: type == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(type == .followers ? "No followers yet" : "Not following anyone")
                .font(.lora(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Text(type == .followers
                ? "When people follow this account, they'll appear here."
                : "When this account follows people, they'll appear here.")
                .font(.lora(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Load both tabs in parallel for smooth swiping experience
        async let followersLoad: () = loadFollowers(forceRefresh: false)
        async let followingLoad: () = loadFollowing(forceRefresh: false)
        _ = await (followersLoad, followingLoad)
    }

    private func loadDataForTab(_ tab: FollowListType) async {
        switch tab {
        case .followers:
            await loadFollowers(forceRefresh: false)
        case .following:
            await loadFollowing(forceRefresh: false)
        }
    }

    private func refreshLists() async {
        // Force refresh both lists to get updated counts
        if let currentUserId = authState.currentUser?.id {
            FollowService.shared.clearCache(for: currentUserId)
        }
        async let followersLoad: () = loadFollowers(forceRefresh: true)
        async let followingLoad: () = loadFollowing(forceRefresh: true)
        _ = await (followersLoad, followingLoad)
    }

    private func loadFollowers(forceRefresh: Bool) async {
        guard forceRefresh || followers.isEmpty else { return }
        isLoadingFollowers = true
        do {
            followers = try await FollowService.shared.getFollowers(for: userId)
        } catch {
            print("❌ Failed to load followers: \(error)")
        }
        isLoadingFollowers = false
    }

    private func loadFollowing(forceRefresh: Bool) async {
        guard forceRefresh || following.isEmpty else { return }
        isLoadingFollowing = true
        do {
            following = try await FollowService.shared.getFollowing(for: userId)
        } catch {
            print("❌ Failed to load following: \(error)")
        }
        isLoadingFollowing = false
    }
}

// MARK: - Small Follow Button

struct FollowButtonSmall: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    let user: User
    var onStatusChanged: (() -> Void)?

    @State private var relationshipStatus: RelationshipStatus?
    @State private var isLoading = true
    @State private var isProcessing = false

    init(user: User, onStatusChanged: (() -> Void)? = nil) {
        self.user = user
        self.onStatusChanged = onStatusChanged
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 80, height: 32)
            } else if let status = relationshipStatus {
                if status.isFollowing {
                    Button {
                        Task { await unfollowUser() }
                    } label: {
                        Text("following")
                            .font(.lora(size: 13))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                            .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                } else if status.hasPendingRequest {
                    Text("requested")
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(8)
                } else {
                    Button {
                        Task { await followUser() }
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 80, height: 32)
                        } else {
                            Text("follow")
                                .font(.lora(size: 13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .task {
            await loadRelationshipStatus()
        }
    }

    private func loadRelationshipStatus() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        isLoading = true
        do {
            relationshipStatus = try await FollowService.shared.getRelationshipStatus(
                currentUserId: currentUserId,
                otherUserId: user.id
            )
        } catch {
            print("Error loading relationship status: \(error)")
        }
        isLoading = false
    }

    private func followUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        isProcessing = true
        do {
            try await FollowService.shared.followOrRequest(
                userId: user.id,
                currentUserId: currentUserId,
                targetUser: user
            )
            FollowService.shared.clearCache(for: currentUserId)
            await loadRelationshipStatus()
            onStatusChanged?()
        } catch {
            print("Error following user: \(error)")
        }
        isProcessing = false
    }

    private func unfollowUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        isProcessing = true
        do {
            try await FollowService.shared.unfollow(userId: user.id, currentUserId: currentUserId)
            FollowService.shared.clearCache(for: currentUserId)
            await loadRelationshipStatus()
            onStatusChanged?()
        } catch {
            print("Error unfollowing user: \(error)")
        }
        isProcessing = false
    }
}

#Preview {
    NavigationStack {
        FollowersListView(
            userId: UUID(),
            initialTab: .followers,
            followerCount: 42,
            followingCount: 128
        )
        .environmentObject(AuthenticationState())
    }
}
