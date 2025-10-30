import SwiftUI
import UIKit

// MARK: - Tab Bar Coordinator

class TabBarCoordinator: NSObject, UITabBarControllerDelegate {
    var onFeedTabReselected: (() -> Void)?
    var onDiscoverTabReselected: (() -> Void)?
    var onInboxTabReselected: (() -> Void)?
    var onTabSelected: ((Int) -> Void)?

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // Get the index of the tapped tab
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return true
        }

        // Check if tapping the already-selected tab
        let currentIndex = tabBarController.selectedIndex
        print("📱 Tab tapped: \(index), current: \(currentIndex)")

        if index == currentIndex {
            print("🔄 Reselecting tab \(index) - triggering callback")
            // Reset navigation for the currently selected tab immediately
            switch index {
            case 0:
                self.onFeedTabReselected?()
            case 1:
                self.onDiscoverTabReselected?()
            case 2:
                self.onInboxTabReselected?()
            default:
                break
            }
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
    @Binding var clearDiscoverSearchTrigger: Int
    @Environment(\.colorScheme) var colorScheme

    let feedView: AnyView
    let discoverView: AnyView
    let inboxView: AnyView

    func makeCoordinator() -> TabBarCoordinator {
        let coordinator = TabBarCoordinator()
        coordinator.onFeedTabReselected = {
            print("🔄 Feed tab reselected - resetting navigation")
            DispatchQueue.main.async {
                self.feedNavigationPath = NavigationPath()
                print("✅ Feed navigation path reset, count: \(self.feedNavigationPath.count)")
            }
        }
        coordinator.onDiscoverTabReselected = {
            print("🔄 Discover tab reselected")
            DispatchQueue.main.async {
                if self.discoverNavigationPath.count > 0 {
                    // Pop to root if we're in a nested view
                    self.discoverNavigationPath = NavigationPath()
                    print("✅ Discover navigation path reset, count: \(self.discoverNavigationPath.count)")
                } else {
                    // Already at root, clear search and focus field
                    self.clearDiscoverSearchTrigger += 1
                    print("🔍 Clearing search and focusing field, trigger: \(self.clearDiscoverSearchTrigger)")
                }
            }
        }
        coordinator.onInboxTabReselected = {
            print("🔄 Inbox tab reselected - resetting navigation")
            DispatchQueue.main.async {
                self.inboxNavigationPath = NavigationPath()
                print("✅ Inbox navigation path reset, count: \(self.inboxNavigationPath.count)")
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

        tabBarController.viewControllers = [feedVC, discoverVC, inboxVC]
        tabBarController.selectedIndex = selectedTab

        return tabBarController
    }

    func updateUIViewController(_ tabBarController: UITabBarController, context: Context) {
        if tabBarController.selectedIndex != selectedTab {
            tabBarController.selectedIndex = selectedTab
        }
    }
}
