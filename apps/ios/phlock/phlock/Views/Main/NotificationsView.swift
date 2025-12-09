import SwiftUI
import UserNotifications

enum NotificationsDestination: Hashable {
    case userProfile(User)
}

struct NotificationsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var navigationState: NavigationState
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true
    @State private var isRefreshing = false

    // Push notification permission state
    @State private var pushPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSettingsAlert = false

    // Sheet state for daily song picker
    @State private var showDailySongSheet = false
    @State private var dailySongNavPath = NavigationPath()
    @State private var dailySongClearTrigger = 0
    @State private var dailySongRefreshTrigger = 0
    @State private var dailySongScrollToTopTrigger = 0

    private let referenceDate = Date()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Loading notifications...")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("what's new")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: NotificationsDestination.self) { destination in
                switch destination {
                case .userProfile(let user):
                    UserProfileView(user: user)
                        .environmentObject(authState)
                        .environmentObject(PlaybackService.shared)
                }
            }
        }
        .sheet(isPresented: $showDailySongSheet) {
            DiscoverView(
                navigationPath: $dailySongNavPath,
                clearSearchTrigger: $dailySongClearTrigger,
                refreshTrigger: $dailySongRefreshTrigger,
                scrollToTopTrigger: $dailySongScrollToTopTrigger
            )
            .environmentObject(authState)
            .environmentObject(navigationState)
        }
        .task {
            await loadNotifications()
            await checkPushNotificationStatus()
        }
        .onChange(of: refreshTrigger) { _ in
            Task {
                isRefreshing = true
                await loadNotifications()
                isRefreshing = false
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Re-check permission status when app becomes active (user may have changed in Settings)
                Task {
                    await checkPushNotificationStatus()
                }
            }
        }
        .alert("Enable Notifications", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("To get notified when friends share their daily picks, go to Settings > phlock > Notifications and turn on Allow Notifications.")
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 24) {
            // Push notification permission prompt at top - shown if not authorized
            if pushPermissionStatus != .authorized {
                pushNotificationPrompt
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "music.note.list")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Text("stay tuned")
                    .font(.lora(size: 20, weight: .semiBold))

                Text("new followers, daily picks, and people\nlistening to your songs will appear here.\ncheck back soon!")
                    .font(.lora(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationList: some View {
        ScrollViewReader { proxy in
            listContent
                .listStyle(.plain)
                .modifier(ListSectionSpacingModifier())
                .environment(\.defaultMinListHeaderHeight, 0)
                .onChange(of: scrollToTopTrigger) { _ in
                    withAnimation {
                        proxy.scrollTo("notificationsTop", anchor: .top)
                    }
                }
                .instagramRefreshable {
                    await MainActor.run { isRefreshing = true }
                    await loadNotifications()
                    await MainActor.run { isRefreshing = false }
                }
        }
    }

    private var listContent: some View {
        List {
            Color.clear
                .frame(height: 0)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .id("notificationsTop")

            // Push notification permission prompt - shown if not authorized
            if pushPermissionStatus != .authorized {
                pushNotificationPrompt
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
            }

            ForEach(Array(sortedSections.enumerated()), id: \.element) { index, section in
                Section(header: sectionHeader(section, isFirst: index == 0)) {
                    ForEach(sortedNotifications(for: section), id: \.id) { notification in
                        notificationRow(for: notification)
                    }
                }
            }
        }
    }

    private var pushNotificationPrompt: some View {
        Button {
            Task {
                await requestPushNotifications()
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }

                // Text content - left aligned
                VStack(alignment: .leading, spacing: 2) {
                    Text("stay in the loop")
                        .font(.lora(size: 16, weight: .semiBold))
                        .foregroundColor(.primary)
                    Text("never miss a friend's pick")
                        .font(.lora(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // CTA button on right
                Text("enable")
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
        .buttonStyle(.plain)
    }

    private func notificationRow(for notification: NotificationItem) -> some View {
        NotificationRowView(
            notification: notification,
            onProfileTap: { user in
                markAsRead(notification)
                navigationPath.append(NotificationsDestination.userProfile(user))
            },
            onPickSong: {
                markAsRead(notification)
                showDailySongSheet = true
            },
            onListenTap: {
                markAsRead(notification)
                navigationState.selectedTab = 0
            },
            onAlbumArtTap: { tappedNotification in
                handleAlbumArtTap(tappedNotification)
            }
        )
        .environmentObject(authState)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private func sectionHeader(_ title: String, isFirst: Bool) -> some View {
        Text(title.lowercased())
            .font(.lora(size: 14, weight: .semiBold))
            .foregroundColor(.primary)
            .textCase(nil)
            .padding(.top, isFirst ? 0 : 8)
            .padding(.bottom, 4)
            .padding(.horizontal, 16)
            .listRowInsets(EdgeInsets())
            .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Data helpers

    private func markAsRead(_ item: NotificationItem) {
        if let index = notifications.firstIndex(where: { $0.id == item.id }) {
            withAnimation {
                notifications[index].isRead = true
            }
            Task {
                try? await NotificationService.shared.markAsRead(notificationId: item.id)
            }
        }
    }

    private func handleAlbumArtTap(_ notification: NotificationItem) {
        markAsRead(notification)

        guard let shareId = notification.shareId else {
            // No shareId, just navigate to phlock tab
            navigationState.selectedTab = 0
            return
        }

        // Determine if this is the user's own pick by checking if they're the sender
        // For now, we'll check in PhlockView - we set isOwnPick to false and let PhlockView figure it out
        let sheetType: NotificationNavigation.NotificationSheetType
        switch notification.type {
        case .shareCommented:
            sheetType = .comments
        case .shareLiked, .commentLiked:
            sheetType = .likers
        default:
            sheetType = .none
        }

        // Set up the pending navigation and switch to phlock tab
        navigationState.pendingNotificationNavigation = NotificationNavigation(
            shareId: shareId,
            sheetType: sheetType,
            isOwnPick: false  // Will be determined by PhlockView
        )
        navigationState.selectedTab = 0
    }

    private func markAllAsRead() async {
        let unreadIds = notifications.enumerated()
            .filter { !$0.element.isRead }
            .map { (index: $0.offset, id: $0.element.id) }

        guard !unreadIds.isEmpty else { return }

        // Update local state immediately for responsive UI
        await MainActor.run {
            for (index, _) in unreadIds {
                notifications[index].isRead = true
            }
        }

        // Clear the unread badge on the tab bar
        await NotificationService.shared.clearUnreadCount()

        // Batch update to backend
        let ids = unreadIds.map { $0.id }
        try? await NotificationService.shared.markAllAsRead(notificationIds: ids)
    }

    private var groupedNotifications: [String: [NotificationItem]] {
        Dictionary(grouping: notifications) { item in
            formatDateSection(item.createdAt)
        }
    }

    private var sortedSections: [String] {
        let sections = groupedNotifications.keys
        return sections.sorted { lhs, rhs in
            let lhsOrder = specialSectionOrder(lhs)
            let rhsOrder = specialSectionOrder(rhs)

            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"

            if let lhsDate = formatter.date(from: lhs),
               let rhsDate = formatter.date(from: rhs) {
                return lhsDate > rhsDate
            }

            return lhs > rhs
        }
    }

    private func sortedNotifications(for section: String) -> [NotificationItem] {
        guard let items = groupedNotifications[section] else { return [] }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private func specialSectionOrder(_ section: String) -> Int {
        switch section {
        case "today": return 0
        case "yesterday": return 1
        case "this week": return 2
        case "last week": return 3
        case "this month": return 4
        case "last 30 days": return 5
        case "earlier": return 6
        default: return 999
        }
    }

    private func formatDateSection(_ date: Date) -> String {
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: date, to: referenceDate).day ?? 0

        if daysDiff == 0 {
            return "today"
        } else if daysDiff == 1 {
            return "yesterday"
        } else if daysDiff <= 6 {
            return "this week"
        } else if daysDiff <= 13 {
            return "last week"
        } else if daysDiff <= 30 {
            return "this month"
        } else {
            return "earlier"
        }
    }

    private func loadNotifications() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            let items = try await NotificationService.shared.fetchNotifications(for: currentUser.id)
            await MainActor.run {
                notifications = items
                isLoading = false
            }

            // Mark all notifications as read after loading (like Instagram)
            await markAllAsRead()
        } catch {
            print("❌ Failed to load notifications: \(error)")
            await MainActor.run {
                notifications = []
                isLoading = false
            }
        }
    }

    // MARK: - Push Notification Helpers

    private func checkPushNotificationStatus() async {
        let status = await PushNotificationService.shared.checkAuthorizationStatus()
        await MainActor.run {
            pushPermissionStatus = status
        }
    }

    private func requestPushNotifications() async {
        if pushPermissionStatus == .notDetermined {
            // Request permission directly
            _ = await PushNotificationService.shared.requestAuthorization()
            // Refresh status to update UI
            await checkPushNotificationStatus()
        } else if pushPermissionStatus == .denied {
            // User denied before - show helpful dialog with directions
            await MainActor.run {
                showSettingsAlert = true
            }
        }
    }
}

// MARK: - Row

private struct NotificationRowView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    let notification: NotificationItem
    let onProfileTap: (User) -> Void
    let onPickSong: () -> Void
    let onListenTap: () -> Void
    let onAlbumArtTap: (NotificationItem) -> Void

    @State private var relationshipStatus: RelationshipStatus?
    @State private var isLoadingRelationship = true
    @State private var isProcessingFollow = false

    private var actors: [User] { notification.actors }
    private var primaryActor: User? { actors.first }

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo (tappable)
            Button {
                if let actor = primaryActor {
                    onProfileTap(actor)
                }
            } label: {
                notificationIcon
            }
            .buttonStyle(.plain)

            // Text content (tappable to profile)
            Button {
                if let actor = primaryActor {
                    onProfileTap(actor)
                }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    notificationText
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Action button OR album art thumbnail on right (Instagram-style)
            if notification.type == .shareLiked || notification.type == .shareCommented || notification.type == .commentLiked {
                albumArtThumbnail
            } else {
                actionButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(notification.isRead ? Color(uiColor: .systemBackground) : Color.blue.opacity(0.05))
        .task {
            await loadRelationshipIfNeeded()
        }
    }

    // MARK: - Album Art Thumbnail (Instagram-style, tappable)

    @ViewBuilder
    private var albumArtThumbnail: some View {
        Button {
            onAlbumArtTap(notification)
        } label: {
            if let urlString = notification.albumArtUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                // Fallback placeholder if no album art
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notification Text (Instagram style)

    private var notificationText: some View {
        Group {
            switch notification.type {
            case .dailyNudge:
                nudgeText
            case .newFollower:
                followerText
            case .followRequestReceived:
                followRequestText
            case .followRequestAccepted:
                followAcceptedText
            case .friendJoined:
                friendJoinedText
            case .phlockSongReady:
                songReadyText
            case .streakMilestone:
                streakText
            case .shareLiked:
                shareLikedText
            case .shareCommented:
                shareCommentedText
            case .commentLiked:
                commentLikedText
            }
        }
    }

    private var shareLikedText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" liked your pick. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var shareCommentedText: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                (boldText(actorNames) + regularText(" commented on your pick. ") + timestampText)
                    .lineLimit(2)
            }
            // Show comment preview if available
            if let commentText = notification.commentText, !commentText.isEmpty {
                Text("\"\(commentText)\"")
                    .font(.lora(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .italic()
            }
        }
    }

    private var commentLikedText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" liked your comment. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var nudgeText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" nudged you to pick today's song. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var followerText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" started following you. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var followRequestText: some View {
        HStack(spacing: 0) {
            // Show different text based on whether request was accepted
            if let status = relationshipStatus, status.isFollowedBy {
                (boldText(actorNames) + regularText(" started following you. ") + timestampText)
                    .lineLimit(2)
            } else {
                (boldText(actorNames) + regularText(" requested to follow you. ") + timestampText)
                    .lineLimit(2)
            }
        }
    }

    private var followAcceptedText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" accepted your follow request. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var friendJoinedText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" joined phlock. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var songReadyText: some View {
        HStack(spacing: 0) {
            (boldText(actorNames) + regularText(" picked today's song. ") + timestampText)
                .lineLimit(2)
        }
    }

    private var streakText: some View {
        let days = notification.streakDays ?? 0
        return HStack(spacing: 0) {
            (regularText("you're on a ") + boldText("\(days)-day streak") + regularText("! ") + timestampText)
                .lineLimit(2)
        }
    }

    // MARK: - Text Helpers

    private var actorNames: String {
        let names = actors.compactMap { $0.username ?? $0.displayName }
        if names.isEmpty {
            return "someone"
        } else if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        } else {
            return "\(names[0]) and \(names.count - 1) others"
        }
    }

    private func boldText(_ string: String) -> Text {
        Text(string)
            .font(.lora(size: 13, weight: .semiBold))
            .foregroundColor(.primary)
    }

    private func regularText(_ string: String) -> Text {
        Text(string)
            .font(.lora(size: 13))
            .foregroundColor(.primary)
    }

    private var timestampText: Text {
        Text(instagramTimestamp(from: notification.createdAt))
            .font(.lora(size: 13))
            .foregroundColor(.secondary)
    }

    private func instagramTimestamp(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7

        if seconds < 60 {
            return "now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if hours < 24 {
            return "\(hours)h"
        } else if days < 7 {
            return "\(days)d"
        } else if weeks < 4 {
            return "\(weeks)w"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var notificationIcon: some View {
        switch notification.type {
        case .dailyNudge, .newFollower, .followRequestReceived, .followRequestAccepted, .friendJoined, .phlockSongReady, .shareLiked, .shareCommented, .commentLiked:
            if let actor = primaryActor {
                VStack(spacing: 0) {
                    if let urlString = actor.profilePhotoUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProfilePhotoPlaceholder(displayName: actor.displayName)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        ProfilePhotoPlaceholder(displayName: actor.displayName)
                            .frame(width: 44, height: 44)
                    }

                    // Streak badge (use effectiveStreak to handle expired streaks)
                    if actor.effectiveStreak > 0 {
                        StreakBadge(streak: actor.effectiveStreak, size: .small)
                            .offset(y: -8)
                    }
                }
            } else {
                fallbackIcon
            }

        case .streakMilestone:
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                )
        }
    }

    private var fallbackIcon: some View {
        Circle()
            .fill(Color.secondary.opacity(0.1))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "bell.fill")
                    .foregroundColor(.secondary)
            )
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch notification.type {
        case .newFollower, .followRequestAccepted, .friendJoined:
            followButton

        case .followRequestReceived:
            followRequestButtons

        case .dailyNudge:
            Button(action: onPickSong) {
                Text("pick")
                    .font(.lora(size: 13, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

        case .phlockSongReady:
            Button(action: onListenTap) {
                Text("listen")
                    .font(.lora(size: 13, weight: .semiBold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

        case .streakMilestone, .shareLiked, .shareCommented, .commentLiked:
            EmptyView()
        }
    }

    @ViewBuilder
    private var followButton: some View {
        if isLoadingRelationship {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 90, height: 32)
        } else if let status = relationshipStatus {
            if status.isFollowing {
                // Already following - show "following" button
                Button {
                    Task { await unfollowUser() }
                } label: {
                    Text("following")
                        .font(.lora(size: 13, weight: .semiBold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        .cornerRadius(8)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(isProcessingFollow)
            } else if status.hasPendingRequest {
                // Request pending
                Text("requested")
                    .font(.lora(size: 13, weight: .semiBold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .cornerRadius(8)
                    .fixedSize()
            } else {
                // Not following - show "follow" or "follow back"
                Button {
                    Task { await followUser() }
                } label: {
                    if isProcessingFollow {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 90, height: 32)
                    } else {
                        Text(status.isFollowedBy ? "follow back" : "follow")
                            .font(.lora(size: 13, weight: .semiBold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Color.blue)
                            .cornerRadius(8)
                            .fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessingFollow)
            }
        } else {
            // Fallback if can't load relationship
            Button {
                if let actor = primaryActor {
                    onProfileTap(actor)
                }
            } label: {
                Text("view")
                    .font(.lora(size: 13, weight: .semiBold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .cornerRadius(8)
                    .fixedSize()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var followRequestButtons: some View {
        if isProcessingFollow {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 90, height: 32)
        } else if let status = relationshipStatus, status.isFollowedBy {
            // Request was accepted - now show follow button (same as other notifications)
            if status.isFollowing {
                // Already following them back
                Button {
                    Task { await unfollowUser() }
                } label: {
                    Text("following")
                        .font(.lora(size: 13, weight: .semiBold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        .cornerRadius(8)
                        .fixedSize()
                }
                .buttonStyle(.plain)
            } else {
                // Not following them yet - show "follow back"
                Button {
                    Task { await followUser() }
                } label: {
                    Text("follow back")
                        .font(.lora(size: 13, weight: .semiBold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .fixedSize()
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 8) {
                Button {
                    Task { await acceptFollowRequest() }
                } label: {
                    Text("confirm")
                        .font(.lora(size: 13, weight: .semiBold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .fixedSize()
                }
                .buttonStyle(.plain)

                Button {
                    Task { await declineFollowRequest() }
                } label: {
                    Text("delete")
                        .font(.lora(size: 13, weight: .semiBold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        .cornerRadius(8)
                        .fixedSize()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func loadRelationshipIfNeeded() async {
        // Only load for notification types that show follow buttons
        guard [.newFollower, .followRequestReceived, .followRequestAccepted, .friendJoined].contains(notification.type),
              let currentUserId = authState.currentUser?.id,
              let actor = primaryActor else {
            isLoadingRelationship = false
            return
        }

        do {
            relationshipStatus = try await FollowService.shared.getRelationshipStatus(
                currentUserId: currentUserId,
                otherUserId: actor.id
            )
        } catch {
            print("Error loading relationship: \(error)")
        }
        isLoadingRelationship = false
    }

    private func followUser() async {
        guard let currentUserId = authState.currentUser?.id,
              let actor = primaryActor else { return }

        isProcessingFollow = true
        do {
            // Fetch fresh user data to get current isPrivate status
            // The actor from notification might have stale data
            let freshUser = try await UserService.shared.getUser(userId: actor.id)
            try await FollowService.shared.followOrRequest(
                userId: actor.id,
                currentUserId: currentUserId,
                targetUser: freshUser ?? actor
            )
            FollowService.shared.clearCache(for: currentUserId)
            await loadRelationshipIfNeeded()
        } catch {
            print("Error following user: \(error)")
        }
        isProcessingFollow = false
    }

    private func unfollowUser() async {
        guard let currentUserId = authState.currentUser?.id,
              let actor = primaryActor else { return }

        isProcessingFollow = true
        do {
            try await FollowService.shared.unfollow(userId: actor.id, currentUserId: currentUserId)
            FollowService.shared.clearCache(for: currentUserId)
            await loadRelationshipIfNeeded()
        } catch {
            print("Error unfollowing user: \(error)")
        }
        isProcessingFollow = false
    }

    private func acceptFollowRequest() async {
        guard let currentUserId = authState.currentUser?.id,
              let actor = primaryActor else { return }

        isProcessingFollow = true
        do {
            // Look up the follow request by requester and target
            if let request = try await FollowService.shared.getFollowRequest(requesterId: actor.id, targetId: currentUserId) {
                try await FollowService.shared.acceptFollowRequest(requestId: request.id)
                FollowService.shared.clearCache(for: currentUserId)
                await loadRelationshipIfNeeded()
            } else {
                print("Follow request not found")
            }
        } catch {
            print("Error accepting follow request: \(error)")
        }
        isProcessingFollow = false
    }

    private func declineFollowRequest() async {
        guard let currentUserId = authState.currentUser?.id,
              let actor = primaryActor else { return }

        isProcessingFollow = true
        do {
            // Look up the follow request by requester and target
            if let request = try await FollowService.shared.getFollowRequest(requesterId: actor.id, targetId: currentUserId) {
                try await FollowService.shared.rejectFollowRequest(requestId: request.id)
                FollowService.shared.clearCache(for: currentUserId)
                await loadRelationshipIfNeeded()
            } else {
                print("Follow request not found")
            }
        } catch {
            print("Error declining follow request: \(error)")
        }
        isProcessingFollow = false
    }
}

// MARK: - List Section Spacing Modifier

private struct ListSectionSpacingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.listSectionSpacing(0)
        } else {
            content
        }
    }
}
