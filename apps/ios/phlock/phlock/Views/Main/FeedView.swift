import SwiftUI

// Navigation destination types for Feed
enum FeedDestination: Hashable {
    case profile
    case userProfile(User)
}

// MARK: - Feed Tab (Network Activity)

struct FeedView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Binding var navigationPath: NavigationPath
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedFilter: FeedFilter = .friends
    @State private var networkShares: [NetworkShare] = []
    @State private var isLoading = true
    @State private var isRefreshing = false

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
                        ProgressView("Loading feed...")
                            .font(.nunitoSans(size: 15))
                    } else if networkShares.isEmpty {
                        emptyState
                    } else {
                        feedList
                    }
                }
            }
            .navigationTitle("feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationPath.append(FeedDestination.profile)
                    } label: {
                        if let profilePhotoUrl = authState.currentUser?.profilePhotoUrl,
                           let url = URL(string: profilePhotoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 22))
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 22))
                        }
                    }
                }
            }
            .navigationDestination(for: FeedDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                case .userProfile(let user):
                    UserProfileView(user: user)
                }
            }
        }
        .task {
            await loadNetworkActivity()
        }
        .refreshable {
            await refreshNetworkActivity()
        }
    }

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
        List {
            ForEach(sortedSections, id: \.self) { date in
                Section(header: sectionHeader(for: date)) {
                    ForEach(sortedShares(for: date), id: \.share.id) { networkShare in
                        NetworkShareRowView(networkShare: networkShare, navigationPath: $navigationPath)
                            .environmentObject(playbackService)
                            .environmentObject(authState)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Section Header

    private func sectionHeader(for date: String) -> some View {
        Text(date)
            .font(.nunitoSans(size: 13, weight: .bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
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
            sectionOrder(section1) < sectionOrder(section2)
        }
    }

    // Get shares for a section, sorted by most recent first
    private func sortedShares(for section: String) -> [NetworkShare] {
        guard let shares = groupedShares[section] else { return [] }
        return shares.sorted { $0.share.createdAt > $1.share.createdAt }
    }

    // Define ordering for section headers (lower number = more recent)
    private func sectionOrder(_ section: String) -> Int {
        switch section {
        case "Today": return 0
        case "Yesterday": return 1
        case "This Week": return 2
        default: return 3
        }
    }

    private func formatDateSection(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return "This Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Actions

    private func loadNetworkActivity() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            let shares = try await ShareService.shared.getNetworkActivity(userId: currentUser.id)

            // Fetch sender and recipient info for each share
            var sharesWithUsers: [NetworkShare] = []
            for share in shares {
                if let sender = try? await UserService.shared.getUser(userId: share.senderId),
                   let recipient = try? await UserService.shared.getUser(userId: share.recipientId) {
                    sharesWithUsers.append(NetworkShare(share: share, sender: sender, recipient: recipient))
                }
            }

            await MainActor.run {
                networkShares = sharesWithUsers
                isLoading = false
            }
        } catch {
            print("❌ Failed to load network activity: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func refreshNetworkActivity() async {
        isRefreshing = true
        await loadNetworkActivity()
        isRefreshing = false
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
    @Environment(\.colorScheme) var colorScheme

    @State private var showShareSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    private var share: Share { networkShare.share }
    private var sender: User { networkShare.sender }
    private var recipient: User { networkShare.recipient }

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == share.trackId
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
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
                        Text(sender.displayName)
                            .font(.nunitoSans(size: 14, weight: .semiBold))
                            .foregroundColor(.primary)

                        Text("→")
                            .font(.nunitoSans(size: 13))
                            .foregroundColor(.secondary)

                        Text(recipient.displayName)
                            .font(.nunitoSans(size: 14, weight: .semiBold))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Time ago
                    Text(timeAgo(from: share.createdAt))
                        .font(.nunitoSans(size: 12))
                        .foregroundColor(.secondary)
                }

                // Track Info
                HStack(spacing: 12) {
                    // Album Art
                    if let artworkUrl = share.albumArtUrl, let url = URL(string: artworkUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                    }

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

                        // Message if exists
                        if let message = share.message, !message.isEmpty {
                            Text("\"\(message)\"")
                                .font(.nunitoSans(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }

                    Spacer()

                    // Share Button
                    Button {
                        showShareSheet.toggle()
                    } label: {
                        Image(systemName: "paperplane")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    // Play button
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isCurrentTrack ? .primary : .secondary)
                }

                // QuickSendBar appears below track when sharing
                if showShareSheet {
                    QuickSendBar(track: createMusicItem()) { sentToFriends in
                        handleShareComplete(sentToFriends: sentToFriends)
                    }
                    .environmentObject(authState)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(
                isCurrentTrack
                    ? Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.05)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
        .confetti(trigger: $showConfetti)
    }

    private func createMusicItem() -> MusicItem {
        MusicItem(
            id: share.trackId,
            name: share.trackName,
            artistName: share.artistName,
            previewUrl: nil,
            albumArtUrl: share.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: nil,
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )
    }

    private func handleTap() {
        let track = createMusicItem()

        if isPlaying {
            // Pause if currently playing this track
            playbackService.pause()
        } else {
            // Play the track
            playbackService.play(track: track)
        }
    }

    private func handleShareComplete(sentToFriends: [User]) {
        showShareSheet = false

        // Show success feedback
        let friendNames = sentToFriends.map { $0.displayName }.joined(separator: ", ")
        toastMessage = sentToFriends.count == 1
            ? "Sent to \(friendNames)"
            : "Sent to \(sentToFriends.count) friends"

        showToast = true
        showConfetti = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
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
    FeedView(navigationPath: .constant(NavigationPath()))
        .environmentObject(AuthenticationState())
        .environmentObject(PlaybackService.shared)
}
