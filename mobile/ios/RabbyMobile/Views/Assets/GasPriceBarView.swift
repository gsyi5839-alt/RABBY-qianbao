import SwiftUI

/// Gas price bar matching extension wallet design.
///
/// Extension layout:
/// - Left: Native token logo + USD price + 24h change %
/// - Right: Gas icon + gas price in Gwei
///
/// Tappable to expand and show Slow / Normal / Fast gas levels.
///
/// Corresponds to: src/ui/views/Dashboard/components/GasPriceBar/
struct GasPriceBarView: View {
    @StateObject private var chainManager = ChainManager.shared
    @State private var gasPrice: OpenAPIService.GasPrice?
    @State private var tokenCurrentPrice: Double?
    @State private var tokenPriceChange: Double?
    @State private var tokenLogoUrl: String?
    @State private var tokenSymbol: String = "ETH"
    @State private var isLoading = true
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main bar: token price (left) + gas price (right)
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 0) {
                    // ── Left: Native token price ──
                    leftSection

                    Spacer()

                    // ── Right: Gas price ──
                    rightSection
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded: show all gas levels
            if isExpanded, let gas = gasPrice {
                Divider().padding(.horizontal, 8)

                HStack(spacing: 0) {
                    gasLevelCard(title: LocalizationManager.shared.t("Slow"), level: gas.slow, color: .green)
                    Divider().frame(height: 50)
                    gasLevelCard(title: LocalizationManager.shared.t("Normal"), level: gas.normal, color: .orange)
                    Divider().frame(height: 50)
                    gasLevelCard(title: LocalizationManager.shared.t("Fast"), level: gas.fast, color: .red)
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .task { await loadData() }
        .onChange(of: chainManager.selectedChain?.serverId) { _ in
            Task { await loadData() }
        }
    }

    // MARK: - Left Section: Native Token Price

    private var leftSection: some View {
        HStack(spacing: 8) {
            // Token logo
            if let logoUrl = tokenLogoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
            } else {
                // Fallback: chain icon
                if let chain = chainManager.selectedChain {
                    AsyncImage(url: URL(string: chain.logo)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(Color(.systemGray4))
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }

            if isLoading {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 60, height: 14)
            } else if let price = tokenCurrentPrice, price > 0 {
                // Price
                Text(formatUSD(price))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                // 24h change
                if let change = tokenPriceChange, change != 0 {
                    Text(formatPercentChange(change))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(change > 0 ? .green : change < 0 ? .red : .secondary)
                }
            } else {
                Text("-")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Right Section: Gas Price

    private var rightSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if isLoading {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 40, height: 14)
            } else if let gas = gasPrice {
                Text(formatGwei(gas.slow.price))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text("Gwei")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("-")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Gas Level Card

    private func gasLevelCard(title: String, level: OpenAPIService.GasLevel, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(formatGwei(level.price))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)

            Text("Gwei")
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            if let seconds = level.estimated_seconds, seconds > 0 {
                Text("~\(formatTime(seconds))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let chain = chainManager.selectedChain else { return }
        isLoading = true
        tokenSymbol = chain.symbol
        tokenLogoUrl = chain.logo  // Use chain logo directly (always available)

        // Load gas price and token price in parallel using reliable sources:
        // - Gas: Direct RPC call (no Rabby API needed)
        // - Price: CoinGecko free API (no auth/signing needed)
        async let gasTask: () = loadGasPriceViaRPC(chain: chain)
        async let priceTask: () = loadTokenPriceFromCoinGecko(chainId: chain.serverId)
        _ = await (gasTask, priceTask)

        isLoading = false
    }

    /// Load gas price directly from chain's RPC endpoint (eth_gasPrice / eth_feeHistory).
    /// This bypasses the Rabby API entirely and is always reliable.
    private func loadGasPriceViaRPC(chain: Chain) async {
        do {
            let rpcUrl = await MainActor.run { RPCManager.shared.getEffectiveRPC(chainId: chain.id) ?? chain.defaultRpcUrl }
            if chain.isEIP1559 {
                // Use eth_feeHistory for EIP-1559 chains (returns slow/normal/fast)
                let fees = try await OpenAPIService.shared.getFeeHistoryViaRPC(rpcUrl: rpcUrl)
                gasPrice = OpenAPIService.GasPrice(
                    slow: OpenAPIService.GasLevel(price: Int(fees.slow), level: "slow", front_tx_count: nil, estimated_seconds: nil, base_fee: nil, priority_price: nil),
                    normal: OpenAPIService.GasLevel(price: Int(fees.normal), level: "normal", front_tx_count: nil, estimated_seconds: nil, base_fee: nil, priority_price: nil),
                    fast: OpenAPIService.GasLevel(price: Int(fees.fast), level: "fast", front_tx_count: nil, estimated_seconds: nil, base_fee: nil, priority_price: nil)
                )
            } else {
                // Use eth_gasPrice for legacy chains
                let weiPrice = try await OpenAPIService.shared.getGasPriceViaRPC(rpcUrl: rpcUrl)
                let level = OpenAPIService.GasLevel(price: Int(weiPrice), level: "normal", front_tx_count: nil, estimated_seconds: nil, base_fee: nil, priority_price: nil)
                gasPrice = OpenAPIService.GasPrice(slow: level, normal: level, fast: level)
            }
        } catch {
            NSLog("[GasPriceBar] RPC gas price failed: \(error), trying Rabby API fallback...")
            // Fallback to Rabby API (may fail due to rate limiting)
            do {
                gasPrice = try await OpenAPIService.shared.getGasPrice(chainId: chain.serverId)
            } catch {
                NSLog("[GasPriceBar] Rabby API gas price also failed: \(error)")
                gasPrice = nil
            }
        }
    }

    /// Load token price from CoinGecko's free API (no auth/signing needed).
    /// Falls back to Rabby API if CoinGecko doesn't have the token.
    private func loadTokenPriceFromCoinGecko(chainId: String) async {
        do {
            let priceData = try await OpenAPIService.shared.getTokenPriceFromCoinGecko(chainServerId: chainId)
            tokenCurrentPrice = priceData.usdPrice
            tokenPriceChange = priceData.usd24hChange
        } catch {
            NSLog("[GasPriceBar] CoinGecko price failed: \(error), trying Rabby API fallback...")
            // Fallback to Rabby API
            do {
                let priceData = try await OpenAPIService.shared.tokenPrice(token: chainId)
                tokenCurrentPrice = priceData.last_price
                tokenPriceChange = priceData.change_percent
            } catch {
                NSLog("[GasPriceBar] Rabby API price also failed: \(error)")
                tokenCurrentPrice = nil
                tokenPriceChange = nil
            }
        }
    }

    // MARK: - Formatting

    private func formatGwei(_ price: Int) -> String {
        let gwei = Double(price) / 1_000_000_000
        if gwei >= 100 { return String(format: "%.0f", gwei) }
        if gwei >= 10 { return String(format: "%.1f", gwei) }
        if gwei >= 1 { return String(format: "%.2f", gwei) }
        return String(format: "%.3f", gwei)
    }

    private func formatUSD(_ price: Double) -> String {
        if price < 0.01 { return "<$0.01" }
        if price >= 10000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return "$" + (formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price))
        }
        return String(format: "$%.2f", price)
    }

    private func formatPercentChange(_ change: Double) -> String {
        // `change_percent` from the API is already a percentage value (e.g., 2.5 for +2.5%)
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, change)
    }

    private func formatTime(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h\(minutes % 60)m"
    }
}
