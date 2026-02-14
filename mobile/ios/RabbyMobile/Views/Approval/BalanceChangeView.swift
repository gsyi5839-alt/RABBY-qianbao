import SwiftUI

/// Balance Change Preview - shows asset changes before/after transaction execution
/// Corresponds to: src/ui/views/Approval/components/BalanceChange in the Rabby browser extension
///
/// Future improvement: integrate with OpenAPI `preExec` endpoint for more accurate
/// balance change data. Currently uses local parsing based on tx to/value/data fields.

// MARK: - Data Models

/// Represents a single token or NFT balance change in a transaction
struct BalanceChangeItem: Identifiable {
    let id = UUID()
    let tokenSymbol: String
    let tokenLogoUrl: String?
    let chainId: String
    let amount: Double          // Positive = incoming, Negative = outgoing
    let usdValue: Double?
    let isNFT: Bool
    let nftName: String?

    /// Whether this item represents an outgoing (spend) change
    var isOutgoing: Bool { amount < 0 }

    /// Absolute amount for display purposes
    var displayAmount: Double { abs(amount) }

    /// Formatted amount string with appropriate precision
    var formattedAmount: String {
        if isNFT { return displayAmount >= 1 ? String(Int(displayAmount)) : String(format: "%.4f", displayAmount) }
        if displayAmount == 0 { return "0" }
        if displayAmount < 0.0001 { return "< 0.0001" }
        if displayAmount < 1 { return String(format: "%.6f", displayAmount) }
        if displayAmount < 1000 { return String(format: "%.4f", displayAmount) }
        if displayAmount < 1_000_000 { return String(format: "%.2f", displayAmount) }
        return String(format: "%.2f", displayAmount)
    }

    /// Formatted USD value string
    var formattedUsdValue: String? {
        guard let usd = usdValue, usd != 0 else { return nil }
        let absUsd = abs(usd)
        if absUsd < 0.01 { return "< $0.01" }
        return String(format: "$%.2f", absUsd)
    }

    /// Display name: NFT name or token symbol
    var displayName: String {
        if isNFT, let name = nftName, !name.isEmpty { return name }
        return tokenSymbol
    }
}

// MARK: - Balance Change View

/// Card-style balance change preview matching Rabby extension BalanceChange component
struct BalanceChangeView: View {
    let changes: [BalanceChangeItem]
    let riskLevel: SecurityEngineManager.RiskLevel

    /// Items where tokens leave the wallet (negative amounts)
    private var outgoingItems: [BalanceChangeItem] {
        changes.filter { $0.isOutgoing }
    }

    /// Items where tokens enter the wallet (positive amounts)
    private var incomingItems: [BalanceChangeItem] {
        changes.filter { !$0.isOutgoing }
    }

    /// Net USD change across all items
    private var netUsdChange: Double {
        changes.compactMap { $0.usdValue }.reduce(0, +)
    }

    /// Border color based on risk level
    private var borderColor: Color {
        switch riskLevel {
        case .safe:      return Color.green.opacity(0.4)
        case .warning:   return Color.orange.opacity(0.5)
        case .danger:    return Color.red.opacity(0.5)
        case .forbidden: return Color.red.opacity(0.8)
        }
    }

    var body: some View {
        if changes.isEmpty {
            emptyState
        } else {
            cardContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.title3)
                .foregroundColor(.secondary)
            Text(L("Unable to preview balance change"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: title + risk badge
            headerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Outgoing (Send) section
            if !outgoingItems.isEmpty {
                sendSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            if !outgoingItems.isEmpty && !incomingItems.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
            }

            // Incoming (Receive) section
            if !incomingItems.isEmpty {
                receiveSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Divider()

            // Net change summary
            netChangeSummary
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text(L("Balance Change"))
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            riskBadge
        }
    }

    private var riskBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: riskBadgeIcon)
                .font(.caption2)
            Text(riskBadgeText)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(riskBadgeBackground)
        .foregroundColor(riskBadgeForeground)
        .cornerRadius(6)
    }

    private var riskBadgeIcon: String {
        switch riskLevel {
        case .safe:      return "checkmark.shield.fill"
        case .warning:   return "exclamationmark.triangle.fill"
        case .danger:    return "xmark.shield.fill"
        case .forbidden: return "hand.raised.fill"
        }
    }

    private var riskBadgeText: String {
        switch riskLevel {
        case .safe:      return "Safe"
        case .warning:   return "Warning"
        case .danger:    return "Danger"
        case .forbidden: return "Forbidden"
        }
    }

    private var riskBadgeBackground: Color {
        switch riskLevel {
        case .safe:      return Color.green.opacity(0.15)
        case .warning:   return Color.orange.opacity(0.15)
        case .danger:    return Color.red.opacity(0.15)
        case .forbidden: return Color.red.opacity(0.25)
        }
    }

    private var riskBadgeForeground: Color {
        switch riskLevel {
        case .safe:      return .green
        case .warning:   return .orange
        case .danger:    return .red
        case .forbidden: return .red
        }
    }

    // MARK: - Send (Outgoing) Section

