import SwiftUI

/// DApp Search/Browse home page with bookmarks and recent history
struct DAppSearchView: View {
    @StateObject private var bookmarkManager = DAppBookmarkManager.shared
    @State private var searchText = ""
    @State private var openURL: String?

    var onOpenDApp: ((String) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Search bar
                searchBar

                // Favorites grid
                if !bookmarkManager.bookmarks.filter({ $0.isFavorite }).isEmpty {
                    favoritesSection
                }

                // Recent DApps
                if !bookmarkManager.recentDApps.isEmpty {
                    recentSection
                }

                // Popular DApps
                popularSection

                // Search results
                if !searchText.isEmpty {
                    searchResultsSection
                }
            }
            .padding()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(L("Search DApps or enter URL"), text: $searchText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onSubmit { handleSearchSubmit() }
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Favorites")).font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 12) {
                ForEach(bookmarkManager.bookmarks.filter { $0.isFavorite }) { dapp in
                    Button(action: { onOpenDApp?(dapp.url) }) {
                        VStack(spacing: 6) {
                            dappIcon(title: dapp.title, iconURL: dapp.iconURL, size: 40, cornerRadius: 10)
                            Text(dapp.title)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Recent")).font(.headline)
                Spacer()
                Button(L("Clear")) { bookmarkManager.clearRecents() }
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            ForEach(bookmarkManager.recentDApps.prefix(5)) { dapp in
                Button(action: { onOpenDApp?(dapp.url) }) {
                    HStack(spacing: 12) {
                        dappIcon(title: dapp.title, iconURL: dapp.iconURL, size: 32, cornerRadius: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dapp.title).font(.subheadline).foregroundColor(.primary)
                            Text(dapp.url).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        }

                        Spacer()

                        Text(dapp.lastVisitedAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Popular

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Popular DApps")).font(.headline)

            ForEach(DAppBookmarkManager.popularDApps) { dapp in
                Button(action: { onOpenDApp?(dapp.url) }) {
                    HStack(spacing: 12) {
                        dappIcon(title: dapp.title, iconURL: dapp.iconURL, size: 32, cornerRadius: 8)

                        Text(dapp.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // URL detection
            if looksLikeURL(searchText) {
                let url = normalizeURL(searchText)
                Button(action: { onOpenDApp?(url) }) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Go to \(url)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            // Bookmark search results
            let results = bookmarkManager.searchBookmarks(query: searchText)
            if !results.isEmpty {
                ForEach(results) { dapp in
                    Button(action: { onOpenDApp?(dapp.url) }) {
                        HStack(spacing: 12) {
                            dappIcon(title: dapp.title, iconURL: dapp.iconURL, size: 28, cornerRadius: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dapp.title).font(.subheadline).foregroundColor(.primary)
                                Text(dapp.url).font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func handleSearchSubmit() {
        if looksLikeURL(searchText) {
            onOpenDApp?(normalizeURL(searchText))
        }
    }

    private func looksLikeURL(_ text: String) -> Bool {
        text.contains(".") && !text.contains(" ")
    }

    private func normalizeURL(_ text: String) -> String {
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return text }
        return "https://\(text)"
    }

    @ViewBuilder
    private func dappIcon(title: String, iconURL: String, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let url = URL(string: iconURL), !iconURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().frame(width: size, height: size).cornerRadius(cornerRadius)
                default:
                    iconFallback(title: title, size: size, cornerRadius: cornerRadius)
                }
            }
        } else {
            iconFallback(title: title, size: size, cornerRadius: cornerRadius)
        }
    }

    private func iconFallback(title: String, size: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray4))
            .frame(width: size, height: size)
            .overlay(
                Text(String(title.prefix(1)).uppercased())
                    .font(.caption)
                    .foregroundColor(.white)
            )
    }
}
