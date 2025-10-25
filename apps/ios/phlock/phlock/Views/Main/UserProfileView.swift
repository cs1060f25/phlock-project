import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
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
                        .font(.system(size: 28, weight: .bold))

                    // Bio
                    if let bio = user.bio {
                        Text(bio)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Platform Badge
                    HStack(spacing: 6) {
                        Image(systemName: user.platformType == .spotify ? "music.note" : "applelogo")
                            .font(.system(size: 12))
                        Text(user.platformType == .spotify ? "Spotify" : "Apple Music")
                            .font(.system(size: 13, weight: .medium))
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
                                    Text("Friends")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)

                            case .pending:
                                if let friendship = friendship, friendship.userId1 == authState.currentUser?.id {
                                    // Current user sent the request
                                    Text("Request Sent")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                } else {
                                    // Other user sent the request - show accept/reject
                                    HStack(spacing: 12) {
                                        Button {
                                            Task { await rejectFriendRequest() }
                                        } label: {
                                            Text("Reject")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(12)
                                        }

                                        Button {
                                            Task { await acceptFriendRequest() }
                                        } label: {
                                            Text("Accept")
                                                .font(.system(size: 15, weight: .semibold))
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
                                    Text("Add Friend")
                                        .font(.system(size: 15, weight: .semibold))
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
                        Text("Music Taste")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)

                        // Top Tracks
                        if let topTracks = platformData.topTracks, !topTracks.isEmpty {
                            MusicStatsCard(title: "Top Tracks", items: topTracks)
                        }

                        // Top Artists
                        if let topArtists = platformData.topArtists, !topArtists.isEmpty {
                            MusicStatsCard(title: "Top Artists", items: topArtists)
                        }

                        // Playlists
                        if let playlists = platformData.playlists, !playlists.isEmpty {
                            MusicStatsCard(title: "Playlists", items: playlists.map { $0.name })
                        }
                    }
                    .padding(.top, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
            await loadFriendshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSendingRequest = false
    }

    private func acceptFriendRequest() async {
        guard let friendship = friendship else { return }

        do {
            try await UserService.shared.acceptFriendRequest(friendshipId: friendship.id)
            await loadFriendshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func rejectFriendRequest() async {
        guard let friendship = friendship else { return }

        do {
            try await UserService.shared.rejectFriendRequest(friendshipId: friendship.id)
            await loadFriendshipStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    let sampleUser = try! JSONDecoder().decode(User.self, from: """
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "display_name": "Test User",
        "bio": "Love discovering new music!",
        "platform_type": "spotify",
        "platform_user_id": "test123",
        "privacy_who_can_send": "friends"
    }
    """.data(using: .utf8)!)

    return NavigationStack {
        UserProfileView(user: sampleUser)
            .environmentObject(AuthenticationState())
    }
}
