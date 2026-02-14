import SwiftUI

/// Token Selector Sheet - Presented as a .sheet for choosing swap tokens
/// Supports search (local + remote), recent tokens, and token list display
struct TokenSelectorSheet: View {
    let excludeToken: SwapManager.Token?
    let onSelect: (SwapManager.Token) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var swapManager = SwapManager.shared

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var remoteResults: [SwapManager.Token] = []
    @State private var hasSearchedRemote = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Recent tokens section
                        if searchText.isEmpty {
                            recentTokensSection
                        }

                        // Token list
                        if isSearching {
                            loadingView
                        } else if filteredTokens.isEmpty {
                            emptyView
                        } else {
                            tokenListSection
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L("Select Token"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(L("Search name, symbol, or address"), text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: searchText) { newValue in
            hasSearchedRemote = false
            remoteResults = []
            if !newValue.isEmpty {
                performRemoteSearchIfNeeded(query: newValue)
            }
        }
    }

    // MARK: - Recent Tokens Section

    private var recentTokensSection: some View {
        let recentTokens = swapManager.getRecentTokens()
            .filter { token in
                if let exclude = excludeToken {
                    return token.id != exclude.id
                }
                return true
            }
            .prefix(5)

        return Group {
            if !recentTokens.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Recent"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(recentTokens), id: \.id) { token in
                                recentTokenItem(token: token)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }

    private func recentTokenItem(token: SwapManager.Token) -> some View {
        Button(action: {
            onSelect(token)
            dismiss()
        }) {
            VStack(spacing: 6) {
                tokenIcon(logoUrl: token.logo, chainServerId: token.chain, size: 40)

                Text(token.symbol)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Token List Section

    private var tokenListSection: some View {
        ForEach(filteredTokens, id: \.id) { token in
            VStack(spacing: 0) {
                tokenRow(token: token)

                Divider()
                    .padding(.leading, 64)
            }
        }
    }

    private func tokenRow(token: SwapManager.Token) -> some View {
        Button(action: {
            swapManager.addRecentToken(token)
            onSelect(token)
            dismiss()
        }) {
            HStack(spacing: 12) {
                // Token icon with chain badge
                tokenIcon(logoUrl: token.logo, chainServerId: token.chain, size: 36)

                // Token name and symbol
                VStack(alignment: .leading, spacing: 2) {
                    Text(token.symbol)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(token.chain.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Balance and USD value
                VStack(alignment: .trailing, spacing: 2) {
                    if let amount = token.amount, !amount.isEmpty, amount != "0" {
                        Text(formatBalance(amount))
                            .font(.body)
                            .foregroundColor(.primary)
                    } else {
                        Text(L("0"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if let price = token.price, price > 0 {
                        let amountValue = Double(token.amount ?? "0") ?? 0
                        let usdValue = price * amountValue
                        Text(formatUSD(usdValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Token Icon

    private func tokenIcon(logoUrl: String?, chainServerId: String, size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // Main token icon
            if let logoUrl = logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: size, height: size)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        tokenPlaceholder(size: size)
                    @unknown default:
                        tokenPlaceholder(size: size)
                    }
                }
            } else {
                tokenPlaceholder(size: size)
            }

            // Chain badge (corner icon)
            if let chain = chainManager.getChain(serverId: chainServerId),
               let chainLogoURL = URL(string: chain.logo) {
                AsyncImage(url: chainLogoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size * 0.4, height: size * 0.4)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1.5)
                            )
                    default:
                        EmptyView()
                    }
                }
                .offset(x: 2, y: 2)
            }
        }
    }

    private func tokenPlaceholder(size: CGFloat) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: size, height: size)
            .overlay {
                Text(L("?"))
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.secondary)
            }
    }

    // MARK: - Loading and Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L("Searching..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(L("No tokens found"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data Logic

    /// Filtered tokens: local first, then remote results if available
    private var filteredTokens: [SwapManager.Token] {
        let allLocalTokens = buildLocalTokenList()

        // Exclude the already-selected token
        let excluded = allLocalTokens.filter { token in
            if let exclude = excludeToken {
                return token.id != exclude.id
            }
            return true
        }

        var results: [SwapManager.Token]

        if searchText.isEmpty {
            results = excluded
        } else {
            let query = searchText.lowercased()
            let localFiltered = excluded.filter { token in
                token.symbol.lowercased().contains(query) ||
                token.chain.lowercased().contains(query) ||
                token.address.lowercased().contains(query)
            }

            if !localFiltered.isEmpty {
                results = localFiltered
            } else {
                // Fall back to remote results
                results = remoteResults.filter { token in
                    if let exclude = excludeToken {
                        return token.id != exclude.id
                    }
                    return true
                }
            }
        }

        // Sort by USD value descending, then by symbol
        return results.sorted { lhs, rhs in
            let lhsValue = usdValue(for: lhs)
            let rhsValue = usdValue(for: rhs)
            if lhsValue != rhsValue {
                return lhsValue > rhsValue
            }
            return lhs.symbol < rhs.symbol
        }
    }

    /// Build a list of SwapManager.Token from TokenManager's cached data
    private func buildLocalTokenList() -> [SwapManager.Token] {
        let allTokenItems = tokenManager.tokens.values.flatMap { $0 }
        return allTokenItems.map { item in
            let balance = tokenManager.getCachedBalance(tokenId: item.id)
            let chain = chainManager.getChain(id: item.chainId)
            return SwapManager.Token(
                id: item.id,
                chain: chain?.serverId ?? String(item.chainId),
                symbol: item.symbol,
                decimals: item.decimals,
                address: item.address,
                logo: item.logoURL,
                amount: balance?.balanceFormatted,
                price: item.price
            )
        }
    }

    /// Remote search when local results are empty
    private func performRemoteSearchIfNeeded(query: String) {
        // Debounce: only search if query length >= 2
        guard query.count >= 2 else { return }

        // Avoid duplicate remote calls for the same search text
        let capturedQuery = query

        Task {
            // Small delay for debounce
            try? await Task.sleep(nanoseconds: 400_000_000)

            // Verify the search text hasn't changed
            guard searchText == capturedQuery else { return }

            // Check if local results exist; skip remote if they do
            let localMatches = buildLocalTokenList().filter { token in
                token.symbol.lowercased().contains(capturedQuery.lowercased()) ||
                token.address.lowercased().contains(capturedQuery.lowercased())
            }
            guard localMatches.isEmpty else { return }

            // Perform remote search
            isSearching = true
            defer { isSearching = false }

            do {
                let chainId = chainManager.selectedChain?.serverId ?? "eth"
                let results: [OpenAPIService.TokenInfo] = try await OpenAPIService.shared.get(
                    "/v1/token/search",
                    params: ["q": capturedQuery, "chain_id": chainId]
                )

                guard searchText == capturedQuery else { return }

                remoteResults = results.map { info in
                    SwapManager.Token(
                        id: info.id,
                        chain: info.chain,
                        symbol: info.symbol,
                        decimals: info.decimals,
                        address: info.id,
                        logo: info.logo_url,
                        amount: info.amount.map { String($0) },
                        price: info.price
                    )
                }
                hasSearchedRemote = true
            } catch {
                print("Token search failed: \(error.localizedDescription)")
                remoteResults = []
                hasSearchedRemote = true
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatBalance(_ amount: String) -> String {
        guard let value = Double(amount) else { return amount }
        if value == 0 { return "0" }
        if value < 0.0001 { return "<0.0001" }
        if value < 1 {
            return String(format: "%.4f", value)
        }
        if value < 1000 {
            return String(format: "%.2f", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? amount
    }

    private func formatUSD(_ value: Double) -> String {
        if value == 0 { return "$0.00" }
        if value < 0.01 { return "<$0.01" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private func usdValue(for token: SwapManager.Token) -> Double {
        let amount = Double(token.amount ?? "0") ?? 0
        let price = token.price ?? 0
        return amount * price
    }
}
