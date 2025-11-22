import SwiftUI
import MusicKit
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playbackService: PlaybackService
    @Environment(\.colorScheme) var colorScheme
    @State private var showEditProfile = false
    @State private var isRefreshing = false
    @State private var refreshCount = 0 // Force view refresh

    var body: some View {
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

                            // Display Name with Platform Logo
                            HStack(spacing: 8) {
                                Text(user.displayName)
                                    .font(.nunitoSans(size: 28, weight: .bold))

                                Image(user.platformType == .spotify ? "SpotifyLogo" : "AppleMusicLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }

                            // Bio
                            if let bio = user.bio {
                                Text(bio)
                                    .font(.nunitoSans(size: 15))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }

                            // Action Buttons
                            HStack(spacing: 16) {
                                Button {
                                    showEditProfile = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11))
                                        Text("edit profile")
                                            .font(.nunitoSans(size: 13))
                                    }
                                    .foregroundColor(.secondary)
                                }

                                HStack(spacing: 4) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 11))
                                    Text("friends")
                                        .font(.nunitoSans(size: 13))
                                }
                                .foregroundColor(.secondary)
                                .opacity(0.5)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.top, 24)

                        // Music Stats
                        if let platformData = user.platformData {
                            VStack(spacing: 16) {
                                Text("your music")
                                    .font(.nunitoSans(size: 20, weight: .bold))
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
                                    .environmentObject(playbackService)
                                    .environmentObject(authState)
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

                        // Sign Out Button
                        PhlockButton(
                            title: "sign out",
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
        .refreshable {
            // Pull to refresh
            print("🔄 User initiated pull-to-refresh on ProfileView")
            await authState.refreshMusicData()
            refreshCount += 1 // Force view to re-render
            print("✅ Refresh completed. Current tracks count: \(authState.currentUser?.platformData?.topTracks?.count ?? 0)")
            if let firstTrack = authState.currentUser?.platformData?.topTracks?.first {
                print("   Latest track: \(firstTrack.name) - played at: \(firstTrack.playedAt?.description ?? "unknown")")
            }
        }
        .id(refreshCount) // Force view refresh when refreshCount changes
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
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

struct ProfilePhotoPlaceholder: View {
    let displayName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.1))

            Text(displayName.prefix(1).uppercased())
                .font(.nunitoSans(size: 40, weight: .bold))
                .foregroundColor(.black.opacity(0.4))
        }
    }
}

struct MusicStatsCard: View {
    let title: String
    let items: [MusicItem]
    let platformType: PlatformType
    let itemType: MusicItemType
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @State private var isExpanded = false
    @State private var showPlatformSheet = false
    @State private var selectedArtist: MusicItem?
    @State private var showQuickSendBar = false
    @State private var trackToShare: MusicItem?

    enum MusicItemType {
        case track
        case artist
    }

