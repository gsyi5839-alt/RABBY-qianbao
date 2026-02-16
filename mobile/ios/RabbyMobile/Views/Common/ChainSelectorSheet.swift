import SwiftUI

/// Reusable chain selector sheet for Send / Swap / Bridge and other views.
/// Displays the full chain list from ChainManager with search, pinned popular chains,
/// native-token symbol, optional balance display, and a checkmark for the current selection.
struct ChainSelectorSheet: View {
    // MARK: - Public interface

    /// The currently-selected chain. The sheet updates this binding on tap.
    @Binding var selectedChain: Chain?

    /// Optional per-chain native balance map (chainId -> formatted balance string).
    /// When provided the balance is shown on the right side of each row.
    var balances: [Int: String] = [:]

    /// Callback fired *after* the binding is written so the caller can perform
    /// side-effects (reload tokens, clear selection, re-estimate gas, etc.).
    var onChainSelected: ((Chain) -> Void)?

    // MARK: - Environment & state

    @Environment(\.dismiss) private var dismiss
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var prefManager = PreferenceManager.shared  // ← 新增

    @State private var searchText = ""

    // IDs of the four "pinned" popular chains (Ethereum, BNB Chain, Polygon, Arbitrum One).
    private let pinnedChainIds: [Int] = [1, 56, 137, 42161]

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Show Testnet Toggle (if there are testnets)
                if !chainManager.testnetChains.isEmpty {
                    showTestnetToggle
                }

                // Chain list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Pinned popular chains (only when search is empty)
                        if searchText.isEmpty {
                            pinnedSection
                            divider
                        }

                        // All chains (filtered when searching)
                        allChainsSection
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("Select Chain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
        .modifier(SheetPresentationModifier(detents: [.medium, .large], showDragIndicator: true))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(L("Search by name"), text: $searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Show Testnet Toggle

    private var showTestnetToggle: some View {
        HStack {
            Text(L("Show Testnets"))
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { prefManager.showTestnet },
                set: { prefManager.setIsShowTestnet($0) }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Pinned section

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Popular"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ForEach(pinnedChains, id: \.id) { chain in
                chainRow(chain)
            }
        }
    }

    // MARK: - All chains section

    private var allChainsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if searchText.isEmpty {
                Text(L("All Chains"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            let chains = filteredChains
            if chains.isEmpty {
                emptyState
            } else {
                ForEach(chains, id: \.id) { chain in
                    chainRow(chain)
                }
            }
        }
    }

    // MARK: - Single chain row (52pt height)

    private func chainRow(_ chain: Chain) -> some View {
        Button(action: {
            selectedChain = chain
            onChainSelected?(chain)
            dismiss()
        }) {
            HStack(spacing: 12) {
                // Chain icon (AsyncImage with fallback)
                chainIcon(chain)

                // Name + native token symbol
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(chain.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Optional balance
                if let balance = balances[chain.id] {
                    Text(balance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Checkmark for selected chain
                if selectedChain?.id == chain.id {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
        }
    }

    // MARK: - Chain icon helper

    private func chainIcon(_ chain: Chain) -> some View {
        Group {
            if let url = URL(string: chain.logo), chain.logo.hasPrefix("http") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .empty:
                        // Loading state — show placeholder while fetching
                        chainIconFallback(chain)
                            .overlay(ProgressView().scaleEffect(0.5))
                    case .failure:
                        chainIconFallback(chain)
                    @unknown default:
                        chainIconFallback(chain)
                    }
                }
            } else {
                chainIconFallback(chain)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    private func chainIconFallback(_ chain: Chain) -> some View {
        Circle()
            .fill(Color.purple.opacity(0.15))
            .overlay(
                Text(String(chain.symbol.prefix(2)))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.gray)
            Text(L("No chains found"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Divider

    private var divider: some View {
        Divider().padding(.horizontal, 16).padding(.vertical, 4)
    }

    // MARK: - Computed chain lists

    /// Popular/pinned chains in the predefined order.
    private var pinnedChains: [Chain] {
        pinnedChainIds.compactMap { id in
            chainManager.allChains.first(where: { $0.id == id })
        }
        .filter { chain in
            // ✅ 过滤测试网（根据设置）
            prefManager.showTestnet || !chain.isTestnet
        }
    }

    /// All chains, filtered by the search text. When not searching the pinned
    /// chains are excluded to avoid showing duplicates.
    private var filteredChains: [Chain] {
        var all = chainManager.allChains

        // ✅ 过滤测试网（根据设置）
        if !prefManager.showTestnet {
            all = all.filter { !$0.isTestnet }
        }

        if searchText.isEmpty {
            return all.filter { chain in
                !pinnedChainIds.contains(chain.id)
            }
        }

        return all.filter { chain in
            chain.name.localizedCaseInsensitiveContains(searchText) ||
            chain.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Preview

struct ChainSelectorSheet_Previews: PreviewProvider {
    static var previews: some View {
        ChainSelectorSheet(selectedChain: .constant(Chain.ethereum))
    }
}
