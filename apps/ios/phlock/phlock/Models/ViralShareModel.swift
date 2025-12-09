import Foundation
import SwiftUI

enum ViralShareStyle: String, CaseIterable, Identifiable {
    case magazine
    case festival
    case mixtape
    case notifications
    case palette
    case ticket

    var id: String { rawValue }

    var title: String {
        switch self {
        case .magazine: return "Magazine"
        case .festival: return "Lineup"
        case .mixtape: return "Mixtape"
        case .notifications: return "Stack"
        case .palette: return "Palette"
        case .ticket: return "Ticket"
        }
    }
}

struct ViralShareData {
    let userTrack: MusicItem
    let userName: String
    let date: Date
    let friendsTracks: [FriendTrack]

    struct FriendTrack: Identifiable {
        let id = UUID()
        let username: String
        let trackName: String
        let artistName: String
        let albumArtUrl: String?
    }
}

// MARK: - Pre-loaded images for rendering (ImageRenderer doesn't work with AsyncImage)

struct ViralShareRenderData {
    let data: ViralShareData
    let userAlbumArt: UIImage?
    let friendsAlbumArt: [UUID: UIImage] // Keyed by FriendTrack.id
    let dominantColors: [UUID: Color]    // Pre-extracted colors for palette view

    /// Pre-loads all images and extracts colors for rendering
    static func prepare(from data: ViralShareData) async -> ViralShareRenderData {
        // Load user's album art
        let userImage = await loadImage(from: data.userTrack.albumArtUrl)

        // Load friends' album art concurrently
        var friendsImages: [UUID: UIImage] = [:]
        var dominantColors: [UUID: Color] = [:]

        await withTaskGroup(of: (UUID, UIImage?, Color?).self) { group in
            for friend in data.friendsTracks {
                group.addTask {
                    let image = await loadImage(from: friend.albumArtUrl)
                    let color = image.flatMap { extractDominantColor(from: $0) }
                    return (friend.id, image, color)
                }
            }

            for await (id, image, color) in group {
                if let image = image {
                    friendsImages[id] = image
                }
                if let color = color {
                    dominantColors[id] = color
                }
            }
        }

        // Also extract color from user's album art
        if let userImage = userImage {
            // Use a special key for user's color
            let userColor = extractDominantColor(from: userImage)
            if let color = userColor {
                // Store with a deterministic ID based on user track
                dominantColors[UUID(uuidString: "00000000-0000-0000-0000-000000000000")!] = color
            }
        }

        return ViralShareRenderData(
            data: data,
            userAlbumArt: userImage,
            friendsAlbumArt: friendsImages,
            dominantColors: dominantColors
        )
    }

    /// Helper to get user's dominant color
    var userDominantColor: Color? {
        dominantColors[UUID(uuidString: "00000000-0000-0000-0000-000000000000")!]
    }

    private static func loadImage(from urlString: String?) async -> UIImage? {
        guard let urlString = urlString,
              let url = URL(string: highQualityUrl(urlString)) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    /// Upgrades Spotify image URLs to high quality (640x640)
    private static func highQualityUrl(_ urlString: String) -> String {
        var upgraded = urlString
        upgraded = upgraded.replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")
        upgraded = upgraded.replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273")
        return upgraded
    }

    private static func extractDominantColor(from image: UIImage) -> Color? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let extentVector = CIVector(
            x: ciImage.extent.origin.x,
            y: ciImage.extent.origin.y,
            z: ciImage.extent.size.width,
            w: ciImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: extentVector
            ]
        ),
        let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
        var bitmap = [UInt8](repeating: 0, count: 4)

        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return Color(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
    }
}
