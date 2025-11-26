import SwiftUI

/// Instagram-style send overlay with vertical scrollable grid and platform options
struct QuickSendBar: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.miniPlayerBottomInset) private var miniPlayerBottomInset
    @EnvironmentObject var playbackService: PlaybackService
    @StateObject private var keyboardObserver = KeyboardHeightObserver()

    let track: MusicItem
    let onDismiss: () -> Void
    let onSendComplete: ([User]) -> Void
    var additionalBottomInset: CGFloat = QuickSendBar.Layout.overlayInset

    @State private var allFriends: [User] = []
    @State private var isLoading = true
    @State private var selectedFriends: Set<UUID> = []
    @State private var searchText = ""
    @State private var message: String = ""
    @State private var isSending = false
    @State private var sentSuccessfully = false
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isMessageFieldFocused: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var showMessageInput = false

    // Computed properties
    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return allFriends
        } else {
            return allFriends.filter { friend in
                friend.displayName.lowercased().contains(searchText.lowercased())
            }
        }
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        GeometryReader { geometry in
            let safeBottom = geometry.safeAreaInsets.bottom
            let isOverlay = additionalBottomInset == QuickSendBar.Layout.overlayInset
            let effectiveMiniPlayerInset = isOverlay ? 0 : (playbackService.shouldShowMiniPlayer ? miniPlayerBottomInset : 0)
            let keyboardPadding = keyboardObserver.height
            // Target ~70% of screen height, capped to avoid full-screen
            let targetHeight = geometry.size.height * 0.7
            let sheetHeight = min(max(460, targetHeight), geometry.size.height * 0.9)
            let computedBottom = safeBottom + additionalBottomInset + effectiveMiniPlayerInset + keyboardPadding
            let bottomPadding = max(safeBottom + 12, computedBottom)
            let gridHeight = min(220, sheetHeight * 0.38)

            ZStack(alignment: .bottom) {
                // Main content container
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 2)
                        .padding(.bottom, 4)

                    // Header with X button
                    ZStack {
                        // Centered title
                        Text("Share")
                            .font(.lora(size: 10))

                        // X close button (positioned to trailing edge)
                        HStack {
                            Spacer()
                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.lora(size: 10, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.6))
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Track info header
                    HStack(spacing: 12) {
                        // Album Art
                        if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Track Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name)
                                .font(.lora(size: 10))
                                .lineLimit(1)
                                .foregroundColor(.primary)

                            if let artist = track.artistName {
                                Text(artist)
                                    .font(.lora(size: 10))
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Search bar
                    searchBar
                        .padding(.bottom, 8)

                    // Friends grid
                    ScrollView {
                        if isLoading {
                            // Loading state
                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Loading friends...")
                                    .font(.lora(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 50)
                        } else if filteredFriends.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                                    .font(.lora(size: 40, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(searchText.isEmpty ? "No friends yet" : "No friends found")
                                    .font(.lora(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 50)
                        } else {
                            // Friends grid
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredFriends, id: \.id) { friend in
                                    FriendGridItem(
                                        friend: friend,
                                        isSelected: selectedFriends.contains(friend.id)
                                    ) {
                                        toggleFriendSelection(friend)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                    .frame(height: gridHeight) // Fixed height for grid to leave room for footer
                    .scrollDismissesKeyboard(.interactively)

                if selectedFriends.isEmpty {
                    platformOptions
                } else {
                    messageInputWithOptionalGroup
                }
            }
            .padding(.bottom, bottomPadding)
            .frame(height: sheetHeight)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                        .ignoresSafeArea(edges: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: -5)
                .offset(y: dragOffset.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    onDismiss()
                                }
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(QuickSendBar.Layout.overlayZ)
        .task {
            await loadFriends()
        }
        .dismissKeyboardOnTouch()
        .onAppear {
            if additionalBottomInset == QuickSendBar.Layout.overlayInset {
                playbackService.isShareOverlayPresented = true
                playbackService.shouldShowMiniPlayer = false
            }
        }
        .onDisappear {
            if additionalBottomInset == QuickSendBar.Layout.overlayInset {
                playbackService.isShareOverlayPresented = false
                playbackService.shouldShowMiniPlayer = true
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.lora(size: 10))

            TextField("Search", text: $searchText)
                .font(.lora(size: 10))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.lora(size: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Platform Options

    private var platformOptions: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    // Copy Link
                    PlatformButton(
                        icon: "link",
                        title: "Copy link",
                        action: copyLink
                    )

                    // Messages (iMessage)
                    PlatformButton(
                        icon: "message.fill",
                        title: "Messages",
                        color: .green,
                        action: shareViaMessages
                    )

                    // WhatsApp
                    PlatformButton(
                        icon: "phone.fill",
                        title: "WhatsApp",
                        color: Color(red: 0.13, green: 0.71, blue: 0.29),
                        action: shareViaWhatsApp
                    )

                    // Instagram
                    PlatformButton(
                        imageName: "instagram",
                        title: "Instagram",
                        action: shareViaInstagram
                    )

                    // Add to story
                    PlatformButton(
                        icon: "plus.circle",
                        title: "Add to story",
                        action: {
                            print("Add to story tapped")
                        }
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Message Input Section

    private var messageInputSection: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.lora(size: 10))
                    .foregroundColor(isMessageFieldFocused
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)))

                TextField("Write a message...", text: $message)
                    .font(.lora(size: 10))
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .focused($isMessageFieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !isSending && !selectedFriends.isEmpty {
                            sendToSelectedFriends()
                        }
                    }

                if !message.isEmpty {
                    Button {
                        message = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.lora(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isMessageFieldFocused
                                ? (colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                                : Color.clear, lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Button {
                    if !isSending {
                        sendToSelectedFriends()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isSending ? "Sending..." : "Send")
                            .font(.lora(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(PressedButtonStyle())
                .disabled(isSending || selectedFriends.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Message Input with Optional Group Button

    private var messageInputWithOptionalGroup: some View {
        VStack(spacing: 0) {
            Divider()

            // Message input field
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.lora(size: 10))
                    .foregroundColor(isMessageFieldFocused
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)))

                TextField("Write a message...", text: $message)
                    .font(.lora(size: 10))
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .focused($isMessageFieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !isSending && !selectedFriends.isEmpty {
                            sendToSelectedFriends()
                        }
                    }

                if !message.isEmpty {
                    Button {
                        message = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.lora(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isMessageFieldFocused
                                ? (colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                                : Color.clear, lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Send button
            Button {
                if !isSending {
                    sendToSelectedFriends()
                }
            } label: {
                HStack {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Text(selectedFriends.count > 1 ? "Send separately" : "Send")
                            .font(.lora(size: 10))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(PressedButtonStyle())
            .disabled(isSending || selectedFriends.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helper Functions

    private func loadFriends() async {
        guard let currentUser = authState.currentUser else {
            isLoading = false
            return
        }

        do {
            allFriends = try await UserService.shared.getFriends(for: currentUser.id)
            isLoading = false
        } catch {
            print("❌ Failed to load friends: \(error)")
            isLoading = false
        }
    }

    private func toggleFriendSelection(_ friend: User) {
        // Haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedFriends.contains(friend.id) {
                selectedFriends.remove(friend.id)
                if selectedFriends.isEmpty {
                    showMessageInput = false
                }
            } else {
                selectedFriends.insert(friend.id)
                // Show message input for single selection
                if selectedFriends.count == 1 {
                    showMessageInput = true
                }
            }
        }
    }

    private func sendToSelectedFriends() {
        guard let currentUser = authState.currentUser else { return }

        // Dismiss keyboard before sending
        isMessageFieldFocused = false
        isSearchFocused = false

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        let selectedFriendUsers = allFriends.filter { selectedFriends.contains($0.id) }

        Task {
            await MainActor.run {
                isSending = true
                sentSuccessfully = false
            }

            do {
                _ = try await ShareService.shared.createShare(
                    track: track,
                    recipients: Array(selectedFriends),
                    message: message.isEmpty ? nil : message,
                    senderId: currentUser.id
                )

                await MainActor.run {
                    isSending = false
                    sentSuccessfully = true

                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)

                    // Call completion and dismiss
                    onSendComplete(selectedFriendUsers)

                    // Dismiss after short delay
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await MainActor.run {
                            onDismiss()
                        }
                    }
                }
            } catch {
                print("❌ Failed to send shares: \(error)")
                await MainActor.run {
                    isSending = false
                    sentSuccessfully = false

                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }

    private func copyLink() {
        // Generate share link
        let shareLink = "phlock://track/\(track.id)"
        UIPasteboard.general.string = shareLink

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        print("📋 Link copied: \(shareLink)")
    }

    private func shareViaMessages() {
        // Share via iMessage
        print("📱 Sharing via Messages")
    }

    private func shareViaWhatsApp() {
        // Share via WhatsApp
        if let url = URL(string: "whatsapp://send?text=Check out this track: \(track.name) by \(track.artistName ?? "Unknown")") {
            UIApplication.shared.open(url)
        }
    }

    private func shareViaInstagram() {
        // Share via Instagram
        print("📸 Sharing via Instagram")
    }
}

// MARK: - Friend Grid Item

struct FriendGridItem: View {
    let friend: User
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar
                    Group {
                        if let photoUrl = friend.profilePhotoUrl, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                FriendInitialsView(displayName: friend.displayName)
                            }
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                        } else {
                            FriendInitialsView(displayName: friend.displayName)
                                .frame(width: 65, height: 65)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )

                    // Selection checkmark
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.lora(size: 10))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                // Name
                Text(friend.displayName)
                    .font(.lora(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .frame(width: 75)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

extension QuickSendBar {
    enum Layout {
        /// Use this when the sheet floats above the tab bar/custom chrome.
        static let overlayInset: CGFloat = -(MiniPlayerView.Layout.tabBarOffset + 12)
        /// Use this when QuickSendBar is embedded inline within scroll content.
        static let embeddedInset: CGFloat = 0
        static let overlayZ: Double = 5000
    }
}

// MARK: - Platform Button

struct PlatformButton: View {
    var icon: String? = nil
    var imageName: String? = nil
    let title: String
    var color: Color = .primary
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(width: 56, height: 56)

                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.lora(size: 20, weight: .semiBold))
                            .foregroundColor(color)
                    } else if imageName != nil {
                        // For custom images like Instagram logo
                        Image(systemName: "camera.fill")
                            .font(.lora(size: 20, weight: .semiBold))
                            .foregroundColor(.purple)
                    }
                }

                Text(title)
                    .font(.lora(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friend Initials View

struct FriendInitialsView: View {
    let displayName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))

            Text(displayName.prefix(1).uppercased())
                .font(.lora(size: 20, weight: .semiBold))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Custom Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        QuickSendBar(
            track: MusicItem(
                id: "123",
                name: "Test Track",
                artistName: "Test Artist",
                previewUrl: nil,
                albumArtUrl: nil,
                isrc: nil,
                playedAt: nil,
                spotifyId: nil,
                appleMusicId: nil,
                popularity: nil,
                followerCount: nil
            ),
            onDismiss: {},
            onSendComplete: { _ in }
        )
        .environmentObject(AuthenticationState())
        .environmentObject(PlaybackService.shared)
    }
}
