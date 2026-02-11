import SwiftUI

/// Chain balance distribution view showing per-chain USD values
/// Corresponds to: src/ui/views/Dashboard/components/BalanceView/ChainList
struct ChainBalanceView: View {
    let address: String
    var onChainSelected: ((String) -> Void)?
    
    @State private var chainBalances: [OpenAPIService.ChainBalanceInfo] = []
    @State private var isLoading = true
    @State private var isExpanded = false
    
    private var totalValue: Double {
        chainBalances.reduce(0) { $0 + $1.usd_value }
    }
    
    private var displayedChains: [OpenAPIService.ChainBalanceInfo] {
        let sorted = chainBalances.sorted { $0.usd_value > $1.usd_value }
        if isExpanded { return sorted }
        return Array(sorted.prefix(5))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Chain Distribution")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                if totalValue > 0 {
                    Text(formatUSD(totalValue))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if chainBalances.isEmpty {
                Text("No chain data")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                // Distribution bar
                distributionBar
                
                // Chain list
                VStack(spacing: 0) {
                    ForEach(displayedChains, id: \.chain_id) { chain in
                        chainRow(chain)
                        if chain.chain_id != displayedChains.last?.chain_id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                
                // Show more / less
                if chainBalances.count > 5 {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        HStack {
                            Text(isExpanded ? "Show Less" : "Show All \(chainBalances.count) Chains")
                                .font(.caption)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .task { await loadData() }
    }
    
    // MARK: - Distribution Bar
    
    private var distributionBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(displayedChains, id: \.chain_id) { chain in
                    let ratio = totalValue > 0 ? chain.usd_value / totalValue : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(chainColor(chain.chain_id))
                        .frame(width: max(2, geometry.size.width * CGFloat(ratio)))
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
    }
    
    // MARK: - Chain Row
    
    private func chainRow(_ chain: OpenAPIService.ChainBalanceInfo) -> some View {
        Button(action: { onChainSelected?(chain.chain_id) }) {
            HStack(spacing: 10) {
                // Chain icon
                if let logoUrl = chain.logo_url, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().frame(width: 28, height: 28).clipShape(Circle())
                    } placeholder: {
                        chainPlaceholder(chain)
                    }
                } else {
                    chainPlaceholder(chain)
                }
                
                // Chain name
                VStack(alignment: .leading, spacing: 1) {
                    Text(chain.chain_name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if let count = chain.token_count, count > 0 {
                        Text("\(count) tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Value + percentage
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatUSD(chain.usd_value))
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    let percent = totalValue > 0 ? (chain.usd_value / totalValue) * 100 : 0
                    Text(String(format: "%.1f%%", percent))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func chainPlaceholder(_ chain: OpenAPIService.ChainBalanceInfo) -> some View {
        Circle()
            .fill(chainColor(chain.chain_id).opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(chain.chain_name.prefix(2)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(chainColor(chain.chain_id))
            )
    }
    
    private func chainColor(_ chainId: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .red, .pink, .yellow, .cyan, .mint, .indigo]
        let hash = abs(chainId.hashValue)
        return colors[hash % colors.count]
    }
    
    private func loadData() async {
        isLoading = true
        do {
            chainBalances = try await OpenAPIService.shared.getChainBalances(address: address)
        } catch {
            chainBalances = []
        }
        isLoading = false
    }
    
    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
