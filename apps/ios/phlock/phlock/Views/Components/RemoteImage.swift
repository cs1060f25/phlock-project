import SwiftUI
import Supabase

/// Cache manager for album art URLs to prevent repeated API calls
class AlbumArtCache {
    static let shared = AlbumArtCache()

    private var cache: [String: String] = [:]
    private var failedIds: Set<String> = [] // Track permanently failed IDs

    private init() {}

    func getCachedUrl(for spotifyId: String) -> String? {
        return cache[spotifyId]
    }

    func setCachedUrl(_ url: String, for spotifyId: String) {
        cache[spotifyId] = url
    }

    func markAsFailed(_ spotifyId: String) {
        failedIds.insert(spotifyId)
    }

    func hasFailed(_ spotifyId: String) -> Bool {
        return failedIds.contains(spotifyId)
    }
}

/// A robust remote image loader that falls back to Spotify API when initial URL fails
struct RemoteImage: View {
    let url: String?
    let spotifyId: String?
    let trackName: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var retryUrl: String?
    @State private var hasFetchedFallback = false
    @State private var isFetchingFallback = false

    var body: some View {
        Group {
            if let urlString = retryUrl ?? url,
               !urlString.isEmpty,
               let imageUrl = URL(string: urlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.2)
                            if isFetchingFallback {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(let error):
                        ZStack {
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            if isFetchingFallback {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: min(width, height) * 0.4))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .onAppear {
                            handleImageLoadFailure(error: error, failedUrl: urlString)
                        }
                    @unknown default:
                        Color.gray.opacity(0.2)
                    }
                }
            } else {
                // No URL at all - show fallback
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: min(width, height) * 0.4))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .frame(width: max(0, width.isFinite ? width : 0), height: max(0, height.isFinite ? height : 0))
        .cornerRadius(cornerRadius)
        .onAppear {
            // Check cache on appear
            checkCacheOnAppear()
        }
    }

    private func checkCacheOnAppear() {
        // Check if we have a cached URL for this Spotify ID
        guard let spotifyId = spotifyId, !spotifyId.isEmpty else { return }

        // If we've already tried and failed, don't retry
        if AlbumArtCache.shared.hasFailed(spotifyId) {
            return
        }

        // Check for cached URL
        if let cachedUrl = AlbumArtCache.shared.getCachedUrl(for: spotifyId) {
            if retryUrl == nil {
                print("📦 Using cached album art URL for '\(trackName)'")
                retryUrl = cachedUrl
            }
        }
    }

    private func handleImageLoadFailure(error: Error, failedUrl: String) {
        // Only try to fetch fallback once
        guard !hasFetchedFallback else { return }

        print("❌ Failed to load album art for '\(trackName)': \(error.localizedDescription)")
        print("   Failed URL: \(failedUrl)")

        // If we have a Spotify ID, try to fetch fresh album art
        guard let spotifyId = spotifyId, !spotifyId.isEmpty else {
            print("   ⚠️ No Spotify ID available for fallback")
            return
        }

        // Don't retry if we've already permanently failed this track
        if AlbumArtCache.shared.hasFailed(spotifyId) {
            print("   ⏭️  Track previously failed, skipping retry")
            return
        }

        hasFetchedFallback = true
        isFetchingFallback = true
        print("   🔄 Attempting to fetch fresh album art from Spotify API...")

        Task {
            defer {
                Task { @MainActor in
                    isFetchingFallback = false
                }
            }

            do {
                let supabase = PhlockSupabaseClient.shared.client

                struct TrackRequest: Encodable {
                    let trackId: String
                }

                struct SpotifyTrackResponse: Decodable {
                    let album: Album

                    struct Album: Decodable {
                        let images: [Image]

                        struct Image: Decodable {
                            let url: String
                            let height: Int?
                            let width: Int?
                        }
                    }
                }

                let request = TrackRequest(trackId: spotifyId)
                let response: SpotifyTrackResponse = try await supabase.functions.invoke(
                    "get-spotify-track",
                    options: FunctionInvokeOptions(body: request)
                )

                // Get largest image (index 0) for best quality
                if !response.album.images.isEmpty {
                    let freshUrl = response.album.images.first!.url

                    await MainActor.run {
                        print("   ✅ Fetched fresh album art URL: \(freshUrl)")
                        retryUrl = freshUrl
                        // Cache the successful URL
                        AlbumArtCache.shared.setCachedUrl(freshUrl, for: spotifyId)
                    }
                } else {
                    print("   ❌ No album images found in Spotify response")
                    AlbumArtCache.shared.markAsFailed(spotifyId)
                }
            } catch {
                print("   ❌ Failed to fetch fresh album art: \(error)")

                // Check if it's a 404 error (track not found)
                if let error = error as? FunctionsError,
                   case .httpError(let code, _) = error,
                   code == 404 {
                    print("   🚫 Track not found in Spotify (404), marking as permanently failed")
                    AlbumArtCache.shared.markAsFailed(spotifyId)
                }
            }
        }
    }
}
