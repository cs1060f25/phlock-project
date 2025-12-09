import SwiftUI

/// A cached version of AsyncImage that stores images in memory and on disk
/// to prevent repeated network requests for the same URL.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    let transaction: Transaction
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var cachedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onAppear {
            // Check cache on appear in case it was populated by another view
            if cachedImage == nil, let url {
                if let cached = ImageCacheManager.shared.image(for: url) {
                    cachedImage = cached
                }
            }
        }
    }

    private func loadImage() {
        guard let url, !isLoading else { return }

        // Check memory cache first
        if let cached = ImageCacheManager.shared.image(for: url) {
            withTransaction(transaction) {
                cachedImage = cached
            }
            return
        }

        isLoading = true

        Task {
            do {
                let image = try await ImageCacheManager.shared.loadImage(from: url)
                await MainActor.run {
                    withTransaction(transaction) {
                        cachedImage = image
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// Convenience initializer that matches standard AsyncImage API
extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?, scale: CGFloat = 1) {
        self.init(
            url: url,
            scale: scale,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}

/// Singleton cache manager for profile and other images
final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.phlock.imagecache", qos: .userInitiated)

    // Track in-flight requests to avoid duplicate downloads
    private var inFlightRequests: [URL: Task<UIImage, Error>] = [:]
    private let requestLock = NSLock()

    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        // Setup disk cache directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("ProfileImages", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Clean old cache files on init (files older than 7 days)
        cleanOldCacheFiles()
    }

    /// Get cached image synchronously (memory only)
    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)

        // Check memory cache
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // Check disk cache synchronously
        let filePath = cacheFilePath(for: url)
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            // Populate memory cache
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }

        return nil
    }

    /// Load image from cache or network
    func loadImage(from url: URL) async throws -> UIImage {
        let key = cacheKey(for: url)

        // Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk cache
        let filePath = cacheFilePath(for: url)
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }

        // Check for in-flight request
        requestLock.lock()
        if let existingTask = inFlightRequests[url] {
            requestLock.unlock()
            return try await existingTask.value
        }

        // Create new download task
        let task = Task<UIImage, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                throw URLError(.badServerResponse)
            }

            // Cache to memory
            self.memoryCache.setObject(image, forKey: key as NSString, cost: data.count)

            // Cache to disk asynchronously
            self.queue.async {
                try? data.write(to: filePath, options: .atomic)
            }

            return image
        }

        inFlightRequests[url] = task
        requestLock.unlock()

        defer {
            requestLock.lock()
            inFlightRequests.removeValue(forKey: url)
            requestLock.unlock()
        }

        return try await task.value
    }

    /// Preload images for a list of URLs
    func preloadImages(urls: [URL]) {
        for url in urls {
            // Skip if already cached
            if image(for: url) != nil { continue }

            Task {
                _ = try? await loadImage(from: url)
            }
        }
    }

    /// Clear memory cache (called on memory warning)
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? url.absoluteString
    }

    private func cacheFilePath(for url: URL) -> URL {
        let key = cacheKey(for: url)
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .prefix(200)
        return cacheDirectory.appendingPathComponent(String(safeKey))
    }

    private func cleanOldCacheFiles() {
        queue.async { [weak self] in
            guard let self else { return }

            let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days

            guard let files = try? fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            for file in files {
                guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                      let modDate = attributes[.modificationDate] as? Date,
                      modDate < expirationDate else { continue }

                try? fileManager.removeItem(at: file)
            }
        }
    }
}
