import SwiftUI

/// Instagram-style send overlay with vertical scrollable grid and platform options
struct QuickSendBar: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    let track: MusicItem
    let onDismiss: () -> Void
    let onSendComplete: ([User]) -> Void
    var additionalBottomInset: CGFloat = 0

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

    private var shouldShowGroupButton: Bool {
        selectedFriends.count > 1
    }

    private var sendButtonText: String {
        if selectedFriends.count > 1 {
            return "Send separately"
        } else if selectedFriends.count == 1 {
            return "Send"
        } else {
            return "Send"
        }
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }

                // Main content container
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Header with X button
                    ZStack {
                        // Centered title
                        Text("Share")
                            .font(.nunitoSans(size: 17, weight: .semiBold))

                        // X close button (positioned to trailing edge)
                        HStack {
                            Spacer()
                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
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
                                .font(.nunitoSans(size: 15, weight: .bold))
                                .lineLimit(1)
                                .foregroundColor(.primary)

                            if let artist = track.artistName {
                                Text(artist)
                                    .font(.nunitoSans(size: 13))
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
                                    .font(.nunitoSans(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 50)
                        } else if filteredFriends.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text(searchText.isEmpty ? "No friends yet" : "No friends found")
                                    .font(.nunitoSans(size: 16))
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
                    .frame(height: UIScreen.main.bounds.height * 0.35) // Fixed height for grid
                    .scrollDismissesKeyboard(.interactively)

                    // Bottom section - changes based on selection
                    if selectedFriends.isEmpty {
                        // Platform sharing options when no friends selected
                        platformOptions
                    } else {
                        // Message input and optional group button for any selection
                        messageInputWithOptionalGroup
                    }
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom + additionalBottomInset)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.75) // Takes up 75% of screen
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                        .ignoresSafeArea(edges: .bottom)
                )
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
        .ignoresSafeArea()
        .task {
            await loadFriends()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField("Search", text: $searchText)
                .font(.nunitoSans(size: 16))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
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
    }

    // MARK: - Message Input Section

    private var messageInputSection: some View {
        VStack(spacing: 0) {
            Divider()

            // Message input field
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 15))
                    .foregroundColor(isMessageFieldFocused
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)))

                TextField("Write a message...", text: $message)
                    .font(.nunitoSans(size: 14, weight: .regular))
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
                            .font(.system(size: 16))
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
                        Text("Send")
                            .font(.nunitoSans(size: 16, weight: .semiBold))
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
            .padding(.bottom, 12)
        }
    }

    // MARK: - Message Input with Optional Group Button

    private var messageInputWithOptionalGroup: some View {
        VStack(spacing: 0) {
            Divider()

            // Message input field
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 15))
                    .foregroundColor(isMessageFieldFocused
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)))

                TextField("Write a message...", text: $message)
                    .font(.nunitoSans(size: 14, weight: .regular))
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
                            .font(.system(size: 16))
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
                            .font(.nunitoSans(size: 16, weight: .semiBold))
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
            .padding(.bottom, shouldShowGroupButton ? 8 : 16)

            // Create group button (only for multiple selections)
            if shouldShowGroupButton {
                Button {
                    createGroup()
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        // Show first two selected friend avatars (smaller size)
                        HStack(spacing: -8) {
                            ForEach(Array(selectedFriends.prefix(2)), id: \.self) { friendId in
                                if let friend = allFriends.first(where: { $0.id == friendId }) {
                                    if let photoUrl = friend.profilePhotoUrl, let url = URL(string: photoUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            FriendInitialsView(displayName: friend.displayName)
                                        }
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 2)
                                        )
                                    } else {
                                        FriendInitialsView(displayName: friend.displayName)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }

                        Text("Create group")
                            .font(.nunitoSans(size: 15, weight: .semiBold))

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Multi-Select Buttons (Deprecated - kept for reference)

    private var multiSelectButtons: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.top, 8)

            // Send separately button
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
                        Text(sendButtonText)
                            .font(.nunitoSans(size: 16, weight: .semiBold))
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

            // Create group button
            if shouldShowGroupButton {
                Button {
                    createGroup()
                } label: {
                    HStack(spacing: 12) {
                        // Show first two selected friend avatars
                        HStack(spacing: -10) {
                            ForEach(Array(selectedFriends.prefix(2)), id: \.self) { friendId in
                                if let friend = allFriends.first(where: { $0.id == friendId }) {
                                    if let photoUrl = friend.profilePhotoUrl, let url = URL(string: photoUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            FriendInitialsView(displayName: friend.displayName)
                                        }
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 2)
                                        )
                                    } else {
                                        FriendInitialsView(displayName: friend.displayName)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle()
                                                    .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }

                        Text("Create group")
                            .font(.nunitoSans(size: 16, weight: .semiBold))

                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            Color.clear.frame(height: 8)
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

    private func createGroup() {
        // Create a group with selected friends
        print("👥 Creating group with \(selectedFriends.count) friends")
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
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                // Name
                Text(friend.displayName)
                    .font(.nunitoSans(size: 13))
                    .lineLimit(2)
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
        static let overlayInset: CGFloat = 110
        /// Use this when QuickSendBar is embedded inline within scroll content.
        static let embeddedInset: CGFloat = 0
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
                            .font(.system(size: 24))
                            .foregroundColor(color)
                    } else if imageName != nil {
                        // For custom images like Instagram logo
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                    }
                }

                Text(title)
                    .font(.nunitoSans(size: 11))
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
                .font(.nunitoSans(size: 24, weight: .bold))
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
    }
}
