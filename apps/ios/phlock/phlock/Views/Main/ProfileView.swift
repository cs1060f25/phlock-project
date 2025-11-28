import SwiftUI
import Combine
import MusicKit
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var isRefreshing = false
    @State private var refreshCount = 0 // Force view refresh
    @StateObject private var insightsViewModel = ProfileInsightsViewModel()
    @State private var insightsLoadedForUser: UUID?
    
    // Daily Curation State
    @State private var todaysPick: Share?
    @State private var pastPicks: [Share] = []
    @State private var phlockMembers: [FriendWithPosition] = []
    
    // Song Picker Sheet
    @State private var showSongPickerSheet = false
    @State private var songPickerNavPath = NavigationPath()
    @State private var songPickerClearTrigger = 0
    @State private var songPickerRefreshTrigger = 0
    @State private var songPickerScrollToTopTrigger = 0
    
    // Phlock Member Interaction
    @State private var selectedUserForProfile: User?
    @State private var showPhlockManagerSheet = false

    // Followers/Following
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var showFollowersList = false
    @State private var followListInitialTab: FollowListType = .followers

    // Refreshed user data (with fresh phlockCount, etc.)
    @State private var refreshedUser: User?

    // Actual phlock count fetched from follows table (more reliable than cached column)
    @State private var actualPhlockCount: Int = 0
    // Historical reach: unique users who have EVER had this user in their phlock
    @State private var historicalReachCount: Int = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                // Top anchor for scroll-to-top functionality
                Color.clear
                    .frame(height: 1)
                    .id("profileTop")

                VStack(spacing: 24) {
                    if let user = authState.currentUser {
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

                            // Edit Profile Button
                            Button {
                                showEditProfile = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.lora(size: 11))
                                    Text("edit profile")
                                        .font(.lora(size: 13))
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.top, 24)
                        
                        // Today's Pick
                        TodaysPickCard(
                            share: todaysPick,
                            isCurrentUser: true, // Since we are viewing own profile for now
                            onPickSong: {
                                showSongPickerSheet = true
                            }
                        )
                        
                        // My Phlock
                        PhlockMembersRow(
                            members: phlockMembers,
                            onMemberTapped: { user in
                                selectedUserForProfile = user
                            },
                            onEditTapped: {
                                showPhlockManagerSheet = true
                            }
                        )

                        ProfileInsightsSection(
                            user: refreshedUser ?? user,
                            viewModel: insightsViewModel,
                            actualPhlockCount: actualPhlockCount,
                            historicalReachCount: historicalReachCount
                        )

                        // Past Picks
                        PastPicksView(shares: pastPicks)
                        
                        // Music Stats from Platform
                        if let platformData = user.platformData {
                            VStack(spacing: 16) {


                                // Top Tracks
                                if let topTracks = platformData.topTracks, !topTracks.isEmpty,
                                   let platformType = getPlatformType(from: user) {
                                    MusicStatsCard(
                                        title: "what i'm listening to",
                                        items: topTracks,
                                        platformType: platformType,
                                        itemType: .track
                                    )
                                    .environmentObject(playbackService)
                                    .environmentObject(authState)
                                }

                                // Top Artists
                                if let topArtists = platformData.topArtists, !topArtists.isEmpty,
                                   let platformType = getPlatformType(from: user) {
                                    MusicStatsCard(
                                        title: "who i'm listening to",
                                        items: topArtists,
                                        platformType: platformType,
                                        itemType: .artist
                                    )
                                }
                            }
                            .padding(.top, 16)
                        }



                        // Version Information
                        VStack(spacing: 4) {
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Phlock v\(version) (\(build))")
                                    .font(.lora(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Text("TestFlight Beta")
                                .font(.lora(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            // DEBUG: Reset Onboarding
                            Button {
                                UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
                                Task {
                                    if let userId = authState.currentUser?.id {
                                        print("🗑️ Attempting to delete daily song for user \(userId)")
                                        do {
                                            try await ShareService.shared.deleteDailySong(for: userId)
                                            print("✅ Successfully deleted daily song")
                                        } catch {
                                            print("❌ Failed to delete daily song: \(error)")
                                        }
                                    }
                                    await authState.signOut()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("Reset Onboarding (Debug)")
                                        .font(.lora(size: 11))
                                        .foregroundColor(.red)
                                    Text("Note: Backend data persists. Use a test account for fresh experience.")
                                        .font(.lora(size: 9))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            // Listen for scroll to top trigger (passed via environment or binding if we kept it, but we removed binding)
            // We'll need to re-add the binding if we want scroll to top to work, but for now focus on the gear icon.
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.primary)
                }
            }
        }
        .instagramRefreshable {
            // Pull to refresh
            print("🔄 User initiated pull-to-refresh on ProfileView")
            await authState.refreshMusicData()
            if let user = authState.currentUser {
                await loadData(for: user)
            }
            refreshCount += 1 // Force view to re-render
        }
        .id(refreshCount) // Force view refresh when refreshCount changes
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSongPickerSheet) {
            DiscoverView(
                navigationPath: $songPickerNavPath,
                clearSearchTrigger: $songPickerClearTrigger,
                refreshTrigger: $songPickerRefreshTrigger,
                scrollToTopTrigger: $songPickerScrollToTopTrigger
            )
            .environmentObject(authState)
            .environmentObject(playbackService)
            .onDisappear {
                Task {
                    if let user = authState.currentUser {
                        await loadData(for: user)
                    }
                }
            }
        }
        .sheet(item: $selectedUserForProfile) { user in
            NavigationStack {
                UserProfileView(user: user)
                    .environmentObject(authState)
            }
        }
        .sheet(isPresented: $showFollowersList) {
            if let user = authState.currentUser {
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
        }
        .sheet(isPresented: $showPhlockManagerSheet) {
            if let user = authState.currentUser {
                PhlockManagerSheet(
                    currentUserId: user.id,
                    currentPhlockMembers: $phlockMembers,
                    onMemberAdded: { selectedUser in
                        Task {
                            await addToPhlock(user: selectedUser)
                        }
                    },
                    onMemberRemoved: { removedUser in
                        Task {
                            await removeFromPhlock(user: removedUser)
                        }
                    },
                    onMemberSwapped: { oldUser, newUser in
                        Task {
                            await swapPhlockMember(oldUser: oldUser, newUser: newUser)
                        }
                    }
                )
                .presentationDragIndicator(.visible)
            }
        }
        .task(id: authState.currentUser?.id) {
            // Re-run whenever the current user changes (including from nil to a value)
            if let user = authState.currentUser {
                await loadData(for: user)
            }
        }
        .onAppear {
            // Also reload when view appears (e.g., switching tabs)
            if let user = authState.currentUser {
                Task {
                    await loadData(for: user)
                }
            }
        }
    }
    
    private func loadData(for user: User) async {
        // Load insights
        await insightsViewModel.load(for: user)
        insightsLoadedForUser = user.id

        // Clear cache to ensure fresh data on profile load
        FollowService.shared.clearCache(for: user.id)

        // Load follow counts first - these should always succeed and are critical for UI
        do {
            async let followersTask = FollowService.shared.getFollowers(for: user.id)
            async let followingTask = FollowService.shared.getFollowing(for: user.id)
            async let whoHasMeTask = FollowService.shared.getWhoHasMeInPhlock(userId: user.id)
            async let historicalReachTask = FollowService.shared.getHistoricalReach(userId: user.id)

            let (followers, following, whoHasMe, reach) = try await (
                followersTask,
                followingTask,
                whoHasMeTask,
                historicalReachTask
            )

            await MainActor.run {
                self.followerCount = followers.count
                self.followingCount = following.count
                self.actualPhlockCount = whoHasMe.count
                self.historicalReachCount = reach
            }
            print("✅ Loaded follow data: followers=\(followers.count), following=\(following.count), phlockCount=\(whoHasMe.count), reach=\(reach)")
        } catch {
            print("❌ Failed to load follow data: \(error)")
        }

        // Load daily curation data, phlock members, and fresh user data
        // These are independent and can fail without affecting the follow counts
        do {
            async let todaysPickTask = ShareService.shared.getTodaysDailySong(for: user.id)
            async let pastPicksTask = ShareService.shared.getDailySongHistory(for: user.id)
            async let phlockTask = UserService.shared.getPhlockMembers(for: user.id)
            async let freshUserTask = UserService.shared.getUser(userId: user.id)

            let (today, past, phlock, freshUser) = try await (
                todaysPickTask,
                pastPicksTask,
                phlockTask,
                freshUserTask
            )

            await MainActor.run {
                self.todaysPick = today
                self.pastPicks = past
                self.phlockMembers = phlock
                self.refreshedUser = freshUser
            }

            if let freshUser = freshUser {
                print("✅ Refreshed user data: cachedPhlockCount=\(freshUser.phlockCount)")
            }
        } catch {
            print("❌ Failed to load profile data: \(error)")
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

    // MARK: - Phlock Management

    private func addToPhlock(user: User) async {
        guard let currentUserId = authState.currentUser?.id else { return }

        do {
            // Find the next available position (1-5)
            let occupiedPositions = Set(phlockMembers.map { $0.position })
            let nextPosition = (1...5).first { !occupiedPositions.contains($0) } ?? 1

            try await FollowService.shared.addToPhlock(
                userId: user.id,
                position: nextPosition,
                currentUserId: currentUserId
            )

            // Refresh phlock members
            phlockMembers = try await UserService.shared.getPhlockMembers(for: currentUserId)
            print("✅ Added \(user.displayName) to phlock at position \(nextPosition)")
        } catch {
            print("❌ Failed to add to phlock: \(error)")
        }
    }

    private func removeFromPhlock(user: User) async {
        guard let currentUserId = authState.currentUser?.id else { return }

        do {
            try await FollowService.shared.removeFromPhlock(
                userId: user.id,
                currentUserId: currentUserId
            )

            // Refresh phlock members
            phlockMembers = try await UserService.shared.getPhlockMembers(for: currentUserId)
            print("✅ Removed \(user.displayName) from phlock")
        } catch {
            print("❌ Failed to remove from phlock: \(error)")
        }
    }

    private func swapPhlockMember(oldUser: User, newUser: User) async {
        guard let currentUserId = authState.currentUser?.id else { return }

        do {
            let wasImmediate = try await FollowService.shared.swapPhlockMember(
                oldUserId: oldUser.id,
                newUserId: newUser.id,
                currentUserId: currentUserId
            )

            // Refresh phlock members
            phlockMembers = try await UserService.shared.getPhlockMembers(for: currentUserId)

            if wasImmediate {
                print("✅ Swapped \(oldUser.displayName) with \(newUser.displayName) immediately")
            } else {
                print("✅ Swap scheduled for midnight: \(oldUser.displayName) → \(newUser.displayName)")
            }
        } catch {
            print("❌ Failed to swap phlock members: \(error)")
        }
    }
}

struct ProfilePhotoPlaceholder: View {
    let displayName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.1))

            Text(displayName.prefix(1).uppercased())
                .font(.lora(size: 40, weight: .bold))
                .foregroundColor(.black.opacity(0.4))
        }
    }
}

