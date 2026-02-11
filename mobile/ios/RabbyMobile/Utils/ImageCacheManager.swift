import SwiftUI
import CryptoKit

/// Image cache manager with memory (NSCache) + disk (Caches directory) two-level caching
/// Solves the problem of AsyncImage re-downloading token icons on every view appearance
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    /// Memory cache (L1) - fast access, auto-evicted by system under memory pressure
    private let memoryCache = NSCache<NSString, UIImage>()
    
    /// Disk cache directory
    private let diskCacheURL: URL
    
    /// Track disk cache size
    private var diskCacheSize: Int = 0
    private let maxDiskCacheSize = 50 * 1024 * 1024 // 50MB
    
    /// Active download tasks to avoid duplicate requests
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    
    private init() {
        // Set up memory cache limits
        memoryCache.countLimit = 500  // max 500 images
        memoryCache.totalCostLimit = 30 * 1024 * 1024  // 30MB
        
        // Set up disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Calculate current disk cache size in background
        Task.detached(priority: .background) { [diskCacheURL] in
            let size = Self.calculateDiskCacheSize(at: diskCacheURL)
            await MainActor.run { [weak self] in
                self?.diskCacheSize = size
            }
        }
    }
    
    // MARK: - Public API
    
    /// Get cached image for URL, returns nil if not cached
    func cachedImage(for urlString: String) -> UIImage? {
        let key = cacheKey(for: urlString)
        
        // L1: Memory cache
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }
        
        // L2: Disk cache
        if let image = loadFromDisk(key: key) {
            // Promote to memory cache
            let cost = image.pngData()?.count ?? 0
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }
        
        return nil
    }
    
    /// Load image from URL with caching
    func loadImage(from urlString: String) async -> UIImage? {
        let key = cacheKey(for: urlString)
        
        // Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // Check disk cache
        if let diskCached = loadFromDisk(key: key) {
            let cost = diskCached.pngData()?.count ?? 0
            memoryCache.setObject(diskCached, forKey: key as NSString, cost: cost)
            return diskCached
        }
        
        // Check if already downloading
        if let existingTask = activeTasks[key] {
            return await existingTask.value
        }
        
        // Download
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
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            
            // Save to disk cache (background)
            saveToDisk(data: data, key: key)
            
            return image
        }
        
        activeTasks[key] = task
        let result = await task.value
        activeTasks.removeValue(forKey: key)
        
        return result
    }
    
    /// Clear all caches
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        diskCacheSize = 0
    }
    
    /// Clear memory cache only (called on memory warning)
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    // MARK: - Disk Cache
    
    private func cacheKey(for urlString: String) -> String {
        let data = Data(urlString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func diskPath(for key: String) -> URL {
        return diskCacheURL.appendingPathComponent(key)
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }
    
    private func saveToDisk(data: Data, key: String) {
        let path = diskPath(for: key)
        try? data.write(to: path)
        diskCacheSize += data.count
        
        // Evict old files if over limit
        if diskCacheSize > maxDiskCacheSize {
            Task.detached(priority: .background) { [weak self, diskCacheURL] in
                Self.evictOldFiles(at: diskCacheURL, targetSize: 30 * 1024 * 1024)
                let newSize = Self.calculateDiskCacheSize(at: diskCacheURL)
                await MainActor.run {
                    self?.diskCacheSize = newSize
                }
            }
        }
    }
    
    private static nonisolated func calculateDiskCacheSize(at url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
            }
        }
        return totalSize
    }
    
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
}

// MARK: - Cached AsyncImage View

/// Drop-in replacement for AsyncImage with automatic two-level caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
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
