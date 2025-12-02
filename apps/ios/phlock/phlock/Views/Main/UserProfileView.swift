import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    let user: User

    @State private var relationshipStatus: RelationshipStatus?
    @State private var isLoading = true
    @State private var isSendingRequest = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Follow counts
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var showFollowersList = false
    @State private var followListInitialTab: FollowListType = .followers

    // Daily Curation State
    @State private var todaysPick: Share?
    @State private var pastPicks: [Share] = []
    @StateObject private var insightsViewModel = ProfileInsightsViewModel()

    // Phlock stats
    @State private var actualPhlockCount: Int = 0
    @State private var historicalReachCount: Int = 0

    // Nudge state
    @State private var hasNudged = false
    @State private var isNudging = false

    // Computed property to check if we can see the profile content
    private var canViewProfile: Bool {
        // Can always view if not private
        guard user.isPrivate else { return true }
        // Can view if we follow them (they accepted us)
        return relationshipStatus?.isFollowing == true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Photo with Streak Badge
                    VStack(spacing: 0) {
                        if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProfilePhotoPlaceholder(displayName: user.displayName)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            ProfilePhotoPlaceholder(displayName: user.displayName)
                                .frame(width: 100, height: 100)
                        }

                        // Streak badge overlapping the photo bottom
                        if user.dailySongStreak > 0 {
                            StreakBadge(streak: user.dailySongStreak, size: .medium)
                                .offset(y: -12)
                        }
                    }

                    // Display Name with Platform Logo
                    HStack(spacing: 8) {
                        Text(user.displayName)
                            .font(.lora(size: 28, weight: .bold))

                        if let platform = user.resolvedPlatformType {
                            Image(platform == .spotify ? "SpotifyLogo" : "AppleMusicLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                    }

                    // Bio
                    if let bio = user.bio {
                        Text(bio)
                            .font(.lora(size: 15))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Followers/Following Stats Row
                    HStack(spacing: 32) {
                        Button {
                            followListInitialTab = .followers
                            showFollowersList = true
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(followerCount)")
                                    .font(.lora(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("followers")
                                    .font(.lora(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            followListInitialTab = .following
                            showFollowersList = true
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(followingCount)")
                                    .font(.lora(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("following")
                                    .font(.lora(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    // Follow Action Button
                    followActionButton
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                // Content (only if can view profile)
                if canViewProfile {
                    // Today's Pick
                    TodaysPickCard(
                        share: todaysPick,
                        isCurrentUser: false,
                        onPickSong: { },
                        userId: user.id,
                        onNudge: hasNudged ? nil : {
                            Task { await sendNudge() }
                        },
                        streak: user.dailySongStreak
                    )

                    // Profile Insights
                    ProfileInsightsSection(
                        user: user,
                        viewModel: insightsViewModel,
                        actualPhlockCount: actualPhlockCount,
                        historicalReachCount: historicalReachCount,
                        isCurrentUser: false
                    )

                    // Past Picks
                    PastPicksView(shares: pastPicks, isCurrentUser: false)

                    // Music Stats from Platform
                    if let platformData = user.platformData {
                        VStack(spacing: 24) {
                            // Top Tracks (Grid Layout)
                            if let topTracks = platformData.topTracks, !topTracks.isEmpty,
                               let platformType = getPlatformType(from: user) {
                                TracksGridView(
                                    title: "what i'm listening to",
                                    items: topTracks,
                                    platformType: platformType
                                )
                                .environmentObject(playbackService)
                            }

                            // Top Artists (Grid Layout)
                            if let topArtists = platformData.topArtists, !topArtists.isEmpty,
                               let platformType = getPlatformType(from: user) {
                                ArtistsGridView(
                                    title: "who i'm listening to",
                                    items: topArtists,
                                    platformType: platformType
                                )
                            }
                        }
                        .padding(.top, 16)
                    }
                } else {
                    // Private profile message
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("this account is private")
                            .font(.lora(size: 16, weight: .medium))
                        Text("follow this account to see their songs and music taste.")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.lora(size: 20, weight: .semiBold))
                        .foregroundColor(.primary)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Task { await blockUser() }
                    } label: {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }

                    Button(role: .destructive) {
                        Task { await reportUser() }
                    } label: {
                        Label("Report User", systemImage: "exclamationmark.bubble.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.lora(size: 20, weight: .semiBold))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenSwipeBack()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showFollowersList) {
            NavigationStack {
                FollowersListView(
                    userId: user.id,
                    initialTab: followListInitialTab,
                    followerCount: followerCount,
                    followingCount: followingCount
                )
                .environmentObject(authState)
            }
            .presentationDragIndicator(.visible)
        }
        .task {
            // Load relationship status and profile data in parallel for faster loading
            // .task already handles initial load - no separate onAppear needed
            async let relationshipTask: () = loadRelationshipStatus()
            async let profileTask: () = loadProfileData()
            _ = await (relationshipTask, profileTask)
        }
    }

    // MARK: - Load Profile Data

    private func loadProfileData() async {
        // Clear cache to ensure fresh data
        FollowService.shared.clearCache(for: user.id)

        // Load insights
        await insightsViewModel.load(for: user)

        // Load follow counts, phlock stats, and daily curation data
        do {
            async let followersTask = FollowService.shared.getFollowers(for: user.id)
            async let followingTask = FollowService.shared.getFollowing(for: user.id)
            async let whoHasMeTask = FollowService.shared.getWhoHasMeInPhlock(userId: user.id)
            async let historicalReachTask = FollowService.shared.getHistoricalReach(userId: user.id)
            async let todaysPickTask = ShareService.shared.getTodaysDailySong(for: user.id)
            async let pastPicksTask = ShareService.shared.getDailySongHistory(for: user.id)

            let (followers, following, whoHasMe, reach, today, past) = try await (
                followersTask,
                followingTask,
                whoHasMeTask,
                historicalReachTask,
                todaysPickTask,
                pastPicksTask
            )

            await MainActor.run {
                self.followerCount = followers.count
                self.followingCount = following.count
                self.actualPhlockCount = whoHasMe.count
                self.historicalReachCount = reach
                self.todaysPick = today
                self.pastPicks = past
            }
            print("✅ Loaded user profile data: followers=\(followers.count), following=\(following.count), phlockCount=\(whoHasMe.count), reach=\(reach)")
        } catch {
            print("❌ Failed to load profile data: \(error)")
        }
    }

    // MARK: - Follow Action Button

    @ViewBuilder
    private var followActionButton: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if let status = relationshipStatus {
            if status.isFollowing {
                // Already following - show "Following" button
                Button {
                    Task { await unfollowUser() }
                } label: {
                    Text("following")
                        .font(.lora(size: 17))
                        .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .cornerRadius(12)
                }
            } else if status.hasPendingRequest {
                // Pending request - show "Requested" button
                Button {
                    // Could add cancel functionality here
                } label: {
                    Text("requested")
                        .font(.lora(size: 17))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(12)
                }
            } else {
                // Not following - show "Follow" button
                Button {
                    Task { await followUser() }
                } label: {
                    if isSendingRequest {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text(user.isPrivate ? "request to follow" : "follow")
                            .font(.lora(size: 17))
                            .foregroundColor(Color.background(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primaryColor(for: colorScheme))
                            .cornerRadius(12)
                    }
                }
                .disabled(isSendingRequest)
            }
        } else {
            // No status loaded - show follow button
            Button {
                Task { await followUser() }
            } label: {
                if isSendingRequest {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text(user.isPrivate ? "request to follow" : "follow")
                        .font(.lora(size: 17))
                        .foregroundColor(Color.background(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primaryColor(for: colorScheme))
                        .cornerRadius(12)
                }
            }
            .disabled(isSendingRequest)
        }
    }

    // MARK: - Actions

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

        isSendingRequest = true

        do {
            try await FollowService.shared.followOrRequest(
                userId: user.id,
                currentUserId: currentUserId,
                targetUser: user
            )

            // Clear cache to ensure fresh data
            FollowService.shared.clearCache(for: currentUserId)

            await loadRelationshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSendingRequest = false
    }

    private func unfollowUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        do {
            try await FollowService.shared.unfollow(userId: user.id, currentUserId: currentUserId)

            // Clear cache to ensure fresh data
            FollowService.shared.clearCache(for: currentUserId)

            await loadRelationshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func blockUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        do {
            try await UserService.shared.blockUser(userId: user.id, currentUserId: currentUserId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func reportUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        // In a real app, we'd show a sheet to collect the reason
        // For now, we'll report as "Inappropriate Content" by default
        do {
            try await UserService.shared.reportUser(userId: user.id, reporterId: currentUserId, reason: "Inappropriate Content")
            errorMessage = "User reported. Thank you for keeping Phlock safe."
            showError = true // Reusing error alert for success message for simplicity
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func getPlatformType(from user: User) -> PlatformType? {
        // Try to get from platformType field first
        if let platformType = user.platformType {
            return platformType
        }
        // Otherwise derive from musicPlatform field
        if let musicPlatform = user.musicPlatform {
            return musicPlatform == "apple_music" ? .appleMusic : .spotify
        }
        return nil
    }

    private func sendNudge() async {
        guard let currentUserId = authState.currentUser?.id else { return }
        guard !hasNudged && !isNudging else { return }

        isNudging = true

        do {
            try await NotificationService.shared.sendDailyNudge(to: user.id, from: currentUserId)
            await MainActor.run {
                hasNudged = true
            }
            print("✅ Nudge sent successfully to \(user.displayName)")
        } catch {
            print("❌ Failed to send nudge: \(error)")
            errorMessage = "Failed to send nudge"
            showError = true
        }

        isNudging = false
    }
}

#Preview {
    // Create sample user using JSON decoding
    let sampleUserData = """
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "display_name": "Test User",
        "bio": "Love discovering new music!",
        "platform_type": "spotify",
        "platform_user_id": "test123",
        "privacy_who_can_send": "friends",
        "auth_user_id": "223e4567-e89b-12d3-a456-426614174000",
        "music_platform": "spotify"
    }
    """.data(using: .utf8)!

    let sampleUser = try! JSONDecoder().decode(User.self, from: sampleUserData)

    NavigationStack {
        UserProfileView(user: sampleUser)
            .environmentObject(AuthenticationState())
            .environmentObject(PlaybackService.shared)
    }
}