// MARK: - Profile Insights

struct ArtistSendStat: Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

struct GenreSendStat: Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

struct ProfileInsightsSnapshot {
    let uniqueRecipientsCount: Int
    let saveCountAllTime: Int
    let topArtists: [ArtistSendStat]
    let topGenres: [GenreSendStat]
}

@MainActor
class ProfileInsightsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var uniqueRecipientsCount = 0
    @Published var saveCountAllTime = 0
    @Published var topArtists: [ArtistSendStat] = []
    @Published var topGenres: [GenreSendStat] = []
    @Published var errorMessage: String?

    func load(for user: User) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Check for cancellation before starting
            try Task.checkCancellation()

            let shares = try await ShareService.shared.getSentShares(userId: user.id, limit: 400)

            // Check for cancellation after fetch
            try Task.checkCancellation()

            let snapshot = ProfileInsightsCalculator.compute(
                shares: shares,
                knownArtists: user.platformData?.topArtists
            )

            uniqueRecipientsCount = snapshot.uniqueRecipientsCount
            saveCountAllTime = snapshot.saveCountAllTime
            topArtists = snapshot.topArtists
            topGenres = snapshot.topGenres
            errorMessage = nil

            print("✅ Profile insights loaded: reach=\(uniqueRecipientsCount), saves=\(saveCountAllTime), artists=\(topArtists.count)")
        } catch is CancellationError {
            // Task was cancelled (e.g., view dismissed) - ignore silently
            print("⚠️ Profile insights task cancelled")
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // URLSession cancellation - ignore silently
            print("⚠️ Profile insights URL request cancelled")
        } catch {
            // Only set error message for real errors, not cancellations
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("cancel") {
                print("⚠️ Profile insights cancelled: \(error)")
            } else {
                print("❌ Profile insights error: \(error)")
                errorMessage = error.localizedDescription
                uniqueRecipientsCount = 0
                saveCountAllTime = 0
                topArtists = []
                topGenres = []
            }
        }
    }
}

