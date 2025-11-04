import SwiftUI

// Navigation destination types for Inbox
enum InboxDestination: Hashable {
    case profile
}

struct TheCrateView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int

    var body: some View {
        NavigationStack(path: $navigationPath) {
            InboxView(refreshTrigger: $refreshTrigger, scrollToTopTrigger: $scrollToTopTrigger)
                .navigationTitle("shares")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            navigationPath.append(InboxDestination.profile)
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
                .navigationDestination(for: InboxDestination.self) { destination in
                    switch destination {
                    case .profile:
                        ProfileView()
                    }
                }
        }
    }
}

// MARK: - Inbox Tab (Received Shares)

struct InboxView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedFilter: SharesFilter = .received
    @State private var receivedShares: [ShareWithSender] = []
    @State private var sentShares: [ShareWithRecipient] = []
    @State private var isLoading = true
    @State private var isRefreshing = false

    // IMPORTANT: Initialize reference date once and never change it during the view's lifetime
    // This ensures consistent date grouping (Today, Yesterday, etc.)
    private let referenceDate = Date()

    enum SharesFilter: String, CaseIterable {
        case received = "Received"
        case sent = "Sent"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Tabs
            filterSegmentedControl
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Content
            Group {
                if isLoading {
                    ProgressView("Loading shares...")
                        .font(.nunitoSans(size: 15))
                } else if isCurrentViewEmpty {
                    emptyState
                } else {
                    sharesList
                }
            }
        }
        .task {
            await loadShares()
        }
        .refreshable {
            await refreshShares()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            Task {
                await refreshShares()
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(SharesFilter.allCases, id: \.self) { filter in
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

    private var isCurrentViewEmpty: Bool {
        selectedFilter == .received ? receivedShares.isEmpty : sentShares.isEmpty
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text(selectedFilter == .received ? "🎵" : "📤")
                    .font(.system(size: 64))

                Text(selectedFilter == .received ? "no shares yet" : "nothing sent yet")
                    .font(.nunitoSans(size: 28, weight: .bold))

                Text(selectedFilter == .received
                    ? "when friends share songs with you,\nthey'll appear here"
                    : "shares you send to friends\nwill appear here")
                    .font(.nunitoSans(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if selectedFilter == .received {
                    Text("start by discovering music and\nsharing it with your friends!")
                        .font(.nunitoSans(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 24)
                }
            }
            .padding(32)
            .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
            .cornerRadius(20)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Shares List

    private var sharesList: some View {
        ScrollViewReader { scrollProxy in
            List {
                // Top anchor for scrolling
                Color.clear
                    .frame(height: 1)
                    .id("inboxTop")

                ForEach(sortedSections, id: \.self) { date in
                Section(header: sectionHeader(for: date)) {
                    if selectedFilter == .received {
                        ForEach(sortedReceivedShares(for: date), id: \.share.id) { shareWithSender in
                            ShareRowView(shareWithSender: shareWithSender)
                                .environmentObject(playbackService)
                                .environmentObject(authState)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            await handleSave(shareWithSender.share)
                                        }
                                    } label: {
                                        Label("Save", systemImage: "heart.fill")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await handleDismiss(shareWithSender.share)
                                        }
                                    } label: {
                                        Label("Dismiss", systemImage: "xmark")
                                    }
                                }
                        }
                    } else {
                        ForEach(sortedSentShares(for: date), id: \.share.id) { shareWithRecipient in
                            SentShareRowView(shareWithRecipient: shareWithRecipient)
                                .environmentObject(playbackService)
                                .environmentObject(authState)
                        }
                    }
                }
            }
            }
            .listStyle(.plain)
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation {
                    scrollProxy.scrollTo("inboxTop", anchor: .top)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(for date: String) -> some View {
        Text(date)
            .font(.nunitoSans(size: 13, weight: .bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    // MARK: - Grouped Shares

    private var groupedReceivedShares: [String: [ShareWithSender]] {
        Dictionary(grouping: receivedShares) { shareWithSender in
            formatDateSection(shareWithSender.share.createdAt)
        }
    }

    private var groupedSentShares: [String: [ShareWithRecipient]] {
        Dictionary(grouping: sentShares) { shareWithRecipient in
            formatDateSection(shareWithRecipient.share.createdAt)
        }
    }

    // Sort sections by recency (Today -> Yesterday -> This Week -> older dates)
    private var sortedSections: [String] {
        let sections = selectedFilter == .received
            ? Array(groupedReceivedShares.keys)
            : Array(groupedSentShares.keys)
        return sections.sorted { section1, section2 in
            sectionOrder(section1) < sectionOrder(section2)
        }
    }

    // Get received shares for a section, sorted by most recent first with stable secondary sort
    private func sortedReceivedShares(for section: String) -> [ShareWithSender] {
        guard let shares = groupedReceivedShares[section] else { return [] }
        // Sort by created_at DESC (most recent first), then by ID DESC for stability
        return shares.sorted { share1, share2 in
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

    // Get sent shares for a section, sorted by most recent first with stable secondary sort
    private func sortedSentShares(for section: String) -> [ShareWithRecipient] {
        guard let shares = groupedSentShares[section] else { return [] }
        // Sort by created_at DESC (most recent first), then by ID DESC for stability
        return shares.sorted { share1, share2 in
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

    // Define ordering for section headers (lower number = more recent)
    private func sectionOrder(_ section: String) -> Int {
        switch section {
        case "Today": return 0
        case "Yesterday": return 1
        case "This Week": return 2
        default: return 3 // For specific dates, they'll be sorted within this group
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

    private func loadShares() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            // Load received shares
            let receivedSharesData = try await ShareService.shared.getReceivedShares(userId: currentUser.id)
            var sharesWithSenders: [ShareWithSender] = []
            for share in receivedSharesData {
                if let sender = try? await UserService.shared.getUser(userId: share.senderId) {
                    sharesWithSenders.append(ShareWithSender(share: share, sender: sender))
                }
            }

            // Load sent shares
            let sentSharesData = try await ShareService.shared.getSentShares(userId: currentUser.id)
            var sharesWithRecipients: [ShareWithRecipient] = []
            for share in sentSharesData {
                if let recipient = try? await UserService.shared.getUser(userId: share.recipientId) {
                    sharesWithRecipients.append(ShareWithRecipient(share: share, recipient: recipient))
                }
            }

            await MainActor.run {
                // Preserve the original order from the database (already sorted by created_at DESC)
                receivedShares = sharesWithSenders
                sentShares = sharesWithRecipients
                isLoading = false
            }
        } catch {
            print("❌ Failed to load shares: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func refreshShares() async {
        isRefreshing = true
        await loadShares()
        isRefreshing = false
    }

    private func handleSave(_ share: Share) async {
        guard let currentUser = authState.currentUser else { return }

        do {
            try await ShareService.shared.markAsSaved(shareId: share.id, userId: currentUser.id)

            // Update local state
            await MainActor.run {
                if let index = receivedShares.firstIndex(where: { $0.share.id == share.id }) {
                    receivedShares[index].share.status = .saved
                }
            }

            print("✅ Saved share: \(share.trackName)")
        } catch {
            print("❌ Failed to save share: \(error)")
        }
    }

    private func handleDismiss(_ share: Share) async {
        guard let currentUser = authState.currentUser else { return }

        do {
            try await ShareService.shared.markAsDismissed(shareId: share.id, userId: currentUser.id)

            // Remove from local state
            await MainActor.run {
                receivedShares.removeAll { $0.share.id == share.id }
            }

            print("✅ Dismissed share: \(share.trackName)")
        } catch {
            print("❌ Failed to dismiss share: \(error)")
        }
    }
}

// MARK: - Share Models

struct ShareWithSender: Identifiable {
    var share: Share
    let sender: User

    var id: UUID { share.id }
}

struct ShareWithRecipient: Identifiable {
    var share: Share
    let recipient: User

    var id: UUID { share.id }
}

// MARK: - Share Row View

struct ShareRowView: View {
    let shareWithSender: ShareWithSender
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showShareSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    private var share: Share { shareWithSender.share }
    private var sender: User { shareWithSender.sender }

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == share.trackId
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        VStack(spacing: 0) {
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

                        // Sender Info
                        HStack(spacing: 4) {
                            Text("from")
                                .font(.nunitoSans(size: 12))
                                .foregroundColor(.secondary)

                            Text(sender.displayName)
                                .font(.nunitoSans(size: 12, weight: .semiBold))
                                .foregroundColor(.blue)

                            if let message = share.message, !message.isEmpty {
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("\"\(message)\"")
                                    .font(.nunitoSans(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
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
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    isCurrentTrack
                        ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                        : Color.clear
                )
                .cornerRadius(8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

            // Mark as played
            Task {
                guard let currentUser = authState.currentUser else { return }
                try? await ShareService.shared.markAsPlayed(shareId: share.id, userId: currentUser.id)
            }
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
}

// MARK: - Sent Share Row View

struct SentShareRowView: View {
    let shareWithRecipient: ShareWithRecipient
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showShareSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    private var share: Share { shareWithRecipient.share }
    private var recipient: User { shareWithRecipient.recipient }

    private var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == share.trackId
    }

    private var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        VStack(spacing: 0) {
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

                        // Recipient Info
                        HStack(spacing: 4) {
                            Text("to")
                                .font(.nunitoSans(size: 12))
                                .foregroundColor(.secondary)

                            Text(recipient.displayName)
                                .font(.nunitoSans(size: 12, weight: .semiBold))
                                .foregroundColor(.blue)

                            // Status indicator
                            if share.status != .sent {
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text(statusText)
                                    .font(.nunitoSans(size: 12, weight: .medium))
                                    .foregroundColor(statusColor)
                            }
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
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    isCurrentTrack
                        ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                        : Color.clear
                )
                .cornerRadius(8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
        .confetti(trigger: $showConfetti)
    }

    private var statusText: String {
        switch share.status {
        case .played: return "played"
        case .saved: return "saved"
        case .dismissed: return "dismissed"
        default: return ""
        }
    }

    private var statusColor: Color {
        switch share.status {
        case .played: return .green
        case .saved: return .purple
        case .dismissed: return .gray
        default: return .secondary
        }
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
}

#Preview {
    TheCrateView(navigationPath: .constant(NavigationPath()), refreshTrigger: .constant(0), scrollToTopTrigger: .constant(0))
        .environmentObject(AuthenticationState())
}
