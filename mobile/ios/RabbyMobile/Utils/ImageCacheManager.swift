import SwiftUI
import CryptoKit

// MARK: - ImageCacheManager

/// Image cache manager with memory (NSCache) + disk (Caches directory) two-level caching.
/// Features:
/// - Memory cache (NSCache, ~50MB limit) with 10-minute soft TTL
/// - Disk cache (FileManager, Caches directory) with 7-day TTL
/// - Automatic cleanup of expired disk cache files
/// - Preloading support for token and chain icons
/// - Deduplication of concurrent requests for the same URL
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    // MARK: - Cache Configuration

    /// Memory cache soft TTL (entries older than this are treated as stale but still returned)
    nonisolated private static let memoryCacheTTL: TimeInterval = 10 * 60  // 10 minutes

    /// Disk cache hard TTL (files older than this are deleted during cleanup)
    nonisolated private static let diskCacheTTL: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    /// Maximum disk cache size in bytes
    nonisolated private static let maxDiskCacheSize = 50 * 1024 * 1024  // 50MB

    /// Target disk cache size after eviction
    nonisolated private static let targetDiskCacheSize = 30 * 1024 * 1024  // 30MB

    // MARK: - Memory Cache (L1)

    /// Memory cache - fast access, auto-evicted by system under memory pressure
    private let memoryCache = NSCache<NSString, CacheEntry>()

    /// Wrapper that stores the image along with its insertion timestamp
    private class CacheEntry {
        let image: UIImage
        let timestamp: Date

        init(image: UIImage, timestamp: Date = Date()) {
            self.image = image
            self.timestamp = timestamp
        }

        /// Whether this entry has exceeded the memory TTL
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > ImageCacheManager.memoryCacheTTL
        }
    }

    // MARK: - Disk Cache (L2)

    /// Disk cache directory
    private let diskCacheURL: URL

    /// Track disk cache size for eviction decisions
    private var diskCacheSize: Int = 0

    // MARK: - Request Deduplication

    /// Active download tasks to avoid duplicate requests for the same URL
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]

    // MARK: - Preloading State

    /// Whether chain icons have been preloaded
    @Published private(set) var chainIconsPreloaded = false

    // MARK: - Initialization

    private init() {
        // Configure memory cache limits
        memoryCache.countLimit = 500       // max 500 images
        memoryCache.totalCostLimit = 50 * 1024 * 1024  // 50MB

        // Set up disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Calculate current disk cache size and run cleanup in background
        Task.detached(priority: .background) { [diskCacheURL] in
            // Clean up expired files first
            Self.cleanupExpiredFiles(at: diskCacheURL, ttl: Self.diskCacheTTL)

            let size = Self.calculateDiskCacheSize(at: diskCacheURL)
            await MainActor.run { [weak self] in
                self?.diskCacheSize = size
            }
        }
    }

    // MARK: - Public API: Cache Read

    /// Get cached image for URL, returns nil if not cached.
    /// Checks memory cache first, then disk cache (promoting to memory on hit).
    func cachedImage(for urlString: String) -> UIImage? {
        let key = cacheKey(for: urlString)

        // L1: Memory cache
        if let entry = memoryCache.object(forKey: key as NSString) {
            // Return even if "expired" in memory - the caller gets a fast result.
            // Background refresh can be triggered separately if needed.
            return entry.image
        }

        // L2: Disk cache
        if let image = loadFromDisk(key: key) {
            // Promote to memory cache
            let cost = estimateCost(for: image)
            let entry = CacheEntry(image: image)
            memoryCache.setObject(entry, forKey: key as NSString, cost: cost)
            return image
        }

        return nil
    }

    /// Check if an image is available in any cache level (without loading it)
    func hasCachedImage(for urlString: String) -> Bool {
        let key = cacheKey(for: urlString)

        if memoryCache.object(forKey: key as NSString) != nil {
            return true
        }

        let path = diskPath(for: key)
        return FileManager.default.fileExists(atPath: path.path)
    }

    // MARK: - Public API: Cache Write / Load

    /// Load image from URL with two-level caching.
    /// Returns cached version if available, otherwise downloads and caches.
    func loadImage(from urlString: String) async -> UIImage? {
        let key = cacheKey(for: urlString)

        // Check memory cache
        if let entry = memoryCache.object(forKey: key as NSString) {
            return entry.image
        }

        // Check disk cache
        if let diskCached = loadFromDisk(key: key) {
            let cost = estimateCost(for: diskCached)
            let entry = CacheEntry(image: diskCached)
            memoryCache.setObject(entry, forKey: key as NSString, cost: cost)
            return diskCached
        }

        // Check if already downloading (deduplication)
        if let existingTask = activeTasks[key] {
            return await existingTask.value
        }

        // Download from network
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }

            // Save to memory cache
            let cost = data.count
            let entry = CacheEntry(image: image)
            memoryCache.setObject(entry, forKey: key as NSString, cost: cost)

            // Save to disk cache
            saveToDisk(data: data, key: key)

            return image
        }

        activeTasks[key] = task
        let result = await task.value
        activeTasks.removeValue(forKey: key)

        return result
    }

    // MARK: - Public API: Preloading

    /// Preload chain icons for all known chains.
    /// Call this once at app startup to ensure chain icons are immediately available.
    func preloadChainIcons() {
        guard !chainIconsPreloaded else { return }

        let urls = CryptoIconProvider.allChainIconURLs
        Task {
            await withTaskGroup(of: Void.self) { group in
                for urlString in urls {
                    group.addTask { [weak self] in
                        _ = await self?.loadImage(from: urlString)
                    }
                }
            }
            chainIconsPreloaded = true
        }
    }

    /// Preload token icons for a list of tokens.
    /// Typically called after the user's token list is loaded.
    /// Only preloads the first `limit` tokens to avoid excessive network usage.
    ///
    /// - Parameters:
    ///   - tokens: Array of (logoURL, symbol, address) tuples
    ///   - limit: Maximum number of tokens to preload (default: 20)
    func preloadTokenIcons(
        tokens: [(logoURL: String?, symbol: String, address: String?)],
        limit: Int = 20
    ) {
        let tokensToPreload = Array(tokens.prefix(limit))

        Task {
            await withTaskGroup(of: Void.self) { group in
                for token in tokensToPreload {
                    guard let urlString = CryptoIconProvider.bestIconURL(
                        logoURL: token.logoURL,
                        symbol: token.symbol,
                        address: token.address
                    ) else { continue }

                    // Skip if already cached
                    if hasCachedImage(for: urlString) { continue }

                    group.addTask { [weak self] in
                        _ = await self?.loadImage(from: urlString)
                    }
                }
            }
        }
    }

    // MARK: - Public API: Cache Management

    /// Clear all caches (memory + disk)
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        diskCacheSize = 0
        chainIconsPreloaded = false
    }

    /// Clear memory cache only (called on memory warning)
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    /// Manually trigger cleanup of expired disk cache files
    func cleanupDiskCache() {
        Task.detached(priority: .background) { [diskCacheURL] in
            Self.cleanupExpiredFiles(at: diskCacheURL, ttl: Self.diskCacheTTL)
            let newSize = Self.calculateDiskCacheSize(at: diskCacheURL)
            await MainActor.run { [weak self] in
                self?.diskCacheSize = newSize
            }
        }
    }

    // MARK: - Disk Cache: Key & Path

    private func cacheKey(for urlString: String) -> String {
        let data = Data(urlString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func diskPath(for key: String) -> URL {
        return diskCacheURL.appendingPathComponent(key)
    }

    // MARK: - Disk Cache: Read

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)

        // Check if file exists and is not expired
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let modDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        // Check TTL - if file is older than 7 days, treat as miss (but don't delete here)
        if Date().timeIntervalSince(modDate) > Self.diskCacheTTL {
            return nil
        }

        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Disk Cache: Write

    private func saveToDisk(data: Data, key: String) {
        let path = diskPath(for: key)
        try? data.write(to: path)
        diskCacheSize += data.count

        // Evict old files if over limit
        if diskCacheSize > Self.maxDiskCacheSize {
            Task.detached(priority: .background) { [weak self, diskCacheURL] in
                Self.evictOldFiles(at: diskCacheURL, targetSize: Self.targetDiskCacheSize)
                let newSize = Self.calculateDiskCacheSize(at: diskCacheURL)
                await MainActor.run { [weak self] in
                    self?.diskCacheSize = newSize
                }
            }
        }
    }

    // MARK: - Disk Cache: Maintenance (nonisolated, runs on background threads)

    /// Calculate total size of all files in the cache directory
    private static nonisolated func calculateDiskCacheSize(at url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var totalSize = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Delete files that have exceeded the TTL
    private static nonisolated func cleanupExpiredFiles(at cacheURL: URL, ttl: TimeInterval) {
        guard let enumerator = FileManager.default.enumerator(
            at: cacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-ttl)

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate < cutoff {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// Evict oldest-accessed files until total size is under the target
    private static nonisolated func evictOldFiles(at cacheURL: URL, targetSize: Int) {
        guard let enumerator = FileManager.default.enumerator(
            at: cacheURL,
            includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey]
        ) else { return }

        struct CacheFile {
            let url: URL
            let accessDate: Date
            let size: Int
        }

        var files: [CacheFile] = []
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey]) {
                files.append(CacheFile(
                    url: fileURL,
                    accessDate: values.contentAccessDate ?? Date.distantPast,
                    size: values.fileSize ?? 0
                ))
            }
        }

        // Sort by access date (oldest first)
        files.sort { $0.accessDate < $1.accessDate }

        var totalSize = files.reduce(0) { $0 + $1.size }

        // Delete oldest files until under target
        for file in files {
            guard totalSize > targetSize else { break }
            try? FileManager.default.removeItem(at: file.url)
            totalSize -= file.size
        }
    }

    // MARK: - Helpers

    /// Estimate memory cost for an image (bytes)
    private func estimateCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