enum ProfileInsightsCalculator {
    static func compute(shares: [Share], knownArtists: [MusicItem]?) -> ProfileInsightsSnapshot {
        // Filter to only daily songs for some insights
        let dailySongs = shares.filter { $0.isDailySong }
        let normalizedShares = dailySongs.sorted { $0.createdAt > $1.createdAt }

        return ProfileInsightsSnapshot(
            uniqueRecipientsCount: uniqueRecipients(from: shares), // Use all shares for reach
            saveCountAllTime: saveCountAllTime(from: shares), // Use all shares for saves
            topArtists: topArtists(from: normalizedShares, limit: 3),
            topGenres: topGenres(from: normalizedShares, knownArtists: knownArtists ?? [])
        )
    }

    private static func uniqueRecipients(from shares: [Share]) -> Int {
        // Count unique recipients, excluding self-shares (where sender = recipient)
        Set(shares.compactMap { share -> UUID? in
            // Only count if recipient is different from sender
            guard share.recipientId != share.senderId else { return nil }
            return share.recipientId
        }).count
    }

    private static func saveCountAllTime(from shares: [Share]) -> Int {
        shares.filter { $0.savedAt != nil }.count
    }

    private static func topArtists(from shares: [Share], limit: Int) -> [ArtistSendStat] {
        var counts: [String: Int] = [:]
        for share in shares {
            let name = share.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            counts[name, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ArtistSendStat(name: $0.key, count: $0.value) }
    }

    private static func topGenres(from shares: [Share], knownArtists: [MusicItem]) -> [GenreSendStat] {
        guard !knownArtists.isEmpty else { return [] }
        var genreCounts: [String: Int] = [:]
        let genreLookup = Dictionary(
            uniqueKeysWithValues: knownArtists.map {
                ($0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), $0.genres ?? [])
            }
        )

        for share in shares {
            let key = share.artistName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let genres = genreLookup[key], !genres.isEmpty else { continue }
            for genre in genres.prefix(3) { // avoid overweighting huge genre lists
                genreCounts[genre, default: 0] += 1
            }
        }

        return genreCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { GenreSendStat(name: $0.key, count: $0.value) }
    }

    private static func shareDate(for share: Share) -> Date {
        share.selectedDate ?? share.createdAt
    }
}

