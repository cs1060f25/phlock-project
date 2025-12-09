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
    @EnvironmentObject var playbackService: PlaybackService
    @ObservedObject private var notificationService = NotificationService.shared

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
            onTabTapped: handleTabTap,
            playbackProgress: playbackProgress,
            showProgressBar: shouldShowProgressBar,
            onSeek: { progress in
                let seekTime = progress * playbackService.duration
                playbackService.seek(to: seekTime)
            },
            hasUnreadNotifications: notificationService.hasUnreadNotifications
        )
        }
    }

    // Progress bar should show on Phlock tab when a track is loaded (playing or paused)
    private var shouldShowProgressBar: Bool {
        selectedTab == 0 && playbackService.currentTrack != nil
    }

    private var playbackProgress: Double {
        guard playbackService.duration > 0 else { return 0 }
        return playbackService.currentTime / playbackService.duration
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

// MARK: - Smooth Progress Bar Shape

/// A shape that animates its width smoothly using animatableData
private struct SmoothProgressBar: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width * CGFloat(min(max(progress, 0), 1))
        path.addRect(CGRect(x: 0, y: 0, width: width, height: rect.height))
        return path
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onTabTapped: (Int) -> Void
    var playbackProgress: Double = 0  // 0.0 to 1.0
    var showProgressBar: Bool = false  // Only show on Phlock tab when playing
    var onSeek: ((Double) -> Void)? = nil  // Callback for scrubbing
    var hasUnreadNotifications: Bool = false  // Show badge on activity tab
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    // Scrubbing state
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @GestureState private var isDragging = false

    // Animated progress for smooth transitions
    @State private var animatedProgress: Double = 0

    // Progress bar colors - adapt to color scheme
    private var progressTrackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15)
    }

    private var progressFillColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    // Display progress (use scrub value when scrubbing)
    private var displayProgress: Double {
        isScrubbing ? scrubProgress : animatedProgress
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top edge of tab bar (TikTok/IG Reels style)
            // Visible progress bar (thin line)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(showProgressBar ? progressTrackColor : Color.clear)

                    // Progress fill - using animatable shape for smooth interpolation
                    SmoothProgressBar(progress: displayProgress)
                        .fill(progressFillColor)
                        .opacity(showProgressBar ? 1 : 0)

                    // Scrub indicator (shows when scrubbing)
                    if isScrubbing && showProgressBar {
                        Circle()
                            .fill(progressFillColor)
                            .frame(width: 14, height: 14)
                            .position(
                                x: geometry.size.width * CGFloat(min(max(scrubProgress, 0), 1)),
                                y: geometry.size.height / 2
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                // Invisible hit area overlay for scrubbing - extends above and below the thin bar
                .overlay(
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 44)  // Large touch target
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard showProgressBar else { return }
                                    if !isScrubbing {
                                        isScrubbing = true
                                        scrubProgress = animatedProgress
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                    }
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    scrubProgress = progress
                                }
                                .onEnded { value in
                                    guard showProgressBar, isScrubbing else { return }
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    onSeek?(progress)
                                    // Update animated progress to match seek position
                                    animatedProgress = progress
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    isScrubbing = false
                                }
                        )
                        .offset(y: -20),  // Center the hit area above the progress bar
                    alignment: .top
                )
            }
            .frame(height: isScrubbing ? 6 : 2)
            .animation(.easeInOut(duration: 0.15), value: isScrubbing)
            .onChange(of: playbackProgress) { newProgress in
                // Smoothly animate to the new progress value
                if !isScrubbing {
                    withAnimation(.linear(duration: 0.1)) {
                        animatedProgress = newProgress
                    }
                }
            }
            .onAppear {
                animatedProgress = playbackProgress
            }

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
                title: "discover",
                tag: 1,
                isSelected: selectedTab == 1,
                onTap: { onTabTapped(1) }
            )

            TabBarButton(
                icon: "bell",
                selectedIcon: "bell.fill",
                title: "activity",
                tag: 2,
                isSelected: selectedTab == 2,
                onTap: { onTabTapped(2) },
                showBadge: hasUnreadNotifications
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
                        isSelected: selectedTab == 3,
                        photoVersion: authState.profilePhotoVersion
                    )
                )
            )
            }
            .frame(height: 49)
        }
        .background(Color.bar(for: colorScheme))
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
    let showBadge: Bool
    @Environment(\.colorScheme) var colorScheme

    init(icon: String, selectedIcon: String, title: String, tag: Int, isSelected: Bool, onTap: @escaping () -> Void, customIcon: AnyView? = nil, showBadge: Bool = false) {
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.title = title
        self.tag = tag
        self.isSelected = isSelected
        self.onTap = onTap
        self.customIcon = customIcon
        self.showBadge = showBadge
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if let customIcon {
                        customIcon
                    } else {
                        Image(systemName: isSelected ? selectedIcon : icon)
                            .font(.lora(size: 20, weight: .semiBold))
                            .foregroundColor(iconColor)
                    }

                    // Notification badge (red dot)
                    if showBadge {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
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
    var photoVersion: Int = 0  // Used to bust AsyncImage cache
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
            .id("\(photoUrl)_\(photoVersion)")  // Force refresh when version changes
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
