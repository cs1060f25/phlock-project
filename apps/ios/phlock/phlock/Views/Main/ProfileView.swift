import SwiftUI
import Combine
import MusicKit
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme
    @Binding var scrollToTopTrigger: Int
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

    // Profile Photo Picker
    @State private var showImagePicker = false
    @State private var selectedProfileImage: Image?
    @State private var selectedProfileImageData: Data?
    @State private var isUploadingPhoto = false
    
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

    // Feedback dialog (only for @woon)
    @State private var showFeedbackDialog = false

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
                        VStack(alignment: .leading, spacing: 12) {
                            // Top row: Profile photo on left, followers/following on right
                            HStack(alignment: .top, spacing: 16) {
                                // Profile Photo with Streak Badge and Camera Overlay
                                VStack(spacing: 0) {
                                    Button {
                                        showImagePicker = true
                                    } label: {
                                        ZStack {
                                            // Profile photo or placeholder
                                            if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                                                AsyncImage(url: url) { image in
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                } placeholder: {
                                                    ProfilePhotoPlaceholder(displayName: user.displayName)
                                                }
                                                .frame(width: 90, height: 90)
                                                .clipShape(Circle())
                                            } else {
                                                ProfilePhotoPlaceholder(displayName: user.displayName)
                                                    .frame(width: 90, height: 90)
                                            }

                                            // Camera overlay based on state
                                            // State 1: Has streak + No photo → Full circle camera overlay
                                            if user.dailySongStreak > 0 && user.profilePhotoUrl == nil {
                                                Circle()
                                                    .fill(Color.black.opacity(0.5))
                                                    .frame(width: 90, height: 90)

                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                            }
                                            // State 2: Has streak + Has photo → No overlay (just tappable)
                                            // (no overlay needed)

                                            // State 3: No streak → Small camera badge at bottom center
                                            if user.dailySongStreak == 0 {
                                                VStack {
                                                    Spacer()
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.black.opacity(0.7))
                                                            .frame(width: 26, height: 26)

                                                        Image(systemName: "camera.fill")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.white)
                                                    }
                                                    .offset(y: 5)
                                                }
                                                .frame(width: 90, height: 90)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isUploadingPhoto)
                                    .overlay {
                                        if isUploadingPhoto {
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                                .frame(width: 90, height: 90)
                                            ProgressView()
                                                .tint(.white)
                                        }
                                    }

                                    // Streak badge overlapping the photo bottom (only when streak > 0)
                                    if user.dailySongStreak > 0 {
                                        StreakBadge(streak: user.dailySongStreak, size: .medium)
                                            .offset(y: -10)
                                    }
                                }

                                // Right side: Display name at top, stats row below
                                VStack(alignment: .leading, spacing: 8) {
                                    // Display Name with Platform Logo
                                    HStack(spacing: 6) {
                                        Text(user.displayName)
                                            .font(.lora(size: 20, weight: .bold))

                                        if let platform = user.resolvedPlatformType {
                                            Image(platform == .spotify ? "SpotifyLogo" : "AppleMusicLogo")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                        }
                                    }

                                    // Stats Row: picks | followers | following
                                    HStack(spacing: 0) {
                                        // Picks
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("\(pastPicks.count + (todaysPick != nil ? 1 : 0))")
                                                .font(.lora(size: 16, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("picks")
                                                .font(.lora(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        // Followers
                                        Button {
                                            followListInitialTab = .followers
                                            showFollowersList = true
                                        } label: {
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text("\(followerCount)")
                                                    .font(.lora(size: 16, weight: .bold))
                                                    .foregroundColor(.primary)
                                                Text("followers")
                                                    .font(.lora(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        // Following
                                        Button {
                                            followListInitialTab = .following
                                            showFollowersList = true
                                        } label: {
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text("\(followingCount)")
                                                    .font(.lora(size: 16, weight: .bold))
                                                    .foregroundColor(.primary)
                                                Text("following")
                                                    .font(.lora(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)

                            // Bio (below the row, full width)
                            if let bio = user.bio {
                                Text(bio)
                                    .font(.lora(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 24)
                            }

                            // Feedback button (only for @woon) - above edit profile
                            if user.username == "woon" {
                                Button {
                                    showFeedbackDialog = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bubble.left.and.bubble.right")
                                            .font(.system(size: 14))
                                        Text("reach out")
                                            .font(.lora(size: 17))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 24)
                            }

                            // Edit Profile Button
                            Button {
                                showEditProfile = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10))
                                    Text("edit profile")
                                        .font(.lora(size: 12))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 16)
                        
                        // Today's Pick
                        TodaysPickCard(
                            share: todaysPick,
                            isCurrentUser: true, // Since we are viewing own profile for now
                            onPickSong: {
                                showSongPickerSheet = true
                            },
                            streak: user.dailySongStreak
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
                            historicalReachCount: historicalReachCount,
                            hasPicks: todaysPick != nil || !pastPicks.isEmpty,
                            onPickSong: { showSongPickerSheet = true }
                        )

                        // Past Picks
                        PastPicksView(
                            shares: pastPicks,
                            onPickSong: { showSongPickerSheet = true }
                        )
                        
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

                            // DEBUG: Reset Onboarding (only visible for @woon)
                            if authState.currentUser?.username == "woon" {
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
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .onChange(of: scrollToTopTrigger) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    scrollProxy.scrollTo("profileTop", anchor: .top)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let username = authState.currentUser?.username {
                    Text("@\(username)")
                        .font(.lora(size: 20, weight: .bold))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
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
                    .environmentObject(PlaybackService.shared)
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
                UnifiedPhlockSheet(
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
                    title: "edit phlock"
                )
                .environmentObject(authState)
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedProfileImage, imageData: $selectedProfileImageData)
        }
        .confirmationDialog(
            "How would you like to provide feedback?",
            isPresented: $showFeedbackDialog,
            titleVisibility: .visible
        ) {
            Button("anonymous form") {
                if let url = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfgipxfs0PlSAJ7L5niN7R7aH4kSE7GvPDqbQlyELwkU8PCrQ/viewform") {
                    UIApplication.shared.open(url)
                }
            }
            Button("text me directly") {
                let phoneNumber = "2016938577"
                let message = "I have feedback for phlock!"
                if let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "sms:\(phoneNumber)&body=\(encodedMessage)") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: selectedProfileImageData) { newImageData in
            // Upload the new profile photo when selected
            if let imageData = newImageData {
                Task {
                    await uploadProfilePhoto(imageData: imageData)
                }
            }
        }
        .task(id: authState.currentUser?.id) {
            // Re-run whenever the current user changes (including from nil to a value)
            if let user = authState.currentUser {
                await loadData(for: user)
            }
        }
        .onAppear {
            // Refresh data every time the view appears (e.g., when navigating back from another profile)
            Task {
                if let user = authState.currentUser {
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

    // MARK: - Profile Photo Upload

    private func uploadProfilePhoto(imageData: Data) async {
        await MainActor.run {
            isUploadingPhoto = true
        }

        print("📸 Uploading profile photo (\(imageData.count) bytes)...")

        // Upload photo using authState
        let uploadedUrl = await authState.uploadProfilePhoto(imageData: imageData)

        if let uploadedUrl = uploadedUrl {
            print("✅ Photo uploaded successfully: \(uploadedUrl)")

            // Update profile with the new photo URL
            await authState.updateProfile(
                displayName: authState.currentUser?.displayName ?? "",
                username: authState.currentUser?.username,
                bio: authState.currentUser?.bio,
                profilePhotoUrl: uploadedUrl
            )

            print("✅ Profile updated with new photo")
        } else {
            print("❌ Photo upload failed")
        }

        await MainActor.run {
            isUploadingPhoto = false
            // Clear the selected image data to allow re-selection
            selectedProfileImage = nil
            selectedProfileImageData = nil
        }
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
    let spotifyId: String?  // Spotify artist ID for direct profile linking
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
        // Track both count and most recent artist ID for each artist name
        var artistData: [String: (count: Int, spotifyId: String?)] = [:]

        for share in shares {
            let name = share.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let existing = artistData[name]
            // Use artist ID from most recent share (shares are sorted by date desc)
            let spotifyId = existing?.spotifyId ?? share.artistId
            artistData[name] = (count: (existing?.count ?? 0) + 1, spotifyId: spotifyId)
        }

        return artistData
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { ArtistSendStat(name: $0.key, count: $0.value.count, spotifyId: $0.value.spotifyId) }
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
    var hasPicks: Bool = false
    var onPickSong: (() -> Void)? = nil
    var isCurrentUser: Bool = true

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
                isLoading: viewModel.isLoading,
                isCurrentUser: isCurrentUser
            )

            TopArtistsSentCard(
                artists: viewModel.topArtists,
                isLoading: viewModel.isLoading,
                onPickSong: onPickSong,
                isCurrentUser: isCurrentUser
            )

            GenreBreakdownCard(
                genres: viewModel.topGenres,
                isLoading: viewModel.isLoading,
                hasPicks: hasPicks,
                onPickSong: onPickSong,
                isCurrentUser: isCurrentUser
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
    var isCurrentUser: Bool = true

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
                subtitle: isCurrentUser ? "from my shares" : "from shares",
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
    var onPickSong: (() -> Void)? = nil
    var isCurrentUser: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @State private var artistToOpen: ArtistSendStat?
    @State private var showPlatformSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isCurrentUser ? "top artists i've sent (last 30 days)" : "top artists (last 30 days)")
                .font(.lora(size: 16, weight: .medium))

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if artists.isEmpty {
                if let onPickSong = onPickSong, isCurrentUser {
                    Button(action: onPickSong) {
                        HStack {
                            Text("pick your first song to start tracking")
                                .font(.lora(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(isCurrentUser ? "start sharing to see your favorites" : "no sharing history yet")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
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
                    openArtistInSpotify(artist: artist)
                }
                Button("Apple Music") {
                    openArtistInAppleMusic(name: artist.name)
                }
            }
            Button("Cancel", role: .cancel) { artistToOpen = nil }
        }
    }

    /// Extract the primary artist name (first artist before any featuring/collaboration markers)
    private func primaryArtistName(from fullName: String) -> String {
        // Split on common collaboration delimiters and take the first artist
        let delimiters = CharacterSet(charactersIn: ",&")
        let patterns = ["ft.", "ft ", "feat.", "feat ", "featuring ", " x ", " X "]

        var name = fullName

        // First check for "ft.", "feat.", etc. patterns
        for pattern in patterns {
            if let range = name.lowercased().range(of: pattern) {
                name = String(name[..<range.lowerBound])
                break
            }
        }

        // Then split on comma or ampersand and take first
        if let firstPart = name.components(separatedBy: delimiters).first {
            name = firstPart
        }

        return name.trimmingCharacters(in: .whitespaces)
    }

    private func openArtistInSpotify(artist: ArtistSendStat) {
        // Use direct profile link if we have the Spotify artist ID
        if let spotifyId = artist.spotifyId, !spotifyId.isEmpty {
            if let url = URL(string: "https://open.spotify.com/artist/\(spotifyId)") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fall back to search if no ID available
        let artistName = primaryArtistName(from: artist.name)
        let encoded = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        if let url = URL(string: "https://open.spotify.com/search/artist%3A\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func openArtistInAppleMusic(name: String) {
        // Note: Apple Music requires their own artist ID for direct links
        // Since we only store Spotify artist IDs, we fall back to search
        let artistName = primaryArtistName(from: name)
        let encoded = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        if let url = URL(string: "https://music.apple.com/us/search?term=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

struct GenreBreakdownCard: View {
    let genres: [GenreSendStat]
    let isLoading: Bool
    var hasPicks: Bool = false
    var onPickSong: (() -> Void)? = nil
    var isCurrentUser: Bool = true
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isCurrentUser ? "top genres from my shares" : "top genres")
                .font(.lora(size: 16, weight: .medium))

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if genres.isEmpty {
                if hasPicks {
                    // User has picks but no genre data available
                    Text(isCurrentUser ? "keep picking to build your taste profile" : "not enough data yet")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                } else if let onPickSong = onPickSong, isCurrentUser {
                    // User has no picks yet - show tappable CTA (only for current user)
                    Button(action: onPickSong) {
                        HStack {
                            Text("start picking to see your genres")
                                .font(.lora(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(isCurrentUser ? "keep picking to reveal your taste profile" : "their taste profile is waiting to be discovered")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                }
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
                            let safeMaxCount = maxCount > 0 ? maxCount : 1
                            let safeWidth = geometry.size.width > 0 ? geometry.size.width : 1
                            let progress = CGFloat(genre.count) / CGFloat(safeMaxCount)
                            let barWidth = max(progress * safeWidth, 6)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(colorScheme == .dark ? 0.35 : 0.18))
                                .frame(height: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.75))
                                        .frame(
                                            width: barWidth,
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

// MARK: - Tracks Grid View (3 columns with album art and track names)

struct TracksGridView: View {
    let title: String
    let items: [MusicItem]
    let platformType: PlatformType
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService
    @State private var isExpanded = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var deduplicatedItems: [MusicItem] {
        var uniqueItems: [String: MusicItem] = [:]
        for item in items {
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
        return items.filter { item in
            uniqueItems[item.id]?.playedAt == item.playedAt
        }
    }

    private var displayedItems: [MusicItem] {
        let list = deduplicatedItems
        return isExpanded ? Array(list.prefix(15)) : Array(list.prefix(9))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.lora(size: 17, weight: .medium))
                .padding(.horizontal, 24)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(displayedItems.enumerated()), id: \.offset) { index, item in
                    TrackGridItem(
                        item: item,
                        allItems: Array(deduplicatedItems.prefix(15)),
                        index: index
                    )
                    .environmentObject(playbackService)
                }
            }
            .padding(.horizontal, 24)

            // Show expand/collapse button if there are more than 9 items
            if deduplicatedItems.count > 9 {
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
    }
}

struct TrackGridItem: View {
    let item: MusicItem
    let allItems: [MusicItem]
    let index: Int
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == item.id
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        Button {
            if isCurrentTrack {
                playbackService.isPlaying ? playbackService.pause() : playbackService.resume()
            } else {
                let startIndex = allItems.firstIndex(where: { $0.id == item.id }) ?? index
                playbackService.startQueue(
                    tracks: allItems,
                    startAt: startIndex,
                    showMiniPlayer: true
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Album artwork with play overlay
                ZStack {
                    if let artworkUrl = item.albumArtUrl, let url = URL(string: artworkUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                    } else {
                        Color.gray.opacity(0.2)
                    }

                    // Play icon overlay
                    Circle()
                        .fill(Color.black.opacity(isPlaying ? 0.5 : 0.3))
                        .frame(width: 36, height: 36)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(2) // Make room for border
                .overlay(
                    RoundedRectangle(cornerRadius: 10) // Slightly larger radius to account for padding
                        .stroke(isCurrentTrack ? Color.primary : Color.clear, lineWidth: 2)
                )

                // Track name
                Text(item.name)
                    .font(.lora(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Artists Grid View (3 columns with circular profile images)

struct ArtistsGridView: View {
    let title: String
    let items: [MusicItem]
    let platformType: PlatformType
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false
    @State private var selectedArtist: MusicItem?
    @State private var showPlatformSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var deduplicatedItems: [MusicItem] {
        var uniqueItems: [String: MusicItem] = [:]
        for item in items {
            if uniqueItems[item.id] == nil {
                uniqueItems[item.id] = item
            }
        }
        return items.filter { item in
            uniqueItems[item.id] != nil
        }
    }

    private var displayedItems: [MusicItem] {
        let list = deduplicatedItems
        return isExpanded ? list : Array(list.prefix(9))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.lora(size: 17, weight: .medium))
                .padding(.horizontal, 24)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(displayedItems.enumerated()), id: \.offset) { _, item in
                    ArtistGridItem(
                        item: item,
                        onTap: {
                            selectedArtist = item
                            showPlatformSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal, 24)

            // Show expand/collapse button if there are more than 9 items
            if deduplicatedItems.count > 9 {
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

    private func openArtistInPlatform(item: MusicItem, platform: PlatformType) {
        switch platform {
        case .spotify:
            if let spotifyId = item.spotifyId, !spotifyId.isEmpty {
                let artistURL = "https://open.spotify.com/artist/\(spotifyId)"
                if let url = URL(string: artistURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                Task {
                    await openArtistInSpotify(artistName: item.name)
                }
            }

        case .appleMusic:
            if let appleMusicId = item.appleMusicId, !appleMusicId.isEmpty, appleMusicId != item.name {
                let artistURL = "music://music.apple.com/us/artist/\(appleMusicId)"
                if let url = URL(string: artistURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                Task {
                    await openArtistInAppleMusic(artistName: item.name)
                }
            }
        }
    }

    private func openArtistInSpotify(artistName: String) async {
        do {
            struct SearchResponse: Decodable {
                let spotifyId: String?
            }

            let supabase = PhlockSupabaseClient.shared.client
            let response: SearchResponse = try await supabase.functions.invoke(
                "search-spotify-artist",
                options: FunctionInvokeOptions(body: ["artistName": artistName])
            )

            if let spotifyId = response.spotifyId {
                let artistURL = "https://open.spotify.com/artist/\(spotifyId)"
                await MainActor.run {
                    if let url = URL(string: artistURL) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                await openSpotifySearch(artistName: artistName)
            }
        } catch {
            await openSpotifySearch(artistName: artistName)
        }
    }

    private func openSpotifySearch(artistName: String) async {
        let searchQuery = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        let spotifyURL = "https://open.spotify.com/search/\(searchQuery)"
        await MainActor.run {
            if let url = URL(string: spotifyURL) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func openArtistInAppleMusic(artistName: String) async {
        print("🎵 Opening Apple Music for artist: \(artistName)")

        // Use server-side edge function to search Apple Music Catalog API
        do {
            struct SearchResponse: Decodable {
                let appleMusicId: String?
                let artistName: String?
            }

            let supabase = PhlockSupabaseClient.shared.client
            let response: SearchResponse = try await supabase.functions.invoke(
                "search-apple-music-artist",
                options: FunctionInvokeOptions(body: ["artistName": artistName])
            )

            if let appleMusicId = response.appleMusicId {
                print("✅ Found Apple Music artist: \(response.artistName ?? artistName) (ID: \(appleMusicId))")
                let artistURL = "https://music.apple.com/us/artist/\(appleMusicId)"
                print("🔗 Opening URL: \(artistURL)")
                await MainActor.run {
                    if let url = URL(string: artistURL) {
                        UIApplication.shared.open(url)
                    }
                }
                return
            } else {
                print("⚠️ No Apple Music artist found")
            }
        } catch {
            print("❌ Apple Music artist search failed: \(error)")
        }

        // Fallback: open search page if we couldn't find the artist
        print("⚠️ Falling back to search page")
        let searchQuery = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        let searchURL = "https://music.apple.com/us/search?term=\(searchQuery)"
        await MainActor.run {
            if let url = URL(string: searchURL) {
                UIApplication.shared.open(url)
            }
        }
    }
}

struct ArtistGridItem: View {
    let item: MusicItem
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Circular artist image
                ZStack {
                    if let artworkUrl = item.albumArtUrl, let url = URL(string: artworkUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                artistInitialsPlaceholder(for: item.name)
                            @unknown default:
                                artistInitialsPlaceholder(for: item.name)
                            }
                        }
                    } else {
                        artistInitialsPlaceholder(for: item.name)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                // Artist name
                Text(item.name)
                    .font(.lora(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
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
                .font(.lora(size: 20, weight: .semiBold))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ProfileView(scrollToTopTrigger: .constant(0))
        .environmentObject(AuthenticationState())
}

struct TodaysPickCard: View {
    let share: Share?
    let isCurrentUser: Bool
    let onPickSong: () -> Void
    var userId: UUID? = nil  // User ID for nudge functionality (when viewing other profiles)
    var onNudge: (() -> Void)? = nil  // Callback when nudge button is tapped
    var streak: Int = 0  // User's current daily song streak
    var isInMyPhlock: Bool = true  // Whether this user is in my phlock (for showing locked state)
    var onAddToPhlock: (() -> Void)? = nil  // Callback when add to phlock button is tapped
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
                        albumArtUrl: share.albumArtUrl,
                        isrc: nil,
                        playedAt: nil,
                        spotifyId: share.trackId,  // Pass Spotify ID for DeepLinkService
                        appleMusicId: nil,
                        popularity: nil,
                        followerCount: nil
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
                            Text(streak == 0 ? "pick your first song" : "pick your song for today")
                                .font(.lora(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Text(streak > 0 ? "\(streak) \(streak == 1 ? "day" : "days") and counting 🔥" : "start your streak today")
                                .font(.lora(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(.lora(size: 32, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.06))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
            } else {
                // Empty state for other users - either hasn't picked or not in my phlock
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

// Separate view for "add to phlock to see pick" state
struct LockedPickCard: View {
    var isLoading: Bool = false
    let onAddToPhlock: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today's pick")
                .font(.lora(size: 17, weight: .medium))
                .padding(.horizontal, 24)

            HStack {
                Text("add me to your phlock to see my pick")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onAddToPhlock) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("add")
                                .font(.lora(size: 13, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        .cornerRadius(16)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct PastPicksView: View {
    let shares: [Share]
    var onPickSong: (() -> Void)? = nil
    var onSeeMore: (() -> Void)? = nil
    var isCurrentUser: Bool = true
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme

    // Convert shares to MusicItems for playback
    private var musicItems: [MusicItem] {
        shares.map {
            MusicItem(
                id: $0.trackId,
                name: $0.trackName,
                artistName: $0.artistName,
                previewUrl: $0.previewUrl,
                albumArtUrl: $0.albumArtUrl,
                isrc: nil,
                playedAt: nil,
                spotifyId: $0.trackId,  // Pass Spotify ID for DeepLinkService
                appleMusicId: nil,
                popularity: nil,
                followerCount: nil
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("past picks")
                .font(.lora(size: 17, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            if shares.isEmpty {
                if let onPickSong = onPickSong, isCurrentUser {
                    Button(action: onPickSong) {
                        HStack {
                            Text("your archive starts with today's pick")
                                .font(.lora(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 40) // Align with plus icons inside cards (24 + 16 card padding)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(isCurrentUser ? "your archive starts with today's pick" : "no past picks yet")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Show first 3 picks as grid items
                        ForEach(Array(shares.prefix(3).enumerated()), id: \.element.id) { index, share in
                            PastPickGridItem(
                                share: share,
                                allItems: musicItems,
                                index: index
                            )
                            .frame(width: (UIScreen.main.bounds.width - 48 - 24) / 3) // Match 3-column grid width
                        }

                        // "See more" button if there are more than 3 picks
                        if shares.count > 3 {
                            Button {
                                onSeeMore?()
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.1))

                                        VStack(spacing: 4) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Text("see more")
                                                .font(.lora(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)

                                    // Empty text to match grid item height
                                    Text(" ")
                                        .font(.lora(size: 12))
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: (UIScreen.main.bounds.width - 48 - 24) / 3)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

struct PastPickGridItem: View {
    let share: Share
    let allItems: [MusicItem]
    let index: Int
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == share.trackId
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        Button {
            if isCurrentTrack {
                playbackService.isPlaying ? playbackService.pause() : playbackService.resume()
            } else {
                playbackService.startQueue(
                    tracks: allItems,
                    startAt: index,
                    showMiniPlayer: true
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Album artwork with play overlay
                ZStack {
                    GeometryReader { geometry in
                        if let artworkUrl = share.albumArtUrl, let url = URL(string: artworkUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                case .failure, .empty:
                                    Color.gray.opacity(0.2)
                                @unknown default:
                                    Color.gray.opacity(0.2)
                                }
                            }
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }

                    // Play icon overlay
                    Circle()
                        .fill(Color.black.opacity(isPlaying ? 0.5 : 0.3))
                        .frame(width: 36, height: 36)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCurrentTrack ? Color.primary : Color.clear, lineWidth: 2)
                        .padding(1) // Inset border so it doesn't get clipped
                )

                // Track name
                Text(share.trackName)
                    .font(.lora(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
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

    // Sort members by streak (highest first), then position - matches phlock tab ordering
    private var sortedMembers: [FriendWithPosition] {
        members.sorted {
            if $0.user.dailySongStreak != $1.user.dailySongStreak {
                return $0.user.dailySongStreak > $1.user.dailySongStreak
            }
            return $0.position < $1.position
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("my phlock (\(members.count)/5)")
                    .font(.lora(size: 17, weight: .medium))
                Text("your daily playlist from friends")
                    .font(.lora(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    // Existing members with streak badges - sorted by streak then position
                    ForEach(sortedMembers) { member in
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

// PhlockManagerSheet has been replaced with UnifiedPhlockSheet in PhlockView.swift
