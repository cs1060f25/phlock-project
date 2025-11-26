import SwiftUI

struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    @Binding var feedNavigationPath: NavigationPath
    @Binding var friendsNavigationPath: NavigationPath
    @Binding var notificationsNavigationPath: NavigationPath
    @Binding var profileNavigationPath: NavigationPath
    @Binding var refreshFeedTrigger: Int
    @Binding var refreshFriendsTrigger: Int
    @Binding var refreshNotificationsTrigger: Int
    @Binding var scrollFeedToTopTrigger: Int
    @Binding var scrollFriendsToTopTrigger: Int
    @Binding var scrollNotificationsToTopTrigger: Int
    @Binding var scrollProfileToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    let feedView: AnyView
    let friendsView: AnyView
    let notificationsView: AnyView
    let profileView: AnyView

    init(
        selectedTab: Binding<Int>,
        feedNavigationPath: Binding<NavigationPath>,
        friendsNavigationPath: Binding<NavigationPath>,
        notificationsNavigationPath: Binding<NavigationPath>,
        profileNavigationPath: Binding<NavigationPath>,
        refreshFeedTrigger: Binding<Int>,
        refreshFriendsTrigger: Binding<Int>,
        refreshNotificationsTrigger: Binding<Int>,
        scrollFeedToTopTrigger: Binding<Int>,
        scrollFriendsToTopTrigger: Binding<Int>,
        scrollNotificationsToTopTrigger: Binding<Int>,
        scrollProfileToTopTrigger: Binding<Int>,
        feedView: AnyView,
        friendsView: AnyView,
        notificationsView: AnyView,
        profileView: AnyView
    ) {
        _selectedTab = selectedTab
        _feedNavigationPath = feedNavigationPath
        _friendsNavigationPath = friendsNavigationPath
        _notificationsNavigationPath = notificationsNavigationPath
        _profileNavigationPath = profileNavigationPath
        _refreshFeedTrigger = refreshFeedTrigger
        _refreshFriendsTrigger = refreshFriendsTrigger
        _refreshNotificationsTrigger = refreshNotificationsTrigger
        _scrollFeedToTopTrigger = scrollFeedToTopTrigger
        _scrollFriendsToTopTrigger = scrollFriendsToTopTrigger
        _scrollNotificationsToTopTrigger = scrollNotificationsToTopTrigger
        _scrollProfileToTopTrigger = scrollProfileToTopTrigger
        self.feedView = feedView
        self.friendsView = friendsView
        self.notificationsView = notificationsView
        self.profileView = profileView
    }

    // Track consecutive taps for reselection
    @State private var lastTapTime: [Int: Date] = [:]
    @State private var consecutiveTaps: [Int: Int] = [:]

    var body: some View {
        ZStack(alignment: .bottom) {
            // TabView without page style - tabs switch only via button taps
            // This prevents conflicts with NavigationStack back gestures
        TabView(selection: $selectedTab) {
            feedView
                .tag(0)

            friendsView
                .tag(1)

            notificationsView
                .tag(2)

            profileView
                .tag(3)
        }

        // Custom Tab Bar (shows 4 visible tabs)
        CustomTabBar(
            selectedTab: $selectedTab,
            onTabTapped: handleTabTap
        )
    }
    }

    private func handleTabTap(_ tappedTab: Int) {
        print("📱 Tab tapped: \(tappedTab), current: \(selectedTab)")

        // Check if same tab tapped (reselection)
        if tappedTab == selectedTab {
            handleTabReselection(tappedTab)
        } else {
            // Different tab - navigate
            selectedTab = tappedTab
        }
    }

    private func handleTabReselection(_ tab: Int) {
        // Track consecutive taps
        let now = Date()
        if let lastTap = lastTapTime[tab], now.timeIntervalSince(lastTap) < 1.0 {
            consecutiveTaps[tab] = (consecutiveTaps[tab] ?? 1) + 1
        } else {
            consecutiveTaps[tab] = 1
        }
        lastTapTime[tab] = now

        let tapCount = consecutiveTaps[tab] ?? 1
        print("🔄 Tab \(tab) reselected - tap #\(tapCount)")

        switch tab {
        case 0: // Feed
            handleFeedReselection(tapCount: tapCount)
        case 1: // Friends
            handleFriendsReselection(tapCount: tapCount)
        case 2: // Notifications
            handleNotificationsReselection(tapCount: tapCount)
        case 3: // Profile
            handleProfileReselection(tapCount: tapCount)
        default:
            break
        }
    }

    private func handleFeedReselection(tapCount: Int) {
        if feedNavigationPath.count > 0 {
            feedNavigationPath = NavigationPath()
            print("✅ Feed navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollFeedToTopTrigger += 1
                print("⬆️ Scrolling feed to top")
            default:
                refreshFeedTrigger += 1
                print("🔄 Refreshing feed")
            }
        }
    }

    private func handleFriendsReselection(tapCount: Int) {
        if friendsNavigationPath.count > 0 {
            friendsNavigationPath = NavigationPath()
            print("✅ Friends navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollFriendsToTopTrigger += 1
                print("⬆️ Scrolling friends to top")
            default:
                refreshFriendsTrigger += 1
                print("🔄 Refreshing friends")
            }
        }
    }

    private func handleNotificationsReselection(tapCount: Int) {
        if notificationsNavigationPath.count > 0 {
            notificationsNavigationPath = NavigationPath()
            print("✅ Notifications navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollNotificationsToTopTrigger += 1
                print("⬆️ Scrolling notifications to top")
            default:
                refreshNotificationsTrigger += 1
                print("🔄 Refreshing notifications")
            }
        }
    }

    private func handleProfileReselection(tapCount: Int) {
        if profileNavigationPath.count > 0 {
            profileNavigationPath = NavigationPath()
            print("✅ Profile navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollProfileToTopTrigger += 1
                print("⬆️ Scrolling profile to top")
            default:
                print("🔄 Refreshing profile view")
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onTabTapped: (Int) -> Void
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house",
                selectedIcon: "house.fill",
                title: "phlock",
                tag: 0,
                isSelected: selectedTab == 0,
                onTap: { onTabTapped(0) },
                customIcon: AnyView(PhlockTabIcon(isSelected: selectedTab == 0))
            )

            TabBarButton(
                icon: "person.2",
                selectedIcon: "person.2.fill",
                title: "friends",
                tag: 1,
                isSelected: selectedTab == 1,
                onTap: { onTabTapped(1) }
            )

            TabBarButton(
                icon: "bell",
                selectedIcon: "bell.fill",
                title: "alerts",
                tag: 2,
                isSelected: selectedTab == 2,
                onTap: { onTabTapped(2) }
            )

            TabBarButton(
                icon: "person",
                selectedIcon: "person.fill",
                title: "profile",
                tag: 3,
                isSelected: selectedTab == 3,
                onTap: { onTabTapped(3) },
                customIcon: AnyView(
                    ProfileTabIcon(
                        photoUrl: authState.currentUser?.profilePhotoUrl,
                        displayName: authState.currentUser?.displayName ?? "",
                        isSelected: selectedTab == 3
                    )
                )
            )
        }
        .frame(height: 49)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let tag: Int
    let isSelected: Bool
    let onTap: () -> Void
    let customIcon: AnyView?
    @Environment(\.colorScheme) var colorScheme

    init(icon: String, selectedIcon: String, title: String, tag: Int, isSelected: Bool, onTap: @escaping () -> Void, customIcon: AnyView? = nil) {
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.title = title
        self.tag = tag
        self.isSelected = isSelected
        self.onTap = onTap
        self.customIcon = customIcon
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let customIcon {
                    customIcon
                } else {
                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.lora(size: 20, weight: .semiBold))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.lora(size: 10))
                    .foregroundColor(iconColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        isSelected ? (colorScheme == .dark ? .white : .black) : .gray
    }
}