// MARK: - CachedAsyncImage

/// SwiftUI view that loads an image from a URL with automatic two-level caching.
/// Displays a configurable placeholder while loading or on failure.
///
/// Usage:
/// ```swift
/// CachedAsyncImage(url: "https://example.com/icon.png", placeholder: "photo", size: 40)
/// ```
struct CachedAsyncImage: View {
    let url: String?
    let placeholder: String  // SF Symbol name
    let size: CGFloat

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        Group {
            if let image = loadedImage {
                // Successfully loaded image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                // Loading state
                placeholderView
                    .overlay(
                        ProgressView()
                            .scaleEffect(size > 32 ? 0.6 : 0.4)
                    )
            } else if didFail {
                // Failed state - show placeholder
                placeholderView
            } else {
                // Initial state - trigger load
                placeholderView
                    .task { await loadImage() }
            }
        }
    }

    private var placeholderView: some View {
        Image(systemName: placeholder)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.5, height: size * 0.5)
            .foregroundColor(.gray.opacity(0.5))
            .frame(width: size, height: size)
            .background(Color.gray.opacity(0.1))
            .clipShape(Circle())
    }

    private func loadImage() async {
        guard let urlString = url, !urlString.isEmpty else {
            didFail = true
            return
        }

        isLoading = true

        // 1. Check memory/disk cache
        if let cached = ImageCacheManager.shared.cachedImage(for: urlString) {
            loadedImage = cached
            isLoading = false
            return
        }

        // 2. Network load + cache write
        if let image = await ImageCacheManager.shared.loadImage(from: urlString) {
            loadedImage = image
        } else {
            // 3. Failed - show placeholder
            didFail = true
        }

        isLoading = false
    }
}

