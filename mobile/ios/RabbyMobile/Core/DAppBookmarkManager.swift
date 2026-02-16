import Foundation
import Combine

/// DApp Bookmark/Favorites manager with persistence
/// Corresponds to: src/background/service/bookmark
@MainActor
class DAppBookmarkManager: ObservableObject {
    static let shared = DAppBookmarkManager()

    @Published var bookmarks: [DAppBookmark] = []
    @Published var recentDApps: [DAppBookmark] = []

    private let bookmarksKey = "dappBookmarks"
    private let recentsKey = "dappRecents"
    private let maxRecents = 20

    private init() {
        loadFromStorage()
    }

    // MARK: - Bookmark Operations

    func addBookmark(url: String, title: String, iconURL: String) {
        guard !bookmarks.contains(where: { $0.url == url }) else { return }
        let bookmark = DAppBookmark(
            id: UUID().uuidString,
            url: url,
            title: title,
            iconURL: iconURL,
            addedAt: Date(),
            lastVisitedAt: Date(),
            isFavorite: true
        )
        bookmarks.insert(bookmark, at: 0)
        saveToStorage()
    }

    func removeBookmark(id: String) {
        bookmarks.removeAll { $0.id == id }
        saveToStorage()
    }

    func toggleFavorite(id: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == id }) {
            bookmarks[index].isFavorite.toggle()
            saveToStorage()
        }
    }

    func isBookmarked(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    // MARK: - Recent Operations

    func addToRecent(url: String, title: String, iconURL: String) {
        recentDApps.removeAll { $0.url == url }
        let recent = DAppBookmark(
            id: UUID().uuidString,
            url: url,
            title: title,
            iconURL: iconURL,
            addedAt: Date(),
            lastVisitedAt: Date(),
            isFavorite: false
        )
        recentDApps.insert(recent, at: 0)
        if recentDApps.count > maxRecents {
            recentDApps = Array(recentDApps.prefix(maxRecents))
        }
        saveToStorage()
    }

    func clearRecents() {
        recentDApps.removeAll()
        saveToStorage()
    }

    // MARK: - Search

    func searchBookmarks(query: String) -> [DAppBookmark] {
        let allDApps = bookmarks + recentDApps
        if query.isEmpty { return allDApps }
        return allDApps.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Persistence

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
        if let data = try? JSONEncoder().encode(recentDApps) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let items = try? JSONDecoder().decode([DAppBookmark].self, from: data) {
            bookmarks = items
        }
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let items = try? JSONDecoder().decode([DAppBookmark].self, from: data) {
            recentDApps = items
        }
    }

    // MARK: - Popular DApps

    static let popularDApps: [DAppBookmark] = [
        DAppBookmark(id: "uniswap", url: "https://app.uniswap.org", title: "Uniswap", iconURL: faviconURL(for: "https://app.uniswap.org"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "aave", url: "https://app.aave.com", title: "Aave", iconURL: faviconURL(for: "https://app.aave.com"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "opensea", url: "https://opensea.io", title: "OpenSea", iconURL: faviconURL(for: "https://opensea.io"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "1inch", url: "https://app.1inch.io", title: "1inch", iconURL: faviconURL(for: "https://app.1inch.io"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "curve", url: "https://curve.fi", title: "Curve", iconURL: faviconURL(for: "https://curve.fi"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "lido", url: "https://lido.fi", title: "Lido", iconURL: faviconURL(for: "https://lido.fi"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "gmx", url: "https://gmx.io", title: "GMX", iconURL: faviconURL(for: "https://gmx.io"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "pancakeswap", url: "https://pancakeswap.finance", title: "PancakeSwap", iconURL: faviconURL(for: "https://pancakeswap.finance"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "sushiswap", url: "https://www.sushi.com", title: "SushiSwap", iconURL: faviconURL(for: "https://www.sushi.com"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "compound", url: "https://app.compound.finance", title: "Compound", iconURL: faviconURL(for: "https://app.compound.finance"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "polymarket", url: "https://polymarket.com", title: "Polymarket", iconURL: faviconURL(for: "https://polymarket.com"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "probable", url: "https://probable.markets", title: "Probable", iconURL: faviconURL(for: "https://probable.markets"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "spark", url: "https://app.spark.fi/my-portfolio", title: "Spark", iconURL: faviconURL(for: "https://app.spark.fi/my-portfolio"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "venus", url: "https://venus.io", title: "Venus", iconURL: faviconURL(for: "https://venus.io"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "hyperliquid", url: "https://app.hyperliquid.xyz", title: "Hyperliquid", iconURL: faviconURL(for: "https://app.hyperliquid.xyz"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "lighter", url: "https://app.lighter.xyz/trade/LIT_USDC", title: "Lighter", iconURL: faviconURL(for: "https://app.lighter.xyz/trade/LIT_USDC"), addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
    ]

    static func faviconURL(for url: String) -> String {
        guard let host = URL(string: url)?.host, !host.isEmpty else { return "" }
        return "https://icons.duckduckgo.com/ip3/\(host).ico"
    }
}

// MARK: - DApp Bookmark Model

struct DAppBookmark: Identifiable, Codable {
    let id: String
    let url: String
    let title: String
    let iconURL: String
    let addedAt: Date
    var lastVisitedAt: Date
    var isFavorite: Bool
}