struct ProfileInsightsSection: View {
    let user: User
    @ObservedObject var viewModel: ProfileInsightsViewModel
    var title: String = "activity"
    var actualPhlockCount: Int? = nil // Fetched from follows table, overrides cached user.phlockCount
    var historicalReachCount: Int? = nil // All-time unique users who ever had you in their phlock

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.lora(size: 17, weight: .medium))
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Use actualPhlockCount if provided (fetched from follows table), otherwise fall back to cached value
            let phlockCount = actualPhlockCount ?? user.phlockCount
            // Use historical reach count if provided, otherwise fall back to current phlock count
            let reachCount = historicalReachCount ?? phlockCount

            ProfileStatsRow(
                reachCount: reachCount,
                saveCountAllTime: viewModel.saveCountAllTime,
                phlockCount: phlockCount,
                isLoading: viewModel.isLoading
            )

            TopArtistsSentCard(
                artists: viewModel.topArtists,
                isLoading: viewModel.isLoading
            )

            GenreBreakdownCard(
                genres: viewModel.topGenres,
                isLoading: viewModel.isLoading
            )

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.lora(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct ProfileStatsRow: View {
    let reachCount: Int
    let saveCountAllTime: Int
    let phlockCount: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Reach = unique people who have ever had you in their phlock
            StatPill(
                title: "reach",
                value: "\(reachCount)",
                subtitle: "people reached",
                systemImage: "person.2.fill",
                customIcon: nil,
                isLoading: isLoading
            )

            StatPill(
                title: "saves",
                value: "\(saveCountAllTime)",
                subtitle: "from my shares",
                systemImage: "plus.circle",
                customIcon: nil,
                isLoading: isLoading
            )

            // Phlocks = current number of people who have you in their phlock
            StatPill(
                title: "phlocks",
                value: "\(phlockCount)",
                subtitle: "i'm in",
                systemImage: nil,
                customIcon: AnyView(
                    MiniPhlockGlyph()
                        .frame(width: 14, height: 14)
                ),
                isLoading: isLoading
            )
        }
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemImage: String?
    let customIcon: AnyView?
    let isLoading: Bool
    @Environment(\.colorScheme) var colorScheme

    private let titleFont = Font.lora(size: 11.5)
    private let valueFont = Font.lora(size: 21, weight: .semiBold).monospacedDigit()
    private let subtitleFont = Font.lora(size: 11)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let customIcon {
                    customIcon
                        .foregroundColor(.secondary)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
                Text(title)
                    .font(titleFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(value)
                    .font(valueFont)
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.1))
        .cornerRadius(12)
    }
}

/// Minimal phlock-like glyph for compact stat pills
struct MiniPhlockGlyph: View {
    private let radius: CGFloat = 7
    private let dotSize: CGFloat = 3.5

    var body: some View {
        ZStack {
            Circle()
                .frame(width: dotSize + 0.5, height: dotSize + 0.5)

            ForEach(0..<6) { index in
                let angle = -Double.pi / 2 + Double(index) * (2 * .pi / 6)
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .offset(
                        x: CGFloat(cos(angle)) * radius,
                        y: CGFloat(sin(angle)) * radius
                    )
            }
        }
        .foregroundColor(.secondary)
    }
}

struct TopArtistsSentCard: View {
    let artists: [ArtistSendStat]
    let isLoading: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var artistToOpen: ArtistSendStat?
    @State private var showPlatformSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("top artists i send (30d)")
                .font(.lora(size: 16, weight: .medium))

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if artists.isEmpty {
                Text("no artist data yet.")
                    .font(.lora(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .leading)

                        Text(artist.name)
                            .font(.lora(size: 15))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 12) {
                            Button {
                                artistToOpen = artist
                                showPlatformSheet = true
                            } label: {
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.lora(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)

                            Text("\(artist.count)")
                                .font(.lora(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)

                    if index < artists.count - 1 {
                        Divider()
                            .padding(.leading, 34)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.06))
        .cornerRadius(12)
        .confirmationDialog(
            "Open artist in",
            isPresented: $showPlatformSheet,
            titleVisibility: .visible
        ) {
            if let artist = artistToOpen {
                Button("Spotify") {
                    openArtistInSpotifySearch(name: artist.name)
                }
                Button("Apple Music") {
                    openArtistInAppleMusicSearch(name: artist.name)
                }
            }
            Button("Cancel", role: .cancel) { artistToOpen = nil }
        }
    }

    private func openArtistInSpotifySearch(name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        if let url = URL(string: "https://open.spotify.com/search/\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func openArtistInAppleMusicSearch(name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        if let url = URL(string: "https://music.apple.com/us/search?term=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

struct GenreBreakdownCard: View {
    let genres: [GenreSendStat]
    let isLoading: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("top genres from my shares")
                .font(.lora(size: 16, weight: .medium))

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if genres.isEmpty {
                Text("no genre data yet.")
                    .font(.lora(size: 11))
                    .foregroundColor(.secondary)
            } else {
                let maxCount = max(genres.map { $0.count }.max() ?? 1, 1)

                ForEach(genres) { genre in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(genre.name.capitalized)
                                .font(.lora(size: 14))
                                .lineLimit(1)
                            Spacer()
                            Text("\(genre.count)")
                                .font(.lora(size: 12))
                                .foregroundColor(.secondary)
                        }

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(colorScheme == .dark ? 0.35 : 0.18))
                                .frame(height: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.75))
                                        .frame(
                                            width: max(
                                                CGFloat(genre.count) / CGFloat(maxCount) * geometry.size.width,
                                                6
                                            ),
                                            height: 8
                                        ),
                                    alignment: .leading
                                )
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.06))
        .cornerRadius(12)
    }
}

struct MusicStatsCard: View {
    let title: String
    let items: [MusicItem]
    let platformType: PlatformType
    let itemType: MusicItemType
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @State private var isExpanded = false
    @State private var showPlatformSheet = false
    @State private var selectedArtist: MusicItem?
    @State private var showQuickSendBar = false
    @State private var trackToShare: MusicItem?

    enum MusicItemType {
        case track
        case artist
    }

