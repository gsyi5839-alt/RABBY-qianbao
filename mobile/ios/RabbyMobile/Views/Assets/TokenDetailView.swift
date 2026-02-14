import SwiftUI

/// Token detail popup view
/// Corresponds to: src/ui/views/Dashboard/components/TokenDetailPopup/
struct TokenDetailView: View {
    let token: TokenItem
    
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var tokenDetail: OpenAPIService.TokenDetailInfo?
    @State private var transactions: [OpenAPIService.HistoryItem] = []
    @State private var isLoading = true
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var copiedAddress = false
    @Environment(\.dismiss) var dismiss
    
    private var address: String {
        KeyringManager.shared.currentAccount?.address ?? ""
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    tokenInfoSection
                    priceSection

                    // Price chart
                    TokenChartView(
                        tokenId: token.address,
                        chainId: token.id.components(separatedBy: ":").first ?? "",
                        tokenSymbol: token.symbol
                    )
                    .background(Color(.systemBackground))

                    balanceSection
                    actionButtonsSection
                    
                    if !token.isNative {
                        contractSection
                    }
                    
                    transactionHistorySection
                }
            }
            .navigationTitle(token.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .task { await loadDetail() }
            .sheet(isPresented: $showSendSheet) { SendTokenView() }
            .sheet(isPresented: $showReceiveSheet) { ReceiveView(address: address) }
        }
    }
    
    // MARK: - Token Info Header
    
    private var tokenInfoSection: some View {
        VStack(spacing: 12) {
            // Token icon (with ErikThiart fallback)
            CryptoIconView(
                symbol: token.symbol,
                logoURL: token.logoURL ?? tokenDetail?.logo_url,
                size: 64
            )
            
            // Name + symbol
            VStack(spacing: 4) {
                Text(token.name)
                    .font(.title2).fontWeight(.bold)
                Text(token.symbol)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Verification badge
            if let detail = tokenDetail {
                HStack(spacing: 4) {
                    if detail.is_verified == true {
                        Label(L("Verified"), systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    if detail.is_scam == true {
                        Label(L("Scam Risk"), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Price Section
    
    private var priceSection: some View {
        VStack(spacing: 12) {
            sectionHeader(LocalizationManager.shared.t("Price"))
            
            HStack {
                // Current price
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Current Price"))
                        .font(.caption).foregroundColor(.secondary)
                    let price = tokenDetail?.price ?? token.price
                    Text(formatUSD(price))
                        .font(.title3).fontWeight(.semibold)
                }
                
                Spacer()
                
                // 24h change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("24h Change"))
                        .font(.caption).foregroundColor(.secondary)
                    let change = tokenDetail?.price_24h_change ?? token.priceChange24h ?? 0
                    priceChangeLabel(change)
                }
            }
            
            // Market Cap + Supply
            if let detail = tokenDetail {
                HStack {
                    if let marketCap = detail.market_cap, marketCap > 0 {
                        statItem(title: LocalizationManager.shared.t("Market Cap"), value: formatCompactUSD(marketCap))
                    }
                    Spacer()
                    if let supply = detail.total_supply, supply > 0 {
                        statItem(title: LocalizationManager.shared.t("Total Supply"), value: formatCompactNumber(supply))
                    }
                    Spacer()
                    if let holders = detail.holders, holders > 0 {
                        statItem(title: LocalizationManager.shared.t("Holders"), value: formatCompactNumber(Double(holders)))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Balance Section
    
    private var balanceSection: some View {
        VStack(spacing: 12) {
            sectionHeader(LocalizationManager.shared.t("Your Balance"))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let bal = tokenManager.getCachedBalance(tokenId: token.id) {
                        Text("\(bal.balanceFormatted) \(token.symbol)")
                            .font(.title3).fontWeight(.semibold)
                        
                        let usdValue = (Double(bal.balanceFormatted) ?? 0) * (tokenDetail?.price ?? token.price)
                        Text(formatUSD(usdValue))
                            .font(.subheadline).foregroundColor(.secondary)
                    } else {
                        Text("0 \(token.symbol)")
                            .font(.title3).fontWeight(.semibold)
                        Text(L("$0.00"))
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            actionButton(icon: "arrow.up.circle.fill", title: LocalizationManager.shared.t("Send"), color: .blue) {
                showSendSheet = true
            }
            actionButton(icon: "arrow.down.circle.fill", title: LocalizationManager.shared.t("Receive"), color: .green) {
                showReceiveSheet = true
            }
            actionButton(icon: "arrow.2.squarepath", title: LocalizationManager.shared.t("Swap"), color: .orange) {
                // Swap action
            }
        }
        .padding()
    }
    
    // MARK: - Contract Section
    
    private var contractSection: some View {
        VStack(spacing: 8) {
            sectionHeader(LocalizationManager.shared.t("Contract"))
            
            Button(action: copyContractAddress) {
                HStack {
                    Text(token.address)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Image(systemName: copiedAddress ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(copiedAddress ? .green : .blue)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if let chain = chainManager.getChain(serverId: token.id.components(separatedBy: ":").first ?? "") ??
                           chainManager.getChain(byId: token.chainId) {
                // View on explorer link
                Link(destination: URL(string: "\(chain.explorerURL)/token/\(token.address)") ?? URL(string: "https://etherscan.io")!) {
                    HStack {
                        Image(systemName: "safari")
                        Text(L("View on Explorer"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Transaction History
    
    private var transactionHistorySection: some View {
        VStack(spacing: 8) {
            sectionHeader(LocalizationManager.shared.t("Recent Transactions"))
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if transactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                    Text(L("No transactions yet"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(transactions, id: \.id) { tx in
                        txRow(tx)
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Transaction Row
    
    private func txRow(_ tx: OpenAPIService.HistoryItem) -> some View {
        HStack(spacing: 12) {
            // Tx type icon
            let (icon, color) = txIcon(tx)
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(txTypeLabel(tx))
                    .font(.subheadline).fontWeight(.medium)
                Text(Date(timeIntervalSince1970: tx.time_at), style: .relative)
                    .font(.caption2).foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                if let sends = tx.sends, !sends.isEmpty {
                    Text("-\(String(format: "%.4f", sends.first?.amount ?? 0))")
                        .font(.subheadline)
                        .foregroundColor(.red)
                } else if let receives = tx.receives, !receives.isEmpty {
                    Text("+\(String(format: "%.4f", receives.first?.amount ?? 0))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                let status = tx.tx?.status == 1 ? LocalizationManager.shared.t("Completed") : LocalizationManager.shared.t("Failed")
                Text(status)
                    .font(.caption2)
                    .foregroundColor(tx.tx?.status == 1 ? .green : .red)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private func loadDetail() async {
        isLoading = true
        let chainServerId = token.id.components(separatedBy: ":").first ?? ""
        
        // Load token detail + transaction history in parallel
        async let detailTask: Void = {
            if let detail = try? await OpenAPIService.shared.getTokenDetail(
                chainId: chainServerId, tokenId: token.address
            ) {
                await MainActor.run { self.tokenDetail = detail }
            }
        }()
        
        async let historyTask: Void = {
            if let history = try? await OpenAPIService.shared.getTransactionHistory(
                address: self.address, chainId: chainServerId, limit: 20
            ) {
                // Filter transactions related to this token
                let filtered = history.filter { item in
                    let hasSend = item.sends?.contains { $0.token_id == self.token.address || $0.token_id == self.token.id } ?? false
                    let hasReceive = item.receives?.contains { $0.token_id == self.token.address || $0.token_id == self.token.id } ?? false
                    let isApproval = item.token_approve?.token_id == self.token.address
                    return hasSend || hasReceive || isApproval
                }
                await MainActor.run { self.transactions = filtered.isEmpty ? Array(history.prefix(10)) : filtered }
            }
        }()
        
        _ = await (detailTask, historyTask)
        isLoading = false
    }
    
    private func copyContractAddress() {
        UIPasteboard.general.string = token.address
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { copiedAddress = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedAddress = false }
        }
    }
    
    
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2).foregroundColor(.secondary)
            Text(value)
                .font(.caption).fontWeight(.medium)
        }
    }
    
    private func priceChangeLabel(_ change: Double) -> some View {
        let isPositive = change >= 0
        return HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.caption2)
            Text(String(format: "%.2f%%", abs(change * 100)))
                .font(.subheadline).fontWeight(.medium)
        }
        .foregroundColor(isPositive ? .green : .red)
    }
    
    private func txIcon(_ tx: OpenAPIService.HistoryItem) -> (String, Color) {
        if tx.token_approve != nil { return ("checkmark.circle", .purple) }
        if tx.sends != nil && !(tx.sends!.isEmpty) && tx.receives != nil && !(tx.receives!.isEmpty) {
            return ("arrow.2.squarepath", .orange)
        }
        if tx.sends != nil && !(tx.sends!.isEmpty) { return ("arrow.up.right", .red) }
        if tx.receives != nil && !(tx.receives!.isEmpty) { return ("arrow.down.left", .green) }
        return ("gearshape", .gray)
    }
    
    private func txTypeLabel(_ tx: OpenAPIService.HistoryItem) -> String {
        if tx.token_approve != nil { return LocalizationManager.shared.t("Approval") }
        if tx.sends != nil && !(tx.sends!.isEmpty) && tx.receives != nil && !(tx.receives!.isEmpty) { return LocalizationManager.shared.t("Swap") }
        if tx.sends != nil && !(tx.sends!.isEmpty) { return LocalizationManager.shared.t("Send") }
        if tx.receives != nil && !(tx.receives!.isEmpty) { return LocalizationManager.shared.t("Receive") }
        return LocalizationManager.shared.t("Contract Call")
    }
    
    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value < 1 ? 6 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private func formatCompactUSD(_ value: Double) -> String {
        if value >= 1_000_000_000 { return "$\(String(format: "%.1fB", value / 1_000_000_000))" }
        if value >= 1_000_000 { return "$\(String(format: "%.1fM", value / 1_000_000))" }
        if value >= 1_000 { return "$\(String(format: "%.1fK", value / 1_000))" }
        return formatUSD(value)
    }
    
    private func formatCompactNumber(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return String(format: "%.0f", value)
    }
}