    private var displayedItems: [MusicItem] {
        // Deduplicate items by ID, keeping only the most recent one
        var uniqueItems: [String: MusicItem] = [:]

        print("🎵 MusicStatsCard rendering with \(items.count) items for \(title)")
        if let firstItem = items.first {
            print("   First item: \(firstItem.name) - played at: \(firstItem.playedAt?.description ?? "no timestamp")")
        }

        for item in items {
            // If we haven't seen this item yet, or if this one is more recent, keep it
            if let existingItem = uniqueItems[item.id] {
                if let newPlayedAt = item.playedAt,
                   let existingPlayedAt = existingItem.playedAt,
                   newPlayedAt > existingPlayedAt {
                    uniqueItems[item.id] = item
                }
            } else {
                uniqueItems[item.id] = item
            }
        }

        // Sort by playedAt (most recent first) and maintain original order
        let deduplicatedItems = items
            .filter { item in
                uniqueItems[item.id]?.playedAt == item.playedAt
            }

        return isExpanded ? deduplicatedItems : Array(deduplicatedItems.prefix(5))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.nunitoSans(size: 17, weight: .semiBold))
                    .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(Array(displayedItems.enumerated()), id: \.offset) { index, item in
                    Button {
                        if itemType == .track {
                            // Play track preview
                            PlaybackService.shared.play(track: item)
                        } else {
                            // Show action sheet for artist
                            selectedArtist = item
                            showPlatformSheet = true
                        }
                    } label: {
                        let isCurrentTrack = itemType == .track && playbackService.currentTrack?.id == item.id
                        let isPlaying = isCurrentTrack && playbackService.isPlaying

                        HStack(spacing: 8) {
                            // Playing indicator bar for tracks
                            if isCurrentTrack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.primary)
                                    .frame(width: 4, height: 30)
                            }

                            Text("\(index + 1).")
                                .font(.nunitoSans(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 24, alignment: .leading)

                            // Album art for tracks, artist image for artists
                            Group {
                                if let artworkUrl = item.albumArtUrl, let url = URL(string: artworkUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                } else {
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: itemType == .track ? 4 : 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: itemType == .track ? 4 : 20)
                                    .stroke(isCurrentTrack ? Color.primary : Color.clear, lineWidth: 2.5)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.nunitoSans(size: 15, weight: isCurrentTrack ? .bold : .regular))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                // Show timestamp for tracks only (not artists)
                                if itemType == .track, let playedAt = item.playedAt {
                                    Text(playedAt.shortRelativeTimeString())
                                        .font(.nunitoSans(size: 12, weight: isCurrentTrack ? .semiBold : .regular))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Different icons based on action type
                            if itemType == .track {
                                // Send button
                                Button {
                                    trackToShare = item
                                    showQuickSendBar = true
                                } label: {
                                    Image(systemName: "paperplane")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)

                                // Show pause icon if playing, play icon if not
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(isCurrentTrack ? .primary : .secondary)
                            } else {
                                // External link icon for artists (opens action sheet)
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            isCurrentTrack
                                ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                                : Color.clear
                        )
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                // Prevent row tap when tapping send button
                            }
                    )

                    if index < displayedItems.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.leading, 80) // Additional: 24 (number) + 8 (spacing) + 40 (artwork) + 8 (spacing)
                    }
                }

                // Show expand/collapse button if there are more than 5 items
                if items.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            Text(isExpanded ? "show less" : "show more")
                                .font(.nunitoSans(size: 13))
                                .foregroundColor(.secondary)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                }
                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .confirmationDialog(
                    "Open artist in",
                    isPresented: $showPlatformSheet,
                    titleVisibility: .visible
                ) {
                    Button("Spotify") {
                        if let artist = selectedArtist {
                            openArtistInPlatform(item: artist, platform: .spotify)
                        }
                    }
                    Button("Apple Music") {
                        if let artist = selectedArtist {
                            openArtistInPlatform(item: artist, platform: .appleMusic)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            // QuickSendBar overlay
            if showQuickSendBar, let track = trackToShare {
                QuickSendBar(
                    track: track,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showQuickSendBar = false
                            trackToShare = nil
                        }
                    },
                    onSendComplete: { sentToFriends in
                        showQuickSendBar = false
                        trackToShare = nil
                    }
                )
                .environmentObject(authState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(QuickSendBar.Layout.overlayZ)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showQuickSendBar)
            }
        }
    }

    private func openArtistInPlatform(item: MusicItem, platform: PlatformType) {
        switch platform {
        case .spotify:
            // Use stored Spotify ID if available, otherwise fallback to search
            if let spotifyId = item.spotifyId, !spotifyId.isEmpty {
                let artistURL = "https://open.spotify.com/artist/\(spotifyId)"
                print("✅ Opening Spotify artist with stored ID: \(spotifyId)")
                if let url = URL(string: artistURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                // Fallback to search for artist to get ID, then open their page
                print("⚠️ No stored Spotify ID, searching for artist: \(item.name)")
                Task {
                    await openArtistInSpotify(artistName: item.name)
                }
            }

        case .appleMusic:
            // Use stored Apple Music ID if available, otherwise search catalog
            if let appleMusicId = item.appleMusicId, !appleMusicId.isEmpty, appleMusicId != item.name {
                // Only use the ID if it's not just the artist name (fallback)
                let artistURL = "music://music.apple.com/us/artist/\(appleMusicId)"
                print("✅ Opening Apple Music artist with stored ID: \(appleMusicId)")
                if let url = URL(string: artistURL) {
                    UIApplication.shared.open(url)
                }
            } else {
                // Fallback to catalog search if no stored Apple Music ID
                print("⚠️ No stored Apple Music ID, searching catalog for: \(item.name)")
                Task {
                    await openArtistInAppleMusic(artistName: item.name)
                }
            }
        }
    }

    private func openArtistInSpotify(artistName: String) async {
        // For Spotify, search for the artist to get their ID, then open their page
        print("🔍 Searching for Spotify artist: \(artistName)")

        do {
            // Call Supabase Edge Function to search for Spotify artist
            struct SearchResponse: Decodable {
                let spotifyId: String?
            }

            let supabase = PhlockSupabaseClient.shared.client
            let response: SearchResponse = try await supabase.functions.invoke(
                "search-spotify-artist",
                options: FunctionInvokeOptions(body: ["artistName": artistName])
            )

            if let spotifyId = response.spotifyId {
                // Got the Spotify ID, open the artist page directly
                print("✅ Found Spotify artist ID: \(spotifyId)")
                let artistURL = "https://open.spotify.com/artist/\(spotifyId)"

                await MainActor.run {
                    if let url = URL(string: artistURL) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("✅ Opened Spotify artist page: \(success)")
                        }
                    }
                }
            } else {
                // No artist found, fallback to search
                print("⚠️ No Spotify artist found, opening search")
                await openSpotifySearch(artistName: artistName)
            }
        } catch {
            // Error searching, fallback to search
            print("❌ Error searching for artist: \(error)")
            await openSpotifySearch(artistName: artistName)
        }
    }

    private func openSpotifySearch(artistName: String) async {
        // Fallback to opening Spotify search
        let searchQuery = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        let spotifyURL = "https://open.spotify.com/search/\(searchQuery)"

        await MainActor.run {
            if let url = URL(string: spotifyURL) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func openArtistInAppleMusic(artistName: String) async {
        // For Apple Music, search for the artist to get the catalog ID
        print("🔍 Searching for artist: \(artistName)")

        do {
            var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [Artist.self])
            searchRequest.limit = 1

            let searchResponse = try await searchRequest.response()

            if let artist = searchResponse.artists.first {
                // Got the artist, open their page using the app URL scheme
                let artistId = artist.id.rawValue
                let artistURL = "music://music.apple.com/us/artist/\(artistId)"

                print("✅ Found artist catalog ID: \(artistId)")

                await MainActor.run {
                    if let url = URL(string: artistURL) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("✅ Opened artist page in Apple Music app")
                            } else {
                                // Fallback to web URL if app scheme doesn't work
                                print("⚠️ App URL failed, trying web URL")
                                let webURL = "https://music.apple.com/us/artist/\(artistId)"
                                if let webUrl = URL(string: webURL) {
                                    UIApplication.shared.open(webUrl)
                                }
                            }
                        }
                    }
                }
            } else {
                print("❌ Artist not found in search results")
            }
        } catch {
            print("❌ Search failed: \(error)")
        }
    }

}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationState())
}
