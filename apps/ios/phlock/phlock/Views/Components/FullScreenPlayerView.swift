import SwiftUI

struct FullScreenPlayerView: View {
    @ObservedObject var playbackService: PlaybackService
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthenticationState
    @State private var isDraggingSlider = false
    @State private var showShareBar = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if let track = playbackService.currentTrack {
                    VStack(spacing: 32) {
                        Spacer()

                        // Album Art with automatic fallback for stale URLs
                        RemoteImage(
                            url: track.albumArtUrl,
                            spotifyId: track.spotifyId,
                            trackName: track.name,
                            width: 300,
                            height: 300,
                            cornerRadius: 12
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)

                        // Track Info
                        VStack(spacing: 8) {
                            Text(track.name)
                                .font(.nunitoSans(size: 24, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if let artistName = track.artistName {
                                Text(artistName)
                                    .font(.nunitoSans(size: 18))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 32)

                        // Progress Slider
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: {
                                        isDraggingSlider ? playbackService.currentTime : playbackService.currentTime
                                    },
                                    set: { newValue in
                                        playbackService.seek(to: newValue)
                                    }
                                ),
                                in: 0...max(playbackService.duration, 1),
                                onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                }
                            )
                            .tint(.black)

                            // Time Labels
                            HStack {
                                Text(formatTime(playbackService.currentTime))
                                    .font(.nunitoSans(size: 13))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(formatTime(playbackService.duration))
                                    .font(.nunitoSans(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 32)

                        // Playback Controls
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                // Play on Platform Button (left side)
                                Button {
                                    openInNativeApp(track: track)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Play on")
                                            .font(.nunitoSans(size: 12, weight: .semiBold))
                                        Text(platformName)
                                            .font(.nunitoSans(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.primary)
                                }
                                .frame(width: geometry.size.width / 3, alignment: .leading)

                                // Play/Pause Button (center)
                                Button {
                                    if playbackService.isPlaying {
                                        playbackService.pause()
                                    } else {
                                        playbackService.resume()
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: 70, height: 70)

                                        Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: geometry.size.width / 3, alignment: .center)

                                // Share Button (right side)
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showShareBar.toggle()
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(showShareBar ? Color.black : Color.gray.opacity(0.2))
                                                .frame(width: 60, height: 60)

                                            Image(systemName: showShareBar ? "xmark" : "paperplane.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(showShareBar ? .white : .primary)
                                        }
                                    }
                                    Spacer()
                                }
                                .frame(width: geometry.size.width / 3, alignment: .trailing)
                            }
                        }
                        .frame(height: 70)
                        .padding(.horizontal, 32)

                        // QuickSendBar
                        if showShareBar {
                            QuickSendBar(track: track) { sentToFriends in
                                handleShareComplete(sentToFriends: sentToFriends)
                            }
                            .environmentObject(authState)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.top, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        playbackService.stopPlayback()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .toast(isPresented: $showToast, message: toastMessage, type: .success, duration: 3.0)
            .confetti(trigger: $showConfetti)
        }
    }

    private var platformName: String {
        switch authState.currentUser?.platformType {
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        case .none:
            return "Streaming Service"
        }
    }

    private func openInNativeApp(track: MusicItem) {
        guard let platformType = authState.currentUser?.platformType else {
            print("❌ No platform type found")
            return
        }

        print("🔗 Opening track in native app - Platform: \(platformType)")
        print("   Track: \(track.name) by \(track.artistName ?? "Unknown")")

        Task {
            do {
                switch platformType {
                case .spotify:
                    try await openInSpotify(track: track)
                case .appleMusic:
                    try await openInAppleMusic(track: track)
                }
            } catch {
                print("   ❌ Failed to open track: \(error)")
            }
        }
    }

    private func openInSpotify(track: MusicItem) async throws {
        print("🎵 Opening track in Spotify: '\(track.name)' by \(track.artistName ?? "Unknown")")
        print("   Track ID: \(track.id)")
        print("   Spotify ID: \(track.spotifyId ?? "nil")")

        // Use the exact Spotify ID if available, otherwise search
        let spotifyId: String

        if let existingSpotifyId = track.spotifyId, !existingSpotifyId.isEmpty {
            // Use the exact track ID that was originally shared
            print("   ✅ Using exact Spotify ID: \(existingSpotifyId)")
            spotifyId = existingSpotifyId
        } else {
            // Fallback: Search for the track
            print("   🔍 No Spotify ID available, searching: \(track.name) - \(track.artistName ?? "")")

            let results = try await SearchService.shared.search(
                query: "\(track.name) \(track.artistName ?? "")",
                type: .tracks,
                platformType: .spotify
            )

            guard !results.tracks.isEmpty else {
                print("   ❌ No results found on Spotify")
                return
            }

            // Smart matching: find best match by comparing track name and artist
            guard let foundTrack = findBestMatch(
                searchResults: results.tracks,
                targetTrackName: track.name,
                targetArtistName: track.artistName
            ) else {
                print("   ❌ Could not find matching track on Spotify")
                print("   📊 Search returned \(results.tracks.count) results but none matched")
                return
            }

            spotifyId = foundTrack.spotifyId ?? foundTrack.id
            print("   ✅ Found match: \(foundTrack.name) (ID: \(spotifyId))")
        }
        let spotifyURL = URL(string: "spotify:track:\(spotifyId)")
        let webURL = URL(string: "https://open.spotify.com/track/\(spotifyId)")

        await MainActor.run {
            if let spotifyURL = spotifyURL, UIApplication.shared.canOpenURL(spotifyURL) {
                print("   ✅ Opening in Spotify app")
                UIApplication.shared.open(spotifyURL)
            } else if let webURL = webURL {
                print("   ✅ Opening in Spotify web player")
                UIApplication.shared.open(webURL)
            }
        }
    }

