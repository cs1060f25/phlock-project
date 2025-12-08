import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Service for generating shareable playlist cards
/// Handles image pre-loading, color extraction, and rendering to UIImage
@MainActor
class ShareCardGenerator {

    // MARK: - Image Cache

    /// Shared image cache to avoid re-downloading album art
    private static let imageCache = NSCache<NSString, UIImage>()

    /// Reusable CIContext for color extraction (expensive to create)
    private static let ciContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])

    // MARK: - Public API

    /// Pre-processed card data that can be rendered to multiple formats
    struct CardData {
        let songs: [ShareCardSong]
        let gradientColors: [Color]
    }

    /// Pre-warms the image cache by downloading album art in the background
    /// Call this when daily songs are loaded to ensure instant share card generation
    static func preWarmCache(for shares: [Share]) {
        let urls = shares.compactMap { $0.albumArtUrl }
        guard !urls.isEmpty else { return }

        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for urlString in urls {
                    // Skip if already cached
                    let cacheKey = urlString as NSString
                    if await MainActor.run(body: { imageCache.object(forKey: cacheKey) }) != nil {
                        continue
                    }

                    group.addTask {
                        let upgradeUrl = await MainActor.run { highQualityUrl(urlString) }
                        guard let url = URL(string: upgradeUrl) else { return }

                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let image = UIImage(data: data) {
                                await MainActor.run {
                                    imageCache.setObject(image, forKey: urlString as NSString)
                                }
                            }
                        } catch {
                            // Silently fail - image will be loaded on demand if needed
                        }
                    }
                }
            }
        }
    }

    /// Prepares card data by loading images and extracting colors
    /// Call this once, then use generateCard(from:format:) for each format
    static func prepareCardData(
        myPick: Share?,
        phlockSongs: [Share],
        members: [FollowWithPosition]
    ) async -> CardData? {
        // Deduplicate phlockSongs: keep only one song per sender
        let myPickSenderId = myPick?.senderId
        var seenSenderIds = Set<UUID>()
        var uniquePhlockSongs: [Share] = []

        for share in phlockSongs {
            if let myId = myPickSenderId, share.senderId == myId { continue }
            if seenSenderIds.contains(share.senderId) { continue }
            seenSenderIds.insert(share.senderId)
            uniquePhlockSongs.append(share)
        }

        let limitedPhlockSongs = Array(uniquePhlockSongs.prefix(5))

        var allShares: [Share] = []
        if let myPick = myPick { allShares.append(myPick) }
        allShares.append(contentsOf: limitedPhlockSongs)

        guard !allShares.isEmpty else { return nil }

        // Pre-load all album art images
        let albumArtUrls = allShares.compactMap { $0.albumArtUrl }
        let images = await loadImages(from: albumArtUrls)
        let colors = extractColors(from: Array(images.values))

        // Build ShareCardSong array
        var cardSongs: [ShareCardSong] = []

        if let myPick = myPick {
            let image = myPick.albumArtUrl.flatMap { images[$0] }
            cardSongs.append(ShareCardSong(
                share: myPick,
                image: image,
                pickerLabel: "my pick",
                isMyPick: true
            ))
        }

        for share in limitedPhlockSongs {
            let image = share.albumArtUrl.flatMap { images[$0] }
            let pickerLabel = findUsername(for: share.senderId, in: members)
            cardSongs.append(ShareCardSong(
                share: share,
                image: image,
                pickerLabel: pickerLabel
            ))
        }

        return CardData(songs: cardSongs, gradientColors: colors)
    }

    /// Generates a share card image in the specified format
    static func generateCard(from data: CardData, format: ShareCardFormat) -> UIImage? {
        let cardView = ShareCardView(
            songs: data.songs,
            gradientColors: data.gradientColors,
            format: format
        )
        return renderToImage(view: cardView, format: format)
    }

    /// Generates a share card image from the user's phlock playlist
    /// - Parameters:
    ///   - myPick: The current user's daily song pick (optional)
    ///   - phlockSongs: Daily songs from phlock members
    ///   - members: Phlock members (for username lookup)
    ///   - format: The card format (story or post)
    /// - Returns: A high-resolution UIImage
    static func generateCard(
        myPick: Share?,
        phlockSongs: [Share],
        members: [FollowWithPosition],
        format: ShareCardFormat = .story
    ) async -> UIImage? {
        guard let data = await prepareCardData(
            myPick: myPick,
            phlockSongs: phlockSongs,
            members: members
        ) else { return nil }

        return generateCard(from: data, format: format)
    }

    /// Generates cards for all formats at once (more efficient for format picker)
    static func generateAllFormats(
        myPick: Share?,
        phlockSongs: [Share],
        members: [FollowWithPosition]
    ) async -> [ShareCardFormat: UIImage] {
        guard let data = await prepareCardData(
            myPick: myPick,
            phlockSongs: phlockSongs,
            members: members
        ) else { return [:] }

        var results: [ShareCardFormat: UIImage] = [:]
        for format in ShareCardFormat.allCases {
            if let image = generateCard(from: data, format: format) {
                results[format] = image
            }
        }
        return results
    }

    // MARK: - Image Loading

    /// Loads images from URLs concurrently, using cache when available
    private static func loadImages(from urls: [String]) async -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        var urlsToFetch: [(original: String, upgraded: String)] = []

        // Check cache first
        for originalUrl in urls {
            let cacheKey = originalUrl as NSString
            if let cachedImage = imageCache.object(forKey: cacheKey) {
                results[originalUrl] = cachedImage
            } else {
                urlsToFetch.append((originalUrl, highQualityUrl(originalUrl)))
            }
        }

        // Fetch missing images concurrently
        if !urlsToFetch.isEmpty {
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for (originalUrl, upgradeUrl) in urlsToFetch {
                    group.addTask {
                        guard let url = URL(string: upgradeUrl) else {
                            return (originalUrl, nil)
                        }

                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            let image = UIImage(data: data)
                            return (originalUrl, image)
                        } catch {
                            print("ShareCardGenerator: Failed to load image from \(originalUrl): \(error)")
                            return (originalUrl, nil)
                        }
                    }
                }

                for await (urlString, image) in group {
                    if let image = image {
                        // Cache the downloaded image
                        imageCache.setObject(image, forKey: urlString as NSString)
                        results[urlString] = image
                    }
                }
            }
        }

        return results
    }

    /// Upgrades Spotify image URLs to high quality (640x640)
    private static func highQualityUrl(_ urlString: String) -> String {
        var upgraded = urlString
        // Upgrade 300px to 640px
        upgraded = upgraded.replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")
        // Upgrade 64px to 640px
        upgraded = upgraded.replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273")
        return upgraded
    }

    // MARK: - Color Extraction

    /// Extracts dominant colors from images for gradient background
    private static func extractColors(from images: [UIImage]) -> [Color] {
        var colors: [Color] = []

        for image in images {
            if let color = dominantColor(from: image) {
                colors.append(color)
            }
        }

        // Ensure we have at least 2 colors for a gradient
        if colors.isEmpty {
            colors = [Color(red: 0.3, green: 0.2, blue: 0.5), Color(red: 0.2, green: 0.3, blue: 0.6)]
        } else if colors.count == 1 {
            // Darken the single color for second gradient stop
            colors.append(colors[0].opacity(0.6))
        }

        return colors
    }

    /// Extracts the dominant (average) color from an image using Core Image
    private static func dominantColor(from image: UIImage) -> Color? {
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

        // Read single pixel to get average color (reuse shared context)
        var bitmap = [UInt8](repeating: 0, count: 4)

        ciContext.render(
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

    // MARK: - Username Lookup

    /// Finds the username for a sender ID from phlock members
    private static func findUsername(for senderId: UUID, in members: [FollowWithPosition]) -> String {
        if let member = members.first(where: { $0.user.id == senderId }) {
            if let username = member.user.username, !username.isEmpty {
                return "@\(username)"
            } else {
                return member.user.displayName
            }
        }
        return "friend"
    }

    // MARK: - Image Rendering

    /// Renders a SwiftUI view to a UIImage for the specified format
    private static func renderToImage<V: View>(view: V, format: ShareCardFormat) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0  // Always render at 3x for high quality
        renderer.proposedSize = ProposedViewSize(
            width: format.baseSize.width,
            height: format.baseSize.height
        )
        return renderer.uiImage
    }
}

// MARK: - Instagram Stories Sharing

extension ShareCardGenerator {

    /// Shares the generated card to Instagram Stories
    /// - Parameter image: The card image to share
    /// - Returns: True if Instagram was opened successfully
    @discardableResult
    static func shareToInstagramStories(image: UIImage) -> Bool {
        guard let imageData = image.pngData() else {
            print("ShareCardGenerator: Failed to convert image to PNG data")
            return false
        }

        // Set the image on the pasteboard for Instagram
        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imageData
        ]]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5) // 5 minutes
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        // Open Instagram Stories
        guard let url = URL(string: "instagram-stories://share?source_application=com.phlock.app") else {
            return false
        }

        guard UIApplication.shared.canOpenURL(url) else {
            print("ShareCardGenerator: Instagram app not installed")
            return false
        }

        UIApplication.shared.open(url)
        return true
    }

    /// Checks if Instagram is installed
    static var isInstagramInstalled: Bool {
        guard let url = URL(string: "instagram-stories://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
