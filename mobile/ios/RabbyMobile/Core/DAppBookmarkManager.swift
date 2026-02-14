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
        DAppBookmark(id: "uniswap", url: "https://app.uniswap.org", title: "Uniswap", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "aave", url: "https://app.aave.com", title: "Aave", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "opensea", url: "https://opensea.io", title: "OpenSea", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "1inch", url: "https://app.1inch.io", title: "1inch", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "curve", url: "https://curve.fi", title: "Curve", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "lido", url: "https://lido.fi", title: "Lido", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "gmx", url: "https://gmx.io", title: "GMX", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "pancakeswap", url: "https://pancakeswap.finance", title: "PancakeSwap", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "sushiswap", url: "https://www.sushi.com", title: "SushiSwap", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
        DAppBookmark(id: "compound", url: "https://app.compound.finance", title: "Compound", iconURL: "", addedAt: Date(), lastVisitedAt: Date(), isFavorite: false),
    ]
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