// MARK: - TokenIconView

/// Convenience view for displaying token icons with automatic fallback chain:
/// 1. Cached image (memory or disk)
/// 2. Network download (with caching)
/// 3. Built-in mapping table lookup
/// 4. Initial letter avatar (colored circle with first letter of symbol)
///
/// Optionally displays a small chain icon badge in the bottom-right corner.
///
/// Usage:
/// ```swift
/// TokenIconView(logoUrl: token.logoUrl, symbol: "ETH", chainId: "1", size: 40)
/// ```
struct TokenIconView: View {
    let logoUrl: String?
    let symbol: String
    let chainId: String?   // If provided, shows a chain icon badge at bottom-right
    let address: String?   // Contract address for CDN fallback
    let size: CGFloat

    init(
        logoUrl: String?,
        symbol: String,
        chainId: String? = nil,
        address: String? = nil,
        size: CGFloat = 40
    ) {
        self.logoUrl = logoUrl
        self.symbol = symbol
        self.chainId = chainId
        self.address = address
        self.size = size
    }

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main token icon
            mainIcon
                .frame(width: size, height: size)

            // Chain badge (bottom-right corner)
            if let chainId = chainId {
                ChainIconView(chainId: chainId, size: size * 0.4)
                    .offset(x: size * 0.08, y: size * 0.08)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var mainIcon: some View {
        if let image = loadedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(Circle())
        } else if didFail || resolvedURL == nil {
            initialLetterAvatar
        } else {
            initialLetterAvatar
                .task { await loadTokenIcon() }
        }
    }

