import SwiftUI

// Navigation destination types for Feed
enum FeedDestination: Hashable {
    case profile
    case userProfile(User)
    case conversation(User)
}

// MARK: - Feed Tab (Network Activity)

struct FeedView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var navigationState: NavigationState
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedFilter: FeedFilter = .friends
    @State private var networkShares: [NetworkShare] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0

    // private let waveformReservedHeight: CGFloat = 26

    // IMPORTANT: Initialize reference date once and never change it during the view's lifetime
    // This ensures consistent date grouping (Today, Yesterday, etc.)
    private let referenceDate = Date()

    // Cached grouping to prevent re-sorting on every render
    @State private var cachedGroupedShares: [String: [NetworkShare]] = [:]
    @State private var cachedSortedSections: [String] = []

    enum FeedFilter: String, CaseIterable {
        case friends = "Friends"
        case following = "Following"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter Tabs
                filterSegmentedControl
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Content
                Group {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading feed...")
                                .font(.nunitoSans(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else if networkShares.isEmpty {
                        emptyState
                    } else {
                        feedList
                    }
                }
            }
            .navigationTitle("feed")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: FeedDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                case .userProfile(let user):
                    UserProfileView(user: user)
                case .conversation(let user):
                    ConversationView(otherUser: user)
                        .environmentObject(authState)
                        .environmentObject(playbackService)
                }
            }
        }
        .fullScreenSwipeBack()
        .task {
            await loadNetworkActivity()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            print("🔄 Feed refreshTrigger changed from \(oldValue) to \(newValue)")
            Task {
                // Scroll to top and reload data
                withAnimation {
                    scrollToTopTrigger += 1
                }
                isRefreshing = true
                print("🔄 Loading network activity...")
                await loadNetworkActivity()
                isRefreshing = false
                print("🔄 Network activity loaded")
            }
        }
    }

    // Commented out waveform animation code for potential future use
    // private func animatePullDown() async {
    //     withAnimation(.easeOut(duration: 0.4)) {
    //         pullProgress = 1.0
    //     }
    //     try? await Task.sleep(nanoseconds: 400_000_000)
    // }

    // MARK: - Filter Tabs

    private var filterSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.nunitoSans(size: 15, weight: selectedFilter == filter ? .bold : .regular))
                        .foregroundColor(selectedFilter == filter ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedFilter == filter
                                ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.08))
        .cornerRadius(10)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text(selectedFilter == .friends ? "🎶" : "👥")
                    .font(.system(size: 64))

                Text(selectedFilter == .friends ? "quiet in here" : "no one yet")
                    .font(.nunitoSans(size: 28, weight: .bold))

                Text(selectedFilter == .friends
                    ? "when friends share music,\nyou'll see it here"
                    : "when you follow people,\ntheir shares will appear here")
                    .font(.nunitoSans(size: 15))
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

    // MARK: - Feed List

    private var feedList: some View {
        ScrollViewReader { scrollProxy in
            List {
                // Top anchor for scroll-to-top functionality
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .id("feedTop")

                ForEach(Array(cachedSortedSections.enumerated()), id: \.element) { index, date in
                    Section(header: sectionHeader(for: date, isFirst: index == 0)) {
                        ForEach(sortedShares(for: date), id: \.share.id) { networkShare in
                            NetworkShareRowView(
                                networkShare: networkShare,
                                navigationPath: $navigationPath
                            )
                            .environmentObject(playbackService)
                            .environmentObject(authState)
                            .environmentObject(navigationState)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            // Commented out waveform refresh for potential future use
            // .hideRefreshControl()
            // .pullToRefreshWithWaveform(
            //     isRefreshing: $isRefreshing,
            //     pullProgress: $pullProgress,
            //     colorScheme: colorScheme,
            //     overlayCompensation: simulatedPullOffset
            // ) {
            //     isRefreshing = true
            //     await loadNetworkActivity()
            //     try? await Task.sleep(nanoseconds: 1_300_000_000)
            //     isRefreshing = false
            // }
            .pullToRefreshWithSpinner(
                isRefreshing: $isRefreshing,
                pullProgress: $pullProgress,
                colorScheme: colorScheme
            ) {
                isRefreshing = true
                await loadNetworkActivity()
                isRefreshing = false
            }
            .onChange(of: scrollToTopTrigger) { oldValue, newValue in
                print("📜 Feed scrollToTopTrigger changed from \(oldValue) to \(newValue)")
                withAnimation {
                    scrollProxy.scrollTo("feedTop", anchor: .top)
                    print("📜 Scrolled to feedTop")
                }
            }
            // .offset(y: simulatedPullOffset)
        }
    }

    // Commented out waveform-related computed properties for potential future use
    // private var refreshSpacerHeight: CGFloat {
    //     max(0, min(1, pullProgress)) * waveformReservedHeight
    // }

    // private var simulatedPullOffset: CGFloat {
    //     isSimulatedPull ? waveformReservedHeight : 0
    // }

    // MARK: - Section Header

    private func sectionHeader(for date: String, isFirst: Bool) -> some View {
        Text(date)
            .font(.nunitoSans(size: 13, weight: .bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.top, isFirst ? 8 : 4) // Add more padding for first section
    }

    // MARK: - Grouped Shares

    private var groupedShares: [String: [NetworkShare]] {
        Dictionary(grouping: filteredShares) { networkShare in
            formatDateSection(networkShare.share.createdAt)
        }
    }

    private var filteredShares: [NetworkShare] {
        // For now, only show Friends feed. Following will be implemented later
        switch selectedFilter {
        case .friends:
            return networkShares
        case .following:
            return [] // Placeholder
        }
    }

    // Sort sections by recency (Today -> Yesterday -> This Week -> older dates)
    private var sortedSections: [String] {
        let sections = Array(groupedShares.keys)
        return sections.sorted { section1, section2 in
            // First compare special sections
            let order1 = specialSectionOrder(section1)
            let order2 = specialSectionOrder(section2)

            if order1 != order2 {
                return order1 < order2
            }

            // Both are regular date sections (order == 999)
            // Parse and compare actual dates
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"

            if let date1 = formatter.date(from: section1),
               let date2 = formatter.date(from: section2) {
                // More recent dates come first
                return date1 > date2
            }

            // Fallback to string comparison (shouldn't happen)
            return section1 > section2
        }
    }

    // Get shares for a section, sorted by most recent first with stable secondary sort
    private func sortedShares(for section: String) -> [NetworkShare] {
        guard let shares = cachedGroupedShares[section] else { return [] }
        // Sort by created_at DESC (most recent first), then by ID DESC for stability
        return shares.sorted { share1, share2 in
            // Compare timestamps first
            let date1 = share1.share.createdAt
            let date2 = share2.share.createdAt

            if date1 != date2 {
                // More recent dates come first
                return date1 > date2
            } else {
                // For identical timestamps, use ID for stable ordering (DESC to match DB behavior)
                return share1.share.id.uuidString > share2.share.id.uuidString
            }
        }
    }

    // Define ordering for special section headers (lower number = more recent)
    private func specialSectionOrder(_ section: String) -> Int {
        switch section {
        case "Today": return 0
        case "Yesterday": return 1
        case "This Week": return 2
        default: return 999 // Regular date sections will be sorted by actual date
        }
    }

    private func formatDateSection(_ date: Date) -> String {
        let calendar = Calendar.current
        // Use stable referenceDate instead of Date() to prevent re-sorting on every render
        if calendar.isDate(date, equalTo: referenceDate, toGranularity: .day) {
            return "Today"
        } else if calendar.isDate(date, equalTo: calendar.date(byAdding: .day, value: -1, to: referenceDate)!, toGranularity: .day) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear) {
            return "This Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Actions

    private func updateCachedGrouping() {
        // Group shares by date section using stable referenceDate
        let grouped = Dictionary(grouping: filteredShares) { networkShare in
            formatDateSection(networkShare.share.createdAt)
        }
        cachedGroupedShares = grouped

        // Sort sections
        let sections = Array(grouped.keys)
        cachedSortedSections = sections.sorted { section1, section2 in
            // First compare special sections
            let order1 = specialSectionOrder(section1)
            let order2 = specialSectionOrder(section2)

            if order1 != order2 {
                return order1 < order2
            }

            // Both are regular date sections (order == 999)
            // Parse and compare actual dates
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"

            if let date1 = formatter.date(from: section1),
               let date2 = formatter.date(from: section2) {
                // More recent dates come first
                return date1 > date2
            }

            // Fallback to string comparison (shouldn't happen)
            return section1 > section2
        }

        print("📊 Updated cached grouping: \(cachedSortedSections.count) sections, \(networkShares.count) total shares")
    }

    private func loadNetworkActivity() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            let shares = try await ShareService.shared.getNetworkActivity(userId: currentUser.id)

            // Fetch sender and recipient info in a single batch to avoid N+1 calls
            let userIds = Array(Set(shares.flatMap { [ $0.senderId, $0.recipientId ] }))
            let userMap = try await UserService.shared.getUsers(userIds: userIds)

            let sharesWithUsers: [NetworkShare] = shares.compactMap { share in
                guard let sender = userMap[share.senderId],
                      let recipient = userMap[share.recipientId] else { return nil }
                return NetworkShare(share: share, sender: sender, recipient: recipient)
            }

            await MainActor.run {
                // Only update if data actually changed
                let hasChanged = networkShares.count != sharesWithUsers.count ||
                    !networkShares.elementsEqual(sharesWithUsers, by: { $0.share.id == $1.share.id })

                if hasChanged {
                    // Preserve the original order from the database (already sorted by created_at DESC)
                    networkShares = sharesWithUsers
                    updateCachedGrouping() // Update cached sections
                }
                isLoading = false
            }

            // Pre-fetch preview URLs for faster playback
            let tracks = sharesWithUsers.map { networkShare in
                MusicItem(
                    id: networkShare.share.trackId,
                    name: networkShare.share.trackName,
                    artistName: networkShare.share.artistName,
                    previewUrl: nil,
                    albumArtUrl: networkShare.share.albumArtUrl,
                    isrc: nil,
                    playedAt: nil,
                    spotifyId: networkShare.share.trackId, // Use track_id as Spotify ID
                    appleMusicId: nil,
                    popularity: nil
                )
            }
            playbackService.prefetchPreviewUrls(for: tracks)
        } catch {
            print("❌ Failed to load network activity: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Network Share Model

struct NetworkShare: Identifiable {
    let share: Share
    let sender: User
    let recipient: User

    var id: UUID { share.id }
}

// MARK: - Network Share Row View

struct NetworkShareRowView: View {
    let networkShare: NetworkShare
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showToast = false
    @State private var toastMessage = ""

    private var share: Share { networkShare.share }
    private var sender: User { networkShare.sender }
    private var recipient: User { networkShare.recipient }

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == share.trackId &&
        playbackService.currentSourceId == share.id.uuidString
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User Activity Header
            HStack(spacing: 8) {
                    // Sender Avatar
                    if let photoUrl = sender.profilePhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            )
                    }

                    // Activity Text
                    HStack(spacing: 4) {
                        Button {
                            navigationPath.append(FeedDestination.conversation(sender))
                        } label: {
                            Text(sender.displayName)
                                .font(.nunitoSans(size: 14, weight: .semiBold))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Text("→")
                            .font(.nunitoSans(size: 13))
                            .foregroundColor(.secondary)

                        Button {
                            navigationPath.append(FeedDestination.conversation(recipient))
                        } label: {
                            Text(recipient.displayName)
                                .font(.nunitoSans(size: 14, weight: .semiBold))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Time ago
                    Text(timeAgo(from: share.createdAt))
                        .font(.nunitoSans(size: 12))
                        .foregroundColor(.secondary)
                }

                // Track Info
                Button {
                    handleTap()
                } label: {
                    HStack(spacing: 12) {
                        // Album Art with automatic fallback for stale URLs
                        RemoteImage(
                            url: share.albumArtUrl,
                            spotifyId: share.trackId,
                            trackName: share.trackName,
                            width: 60,
                            height: 60,
                            cornerRadius: 8
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            // Track Name
                            Text(share.trackName)
                                .font(.nunitoSans(size: 15, weight: isCurrentTrack ? .bold : .regular))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            // Artist Name
                            Text(share.artistName)
                                .font(.nunitoSans(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Share Button
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                navigationState.shareTrack = createMusicItem()
                                navigationState.showShareSheet = true
                            }
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        // Play button (matching ProfileView style)
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(isCurrentTrack ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            isCurrentTrack
                ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                : Color.clear
        )
        .cornerRadius(8)
        .padding(.horizontal, 4)
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
    }

    private func createMusicItem() -> MusicItem {
        // The track_id in shares table stores the Spotify ID
        print("📥 Loading share for '\(share.trackName)' with Spotify ID: \(share.trackId)")
        return MusicItem(
            id: share.trackId,
            name: share.trackName,
            artistName: share.artistName,
            previewUrl: nil,
            albumArtUrl: share.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: share.trackId, // track_id is the Spotify ID
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )
    }

    private func handleTap() {
        let track = createMusicItem()

        if isCurrentTrack {
            // Same exact share instance - toggle play/pause
            if isPlaying {
                playbackService.pause()
            } else {
                playbackService.resume()
            }
        } else {
            // Different share instance or different track - always start fresh
            playbackService.play(track: track, sourceId: share.id.uuidString)
        }
    }


    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return "\(day)d"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m"
        } else {
            return "now"
        }
    }
}

#Preview {
    FeedView(navigationPath: .constant(NavigationPath()), refreshTrigger: .constant(0), scrollToTopTrigger: .constant(0))
        .environmentObject(AuthenticationState())
        .environmentObject(PlaybackService.shared)
}
