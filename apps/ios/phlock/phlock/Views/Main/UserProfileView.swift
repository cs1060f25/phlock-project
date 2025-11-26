import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    let user: User

    @State private var friendshipStatus: FriendshipStatus?
    @State private var friendship: Friendship?
    @State private var isLoading = true
    @State private var isSendingRequest = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Photo
                    if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProfilePhotoPlaceholder(displayName: user.displayName)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        ProfilePhotoPlaceholder(displayName: user.displayName)
                            .frame(width: 100, height: 100)
                    }

                    // Display Name
                    Text(user.displayName)
                        .font(.dmSans(size: 20, weight: .bold))

                    // Bio
                    if let bio = user.bio {
                        Text(bio)
                            .font(.dmSans(size: 10))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Platform Badge
                    HStack(spacing: 6) {
                        Image(systemName: user.platformType == .spotify ? "music.note" : "applelogo")
                            .font(.dmSans(size: 10))
                        Text(user.platformType == .spotify ? "spotify" : "apple music")
                            .font(.dmSans(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(user.platformType == .spotify ? Color(red: 0.11, green: 0.73, blue: 0.33) : Color(red: 0.98, green: 0.26, blue: 0.42))
                    .cornerRadius(16)

                    // Friend Action Button
                    Group {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else if let status = friendshipStatus {
                            switch status {
                            case .accepted:
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("friends")
                                        .font(.dmSans(size: 10))
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .cornerRadius(12)

                            case .pending:
                                if let friendship = friendship, friendship.userId1 == authState.currentUser?.id {
                                    // Current user sent the request
                                    Text("request sent")
                                        .font(.dmSans(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                        .cornerRadius(12)
                                } else {
                                    // Other user sent the request - show accept/reject
                                    HStack(spacing: 12) {
                                        Button {
                                            Task { await rejectFriendRequest() }
                                        } label: {
                                            Text("reject")
                                                .font(.dmSans(size: 10))
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                                .cornerRadius(12)
                                        }

                                        Button {
                                            Task { await acceptFriendRequest() }
                                        } label: {
                                            Text("accept")
                                                .font(.dmSans(size: 10))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.black)
                                                .cornerRadius(12)
                                        }
                                    }
                                }

                            case .blocked:
                                EmptyView()
                            }
                        } else {
                            // No friendship - show add friend button
                            Button {
                                Task { await sendFriendRequest() }
                            } label: {
                                if isSendingRequest {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                } else {
                                    Text("add friend")
                                        .font(.dmSans(size: 10))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.black)
                                        .cornerRadius(12)
                                }
                            }
                            .disabled(isSendingRequest)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                // Music Stats
                if let platformData = user.platformData {
                    VStack(spacing: 16) {
                        Text("music taste")
                            .font(.dmSans(size: 20, weight: .semiBold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)

                        // Top Tracks
                        if let topTracks = platformData.topTracks, !topTracks.isEmpty,
                           let platformType = getPlatformType(from: user) {
                            MusicStatsCard(
                                title: "what i'm listening to",
                                items: topTracks,
                                platformType: platformType,
                                itemType: .track
                            )
                        }

                        // Top Artists
                        if let topArtists = platformData.topArtists, !topArtists.isEmpty,
                           let platformType = getPlatformType(from: user) {
                            MusicStatsCard(
                                title: "who i'm listening to",
                                items: topArtists,
                                platformType: platformType,
                                itemType: .artist
                            )
                        }
                    }
                    .padding(.top, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.dmSans(size: 20, weight: .semiBold))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Task { await blockUser() }
                    } label: {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                    
                    Button(role: .destructive) {
                        Task { await reportUser() }
                    } label: {
                        Label("Report User", systemImage: "exclamationmark.bubble.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.dmSans(size: 20, weight: .semiBold))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenSwipeBack()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadFriendshipStatus()
        }
    }

    private func loadFriendshipStatus() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        isLoading = true

        do {
            friendship = try await UserService.shared.getFriendship(currentUserId: currentUserId, otherUserId: user.id)
            friendshipStatus = friendship?.status
        } catch {
            print("Error loading friendship status: \(error)")
        }

        isLoading = false
    }

    private func sendFriendRequest() async {
        guard let currentUserId = authState.currentUser?.id else { return }

        isSendingRequest = true

        do {
            try await UserService.shared.sendFriendRequest(to: user.id, from: currentUserId)

            // Clear cache to ensure fresh data in friends list
            UserService.shared.clearCache(for: currentUserId)

            await loadFriendshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSendingRequest = false
    }

    private func acceptFriendRequest() async {
        guard let friendship = friendship,
              let currentUserId = authState.currentUser?.id else { return }

        do {
            try await UserService.shared.acceptFriendRequest(
                friendshipId: friendship.id,
                currentUserId: currentUserId
            )

            // Clear cache to ensure fresh data in friends list
            UserService.shared.clearCache(for: currentUserId)

            await loadFriendshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func rejectFriendRequest() async {
        guard let friendship = friendship,
              let currentUserId = authState.currentUser?.id else { return }

        do {
            try await UserService.shared.rejectFriendRequest(friendshipId: friendship.id)

            // Clear cache to ensure fresh data in friends list
            UserService.shared.clearCache(for: currentUserId)

            await loadFriendshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func blockUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }
        
        do {
            try await UserService.shared.blockUser(userId: user.id, currentUserId: currentUserId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func reportUser() async {
        guard let currentUserId = authState.currentUser?.id else { return }
        
        // In a real app, we'd show a sheet to collect the reason
        // For now, we'll report as "Inappropriate Content" by default
        do {
            try await UserService.shared.reportUser(userId: user.id, reporterId: currentUserId, reason: "Inappropriate Content")
            errorMessage = "User reported. Thank you for keeping Phlock safe."
            showError = true // Reusing error alert for success message for simplicity
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func getPlatformType(from user: User) -> PlatformType? {
        // Try to get from platformType field first
        if let platformType = user.platformType {
            return platformType
        }
        // Otherwise derive from musicPlatform field
        if let musicPlatform = user.musicPlatform {
            return musicPlatform == "apple_music" ? .appleMusic : .spotify
        }
        return nil
    }
}

#Preview {
    // Create sample user using JSON decoding
    let sampleUserData = """
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "display_name": "Test User",
        "bio": "Love discovering new music!",
        "platform_type": "spotify",
        "platform_user_id": "test123",
        "privacy_who_can_send": "friends",
        "auth_user_id": "223e4567-e89b-12d3-a456-426614174000",
        "music_platform": "spotify"
    }
    """.data(using: .utf8)!

    let sampleUser = try! JSONDecoder().decode(User.self, from: sampleUserData)

    return NavigationStack {
        UserProfileView(user: sampleUser)
            .environmentObject(AuthenticationState())
    }
}