    private func openInAppleMusic(track: MusicItem) async throws {
        // Search for the track to get the correct Apple Music ID
        print("   🔍 Searching Apple Music for: \(track.name) - \(track.artistName ?? "")")

        guard let artistName = track.artistName else {
            print("   ❌ No artist name available")
            return
        }

        guard let foundTrack = try await AppleMusicService.shared.searchTrack(
            name: track.name,
            artist: artistName,
            isrc: track.isrc
        ) else {
            print("   ❌ Could not find track on Apple Music")
            return
        }

        let appleMusicId = foundTrack.id
        let appleMusicURL = URL(string: "music://music.apple.com/song/\(appleMusicId)")
        let webURL = URL(string: "https://music.apple.com/song/\(appleMusicId)")

        print("   ✅ Found on Apple Music: \(foundTrack.title) (ID: \(appleMusicId))")

        await MainActor.run {
            if let appleMusicURL = appleMusicURL, UIApplication.shared.canOpenURL(appleMusicURL) {
                print("   ✅ Opening in Apple Music app")
                UIApplication.shared.open(appleMusicURL)
            } else if let webURL = webURL {
                print("   ✅ Opening in Apple Music web player")
                UIApplication.shared.open(webURL)
            }
        }
    }

    private func findBestMatch(
        searchResults: [MusicItem],
        targetTrackName: String,
        targetArtistName: String?
    ) -> MusicItem? {
        let normalizedTargetTrack = targetTrackName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTargetArtist = targetArtistName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        print("   🎯 Matching against: '\(normalizedTargetTrack)' by '\(normalizedTargetArtist ?? "Unknown")'")

        // Score each result
        var scoredResults: [(track: MusicItem, score: Int)] = []

        for result in searchResults {
            let normalizedResultTrack = result.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedResultArtist = result.artistName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            var score = 0

            // Track name matching (most important)
            if normalizedResultTrack == normalizedTargetTrack {
                score += 100 // Exact match
            } else if normalizedResultTrack.contains(normalizedTargetTrack) || normalizedTargetTrack.contains(normalizedResultTrack) {
                score += 50 // Partial match (handles "feat.", remixes, etc.)
            } else {
                continue // Skip if track name doesn't match at all
            }

            // Artist name matching
            if let targetArtist = normalizedTargetArtist, let resultArtist = normalizedResultArtist {
                if resultArtist == targetArtist {
                    score += 100 // Exact artist match
                } else if resultArtist.contains(targetArtist) || targetArtist.contains(resultArtist) {
                    score += 50 // Partial artist match (handles "feat.", "& The Band", etc.)
                } else {
                    score += 10 // Artist doesn't match but track does (could be cover)
                }
            } else {
                score += 20 // No artist to compare
            }

            // Popularity bonus (prefer more popular versions)
            if let popularity = result.popularity {
                score += popularity / 10 // Up to 10 points for popularity
            }

            scoredResults.append((track: result, score: score))
            print("      - '\(result.name)' by '\(result.artistName ?? "Unknown")': score \(score)")
        }

        // Sort by score descending and return best match
        let bestMatch = scoredResults.sorted { $0.score > $1.score }.first

        if let best = bestMatch {
            print("   🏆 Best match: '\(best.track.name)' by '\(best.track.artistName ?? "Unknown")' (score: \(best.score))")
        }

        return bestMatch?.track
    }

    private func handleShareComplete(sentToFriends: [User]) {
        showShareBar = false

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

    private func formatTime(_ timeInSeconds: Double) -> String {
        guard !timeInSeconds.isNaN && !timeInSeconds.isInfinite else {
            return "0:00"
        }

        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    FullScreenPlayerView(
        playbackService: PlaybackService.shared,
        isPresented: .constant(true)
    )
}