    /// The resolved URL using CryptoIconProvider's priority strategy
    private var resolvedURL: String? {
        return CryptoIconProvider.bestIconURL(
            logoURL: logoUrl,
            symbol: symbol,
            address: address,
            size: iconSize
        )
    }

    private var iconSize: CryptoIconProvider.IconSize {
        if size <= 16 { return .small }
        if size <= 32 { return .medium }
        if size <= 64 { return .large }
        return .xlarge
    }

    private func loadTokenIcon() async {
        guard let urlString = resolvedURL else {
            didFail = true
            return
        }

        isLoading = true

        // Check cache
        if let cached = ImageCacheManager.shared.cachedImage(for: urlString) {
            loadedImage = cached
            isLoading = false
            return
        }

        // Download
        if let image = await ImageCacheManager.shared.loadImage(from: urlString) {
            loadedImage = image
        } else {
            didFail = true
        }

        isLoading = false
    }

    /// Initial letter avatar: colored circle with the first letter of the token symbol.
    /// Color is deterministic based on the symbol hash (same token always gets the same color).
    private var initialLetterAvatar: some View {
        let color = CryptoIconProvider.symbolColor(for: symbol)
        let letter = String(symbol.prefix(1)).uppercased()

        return Circle()
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            )
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - ChainIconView

/// Convenience view for displaying chain icons with built-in mapping + caching.
/// Falls back to an SF Symbol if no image can be loaded.
///
/// Usage:
/// ```swift
/// ChainIconView(chainId: "1", size: 20)
/// ```
struct ChainIconView: View {
    let chainId: String
    let logoUrl: String?  // API-provided chain logo URL (optional override)
    let size: CGFloat

    init(chainId: String, logoUrl: String? = nil, size: CGFloat = 20) {
        self.chainId = chainId
        self.logoUrl = logoUrl
        self.size = size
    }

    @State private var loadedImage: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: size > 16 ? 1.5 : 1)
                    )
            } else if didFail {
                sfSymbolFallback
            } else {
                sfSymbolFallback
                    .task { await loadChainIcon() }
            }
        }
    }

    /// SF Symbol fallback for the chain
    private var sfSymbolFallback: some View {
        let symbolName = CryptoIconProvider.chainSFSymbol(for: chainId)
        return Image(systemName: symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.6, height: size * 0.6)
            .foregroundColor(.secondary)
            .frame(width: size, height: size)
            .background(Color(.systemBackground))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: size > 16 ? 1.5 : 1)
            )
    }

    private func loadChainIcon() async {
        guard let urlString = CryptoIconProvider.chainIconURL(
            chainId: chainId,
            logoURL: logoUrl
        ) else {
            didFail = true
            return
        }

        // Check cache
        if let cached = ImageCacheManager.shared.cachedImage(for: urlString) {
            loadedImage = cached
            return
        }

        // Download
        if let image = await ImageCacheManager.shared.loadImage(from: urlString) {
            loadedImage = image
        } else {
            didFail = true
        }
    }
}

// MARK: - CryptoIconView (Legacy Compatibility)

/// Legacy compatibility wrapper around TokenIconView.
/// Existing code uses `CryptoIconView(symbol:logoURL:size:)`.
/// This maps to the new TokenIconView with the same behavior.
struct CryptoIconView: View {
    let symbol: String
    let logoURL: String?
    var size: CGFloat = 40

    var body: some View {
        TokenIconView(
            logoUrl: logoURL,
            symbol: symbol,
            size: size
        )
    }
}

// MARK: - Legacy CachedAsyncImage (Generic Version)

/// Generic version of CachedAsyncImage that accepts custom content and placeholder builders.
/// Kept for backward compatibility with existing code that uses the builder pattern.
struct CachedAsyncImageGeneric<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .task { await loadImage() }
            }
        }
    }

    private func loadImage() async {
        guard let url = url else { return }
        isLoading = true

        let urlString = url.absoluteString

        // Check cache first
        if let cached = ImageCacheManager.shared.cachedImage(for: urlString) {
            loadedImage = cached
            isLoading = false
            return
        }

        // Download with caching
        loadedImage = await ImageCacheManager.shared.loadImage(from: urlString)
        isLoading = false
    }
}
