import SwiftUI

struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    @Binding var feedNavigationPath: NavigationPath
    @Binding var discoverNavigationPath: NavigationPath
    @Binding var inboxNavigationPath: NavigationPath
    @Binding var phlocksNavigationPath: NavigationPath
    @Binding var profileNavigationPath: NavigationPath
    @Binding var clearDiscoverSearchTrigger: Int
    @Binding var refreshFeedTrigger: Int
    @Binding var refreshDiscoverTrigger: Int
    @Binding var refreshInboxTrigger: Int
    @Binding var refreshPhlocksTrigger: Int
    @Binding var scrollFeedToTopTrigger: Int
    @Binding var scrollDiscoverToTopTrigger: Int
    @Binding var scrollInboxToTopTrigger: Int
    @Binding var scrollPhlocksToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    let feedView: AnyView
    let discoverView: AnyView
    let inboxView: AnyView
    let phlocksView: AnyView
    let profileView: AnyView

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

                discoverView
                    .tag(1)

                inboxView
                    .tag(2)

                phlocksView
                    .tag(3)

                profileView
                    .tag(4)
            }

            // Custom Tab Bar (only shows 4 tabs, not Profile)
            CustomTabBar(
                selectedTab: $selectedTab,
                onTabTapped: handleTabTap
            )
        }
    }

    private func handleTabTap(_ tappedTab: Int) {
        print("📱 Tab tapped: \(tappedTab), current: \(selectedTab)")

        // If tapping Phlocks while on Profile, return to Phlocks
        if selectedTab == 4 && tappedTab == 3 {
            selectedTab = 3
            return
        }

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
        case 1: // Discover
            handleDiscoverReselection(tapCount: tapCount)
        case 2: // Inbox
            handleInboxReselection(tapCount: tapCount)
        case 3: // Phlocks
            handlePhlocksReselection(tapCount: tapCount)
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

    private func handleDiscoverReselection(tapCount: Int) {
        if discoverNavigationPath.count > 0 {
            discoverNavigationPath = NavigationPath()
            print("✅ Discover navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollDiscoverToTopTrigger += 1
                print("⬆️ Scrolling discover to top")
            default:
                refreshDiscoverTrigger += 1
                print("🔄 Refreshing discover")
            }
        }
    }

    private func handleInboxReselection(tapCount: Int) {
        if inboxNavigationPath.count > 0 {
            inboxNavigationPath = NavigationPath()
            print("✅ Inbox navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollInboxToTopTrigger += 1
                print("⬆️ Scrolling inbox to top")
            default:
                refreshInboxTrigger += 1
                print("🔄 Refreshing inbox")
            }
        }
    }

    private func handlePhlocksReselection(tapCount: Int) {
        if phlocksNavigationPath.count > 0 {
            phlocksNavigationPath = NavigationPath()
            print("✅ Phlocks navigation path reset")
        } else {
            switch tapCount {
            case 1:
                scrollPhlocksToTopTrigger += 1
                print("⬆️ Scrolling phlocks to top")
            default:
                refreshPhlocksTrigger += 1
                print("🔄 Refreshing phlocks")
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onTabTapped: (Int) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house",
                selectedIcon: "house.fill",
                title: "feed",
                tag: 0,
                isSelected: selectedTab == 0,
                onTap: { onTabTapped(0) }
            )

            TabBarButton(
                icon: "magnifyingglass",
                selectedIcon: "magnifyingglass",
                title: "discover",
                tag: 1,
                isSelected: selectedTab == 1,
                onTap: { onTabTapped(1) }
            )

            TabBarButton(
                icon: "tray",
                selectedIcon: "tray.fill",
                title: "shares",
                tag: 2,
                isSelected: selectedTab == 2,
                onTap: { onTabTapped(2) }
            )

            TabBarButton(
                icon: "chart.line.uptrend.xyaxis",
                selectedIcon: "chart.line.uptrend.xyaxis",
                title: "phlocks",
                tag: 3,
                isSelected: selectedTab == 3 || selectedTab == 4, // Highlight when on Profile too
                onTap: { onTabTapped(3) }
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .gray)

                Text(title)
                    .font(.lora(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
