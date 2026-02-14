import SwiftUI

/// DeFi protocol positions view
/// Corresponds to: src/ui/views/CommonPopup/AssetList/ProtocolList.tsx + ProtocolTemplates/
struct ProtocolPositionView: View {
    let address: String
    
    @State private var portfolios: [OpenAPIService.PortfolioItem] = []
    @State private var isLoading = true
    @State private var expandedProtocols: Set<String> = []
    @State private var showSmallValues = false
    
    private var totalDeFiValue: Double {
        portfolios.reduce(0) { $0 + $1.net_usd_value }
    }
    
    private var visiblePortfolios: [OpenAPIService.PortfolioItem] {
        let sorted = portfolios.sorted { $0.net_usd_value > $1.net_usd_value }
        if showSmallValues { return sorted }
        return sorted.filter { $0.net_usd_value > 1.0 }
    }
    
    private var hiddenCount: Int {
        portfolios.count - visiblePortfolios.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("DeFi Positions"))
                        .font(.headline)
                    Text(formatUSD(totalDeFiValue))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            
            if isLoading && portfolios.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L("Loading DeFi positions..."))
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if portfolios.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "building.columns")
                        .foregroundColor(.gray)
                    Text(L("No DeFi positions"))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
            } else {
                // Protocol cards
                LazyVStack(spacing: 8) {
                    ForEach(visiblePortfolios, id: \.id) { protocol_ in
                        protocolCard(protocol_)
                    }
                    
                    // Show small values toggle
                    if hiddenCount > 0 {
                        Button(action: { withAnimation { showSmallValues.toggle() } }) {
                            HStack {
                                Text(showSmallValues ? "Hide small values" : "Show \(hiddenCount) more (< $1)")
                                    .font(.caption)
                                Image(systemName: showSmallValues ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .task { await loadPortfolios() }
    }
    
    // MARK: - Protocol Card
    
    private func protocolCard(_ portfolio: OpenAPIService.PortfolioItem) -> some View {
        let isExpanded = expandedProtocols.contains(portfolio.id)
        
        return VStack(spacing: 0) {
            // Protocol header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedProtocols.remove(portfolio.id)
                    } else {
                        expandedProtocols.insert(portfolio.id)
                    }
                }
            }) {
                HStack(spacing: 10) {
                    // Protocol icon
                    if let logoUrl = portfolio.logo_url, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().frame(width: 32, height: 32).clipShape(Circle())
                        } placeholder: {
                            protocolPlaceholder(portfolio)
                        }
                    } else {
                        protocolPlaceholder(portfolio)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(portfolio.name)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text(portfolio.chain.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(3)
                            
                            positionTypeBadges(portfolio)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatUSD(portfolio.net_usd_value))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if portfolio.debt_usd_value > 0 {
                            Text("Debt: \(formatUSD(portfolio.debt_usd_value))")
                                .font(.caption2).foregroundColor(.red)
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded position details
            if isExpanded {
                Divider().padding(.leading, 54)
                
                VStack(spacing: 0) {
                    ForEach(Array(portfolio.portfolio_item_list.enumerated()), id: \.offset) { index, position in
                        positionRow(position)
                        if index < portfolio.portfolio_item_list.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    // MARK: - Position Row
    
    private func positionRow(_ position: OpenAPIService.PortfolioPosition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Position name
            Text(position.name)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Supply tokens
            if let supplyTokens = position.detail?.supply_token_list, !supplyTokens.isEmpty {
                VStack(spacing: 4) {
                    ForEach(supplyTokens, id: \.id) { token in
                        tokenValueRow(token, label: "Supply", color: .green)
                    }
                }
            }
            
            // General token list
            if let tokens = position.detail?.token_list, !tokens.isEmpty {
                VStack(spacing: 4) {
                    ForEach(tokens, id: \.id) { token in
                        tokenValueRow(token, label: nil, color: .primary)
                    }
                }
            }
            
            // Borrow tokens
            if let borrowTokens = position.detail?.borrow_token_list, !borrowTokens.isEmpty {
                VStack(spacing: 4) {
                    ForEach(borrowTokens, id: \.id) { token in
                        tokenValueRow(token, label: "Borrow", color: .red)
                    }
                }
            }
            
            // Reward tokens
            if let rewardTokens = position.detail?.reward_token_list, !rewardTokens.isEmpty {
                VStack(spacing: 4) {
                    ForEach(rewardTokens, id: \.id) { token in
                        tokenValueRow(token, label: "Reward", color: .orange)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func tokenValueRow(_ token: OpenAPIService.PortfolioToken, label: String?, color: Color) -> some View {
        HStack(spacing: 8) {
            if let logoUrl = token.logo_url, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().frame(width: 20, height: 20).clipShape(Circle())
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2)).frame(width: 20, height: 20)
                }
            } else {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 20, height: 20)
                    .overlay(Text(String(token.symbol.prefix(1))).font(.system(size: 8)).foregroundColor(color))
            }
            
            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(color)
                    .frame(width: 42, alignment: .leading)
            }
            
            Text(token.symbol)
                .font(.caption).fontWeight(.medium)
            
            Spacer()
            
            Text(formatAmount(token.amount))
                .font(.caption)
                .foregroundColor(.secondary)
            
            let value = token.amount * (token.price ?? 0)
            if value > 0 {
                Text(formatUSD(value))
                    .font(.caption).fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func protocolPlaceholder(_ portfolio: OpenAPIService.PortfolioItem) -> some View {
        Circle()
            .fill(Color.purple.opacity(0.15))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(portfolio.name.prefix(1)).uppercased())
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(.purple)
            )
    }
    
    private func positionTypeBadges(_ portfolio: OpenAPIService.PortfolioItem) -> some View {
        let types = Set(portfolio.portfolio_item_list.flatMap { $0.detail_types ?? [] })
        return HStack(spacing: 2) {
            ForEach(Array(types.prefix(2)), id: \.self) { type in
                Text(formatPositionType(type))
                    .font(.system(size: 8))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(2)
            }
        }
    }
    
    private func formatPositionType(_ type: String) -> String {
        switch type.lowercased() {
        case "lending": return "Lend"
        case "staking", "staked": return "Stake"
        case "farming", "yield": return "Farm"
        case "liquidity", "lp": return "LP"
        case "vesting": return "Vest"
        default: return type.prefix(4).capitalized
        }
    }
    
    private func loadPortfolios() async {
        isLoading = true
        do {
            portfolios = try await OpenAPIService.shared.getPortfolios(address: address)
        } catch {
            portfolios = []
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
    
    private func formatAmount(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.2fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.2fK", value / 1_000) }
        if value >= 1 { return String(format: "%.4f", value) }
        return String(format: "%.6f", value)
    }
}