    private var sendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Send"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ForEach(outgoingItems) { item in
                balanceChangeRow(item: item, isOutgoing: true)
            }
        }
    }

    // MARK: - Receive (Incoming) Section

    private var receiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Receive"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ForEach(incomingItems) { item in
                balanceChangeRow(item: item, isOutgoing: false)
            }
        }
    }

    // MARK: - Balance Change Row

    private func balanceChangeRow(item: BalanceChangeItem, isOutgoing: Bool) -> some View {
        HStack(spacing: 10) {
            // Sign prefix
            Text(isOutgoing ? "-" : "+")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(isOutgoing ? .red : .green)
                .frame(width: 14, alignment: .center)

            // Token icon
            tokenIcon(item: item)

            // Amount + Symbol
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.formattedAmount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(item.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                // USD equivalent
                if let usdStr = item.formattedUsdValue {
                    Text("~\(usdStr)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Token Icon

    private func tokenIcon(item: BalanceChangeItem) -> some View {
        Group {
            if item.isNFT {
                // NFT icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 28, height: 28)
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else if let logoUrl = item.tokenLogoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    case .failure:
                        tokenFallbackIcon(symbol: item.tokenSymbol)
                    case .empty:
                        ProgressView()
                            .frame(width: 28, height: 28)
                    @unknown default:
                        tokenFallbackIcon(symbol: item.tokenSymbol)
                    }
                }
            } else {
                tokenFallbackIcon(symbol: item.tokenSymbol)
            }
        }
    }

    private func tokenFallbackIcon(symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 28, height: 28)
            Text(String(symbol.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Net Change Summary

    private var netChangeSummary: some View {
        HStack {
            Text(L("Net Change"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Spacer()

            if netUsdChange == 0 && !changes.isEmpty {
                Text(L("~$0.00"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 2) {
                    Text(netUsdChange >= 0 ? "+" : "-")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(netUsdChange >= 0 ? .green : .red)
                    Text(String(format: "$%.2f", abs(netUsdChange)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(netUsdChange >= 0 ? .green : .red)
                }
            }
        }
    }
}

// MARK: - Balance Change Parser

/// Parses transaction data into balance change items for preview.
/// This is a local heuristic parser. For production accuracy, integrate with
/// OpenAPI `preExec` endpoint: POST /v1/tx/pre_exec which returns actual
/// simulated balance changes from running the transaction on a fork.
struct BalanceChangeParser {

    /// Well-known ERC-20 method selectors
    private static let transferSelector = "0xa9059cbb"
    private static let approveSelector = "0x095ea7b3"
    private static let transferFromSelector = "0x23b872dd"

    /// Swap router selectors indicating token exchange
    private static let swapSelectors: Set<String> = [
        "0x38ed1739", // swapExactTokensForTokens
        "0x7ff36ab5", // swapExactETHForTokens
        "0x18cbafe5", // swapExactTokensForETH
        "0x5c11d795", // swapExactTokensForTokensSupportingFee
        "0x3593564c", // execute (Universal Router)
        "0x0162e2d0", // swap (1inch)
    ]

    /// Unlimited approval threshold (2^255)
    private static let unlimitedApprovalThreshold: Double = pow(2, 255)

    /// Parse an approval request into balance change items and risk level.
    /// - Parameter approval: The transaction approval request
    /// - Returns: Tuple of balance change items and assessed risk level
    static func parse(approval: ApprovalRequest) -> (changes: [BalanceChangeItem], riskLevel: SecurityEngineManager.RiskLevel) {
        var items: [BalanceChangeItem] = []
        var riskLevel: SecurityEngineManager.RiskLevel = .safe

        let chainId = String(approval.chainId)

        // 1. Parse native ETH value transfer
        if let valueHex = approval.value, valueHex != "0x0", valueHex != "0x" {
            let ethAmount = parseHexToEth(valueHex)
            if ethAmount > 0 {
                items.append(BalanceChangeItem(
                    tokenSymbol: "ETH",
                    tokenLogoUrl: nil,
                    chainId: chainId,
                    amount: -ethAmount,   // Outgoing
                    usdValue: nil,        // Unknown without price feed
                    isNFT: false,
                    nftName: nil
                ))
            }
        }

        // 2. Parse contract interaction data
        if let data = approval.data, data.count >= 10 {
            let selector = String(data.prefix(10))
            let params = String(data.dropFirst(10))

            if selector == transferSelector {
                // ERC-20 transfer(address to, uint256 amount)
                // We are sending tokens
                let amount = parseAmountFromCalldata(params, paramIndex: 1)
                items.append(BalanceChangeItem(
                    tokenSymbol: "Token",
                    tokenLogoUrl: nil,
                    chainId: chainId,
                    amount: -amount,
                    usdValue: nil,
                    isNFT: false,
                    nftName: nil
                ))
            } else if selector == approveSelector {
                // ERC-20 approve(address spender, uint256 amount)
                let amount = parseAmountFromCalldata(params, paramIndex: 1)
                if amount >= unlimitedApprovalThreshold {
                    // Unlimited approval to potentially unknown contract - high risk
                    riskLevel = .danger
                } else if amount > 0 {
                    riskLevel = .warning
                }
                // Approvals don't directly change balance, but we flag the risk
            } else if selector == transferFromSelector {
                // transferFrom(address from, address to, uint256 amount)
                let amount = parseAmountFromCalldata(params, paramIndex: 2)
                items.append(BalanceChangeItem(
                    tokenSymbol: "Token",
                    tokenLogoUrl: nil,
                    chainId: chainId,
                    amount: -amount,
                    usdValue: nil,
                    isNFT: false,
                    nftName: nil
                ))
            } else if swapSelectors.contains(selector) {
                // Swap operations: we expect outgoing + incoming
                // Without simulation we can't know exact amounts,
                // so we mark this as a swap with placeholder incoming
                riskLevel = .safe
            }
        }

        // 3. Risk assessment based on balance changes
        if riskLevel == .safe {
            riskLevel = assessRisk(items: items)
        }

        return (items, riskLevel)
    }

    /// Assess risk level from balance change items
    private static func assessRisk(items: [BalanceChangeItem]) -> SecurityEngineManager.RiskLevel {
        let outgoing = items.filter { $0.isOutgoing }
        let incoming = items.filter { !$0.isOutgoing }

        // No outgoing = safe (pure receive or no change)
        if outgoing.isEmpty { return .safe }

        // Large outgoing with no incoming = danger
        if incoming.isEmpty && !outgoing.isEmpty {
            let totalOutUsd = outgoing.compactMap { $0.usdValue }.reduce(0) { $0 + abs($1) }
            if totalOutUsd > 1000 { return .danger }
            return .warning
        }

        // Outgoing much larger than incoming = warning
        let totalOutUsd = outgoing.compactMap { $0.usdValue }.reduce(0) { $0 + abs($1) }
        let totalInUsd = incoming.compactMap { $0.usdValue }.reduce(0, +)
        if totalOutUsd > 0 && totalInUsd > 0 && totalOutUsd > totalInUsd * 2 {
            return .warning
        }

        return .safe
    }

    // MARK: - Hex Parsing Helpers

    /// Convert a hex wei string (e.g. "0x38d7ea4c68000") to ETH (Double)
    private static func parseHexToEth(_ hex: String) -> Double {
        let cleanHex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard let value = UInt64(cleanHex, radix: 16) else { return 0 }
        return Double(value) / 1e18
    }

    /// Extract a uint256 parameter from ABI-encoded calldata at a given 32-byte slot index.
    /// paramIndex 0 = first param, 1 = second param, etc.
    private static func parseAmountFromCalldata(_ params: String, paramIndex: Int) -> Double {
        let slotSize = 64 // 32 bytes = 64 hex chars
        let start = params.index(params.startIndex, offsetBy: paramIndex * slotSize, limitedBy: params.endIndex)
        let end = start.flatMap { params.index($0, offsetBy: slotSize, limitedBy: params.endIndex) }

        guard let s = start, let e = end else { return 0 }
        let hexSlot = String(params[s..<e])

        // For very large numbers (> UInt64.max), use rough approximation
        // A proper implementation should use BigInt
        if hexSlot.count > 16 {
            // Take the top 16 hex chars and shift
            let topHex = String(hexSlot.prefix(16))
            guard let topValue = UInt64(topHex, radix: 16) else { return 0 }
            let shiftBits = (hexSlot.count - 16) * 4
            return Double(topValue) * pow(2, Double(shiftBits))
        }

        guard let value = UInt64(hexSlot, radix: 16) else { return 0 }
        return Double(value)
    }
}

// MARK: - Preview

#if DEBUG
struct BalanceChangeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Safe swap example
            BalanceChangeView(
                changes: [
                    BalanceChangeItem(
                        tokenSymbol: "USDC", tokenLogoUrl: nil, chainId: "1",
                        amount: -1000.0, usdValue: -1000.0, isNFT: false, nftName: nil
                    ),
                    BalanceChangeItem(
                        tokenSymbol: "ETH", tokenLogoUrl: nil, chainId: "1",
                        amount: 0.45, usdValue: 990.0, isNFT: false, nftName: nil
                    ),
                ],
                riskLevel: .safe
            )

            // Danger: outgoing with no incoming
            BalanceChangeView(
                changes: [
                    BalanceChangeItem(
                        tokenSymbol: "ETH", tokenLogoUrl: nil, chainId: "1",
                        amount: -5.0, usdValue: -11000.0, isNFT: false, nftName: nil
                    ),
                ],
                riskLevel: .danger
            )

            // NFT transfer with warning
            BalanceChangeView(
                changes: [
                    BalanceChangeItem(
                        tokenSymbol: "NFT", tokenLogoUrl: nil, chainId: "1",
                        amount: -1.0, usdValue: -5000.0, isNFT: true, nftName: "Bored Ape #1234"
                    ),
                ],
                riskLevel: .warning
            )

            // Empty state
            BalanceChangeView(changes: [], riskLevel: .safe)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