struct PhlockTabIcon: View {
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme

    private var fillColor: Color {
        isSelected ? (colorScheme == .dark ? .white : .black) : .gray
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 8, height: 8)

            ForEach(0..<5) { index in
                // Start at top (-90°) to match the app logo's pentagonal layout
                // 5 circles distributed evenly: 72 degrees apart
                let angle = -Double.pi / 2 + Double(index) * (2 * .pi / 5)
                Circle()
                    .fill(fillColor)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: CGFloat(cos(angle)) * 10,
                        y: CGFloat(sin(angle)) * 10
                    )
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct ProfileTabIcon: View {
    let photoUrl: String?
    let displayName: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.15))
            profileImage
        }
        .frame(width: 26, height: 26)
        .overlay(
            Circle()
                .stroke(isSelected ? (colorScheme == .dark ? Color.white : Color.black) : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var profileImage: some View {
        if let photoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                initialsView
            }
            .clipShape(Circle())
        } else {
            initialsView
        }
    }

    private var initialsView: some View {
        Text(initials(from: displayName))
            .font(.lora(size: 10))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.3))
            .clipShape(Circle())
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        if parts.isEmpty {
            return "?"
        }
        let initials = parts.compactMap { $0.first }.map { String($0) }.joined()
        return initials.isEmpty ? "?" : initials.uppercased()
    }
}
