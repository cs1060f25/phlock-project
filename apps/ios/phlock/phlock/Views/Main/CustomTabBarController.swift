import SwiftUI
import UIKit

// MARK: - Tab Bar Coordinator

class TabBarCoordinator: NSObject, UITabBarControllerDelegate {
    var onFeedTabReselected: ((Int) -> Void)?  // Pass tap count
    var onDiscoverTabReselected: ((Int) -> Void)?  // Pass tap count
    var onInboxTabReselected: ((Int) -> Void)?  // Pass tap count
    var onPhlocksTabReselected: ((Int) -> Void)?  // Pass tap count
    var onTabSelected: ((Int) -> Void)?

    // Track consecutive taps for each tab
    private var consecutiveTaps: [Int: Int] = [:]
    private var lastTapTime: [Int: Date] = [:]

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // Get the index of the tapped tab
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return true
        }

        // Check if tapping the already-selected tab
        let currentIndex = tabBarController.selectedIndex
        print("📱 Tab tapped: \(index), current: \(currentIndex)")

        if index == currentIndex {
            // Track consecutive taps
            let now = Date()
            if let lastTap = lastTapTime[index], now.timeIntervalSince(lastTap) < 1.0 {
                // Within 1 second - increment consecutive count
                consecutiveTaps[index] = (consecutiveTaps[index] ?? 1) + 1
            } else {
                // First tap or after timeout - reset to 1
                consecutiveTaps[index] = 1
            }
            lastTapTime[index] = now

            let tapCount = consecutiveTaps[index] ?? 1
            print("🔄 Reselecting tab \(index) - tap #\(tapCount)")

            // Pass tap count to appropriate handler
            switch index {
            case 0:
                self.onFeedTabReselected?(tapCount)
            case 1:
                self.onDiscoverTabReselected?(tapCount)
            case 2:
                self.onInboxTabReselected?(tapCount)
            case 3:
                self.onPhlocksTabReselected?(tapCount)
            default:
                break
            }
        } else {
            // Different tab selected - reset counters
            consecutiveTaps[index] = 0
        }

        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Update SwiftUI binding when tab changes
        if let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
            onTabSelected?(index)
        }
    }
}

// MARK: - UIKit Tab Bar Wrapper

struct CustomTabBarView: UIViewControllerRepresentable {
    @Binding var selectedTab: Int
    @Binding var feedNavigationPath: NavigationPath
    @Binding var discoverNavigationPath: NavigationPath
    @Binding var inboxNavigationPath: NavigationPath
    @Binding var phlocksNavigationPath: NavigationPath
    @Binding var clearDiscoverSearchTrigger: Int
    @Binding var refreshFeedTrigger: Int
    @Binding var refreshInboxTrigger: Int
    @Binding var scrollFeedToTopTrigger: Int
    @Binding var scrollInboxToTopTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    let feedView: AnyView
    let discoverView: AnyView
    let inboxView: AnyView
    let phlocksView: AnyView

    func makeCoordinator() -> TabBarCoordinator {
        let coordinator = TabBarCoordinator()
        coordinator.onFeedTabReselected = { tapCount in
            print("🔄 Feed tab reselected - tap #\(tapCount)")
            DispatchQueue.main.async {
                if self.feedNavigationPath.count > 0 {
                    // Always pop to root first if in nested view
                    self.feedNavigationPath = NavigationPath()
                    print("✅ Feed navigation path reset")
                } else {
                    // Already at root - handle based on tap count
                    switch tapCount {
                    case 1:
                        // First tap when at root - scroll to top
                        self.scrollFeedToTopTrigger += 1
                        print("⬆️ Scrolling feed to top")
                    default:
                        // Second+ tap - refresh feed (reload data)
                        self.refreshFeedTrigger += 1
                        print("🔄 Refreshing feed - trigger: \(self.refreshFeedTrigger)")
                    }
                }
            }
        }
        coordinator.onDiscoverTabReselected = { tapCount in
            print("🔄 Discover tab reselected - tap #\(tapCount)")
            DispatchQueue.main.async {
                if self.discoverNavigationPath.count > 0 {
                    // Pop to root if we're in a nested view
                    self.discoverNavigationPath = NavigationPath()
                    print("✅ Discover navigation path reset")
                } else {
                    // Already at root, clear search and focus field
                    self.clearDiscoverSearchTrigger += 1
                    print("🔍 Clearing search and focusing field")
                }
            }
        }
        coordinator.onInboxTabReselected = { tapCount in
            print("🔄 Inbox tab reselected - tap #\(tapCount)")
            DispatchQueue.main.async {
                if self.inboxNavigationPath.count > 0 {
                    // Always pop to root first if in nested view
                    self.inboxNavigationPath = NavigationPath()
                    print("✅ Inbox navigation path reset")
                } else {
                    // Already at root - handle based on tap count
                    switch tapCount {
                    case 1:
                        // First tap when at root - scroll to top
                        self.scrollInboxToTopTrigger += 1
                        print("⬆️ Scrolling inbox to top")
                    default:
                        // Second+ tap - refresh shares (reload data)
                        self.refreshInboxTrigger += 1
                        print("🔄 Refreshing shares - trigger: \(self.refreshInboxTrigger)")
                    }
                }
            }
        }
        coordinator.onPhlocksTabReselected = { tapCount in
            print("🔄 Phlocks tab reselected - tap #\(tapCount)")
            DispatchQueue.main.async {
                if self.phlocksNavigationPath.count > 0 {
                    // Pop to root if in nested view
                    self.phlocksNavigationPath = NavigationPath()
                    print("✅ Phlocks navigation path reset")
                }
            }
        }
        coordinator.onTabSelected = { index in
            DispatchQueue.main.async {
                self.selectedTab = index
            }
        }
        return coordinator
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()
        tabBarController.delegate = context.coordinator

        // Set tab bar colors
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colorScheme == .dark ? UIColor.black : UIColor.white

        // Unselected icon color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]

        // Selected icon color
        appearance.stackedLayoutAppearance.selected.iconColor = colorScheme == .dark ? UIColor.white : UIColor.black
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: colorScheme == .dark ? UIColor.white : UIColor.black
        ]

        tabBarController.tabBar.standardAppearance = appearance
        tabBarController.tabBar.scrollEdgeAppearance = appearance

        // Create view controllers for each tab
        let feedVC = UIHostingController(rootView: feedView)
        feedVC.tabBarItem = UITabBarItem(
            title: "feed",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        let discoverVC = UIHostingController(rootView: discoverView)
        discoverVC.tabBarItem = UITabBarItem(
            title: "discover",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )

        let inboxVC = UIHostingController(rootView: inboxView)
        inboxVC.tabBarItem = UITabBarItem(
            title: "shares",
            image: UIImage(systemName: "tray"),
            selectedImage: UIImage(systemName: "tray.fill")
        )

        let phlocksVC = UIHostingController(rootView: phlocksView)
        phlocksVC.tabBarItem = UITabBarItem(
            title: "phlocks",
            image: UIImage(systemName: "chart.line.uptrend.xyaxis"),
            selectedImage: UIImage(systemName: "chart.line.uptrend.xyaxis")
        )

        tabBarController.viewControllers = [feedVC, discoverVC, inboxVC, phlocksVC]
        tabBarController.selectedIndex = selectedTab

        return tabBarController
    }

    func updateUIViewController(_ tabBarController: UITabBarController, context: Context) {
        if tabBarController.selectedIndex != selectedTab {
            tabBarController.selectedIndex = selectedTab
        }
    }
}
