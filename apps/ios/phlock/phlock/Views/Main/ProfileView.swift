import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = authState.currentUser {
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

                            // Edit Profile Button
                            Button {
                                showEditProfile = true
                            } label: {
                                Text("Edit Profile")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 24)

                        // Music Stats
                        if let platformData = user.platformData {
                            VStack(spacing: 16) {
                                Text("Your Music")
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

                        // Sign Out Button
                        PhlockButton(
                            title: "Sign Out",
                            action: { Task { await authState.signOut() } },
                            variant: .secondary,
                            fullWidth: true
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
        }
    }
}

struct ProfilePhotoPlaceholder: View {
    let displayName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.1))

            Text(displayName.prefix(1).uppercased())
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black.opacity(0.4))
        }
    }
}

struct MusicStatsCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1).")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Text(item)
                            .font(.system(size: 15))
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                    if index < min(4, items.count - 1) {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthenticationState())
    }
}
