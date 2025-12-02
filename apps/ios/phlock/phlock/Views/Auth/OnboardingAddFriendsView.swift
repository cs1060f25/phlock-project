import SwiftUI

struct OnboardingAddFriendsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedFriends: Set<UUID> = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isButtonPressed = false

    private var selectedCount: Int {
        selectedFriends.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo
            HStack(spacing: 8) {
                Image("PhlockLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                Text("phlock")
                    .font(.lora(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 60)

            // Title
            Text("add your friends\nalready on phlock")
                .font(.lora(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .padding(.bottom, 32)

            // Friends list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(authState.onboardingContactMatches) { match in
                        FriendToggleRow(
                            match: match,
                            isSelected: selectedFriends.contains(match.user.id),
                            onToggle: { isOn in
                                if isOn {
                                    selectedFriends.insert(match.user.id)
                                } else {
                                    selectedFriends.remove(match.user.id)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Add Friends Button - using gesture for press feedback
            Group {
                if isSubmitting {
                    ProgressView()
                        .tint(Color.background(for: colorScheme))
                } else {
                    Text(selectedCount > 0 ? "add \(selectedCount) friend\(selectedCount == 1 ? "" : "s")" : "continue")
                        .font(.lora(size: 17, weight: .semiBold))
                }
            }
            .foregroundColor(Color.background(for: colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primaryColor(for: colorScheme))
            .cornerRadius(16)
            .scaleEffect(isButtonPressed ? 0.97 : 1.0)
            .opacity(isButtonPressed ? 0.8 : 1.0)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isSubmitting else { return }
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = false
                        }
                        guard !isSubmitting else { return }
                        Task {
                            await addSelectedFriends()
                        }
                    }
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .onAppear {
            // Pre-select all friends by default
            for match in authState.onboardingContactMatches {
                selectedFriends.insert(match.user.id)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func addSelectedFriends() async {
        isSubmitting = true

        guard let currentUserId = authState.currentUser?.id else {
            await MainActor.run {
                authState.needsAddFriends = false
                authState.needsInviteFriends = true
            }
            return
        }

        do {
            // Send follow requests for selected friends
            for userId in selectedFriends {
                try await FollowService.shared.sendFollowRequest(to: userId, from: currentUserId)
            }

            await MainActor.run {
                authState.needsAddFriends = false
                authState.needsInviteFriends = true
                print("✅ Added \(selectedFriends.count) friends - moving to invite friends")
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        await MainActor.run {
            isSubmitting = false
        }
    }
}

// MARK: - Friend Toggle Row

struct FriendToggleRow: View {
    let match: ContactMatch
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    // Generate consistent color for initials
    private var avatarColor: Color {
        let colors: [Color] = [.orange, .green, .blue, .purple, .pink, .red, .teal, .indigo]
        let index = abs(match.user.id.hashValue) % colors.count
        return colors[index]
    }

    private var initials: String {
        let name = match.contactName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            if let photoUrl = match.user.profilePhotoUrl,
               let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsCircle
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                initialsCircle
            }

            // Name and username
            VStack(alignment: .leading, spacing: 4) {
                Text(match.contactName)
                    .font(.lora(size: 17, weight: .semiBold))
                    .foregroundColor(.primary)

                if let username = match.user.username {
                    Text("@\(username)")
                        .font(.lora(size: 15))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .tint(.blue)
        }
        .padding(.vertical, 12)
    }

    private var initialsCircle: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 56, height: 56)
            .overlay(
                Text(initials)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    OnboardingAddFriendsView()
        .environmentObject(AuthenticationState())
}
