import SwiftUI

// MARK: - Search Results Components

struct SearchResultsList: View {
    let results: SearchResult
    let filter: DiscoverView.SearchFilter
    let platformType: PlatformType
    let searchQuery: String
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState

    var displayedTracks: [MusicItem] {
        filter == .artists ? [] : results.tracks
    }

    var displayedArtists: [MusicItem] {
        filter == .tracks ? [] : results.artists
    }

    // For "All" tab, rank results using Spotify's API position + popularity + name matching
    // Respects Spotify's search relevance while boosting exact/close name matches
    var allResults: [(item: MusicItem, type: String)] {
        // Helper to calculate name match score
        func nameMatchScore(itemName: String, query: String) -> Double {
            let itemLower = itemName.lowercased().trimmingCharacters(in: .whitespaces)
            let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)

            // Exact match
            if itemLower == queryLower {
                return 100.0
            }

            // Contains as whole word
            if itemLower.contains(queryLower) {
                return 50.0
            }

            // Starts with query
            if itemLower.hasPrefix(queryLower) {
                return 30.0
            }

            return 0.0
        }

        // Helper to calculate unified relevance score
        func calculateScore(item: MusicItem, index: Int, isArtist: Bool) -> Double {
            // Position score: Spotify's API ordering is the primary signal
            // Index 0 = 200 points, index 1 = 190, index 2 = 180, etc.
            let positionScore = Double(200 - (index * 10))

            // Popularity score: 0-100 from Spotify (secondary factor)
            let popularityScore = Double(item.popularity ?? 0)

            // Name matching score: Heavy boost for names that match query
            let matchScore = nameMatchScore(itemName: item.name, query: searchQuery)

            // Combined score: 50% position, 30% name match, 20% popularity
            var finalScore = (positionScore * 0.5) + (matchScore * 0.3) + (popularityScore * 0.2)

            // Additional boost for artists with name matches (canonical entities)
            if isArtist && matchScore > 0 {
                finalScore += 50.0
            }

            return finalScore
        }

        // Create scored items with stable sort key
        var scoredItems: [(item: MusicItem, type: String, score: Double, originalIndex: Int)] = []

        // Add tracks with scores
        for (index, track) in results.tracks.enumerated() {
            let score = calculateScore(item: track, index: index, isArtist: false)
            scoredItems.append((track, "Track", score, index))
        }

        // Add artists with scores (offset index to ensure uniqueness)
        for (index, artist) in results.artists.enumerated() {
            let score = calculateScore(item: artist, index: index, isArtist: true)
            scoredItems.append((artist, "Artist", score, results.tracks.count + index))
        }

        // Sort by score descending, then by original index for stability
        scoredItems.sort {
            if $0.score == $1.score {
                return $0.originalIndex < $1.originalIndex
            }
            return $0.score > $1.score
        }

        // Return without scores
        return scoredItems.map { ($0.item, $0.type) }
    }

    var body: some View {
        List {
            if filter == .all {
                // All tab - show combined results
                ForEach(Array(allResults.enumerated()), id: \.offset) { index, result in
                    if result.type == "Track" {
                        TrackResultRow(track: result.item, platformType: platformType, showType: true)
                            .environmentObject(authState)
                            .onTapGesture {
                                playTrack(result.item)
                            }
                    } else {
                        Button {
                            navigationPath.append(DiscoverDestination.artist(result.item, platformType))
                        } label: {
                            ArtistResultRow(artist: result.item, showType: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Tracks Section
                if !displayedTracks.isEmpty {
                    ForEach(displayedTracks, id: \.id) { track in
                        TrackResultRow(track: track, platformType: platformType, showType: false)
                            .environmentObject(authState)
                            .onTapGesture {
                                playTrack(track)
                            }
                    }
                }

                // Artists Section
                if !displayedArtists.isEmpty {
                    ForEach(displayedArtists, id: \.id) { artist in
                        Button {
                            navigationPath.append(DiscoverDestination.artist(artist, platformType))
                        } label: {
                            ArtistResultRow(artist: artist, showType: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // No Results
            if displayedTracks.isEmpty && displayedArtists.isEmpty {
                NoResultsView()
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
    }

    private func playTrack(_ track: MusicItem) {
        PlaybackService.shared.play(track: track)
    }
}

struct TrackResultRow: View {
    let track: MusicItem
    let platformType: PlatformType
    let showType: Bool
    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showShareSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    var isCurrentTrack: Bool {
        playbackService.currentTrack?.id == track.id
    }

    var isPlaying: Bool {
        isCurrentTrack && playbackService.isPlaying
    }

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 12) {
            // Playing indicator bar
            if isCurrentTrack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: 4, height: 40)
            }

            // Album Art
            if let artworkUrl = track.albumArtUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isCurrentTrack ? Color.primary : Color.clear, lineWidth: 2.5)
                )
            } else {
                Color.gray.opacity(0.2)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Track Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.nunitoSans(size: 16, weight: isCurrentTrack ? .bold : .semiBold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if showType {
                    Text("Track")
                        .font(.nunitoSans(size: 13, weight: isCurrentTrack ? .semiBold : .regular))
                        .foregroundColor(.secondary)
                } else if let artist = track.artistName {
                    Text(artist)
                        .font(.nunitoSans(size: 14, weight: isCurrentTrack ? .semiBold : .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Share Button
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // Play Button
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(isCurrentTrack ? .primary : .secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isCurrentTrack ? 8 : 12)
        .background(
            isCurrentTrack
                ? Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.06)
                : Color.clear
        )
        .cornerRadius(8)

            // QuickSendBar appears below track when sharing
            if showShareSheet {
                QuickSendBar(track: track) { sentToFriends in
                    handleShareComplete(sentToFriends: sentToFriends)
                }
                .environmentObject(authState)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            // Alternative: Full screen share sheet (disabled for now, using inline QuickSendBar)
        }
        .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
        .confetti(trigger: $showConfetti)
    }

    private func handleShareComplete(sentToFriends: [User]) {
        showShareSheet = false

        // Show success feedback
        let friendNames = sentToFriends.map { $0.displayName }.joined(separator: ", ")
        toastMessage = sentToFriends.count == 1
            ? "Sent to \(friendNames)"
            : "Sent to \(sentToFriends.count) friends"

        showToast = true
        showConfetti = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct ArtistResultRow: View {
    let artist: MusicItem
    let showType: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Artist Image
            if let artworkUrl = artist.albumArtUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Color.gray.opacity(0.2)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }

            // Artist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.nunitoSans(size: 16, weight: .semiBold))
                    .lineLimit(1)

                if showType {
                    Text("Artist")
                        .font(.nunitoSans(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty States

struct EmptySearchView: View {
    @FocusState.Binding var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("search for music")
                .font(.nunitoSans(size: 20, weight: .semiBold))

            Text("find tracks and artists to send")
                .font(.nunitoSans(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = false
        }
    }
}

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("no results found")
                .font(.nunitoSans(size: 20, weight: .semiBold))

            Text("try a different search term")
                .font(.nunitoSans(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("search error")
                .font(.nunitoSans(size: 20, weight: .semiBold))

            Text(message)
                .font(.nunitoSans(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                retry()
            }
            .font(.nunitoSans(size: 16, weight: .semiBold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