    private var deduplicatedItems: [MusicItem] {
        // Deduplicate items by ID, keeping only the most recent one
        var uniqueItems: [String: MusicItem] = [:]

        print("🎵 MusicStatsCard rendering with \(items.count) items for \(title)")
        if let firstItem = items.first {
            print("   First item: \(firstItem.name) - albumArtUrl: \(firstItem.albumArtUrl ?? "nil") - played at: \(firstItem.playedAt?.description ?? "no timestamp")")
        }

        for item in items {
            // If we haven't seen this item yet, or if this one is more recent, keep it
            if let existingItem = uniqueItems[item.id] {
                if let newPlayedAt = item.playedAt,
                   let existingPlayedAt = existingItem.playedAt,
                   newPlayedAt > existingPlayedAt {
                    uniqueItems[item.id] = item
                }
            } else {
                uniqueItems[item.id] = item
            }
        }

        // Sort by playedAt (most recent first) and maintain original order
        return items
            .filter { item in
                uniqueItems[item.id]?.playedAt == item.playedAt
            }
    }

    private var displayedItems: [MusicItem] {
        let list = deduplicatedItems
        return isExpanded ? list : Array(list.prefix(5))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.lora(size: 17, weight: .medium))
                    .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(Array(displayedItems.enumerated()), id: \.offset) { index, item in
                    Button {
                        if itemType == .track {
                            let isCurrentTrack = playbackService.currentTrack?.id == item.id
                            if isCurrentTrack {
                                playbackService.isPlaying ? playbackService.pause() : playbackService.resume()
                            } else {
                                let queueItems = deduplicatedItems
                                let startIndex = queueItems.firstIndex(where: { $0.id == item.id }) ?? index
                                playbackService.startQueue(
                                    tracks: queueItems,
                                    startAt: startIndex,
                                    showMiniPlayer: true
                                )
                            }
                        } else {
                            // Show action sheet for artist
                            selectedArtist = item
                            showPlatformSheet = true
                        }
                    } label: {
                        let isCurrentTrack = itemType == .track && playbackService.currentTrack?.id == item.id
                        let isPlaying = isCurrentTrack && playbackService.isPlaying

                        HStack(spacing: 8) {
                            // Playing indicator bar for tracks
                            if isCurrentTrack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.primary)
                                    .frame(width: 4, height: 30)
                            }

                            Text("\(index + 1).")
                                .font(.lora(size: 15))
                                .foregroundColor(.secondary)
                                .frame(width: 24, alignment: .leading)

                            // Album art for tracks, artist image for artists
                            Group {
                                if let artworkUrl = item.albumArtUrl, let url = URL(string: artworkUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .failure:
                                            // Show initials on failure
                                            artistInitialsPlaceholder(for: item.name)
                                        case .empty:
                                            Color.gray.opacity(0.2)
                                        @unknown default:
                                            Color.gray.opacity(0.2)
                                        }
                                    }
                                } else {
                                    // No URL - show initials for artists, gray for tracks
                                    if itemType == .artist {
                                        artistInitialsPlaceholder(for: item.name)
                                    } else {
                                        Color.gray.opacity(0.2)
                                    }
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: itemType == .track ? 4 : 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: itemType == .track ? 4 : 20)
                                    .stroke(isCurrentTrack ? Color.primary : Color.clear, lineWidth: 2.5)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.lora(size: 15))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                // Show timestamp for tracks only (not artists)
                                if itemType == .track, let playedAt = item.playedAt {
                                    Text(playedAt.shortRelativeTimeString())
                                        .font(.lora(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Different icons based on action type
                            if itemType == .track {
                                // Show pause icon if playing, play icon if not
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.lora(size: 22))
                                    .foregroundColor(isCurrentTrack ? .primary : .secondary)
                            } else {
                                // External link icon for artists (opens action sheet)
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.lora(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            isCurrentTrack
                                ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                                : Color.clear
                        )
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                // Prevent row tap when tapping send button
                            }
                    )

                    if index < displayedItems.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.leading, 80) // Additional: 24 (number) + 8 (spacing) + 40 (artwork) + 8 (spacing)
                    }
                }

                // Show expand/collapse button if there are more than 5 items
                if items.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            Text(isExpanded ? "show less" : "show more")
                                .font(.lora(size: 13))
                                .foregroundColor(.secondary)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.lora(size: 10))
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                }
                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .confirmationDialog(
                    "Open artist in",
                    isPresented: $showPlatformSheet,
                    titleVisibility: .visible
                ) {
                    Button("Spotify") {
                        if let artist = selectedArtist {
                            openArtistInPlatform(item: artist, platform: .spotify)
                        }
                    }
                    Button("Apple Music") {
                        if let artist = selectedArtist {
                            openArtistInPlatform(item: artist, platform: .appleMusic)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            // Share sheet overlay
            if showQuickSendBar, let track = trackToShare {
                VStack {
                    Spacer()
                    ShareOptionsSheet(
                        track: track,
                    shareURL: ShareLinkBuilder.url(for: track),
                    context: .overlay,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showQuickSendBar = false
                                trackToShare = nil
                            }
                        },
                        onCopy: { url in UIPasteboard.general.string = url.absoluteString },
                        onOpen: { url in UIApplication.shared.open(url) },
                        onFallback: { _ in }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showQuickSendBar)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    @ViewBuilder
    private func artistInitialsPlaceholder(for name: String) -> some View {
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
            Text(initials.isEmpty ? "?" : initials)
                .font(.lora(size: 14, weight: .semiBold))
                .foregroundColor(.secondary)
        }
    }

    private func openArtistInPlatform(item: MusicItem, platform: PlatformType) {
        switch platform {
        case .spotify:
            // Use stored Spotify ID if available, otherwise fallback to search
            if let spotifyId = item.spotifyId, !spotifyId.isEmpty {
                let artistURL = "https://open.spotify.com/artist/\(spotifyId)"
                print("✅ Opening Spotify artist with stored ID: \(spotifyId)")
                if let url = URL(string: artistURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                // Fallback to search for artist to get ID, then open their page
                print("⚠️ No stored Spotify ID, searching for artist: \(item.name)")
                Task {
                    await openArtistInSpotify(artistName: item.name)
                }
            }

        case .appleMusic:
            // Use stored Apple Music ID if available, otherwise search catalog
            if let appleMusicId = item.appleMusicId, !appleMusicId.isEmpty, appleMusicId != item.name {
                // Only use the ID if it's not just the artist name (fallback)
                let artistURL = "music://music.apple.com/us/artist/\(appleMusicId)"
                print("✅ Opening Apple Music artist with stored ID: \(appleMusicId)")
                if let url = URL(string: artistURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                // Fallback to catalog search if no stored Apple Music ID
                print("⚠️ No stored Apple Music ID, searching catalog for: \(item.name)")
                Task {
                    await openArtistInAppleMusic(artistName: item.name)
                }
            }
        }
    }

    private func openArtistInSpotify(artistName: String) async {
        // For Spotify, search for the artist to get their ID, then open their page
        print("🔍 Searching for Spotify artist: \(artistName)")

        do {
            // Call Supabase Edge Function to search for Spotify artist
            struct SearchResponse: Decodable {
                let spotifyId: String?
            }

            let supabase = PhlockSupabaseClient.shared.client
            let response: SearchResponse = try await supabase.functions.invoke(
                "search-spotify-artist",
                options: FunctionInvokeOptions(body: ["artistName": artistName])
            )

            if let spotifyId = response.spotifyId {
                // Got the Spotify ID, open the artist page directly
                print("✅ Found Spotify artist ID: \(spotifyId)")
                let artistURL = "https://open.spotify.com/artist/\(spotifyId)"

                await MainActor.run {
                    if let url = URL(string: artistURL) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("✅ Opened Spotify artist page: \(success)")
                        }
                    }
                }
            } else {
                // No artist found, fallback to search
                print("⚠️ No Spotify artist found, opening search")
                await openSpotifySearch(artistName: artistName)
            }
        } catch {
            // Error searching, fallback to search
            print("❌ Error searching for artist: \(error)")
            await openSpotifySearch(artistName: artistName)
        }
    }

    private func openSpotifySearch(artistName: String) async {
        // Fallback to opening Spotify search
        let searchQuery = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        let spotifyURL = "https://open.spotify.com/search/\(searchQuery)"

        await MainActor.run {
            if let url = URL(string: spotifyURL) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func openArtistInAppleMusic(artistName: String) async {
        // For Apple Music, search for the artist to get the catalog ID
        print("🔍 Searching for artist: \(artistName)")

        do {
            var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [Artist.self])
            searchRequest.limit = 1

            let searchResponse = try await searchRequest.response()

            if let artist = searchResponse.artists.first {
                // Got the artist, open their page using the app URL scheme
                let artistId = artist.id.rawValue
                let artistURL = "music://music.apple.com/us/artist/\(artistId)"

                print("✅ Found artist catalog ID: \(artistId)")

                await MainActor.run {
                    if let url = URL(string: artistURL) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("✅ Opened artist page in Apple Music app")
                            } else {
                                // Fallback to web URL if app scheme doesn't work
                                print("⚠️ App URL failed, trying web URL")
                                let webURL = "https://music.apple.com/us/artist/\(artistId)"
                                if let webUrl = URL(string: webURL) {
                                    UIApplication.shared.open(webUrl)
                                }
                            }
                        }
                    }
                }
            } else {
                print("❌ Artist not found in search results")
            }
        } catch {
            print("❌ Search failed: \(error)")
        }
    }

}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationState())
}

