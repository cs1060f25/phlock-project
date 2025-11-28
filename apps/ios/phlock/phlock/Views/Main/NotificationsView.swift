import SwiftUI

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

    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true
    @State private var isRefreshing = false

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
            .navigationTitle("notifications")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: NotificationsDestination.self) { destination in
                switch destination {
                case .userProfile(let user):
                    UserProfileView(user: user)
                }
            }
        }
        .task {
            await loadNotifications()
        }
        .onChange(of: refreshTrigger) { _ in
            Task {
                isRefreshing = true
                await loadNotifications()
                isRefreshing = false
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bell.slash")
                    .font(.lora(size: 32, weight: .bold))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Text("All caught up")
                    .font(.lora(size: 20, weight: .semiBold))

                Text("When friends add you or nudge you for a song,\nyou'll see it here.")
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
            List {
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .id("notificationsTop")

                ForEach(Array(sortedSections.enumerated()), id: \.element) { index, section in
                    Section(header: sectionHeader(section, isFirst: index == 0)) {
                        ForEach(sortedNotifications(for: section), id: \.id) { notification in
                            NotificationRowView(
                                notification: notification,
                                onProfileTap: {
                                    markAsRead(notification)
                                    if let actor = notification.actors.first {
                                        navigationPath.append(NotificationsDestination.userProfile(actor))
                                    }
                                },
                                onDailyAction: {
                                    markAsRead(notification)
                                    navigationState.selectedTab = 0 // jump to phlock tab to pick daily song
                                },
                                onGenericTap: {
                                    markAsRead(notification)
                                    // Default action based on type
                                    if notification.type == .dailyNudge {
                                        navigationState.selectedTab = 0
                                    } else if let actor = notification.actors.first {
                                        navigationPath.append(NotificationsDestination.userProfile(actor))
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    // TODO: Implement delete
                                    // Task { await deleteNotification(notification) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
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

    private func sectionHeader(_ title: String, isFirst: Bool) -> some View {
        Text(title)
            .font(.lora(size: 12))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.top, isFirst ? 0 : 16)
            .padding(.bottom, 8)
            .padding(.horizontal, 20)
            .listRowInsets(EdgeInsets())
            .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Data helpers

    private func markAsRead(_ item: NotificationItem) {
        if let index = notifications.firstIndex(where: { $0.id == item.id }) {
            withAnimation {
                notifications[index].isRead = true
            }
            // TODO: Call backend to mark read
        }
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
        default: return 999
        }
    }

    private func formatDateSection(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, equalTo: referenceDate, toGranularity: .day) {
            return "today"
        } else if calendar.isDate(date, equalTo: calendar.date(byAdding: .day, value: -1, to: referenceDate)!, toGranularity: .day) {
            return "yesterday"
        } else if calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear) {
            return "this week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
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
        } catch {
            print("❌ Failed to load notifications: \(error)")
            await MainActor.run {
                notifications = []
                isLoading = false
            }
        }
    }
}

// MARK: - Row

private struct NotificationRowView: View {
    let notification: NotificationItem
    let onProfileTap: () -> Void
    let onDailyAction: () -> Void
    let onGenericTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var actors: [User] { notification.actors }
    
    private var primaryActor: User? { actors.first }

    // Helper to bold the actor names in the text
    private var attributedTitle: AttributedString {
        var text = AttributedString("")

        switch notification.type {
        case .dailyNudge:
            let names = actors.map { $0.displayName }
            if names.isEmpty {
                text.append(AttributedString(notification.message ?? "You were nudged"))
            } else {
                var namePart = AttributedString(names[0])
                namePart.font = .lora(size: 16)
                text.append(namePart)

                if names.count == 1 {
                    text.append(AttributedString(" nudged you to pick today's song"))
                } else if names.count == 2 {
                    text.append(AttributedString(" and "))
                    var name2 = AttributedString(names[1])
                    name2.font = .lora(size: 16)
                    text.append(name2)
                    text.append(AttributedString(" nudged you to pick today's song"))
                } else {
                    text.append(AttributedString(", "))
                    var name2 = AttributedString(names[1])
                    name2.font = .lora(size: 16)
                    text.append(name2)
                    text.append(AttributedString(", and \(names.count - 2) others nudged you"))
                }
            }

        case .newFollower:
            if let actor = primaryActor {
                var name = AttributedString(actor.displayName)
                name.font = .lora(size: 16)
                text.append(name)
                text.append(AttributedString(" started following you"))
            } else {
                text.append(AttributedString("Someone started following you"))
            }

        case .followRequestReceived:
            if let actor = primaryActor {
                var name = AttributedString(actor.displayName)
                name.font = .lora(size: 16)
                text.append(name)
                text.append(AttributedString(" wants to follow you"))
            } else {
                text.append(AttributedString("New follow request"))
            }

        case .followRequestAccepted:
            if let actor = primaryActor {
                var name = AttributedString(actor.displayName)
                name.font = .lora(size: 16)
                text.append(name)
                text.append(AttributedString(" accepted your follow request"))
            } else {
                text.append(AttributedString("Your follow request was accepted"))
            }

        case .friendJoined:
            if let actor = primaryActor {
                var name = AttributedString(actor.displayName)
                name.font = .lora(size: 16)
                text.append(name)
                text.append(AttributedString(" joined Phlock"))
                if let username = actor.username {
                    text.append(AttributedString(" as @\(username)"))
                }
            } else {
                text.append(AttributedString("A contact joined Phlock"))
            }

        case .phlockSongReady:
            if let actor = primaryActor {
                var name = AttributedString(actor.displayName)
                name.font = .lora(size: 16)
                text.append(name)
                if let trackName = notification.trackName {
                    text.append(AttributedString(" picked \"\(trackName)\""))
                } else {
                    text.append(AttributedString(" picked a song for today"))
                }
            } else {
                text.append(AttributedString("New song in your phlock"))
            }

        case .songPlayed:
            let count = notification.count ?? 1
            if count == 1 {
                text.append(AttributedString("Someone played your song"))
            } else {
                text.append(AttributedString("\(count) people played your song today"))
            }

        case .songSaved:
            let count = notification.count ?? 1
            if count == 1 {
                text.append(AttributedString("Someone saved your song"))
            } else {
                text.append(AttributedString("\(count) people saved your song today"))
            }

        case .streakMilestone:
            if let days = notification.streakDays {
                text.append(AttributedString("🔥 You're on a \(days)-day streak!"))
            } else {
                text.append(AttributedString(notification.message ?? "New streak milestone!"))
            }
        }

        return text
    }

    @ViewBuilder
    private var notificationIcon: some View {
        switch notification.type {
        case .dailyNudge, .newFollower, .followRequestReceived, .followRequestAccepted, .friendJoined, .phlockSongReady:
            // Show actor's profile photo
            if let actor = primaryActor {
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
            } else {
                fallbackIcon
            }

        case .songPlayed:
            Circle()
                .fill(Color.green.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                )

        case .songSaved:
            Circle()
                .fill(Color.pink.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.pink)
                )

        case .streakMilestone:
            Circle()
                .fill(Color.orange.opacity(0.1))
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

    private var actionButton: some View {
        Group {
            switch notification.type {
            case .dailyNudge:
                Button(action: onDailyAction) {
                    Text("Pick Song")
                        .font(.lora(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

            case .newFollower, .followRequestAccepted:
                Button(action: onProfileTap) {
                    Text("View")
                        .font(.lora(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

            case .followRequestReceived:
                // TODO: Add Accept/Decline buttons
                Button(action: onProfileTap) {
                    Text("View")
                        .font(.lora(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

            case .friendJoined:
                Button(action: onProfileTap) {
                    Text("Follow")
                        .font(.lora(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

            case .phlockSongReady:
                Button(action: onDailyAction) {
                    Text("Listen")
                        .font(.lora(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

            case .songPlayed, .songSaved:
                // Informational only - no action button needed
                EmptyView()

            case .streakMilestone:
                // TODO: Could add "Share" button in future
                EmptyView()
            }
        }
    }

    var body: some View {
        Button(action: onGenericTap) {
            HStack(spacing: 12) {
                // Unread Indicator (Left side)
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                } else {
                    // Invisible spacer to keep alignment if desired, or just omit
                    Color.clear.frame(width: 8, height: 8)
                }

                // Main Content (Avatar + Text)
                HStack(alignment: .top, spacing: 12) {
                    // Avatar or Icon
                    notificationIcon

                    VStack(alignment: .leading, spacing: 4) {
                        Text(attributedTitle)
                            .font(.lora(size: 16))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(relativeTime(from: notification.createdAt))
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()

                // Action Button (Right side, centered)
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
