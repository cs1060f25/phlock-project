import SwiftUI
import Combine

/// Centralized navigation state management for MainView
/// Reduces complexity by consolidating 16+ @State variables into a single object
@available(iOS 14.0, *)
class NavigationState: ObservableObject {

    // MARK: - Tab Selection
    @AppStorage("selectedTab") private var selectedTabStorage = 0
    @Published var selectedTab: Int = 0 {
        didSet {
            selectedTabStorage = selectedTab
        }
    }

    // MARK: - Navigation Paths for Each Tab
    @Published var feedNavigationPath = NavigationPath()
    @Published var discoverNavigationPath = NavigationPath()
    @Published var inboxNavigationPath = NavigationPath()
    @Published var phlocksNavigationPath = NavigationPath()

    // MARK: - Refresh Triggers
    @Published var clearDiscoverSearchTrigger = 0
    @Published var refreshFeedTrigger = 0
    @Published var refreshInboxTrigger = 0
    @Published var refreshPhlocksTrigger = 0

    // MARK: - Scroll Triggers
    @Published var scrollFeedToTopTrigger = 0
    @Published var scrollInboxToTopTrigger = 0
    @Published var scrollPhlocksToTopTrigger = 0

    // MARK: - Player State
    @Published var showFullPlayer = false

    init() {
        // Initialize selectedTab with stored value after all properties are set
        self.selectedTab = selectedTabStorage
    }

    // MARK: - Helper Methods

    /// Reset navigation for a specific tab
    func resetNavigation(for tab: Int) {
        switch tab {
        case 0:
            feedNavigationPath = NavigationPath()
        case 1:
            discoverNavigationPath = NavigationPath()
        case 2:
            inboxNavigationPath = NavigationPath()
        case 3:
            phlocksNavigationPath = NavigationPath()
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
            clearDiscoverSearchTrigger += 1
        case 2:
            refreshInboxTrigger += 1
            scrollInboxToTopTrigger += 1
        case 3:
            refreshPhlocksTrigger += 1
            scrollPhlocksToTopTrigger += 1
        default:
            break
        }
    }

    /// Clear all search in Discover tab
    func clearDiscoverSearch() {
        clearDiscoverSearchTrigger += 1
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
        case 1: return discoverNavigationPath
        case 2: return inboxNavigationPath
        case 3: return phlocksNavigationPath
        default: return NavigationPath()
        }
    }
}

// MARK: - Tab Identifiers

enum AppTab: Int, CaseIterable {
    case feed = 0
    case discover = 1
    case inbox = 2
    case phlocks = 3

    var title: String {
        switch self {
        case .feed: return "Feed"
        case .discover: return "Discover"
        case .inbox: return "Inbox"
        case .phlocks: return "Phlocks"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: return "house.fill"
        case .discover: return "magnifyingglass"
        case .inbox: return "envelope.fill"
        case .phlocks: return "star.fill"
        }
    }
}