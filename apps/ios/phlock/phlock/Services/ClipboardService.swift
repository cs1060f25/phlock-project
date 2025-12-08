//
//  ClipboardService.swift
//  phlock
//
//  Monitors clipboard for music URLs and provides track suggestions
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class ClipboardService: ObservableObject {

    // MARK: - Published State

    /// The track detected from clipboard, if any
    @Published var detectedTrack: MusicItem?

    /// Whether to show the suggestion dialog
    @Published var showSuggestionDialog: Bool = false

    /// Whether we're currently fetching track info
    @Published var isLoading: Bool = false

    /// Whether clipboard checking is enabled (set to true after splash screen completes)
    var isEnabled: Bool = false

    // MARK: - Private State

    /// Last clipboard change count we checked (to avoid re-prompting for same clipboard)
    private var lastCheckedChangeCount: Int = -1

    /// Last clipboard content we checked (to avoid re-processing same content)
    private var lastCheckedContent: String?

    /// Track IDs that user has already dismissed (persisted for current day only)
    private var dismissedTrackIds: Set<String> {
        get {
            // Check if stored date is today, otherwise return empty set (reset daily)
            let storedDate = UserDefaults.standard.string(forKey: "dismissedClipboardTrackIdsDate") ?? ""
            let today = formatDateForComparison(Date())

            if storedDate == today {
                let array = UserDefaults.standard.stringArray(forKey: "dismissedClipboardTrackIds") ?? []
                return Set(array)
            } else {
                // Different day - clear old dismissed tracks
                return []
            }
        }
        set {
            let today = formatDateForComparison(Date())
            UserDefaults.standard.set(today, forKey: "dismissedClipboardTrackIdsDate")
            UserDefaults.standard.set(Array(newValue), forKey: "dismissedClipboardTrackIds")
        }
    }

    private func formatDateForComparison(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Track IDs that user has shared from Phlock (don't suggest their own shares)
    private var recentlySharedTrackIds: Set<String> = []

    // MARK: - Public Methods

    /// Check clipboard for music URLs and fetch track info if found
    /// Call this when app comes to foreground
    /// - Parameter userId: The current user's ID to check if they've already posted today
    func checkClipboard(userId: UUID?) async {
        // Skip if clipboard checking is not enabled yet (e.g., during splash screen)
        guard isEnabled else {
            return
        }

        // Skip if no user ID (shouldn't happen, but safety check)
        guard let userId = userId else {
            return
        }

        // Check if user has already posted a daily song today
        do {
            let hasPostedToday = try await ShareService.shared.hasDailySongToday(for: userId)
            if hasPostedToday {
                return
            }
        } catch {
            // If we can't check, skip clipboard detection to be safe
            print("❌ ClipboardService: Failed to check if user has posted today: \(error)")
            return
        }

        // Check if clipboard has changed since last check (doesn't trigger paste dialog)
        let currentChangeCount = UIPasteboard.general.changeCount
        guard currentChangeCount != lastCheckedChangeCount else {
            return
        }
        lastCheckedChangeCount = currentChangeCount

        // Check if clipboard contains a URL (doesn't trigger paste dialog)
        guard UIPasteboard.general.hasURLs else {
            return
        }

        // Now read the actual content (this triggers the paste permission dialog)
        guard let clipboardString = UIPasteboard.general.string else {
            return
        }

        // Skip if same content as last check (safety check)
        if clipboardString == lastCheckedContent {
            return
        }
        lastCheckedContent = clipboardString

        // Quick check if it might be a music URL
        guard MusicURLParser.mightBeMusicURL(clipboardString) else {
            return
        }

        // Parse the URL
        guard let parsed = MusicURLParser.parse(clipboardString) else {
            return
        }

        // Skip if already dismissed this track
        if dismissedTrackIds.contains(parsed.trackId) {
            return
        }

        // Fetch track info
        await fetchTrackInfo(parsed: parsed)
    }

    /// User confirmed sharing the suggested track
    func confirmSuggestion() {
        showSuggestionDialog = false
        // Track stays in detectedTrack for DiscoverView to use
    }

    /// User dismissed the suggestion
    func dismissSuggestion() {
        if let track = detectedTrack {
            dismissedTrackIds.insert(track.spotifyId ?? track.id)
        }
        showSuggestionDialog = false
        detectedTrack = nil
    }

    /// Clear the detected track (after it's been used)
    func clearDetectedTrack() {
        detectedTrack = nil
    }

    /// Mark a track as recently shared by the user (to avoid suggesting their own shares)
    func markAsShared(trackId: String) {
        recentlySharedTrackIds.insert(trackId)
    }

    // MARK: - Private Methods

    private func fetchTrackInfo(parsed: MusicURLParser.ParsedTrack) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let track: MusicItem

            switch parsed.platform {
            case .spotify:
                track = try await fetchSpotifyTrack(id: parsed.trackId)
            case .appleMusic:
                track = try await fetchAppleMusicTrack(id: parsed.trackId)
            }

            // Skip if user recently shared this track
            if recentlySharedTrackIds.contains(track.spotifyId ?? track.id) {
                return
            }

            // Success - show the suggestion
            detectedTrack = track
            showSuggestionDialog = true

        } catch {
            print("❌ ClipboardService: Failed to fetch track info: \(error)")
            // Silently fail - don't bother user if we can't fetch track info
        }
    }

    private func fetchSpotifyTrack(id: String) async throws -> MusicItem {
        let supabase = PhlockSupabaseClient.shared.client

        struct TrackRequest: Encodable {
            let trackId: String
        }

        struct SpotifyTrackResponse: Decodable {
            let id: String
            let name: String
            let artists: [Artist]
            let album: Album
            let previewUrl: String?
            let externalIds: ExternalIds?
            let popularity: Int?

            struct Artist: Decodable {
                let id: String
                let name: String
            }

            struct Album: Decodable {
                let id: String
                let name: String
                let images: [Image]

                struct Image: Decodable {
                    let url: String
                    let height: Int?
                    let width: Int?
                }
            }

            struct ExternalIds: Decodable {
                let isrc: String?
            }

            enum CodingKeys: String, CodingKey {
                case id, name, artists, album, popularity
                case previewUrl = "preview_url"
                case externalIds = "external_ids"
            }
        }

        let request = TrackRequest(trackId: id)
        let response: SpotifyTrackResponse = try await supabase.functions.invoke(
            "get-spotify-track",
            options: FunctionInvokeOptions(body: request)
        )

        // Convert to MusicItem
        let artistName = response.artists.first?.name
        let artistSpotifyId = response.artists.first?.id
        let albumArtUrl = response.album.images.first?.url

        return MusicItem(
            id: response.id,
            name: response.name,
            artistName: artistName,
            artistSpotifyId: artistSpotifyId,
            previewUrl: response.previewUrl,
            albumArtUrl: albumArtUrl,
            isrc: response.externalIds?.isrc,
            spotifyId: response.id,
            popularity: response.popularity
        )
    }

    private func fetchAppleMusicTrack(id: String) async throws -> MusicItem {
        // For Apple Music, we can use the validate-track endpoint with just the ID
        // It will search Apple Music catalog server-side
        let supabase = PhlockSupabaseClient.shared.client

        struct ValidateRequest: Encodable {
            let appleMusicId: String
        }

        struct ValidateResponse: Decodable {
            let success: Bool
            let track: TrackData?
            let error: String?

            struct TrackData: Decodable {
                let id: String
                let name: String
                let artistName: String
                let albumArtUrl: String?
                let previewUrl: String?
                let isrc: String?
                let spotifyId: String?
                let appleMusicId: String?
            }
        }

        let request = ValidateRequest(appleMusicId: id)
        let response: ValidateResponse = try await supabase.functions.invoke(
            "validate-track",
            options: FunctionInvokeOptions(body: request)
        )

        guard response.success, let track = response.track else {
            throw NSError(
                domain: "ClipboardService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: response.error ?? "Track not found"]
            )
        }

        return MusicItem(
            id: track.id,
            name: track.name,
            artistName: track.artistName,
            previewUrl: track.previewUrl,
            albumArtUrl: track.albumArtUrl,
            isrc: track.isrc,
            spotifyId: track.spotifyId,
            appleMusicId: track.appleMusicId ?? id
        )
    }
}