struct TodaysPickCard: View {
    let share: Share?
    let isCurrentUser: Bool
    let onPickSong: () -> Void
    var userId: UUID? = nil  // User ID for nudge functionality (when viewing other profiles)
    var onNudge: (() -> Void)? = nil  // Callback when nudge button is tapped
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService

    private var isCurrentTrack: Bool {
        guard let share = share else { return false }
        return playbackService.currentTrack?.id == share.trackId
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today's pick")
                .font(.lora(size: 17, weight: .medium))
                .padding(.horizontal, 24)

            if let share = share {
                Button {
                    let track = MusicItem(
                        id: share.trackId,
                        name: share.trackName,
                        artistName: share.artistName,
                        previewUrl: share.previewUrl,
                        albumArtUrl: share.albumArtUrl
                    )
                    
                    // Toggle play/pause if this track is current, otherwise play it
                    if isCurrentTrack {
                        if playbackService.isPlaying {
                            playbackService.pause()
                        } else {
                            playbackService.resume()
                        }
                    } else {
                        playbackService.startQueue(
                            tracks: [track],
                            startAt: 0,
                            sourceIds: [Optional(share.id.uuidString)],
                            showMiniPlayer: true
                        )
                    }
                } label: {
                    HStack(spacing: 16) {
                        // Playing indicator bar
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary)
                                .frame(width: 4, height: 60)
                        }
                        
                        // Album Art
                        if let artworkUrl = share.albumArtUrl, let url = URL(string: artworkUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(share.trackName)
                                .font(.lora(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text(share.artistName)
                                .font(.lora(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            if let message = share.message, !message.isEmpty {
                                Text("\"\(message)\"")
                                    .font(.lora(size: 13))
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                        
                        // Play/Pause Icon
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.lora(size: 32, weight: .medium))
                            .foregroundColor(isCurrentTrack ? .primary : .secondary)
                    }
                    .padding(16)
                    .background(
                        isPlaying 
                            ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1)
                            : Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.06)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
            } else if isCurrentUser {
                Button(action: onPickSong) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("pick your song for today")
                                .font(.lora(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Text("keep your streak alive 🔥")
                                .font(.lora(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.lora(size: 32, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.06))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
            } else {
                // Empty state for other users
                HStack {
                    Text("i haven't chosen a song today yet")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Nudge button (shows "nudged" state when already nudged)
                    if let onNudge = onNudge {
                        Button(action: onNudge) {
                            HStack(spacing: 4) {
                                Text("👋")
                                    .font(.system(size: 14))
                                Text("nudge")
                                    .font(.lora(size: 13, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    } else if userId != nil {
                        // Already nudged state
                        HStack(spacing: 4) {
                            Text("✓")
                                .font(.system(size: 12, weight: .medium))
                            Text("nudged")
                                .font(.lora(size: 13, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.08))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct PastPicksView: View {
    let shares: [Share]
    @EnvironmentObject var playbackService: PlaybackService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("past picks")
                .font(.lora(size: 17, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            if shares.isEmpty {
                Text("no past picks yet.")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
            } else {
                let limitedShares = Array(shares.prefix(10))
                VStack(spacing: 0) {
                    ForEach(Array(limitedShares.enumerated()), id: \.element.id) { index, share in
                        Button {
                            let track = MusicItem(
                                id: share.trackId,
                                name: share.trackName,
                                artistName: share.artistName,
                                previewUrl: share.previewUrl,
                                albumArtUrl: share.albumArtUrl
                            )
                            let tracks = limitedShares.map {
                                MusicItem(
                                    id: $0.trackId,
                                    name: $0.trackName,
                                    artistName: $0.artistName,
                                    previewUrl: $0.previewUrl,
                                    albumArtUrl: $0.albumArtUrl
                                )
                            }

                            if playbackService.currentTrack?.id == track.id {
                                playbackService.isPlaying ? playbackService.pause() : playbackService.resume()
                            } else {
                                playbackService.startQueue(
                                    tracks: tracks,
                                    startAt: index,
                                    sourceIds: limitedShares.map { Optional($0.id.uuidString) },
                                    showMiniPlayer: true
                                )
                            }
                        } label: {
                            HStack(spacing: 12) {
                                // Artwork
                                if let artworkUrl = share.albumArtUrl, let url = URL(string: artworkUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(4)
                                } else {
                                    Color.gray.opacity(0.2)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(4)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(share.trackName)
                                        .font(.lora(size: 15))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    Text(share.artistName)
                                        .font(.lora(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Date on the right
                                Text(share.formattedDate)
                                    .font(.lora(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        if index < min(shares.count, 10) - 1 {
                            Divider()
                                .padding(.leading, 86)
                        }
                    }
                }
            }
        }
    }
}

struct PhlockMembersRow: View {
    let members: [FriendWithPosition]
    let onMemberTapped: (User) -> Void
    let onEditTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    // Calculate empty slots (max 5 members in a phlock)
    private var emptySlots: Int {
        max(0, 5 - members.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("my phlock")
                .font(.lora(size: 17, weight: .medium))
                .padding(.horizontal, 24)

            if members.isEmpty && emptySlots > 0 {
                Text("add members to your phlock to get started.")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    // Existing members with streak badges
                    ForEach(members) { member in
                        Button {
                            onMemberTapped(member.user)
                        } label: {
                            VStack(spacing: 8) {
                                // Fixed height container for photo + streak badge
                                ZStack(alignment: .bottom) {
                                    // Profile photo
                                    Group {
                                        if let photoUrl = member.user.profilePhotoUrl, let url = URL(string: photoUrl) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                ProfilePhotoPlaceholder(displayName: member.user.displayName)
                                            }
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                        } else {
                                            ProfilePhotoPlaceholder(displayName: member.user.displayName)
                                                .frame(width: 60, height: 60)
                                        }
                                    }

                                    // Streak badge overlapping bottom
                                    if member.user.dailySongStreak > 0 {
                                        StreakBadge(streak: member.user.dailySongStreak, size: .small)
                                            .offset(y: 8)
                                    }
                                }
                                .frame(height: 60) // Fixed height to match placeholders

                                Text(member.user.displayName)
                                    .font(.lora(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .frame(width: 70)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Empty slot placeholders - tap to open edit sheet
                    ForEach(0..<emptySlots, id: \.self) { index in
                        Button {
                            onEditTapped()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(
                                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                                        )
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .frame(width: 60, height: 60)

                                    Circle()
                                        .fill(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.08))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "plus")
                                        .font(.lora(size: 20, weight: .semiBold))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .frame(height: 60) // Fixed height to match

                                Text("add")
                                    .font(.lora(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Three-dot menu button
                    Button {
                        onEditTapped()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.12))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "ellipsis")
                                    .font(.lora(size: 20, weight: .semiBold))
                                    .foregroundColor(.primary)
                            }
                            .frame(height: 60) // Fixed height to match

                            Text("edit")
                                .font(.lora(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(width: 70)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Unified Phlock Manager Sheet

struct PhlockManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    let currentUserId: UUID
    @Binding var currentPhlockMembers: [FriendWithPosition]
    let onMemberAdded: (User) -> Void
    let onMemberRemoved: (User) -> Void
    let onMemberSwapped: (User, User) -> Void

    @State private var followingList: [User] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var memberToReplace: User?

    // Filter out users already in phlock
    private var availableUsers: [User] {
        let phlockMemberIds = Set(currentPhlockMembers.map { $0.user.id })
        return followingList.filter { !phlockMemberIds.contains($0.id) }
    }

    // Filter by search text
    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return availableUsers
        }
        return availableUsers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Get sorted slots (filled and empty)
    private var sortedSlots: [(position: Int, member: FriendWithPosition?)] {
        (1...5).map { position in
            let member = currentPhlockMembers.first { $0.position == position }
            return (position, member)
        }
    }

    // Check if phlock is full
    private var isPhlockFull: Bool {
        currentPhlockMembers.count >= 5
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Current Members Section (5 slots)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("my phlock")
                            .font(.lora(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        VStack(spacing: 0) {
                            ForEach(sortedSlots, id: \.position) { slot in
                                if let member = slot.member {
                                    // Filled slot
                                    filledSlotRow(member: member, position: slot.position)
                                } else {
                                    // Empty slot
                                    emptySlotRow(position: slot.position)
                                }

                                if slot.position < 5 {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.06))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }

                    // MARK: - Available Friends Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("add from following")
                            .font(.lora(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)

                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("search", text: $searchText)
                                .font(.lora(size: 16))
                        }
                        .padding(12)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 40)
                        } else if availableUsers.isEmpty {
                            VStack(spacing: 8) {
                                Text("no friends available")
                                    .font(.lora(size: 14, weight: .medium))
                                Text("follow more people to add them")
                                    .font(.lora(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else if filteredUsers.isEmpty {
                            VStack(spacing: 8) {
                                Text("no matches found")
                                    .font(.lora(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(filteredUsers, id: \.id) { user in
                                    availableFriendRow(user: user)

                                    if user.id != filteredUsers.last?.id {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                            .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.06))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("edit phlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                    .font(.lora(size: 16, weight: .medium))
                }
            }
        }
        .task {
            await loadFollowing()
        }
    }

    // MARK: - Filled Slot Row

    @ViewBuilder
    private func filledSlotRow(member: FriendWithPosition, position: Int) -> some View {
        HStack(spacing: 12) {
            // Profile photo with streak
            ProfilePhotoWithStreak(
                photoUrl: member.user.profilePhotoUrl,
                displayName: member.user.displayName,
                streak: member.user.dailySongStreak,
                size: 44,
                badgeSize: .small
            )
            .frame(width: 44, height: 54) // Extra height for streak badge

            VStack(alignment: .leading, spacing: 2) {
                Text(member.user.displayName)
                    .font(.lora(size: 16, weight: .medium))
                if let username = member.user.username {
                    Text("@\(username)")
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Replace button
            Button {
                memberToReplace = member.user
            } label: {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // Remove button
            Button {
                // Clear memberToReplace if this member was selected for replacement
                if memberToReplace?.id == member.user.id {
                    memberToReplace = nil
                }
                onMemberRemoved(member.user)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Highlight if this member is selected for replacement
            memberToReplace?.id == member.user.id
                ? Color.blue.opacity(0.1)
                : Color.clear
        )
    }

    // MARK: - Empty Slot Row

    @ViewBuilder
    private func emptySlotRow(position: Int) -> some View {
        HStack(spacing: 12) {
            // Empty circle placeholder
            ZStack {
                Circle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .foregroundColor(.secondary.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.4))
            }

            Text("add member to phlock")
                .font(.lora(size: 15))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Available Friend Row

    @ViewBuilder
    private func availableFriendRow(user: User) -> some View {
        Button {
            if let replacingUser = memberToReplace {
                // Swap mode: replace the selected member
                onMemberSwapped(replacingUser, user)
                memberToReplace = nil
            } else if !isPhlockFull {
                // Add mode: add to next available slot
                onMemberAdded(user)
            }
        } label: {
            HStack(spacing: 12) {
                // Profile photo with streak
                ProfilePhotoWithStreak(
                    photoUrl: user.profilePhotoUrl,
                    displayName: user.displayName,
                    streak: user.dailySongStreak,
                    size: 44,
                    badgeSize: .small
                )
                .frame(width: 44, height: 54) // Extra height for streak badge

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.lora(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.lora(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Show swap icon if in replace mode, plus icon otherwise
                if memberToReplace != nil {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                } else if !isPhlockFull {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else {
                    // Phlock is full and not in replace mode
                    Text("full")
                        .font(.lora(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isPhlockFull && memberToReplace == nil)
        .opacity(isPhlockFull && memberToReplace == nil ? 0.5 : 1.0)
    }

    private func loadFollowing() async {
        do {
            followingList = try await FollowService.shared.getFollowing(for: currentUserId)
        } catch {
            print("❌ Failed to load following list: \(error)")
        }
        isLoading = false
    }
}
