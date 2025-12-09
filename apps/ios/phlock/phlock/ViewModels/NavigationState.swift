import SwiftUI
import Combine

/// Represents a pending navigation from a notification tap
struct NotificationNavigation: Equatable {
    let shareId: UUID
    let sheetType: NotificationSheetType
    let isOwnPick: Bool  // Whether this is the user's own daily pick

    enum NotificationSheetType: Equatable {
        case comments
        case likers
        case none
    }
}

/// Centralized navigation state management for MainView
/// Reduces complexity by consolidating 16+ @State variables into a single object
@available(iOS 14.0, *)
class NavigationState: ObservableObject {

    // MARK: - Tab Selection
    // Note: Tab selection is NOT persisted to storage
    // This ensures the app always opens to phlock tab (index 0) on cold launch
    // While returning from background preserves the current tab (state in memory)
    @Published var selectedTab: Int = 0

    // MARK: - Navigation Paths for Each Tab
    @Published var feedNavigationPath = NavigationPath()
    @Published var friendsNavigationPath = NavigationPath()
    @Published var notificationsNavigationPath = NavigationPath()
    @Published var profileNavigationPath = NavigationPath()

    // MARK: - Refresh Triggers
    @Published var refreshFeedTrigger = 0
    @Published var refreshFriendsTrigger = 0
    @Published var refreshNotificationsTrigger = 0

    // MARK: - Scroll Triggers
    @Published var scrollFeedToTopTrigger = 0
    @Published var scrollFriendsToTopTrigger = 0
    @Published var scrollNotificationsToTopTrigger = 0
    @Published var scrollProfileToTopTrigger = 0

    // MARK: - Player State
    @Published var showFullPlayer = false
    @Published var isFabHidden = false

    // MARK: - Share Sheet State
    @Published var showShareSheet = false
    @Published var shareTrack: MusicItem? = nil

    // MARK: - Notification-triggered Navigation
    /// When set, PhlockView should navigate to this share and show the specified sheet
    @Published var pendingNotificationNavigation: NotificationNavigation? = nil

    init() {
        // Default to phlock tab (index 0) on every cold launch
        // No tab persistence - this is intentional
        selectedTab = 0
    }

    // MARK: - Helper Methods

    /// Reset navigation for a specific tab
    func resetNavigation(for tab: Int) {
        switch tab {
        case 0:
            feedNavigationPath = NavigationPath()
        case 1:
            friendsNavigationPath = NavigationPath()
        case 2:
            notificationsNavigationPath = NavigationPath()
        case 3:
            profileNavigationPath = NavigationPath()
        default:
            break
        }
    }

    /// Trigger refresh for a specific tab
    func triggerRefresh(for tab: Int) {
        switch tab {
        case 0:
            refreshFeedTrigger += 1
            scrollFeedToTopTrigger += 1
        case 1:
            refreshFriendsTrigger += 1
            scrollFriendsToTopTrigger += 1
        case 2:
            refreshNotificationsTrigger += 1
            scrollNotificationsToTopTrigger += 1
        case 3:
            scrollProfileToTopTrigger += 1
        default:
            break
        }
    }

    /// Handle tab reselection (double tap)
    func handleTabReselection(tab: Int) {
        if selectedTab == tab {
            // If already on this tab, either pop to root or refresh
            let currentPath = navigationPath(for: tab)
            if currentPath.isEmpty {
                // Already at root, trigger refresh
                triggerRefresh(for: tab)
            } else {
                // Pop to root
                resetNavigation(for: tab)
            }
        }
    }

    /// Get navigation path for a specific tab
    private func navigationPath(for tab: Int) -> NavigationPath {
        switch tab {
        case 0: return feedNavigationPath
        case 1: return friendsNavigationPath
        case 2: return notificationsNavigationPath
        case 3: return profileNavigationPath
        default: return NavigationPath()
        }
    }
}

// MARK: - Tab Identifiers

enum AppTab: Int, CaseIterable {
    case feed = 0
    case friends = 1
    case notifications = 2
    case profile = 3

    var title: String {
        switch self {
        case .feed: return "Feed"
        case .friends: return "Friends"
        case .notifications: return "Notifications"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: return "house.fill"
        case .friends: return "person.2.fill"
        case .notifications: return "bell.fill"
        case .profile: return "person.fill"
        }
    }
}
