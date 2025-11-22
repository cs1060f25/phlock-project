import SwiftUI

// Navigation destination types for Inbox
enum InboxDestination: Hashable {
    case profile
    case conversation(User)
}

struct TheCrateView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int

    var body: some View {
        NavigationStack(path: $navigationPath) {
            InboxView(navigationPath: $navigationPath, refreshTrigger: $refreshTrigger, scrollToTopTrigger: $scrollToTopTrigger)
                .navigationTitle("shares")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: InboxDestination.self) { destination in
                    switch destination {
                    case .profile:
                        ProfileView()
                    case .conversation(let user):
                        ConversationView(otherUser: user)
                            .environmentObject(authState)
                    }
                }
        }
        .fullScreenSwipeBack()
    }
}

// MARK: - Inbox Tab (Received Shares)

struct InboxView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedFilter: SharesFilter = .received
    @State private var receivedShares: [ShareWithSender] = []
    @State private var savedShares: [ShareWithSender] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0
    @State private var showQuickSendBar = false
    @State private var trackToShare: MusicItem? = nil

    // private let waveformReservedHeight: CGFloat = 26

    // IMPORTANT: Initialize reference date once and never change it during the view's lifetime
    // This ensures consistent date grouping (Today, Yesterday, etc.)
    private let referenceDate = Date()

    enum SharesFilter: String, CaseIterable {
        case received = "Received"
        case saved = "Saved"
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
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading shares...")
                            .font(.nunitoSans(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if isCurrentViewEmpty {
                    emptyState
                } else {
                    sharesList
                }
            }
        }
        .overlay(
            ZStack {
                if showQuickSendBar, let track = trackToShare {
                    QuickSendBar(
                        track: track,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showQuickSendBar = false
                                trackToShare = nil
                            }
                        },
                        onSendComplete: { sentToFriends in
                            if !sentToFriends.isEmpty {
                                print("✅ Sent to \(sentToFriends.count) friend\(sentToFriends.count == 1 ? "" : "s")")
                            }
                        },
                        additionalBottomInset: QuickSendBar.Layout.overlayInset
                    )
                    .environmentObject(authState)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(QuickSendBar.Layout.overlayZ)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showQuickSendBar)
        )
        .task {
            await loadShares()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            Task {
                // Scroll to top and reload data
                withAnimation {
                    scrollToTopTrigger += 1
                }
                isRefreshing = true
                await loadShares()
                isRefreshing = false
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
        selectedFilter == .received ? receivedShares.isEmpty : savedShares.isEmpty
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text(selectedFilter == .received ? "🎵" : "💜")
                    .font(.system(size: 64))

                Text(selectedFilter == .received ? "no shares yet" : "no saved songs yet")
                    .font(.nunitoSans(size: 28, weight: .bold))

                Text(selectedFilter == .received
                    ? "when friends share songs with you,\nthey'll appear here"
                    : "songs you save from shares\nwill appear here")
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
                } else {
                    Text("swipe right on received shares\nto save them to your collection!")
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
                // Top anchor for scroll-to-top functionality
                // Commented out waveform spacer for potential future use
                // Color.clear
                //     .frame(height: refreshSpacerHeight)
                //     .animation(.easeOut(duration: 0.4), value: pullProgress)
                //     .animation(.easeOut(duration: 0.4), value: isRefreshing)
                //     .listRowSeparator(.hidden)
                //     .listRowInsets(EdgeInsets())
                //     .id("inboxTop")
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .id("inboxTop")

                ForEach(Array(sortedSections.enumerated()), id: \.element) { index, date in
                    Section(header: sectionHeader(for: date, isFirst: index == 0)) {
                        if selectedFilter == .received {
                            ForEach(sortedReceivedShares(for: date), id: \.share.id) { shareWithSender in
                                ShareRowView(
                                    shareWithSender: shareWithSender,
                                    navigationPath: $navigationPath,
                                    showQuickSendBar: $showQuickSendBar,
                                    trackToShare: $trackToShare
                                )
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
                            ForEach(sortedSavedShares(for: date), id: \.share.id) { shareWithSender in
                                ShareRowView(
                                    shareWithSender: shareWithSender,
                                    navigationPath: $navigationPath,
                                    showQuickSendBar: $showQuickSendBar,
                                    trackToShare: $trackToShare
                                )
                                .environmentObject(playbackService)
                                .environmentObject(authState)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                await handleRemoveFromSaved(shareWithSender.share)
                                            }
                                        } label: {
                                            Label("Remove", systemImage: "xmark")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            .pullToRefreshWithSpinner(
                isRefreshing: $isRefreshing,
                pullProgress: $pullProgress,
                colorScheme: colorScheme
            ) {
                isRefreshing = true
                await loadShares()
                isRefreshing = false
            }
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation {
                    scrollProxy.scrollTo("inboxTop", anchor: .top)
                }
            }
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
            .padding(.top, isFirst ? 0 : 4)
    }

    // MARK: - Grouped Shares

    private var groupedReceivedShares: [String: [ShareWithSender]] {
        Dictionary(grouping: receivedShares) { shareWithSender in
            formatDateSection(shareWithSender.share.createdAt)
        }
    }

    private var groupedSavedShares: [String: [ShareWithSender]] {
        Dictionary(grouping: savedShares) { shareWithSender in
            // Group by saved_at date instead of created_at for saved shares
            formatDateSection(shareWithSender.share.savedAt ?? shareWithSender.share.createdAt)
        }
    }

    // Sort sections by recency (Today -> Yesterday -> This Week -> older dates)
    private var sortedSections: [String] {
        let sections = selectedFilter == .received
            ? Array(groupedReceivedShares.keys)
            : Array(groupedSavedShares.keys)
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

    // Get saved shares for a section, sorted by most recent first with stable secondary sort
    private func sortedSavedShares(for section: String) -> [ShareWithSender] {
        guard let shares = groupedSavedShares[section] else { return [] }
        // Sort by saved_at DESC (most recent first), then by ID DESC for stability
        return shares.sorted { share1, share2 in
            let date1 = share1.share.savedAt ?? share1.share.createdAt
            let date2 = share2.share.savedAt ?? share2.share.createdAt

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

    private func loadShares() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            // Load received shares
            let receivedSharesData = try await ShareService.shared.getReceivedShares(userId: currentUser.id)

            // Load saved shares
            let savedSharesData = try await ShareService.shared.getSavedShares(userId: currentUser.id)

            // Batch fetch senders once to avoid N+1 user lookups
            let senderIds = Array(Set(receivedSharesData.map { $0.senderId } + savedSharesData.map { $0.senderId }))
            let userMap = try await UserService.shared.getUsers(userIds: senderIds)

            let sharesWithSenders: [ShareWithSender] = receivedSharesData.compactMap { share in
                guard let sender = userMap[share.senderId] else { return nil }
                return ShareWithSender(share: share, sender: sender)
            }

            let savedSharesWithSenders: [ShareWithSender] = savedSharesData.compactMap { share in
                guard let sender = userMap[share.senderId] else { return nil }
                return ShareWithSender(share: share, sender: sender)
            }

            await MainActor.run {
                // Preserve the original order from the database (already sorted by created_at DESC)
                receivedShares = sharesWithSenders
                savedShares = savedSharesWithSenders
                isLoading = false
            }
        } catch {
            print("❌ Failed to load shares: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
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

    private func handleRemoveFromSaved(_ share: Share) async {
        guard let currentUser = authState.currentUser else { return }

        do {
            // Mark as played to remove from saved collection
            try await ShareService.shared.markAsPlayed(shareId: share.id, userId: currentUser.id)

            // Remove from local saved state
            await MainActor.run {
                savedShares.removeAll { $0.share.id == share.id }
            }

            print("✅ Removed from saved: \(share.trackName)")
        } catch {
            print("❌ Failed to remove from saved: \(error)")
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
    @Binding var navigationPath: NavigationPath
    @Binding var showQuickSendBar: Bool
    @Binding var trackToShare: MusicItem?
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showToast = false
    @State private var toastMessage = ""

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

                VStack(alignment: .leading, spacing: 6) {
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

                    // Sender Profile Pic (clickable to conversation)
                    Button {
                        navigationPath.append(InboxDestination.conversation(sender))
                    } label: {
                        HStack(spacing: 6) {
                            // Profile picture
                            if let profilePhotoUrl = sender.profilePhotoUrl,
                               let url = URL(string: profilePhotoUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                                    .frame(width: 20, height: 20)
                            }

                            Text(sender.displayName)
                                .font(.nunitoSans(size: 12, weight: .semiBold))
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    // Message on new line
                    if let message = share.message, !message.isEmpty {
                        Text(message)
                            .font(.nunitoSans(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                // Share Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        trackToShare = createMusicItem()
                        showQuickSendBar = true
                    }
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Play button
                Button {
                    handlePlayTap()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isCurrentTrack ? .primary : .secondary)
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
        }
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
    }

    private func createMusicItem() -> MusicItem {
        // The track_id in shares table stores the Spotify ID
        MusicItem(
            id: share.trackId,
            name: share.trackName,
            artistName: share.artistName,
            previewUrl: nil,
            albumArtUrl: share.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: share.trackId, // Use track_id as Spotify ID
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )
    }

    private func handlePlayTap() {
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
                        Image(systemName: showShareSheet ? "paperplane.fill" : "paperplane")
                            .font(.system(size: 20))
                            .foregroundColor(showShareSheet ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Play button
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isCurrentTrack ? .primary : .secondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    isCurrentTrack
                        ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                        : Color.clear
                )
                .cornerRadius(8)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            // QuickSendBar appears below track when sharing
            if showShareSheet {
                QuickSendBar(
                    track: createMusicItem(),
                    onDismiss: {
                        withAnimation {
                            showShareSheet = false
                        }
                    },
                    onSendComplete: { sentToFriends in
                        if !sentToFriends.isEmpty {
                            print("✅ Sent to \(sentToFriends.count) friend\(sentToFriends.count == 1 ? "" : "s")")
                        }
                    },
                    additionalBottomInset: QuickSendBar.Layout.embeddedInset
                )
                .environment(\.miniPlayerBottomInset, 0)
                .environmentObject(authState)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
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
        // The track_id in shares table stores the Spotify ID
        MusicItem(
            id: share.trackId,
            name: share.trackName,
            artistName: share.artistName,
            previewUrl: nil,
            albumArtUrl: share.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: share.trackId, // Use track_id as Spotify ID
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

}

#Preview {
    TheCrateView(navigationPath: .constant(NavigationPath()), refreshTrigger: .constant(0), scrollToTopTrigger: .constant(0))
        .environmentObject(AuthenticationState())
}
