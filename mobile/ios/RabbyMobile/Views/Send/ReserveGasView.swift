import SwiftUI
import BigInt
import Combine

// MARK: - PreExecutionManager

/// Manages pre-execution simulation of Ethereum transactions via eth_call and eth_estimateGas.
/// Caches results for identical transaction parameters to avoid redundant RPC calls.
@MainActor
class PreExecutionManager: ObservableObject {
    static let shared = PreExecutionManager()

    private let networkManager = NetworkManager.shared
    private let transactionManager = TransactionManager.shared

    /// In-memory cache keyed by a hash of transaction parameters.
    /// Each entry stores the simulation result and a timestamp for staleness checks.
    private var cache: [String: CachedPreExecResult] = [:]

    /// Cache entries expire after 30 seconds (gas prices and state can change).
    private let cacheExpirySeconds: TimeInterval = 30

    /// Maximum cache entries to prevent unbounded growth.
    private let maxCacheEntries = 50

    private init() {}

    // MARK: - Public API

    /// Simulate a transaction and return a structured result.
    /// Returns a cached result when the same tx params were simulated recently.
    func simulate(
        from: String,
        to: String,
        value: String,
        data: String,
        chain: Chain
    ) async -> PreExecResult {
        let cacheKey = buildCacheKey(from: from, to: to, value: value, data: data, chainId: chain.id)

        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince1970 - cached.timestamp < cacheExpirySeconds {
            return cached.result
        }

        let txDict: [String: Any] = [
            "from": from,
            "to": to,
            "value": value,
            "data": data
        ]

        // Run eth_call (simulation) and eth_estimateGas in parallel
        var simulationSuccess = true
        var revertReason: String? = nil
        var estimatedGas: BigUInt = 0
        var gasPrice: BigUInt = 0

        await withTaskGroup(of: Void.self) { group in
            // Task 1: eth_call simulation
            group.addTask { @MainActor in
                do {
                    _ = try await self.networkManager.call(transaction: txDict, chain: chain)
                    simulationSuccess = true
                } catch let error as NetworkError {
                    simulationSuccess = false
                    revertReason = self.parseRevertReason(from: error)
                } catch {
                    simulationSuccess = false
                    revertReason = error.localizedDescription
                }
            }

            // Task 2: eth_estimateGas
            group.addTask { @MainActor in
                do {
                    estimatedGas = try await self.transactionManager.estimateGas(
                        from: from, to: to, value: value, data: data, chain: chain
                    )
                } catch {
                    // If estimation fails the tx likely reverts; estimatedGas stays 0
                }
            }

            // Task 3: gas price
            group.addTask { @MainActor in
                do {
                    gasPrice = try await self.transactionManager.getGasPrice(chain: chain)
                } catch {
                    // Fallback: 0 means we cannot compute total cost
                }
            }
        }

        let totalCostWei = estimatedGas * gasPrice
        let valueBigUInt = TransactionManager.parseBigUIntFromHex(value)
        let totalWithValue = totalCostWei + valueBigUInt

        let explanation = buildExplanation(
            from: from, to: to, value: value, data: data, chain: chain
        )

        let balanceChanges = buildBalanceChanges(
            from: from, to: to, value: value, data: data, chain: chain
        )

        let result = PreExecResult(
            success: simulationSuccess,
            revertReason: revertReason,
            estimatedGasUsed: estimatedGas,
            gasPriceWei: gasPrice,
            totalGasCostWei: totalCostWei,
            totalCostWithValueWei: totalWithValue,
            explanation: explanation,
            balanceChanges: balanceChanges,
            chain: chain
        )

        // Store in cache (evict oldest if full)
        if cache.count >= maxCacheEntries {
            let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp })
            if let oldestKey = oldest?.key {
                cache.removeValue(forKey: oldestKey)
            }
        }
        cache[cacheKey] = CachedPreExecResult(result: result, timestamp: Date().timeIntervalSince1970)

        return result
    }

    /// Invalidate all cached results (e.g., when chain or account changes).
    func invalidateCache() {
        cache.removeAll()
    }

    // MARK: - Revert Reason Parsing

    /// Parse a revert reason from an RPC error.
    /// Supports Error(string) selector 0x08c379a0 and Panic(uint256) selector 0x4e487b71.
    private func parseRevertReason(from error: NetworkError) -> String {
        guard case .rpcError(_, let message) = error else {
            return error.localizedDescription
        }

        // Some nodes embed the revert data in the error message.
        // Look for a hex-encoded revert payload.
        if let range = message.range(of: "0x08c379a0") {
            let hexPayload = String(message[range.lowerBound...])
                .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "x")))
                .first ?? ""
            return decodeErrorString(hexPayload)
        }

        if let range = message.range(of: "0x4e487b71") {
            let hexPayload = String(message[range.lowerBound...])
                .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "x")))
                .first ?? ""
            return decodePanicCode(hexPayload)
        }

        // Fallback: return the raw message
        return message
    }

    /// Decode Error(string) ABI: 0x08c379a0 + offset(32) + length(32) + utf8 data
    private func decodeErrorString(_ hex: String) -> String {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        // Skip selector (8 chars) + offset (64 chars) = 72 chars
        guard clean.count > 72 + 64 else { return "Execution reverted" }

        let lengthHex = String(clean[clean.index(clean.startIndex, offsetBy: 72)..<clean.index(clean.startIndex, offsetBy: 72 + 64)])
        guard let length = Int(lengthHex, radix: 16), length > 0, length < 1024 else {
            return "Execution reverted"
        }

        let dataStart = clean.index(clean.startIndex, offsetBy: 72 + 64)
        let dataEnd = clean.index(dataStart, offsetBy: min(length * 2, clean.count - (72 + 64)), limitedBy: clean.endIndex) ?? clean.endIndex
        let dataHex = String(clean[dataStart..<dataEnd])

        if let data = dataHex.hexToData(), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "Execution reverted"
    }

    /// Decode Panic(uint256) ABI: 0x4e487b71 + code(32 bytes)
    private func decodePanicCode(_ hex: String) -> String {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard clean.count >= 8 + 64 else { return "Panic: unknown" }

        let codeHex = String(clean[clean.index(clean.startIndex, offsetBy: 8)..<clean.index(clean.startIndex, offsetBy: 8 + 64)])
        guard let code = UInt64(codeHex, radix: 16) else { return "Panic: unknown" }

        let panicReasons: [UInt64: String] = [
            0x00: "Generic compiler panic",
            0x01: "Assertion failed",
            0x11: "Arithmetic overflow/underflow",
            0x12: "Division or modulo by zero",
            0x21: "Invalid enum conversion",
            0x22: "Incorrectly encoded storage byte array",
            0x31: "pop() on empty array",
            0x32: "Array index out of bounds",
            0x41: "Too much memory allocated",
            0x51: "Zero-initialized variable of internal function type",
        ]

        return "Panic: \(panicReasons[code] ?? "code \(code)")"
    }

    // MARK: - Plain Language Explanation

    /// Build a human-readable explanation of what the transaction will do.
    private func buildExplanation(
        from: String,
        to: String,
        value: String,
        data: String,
        chain: Chain
    ) -> String {
        let toFormatted = formatAddress(to)
        let valueBigUInt = TransactionManager.parseBigUIntFromHex(value)
        let ethValue = EthereumUtil.weiToEther(valueBigUInt)

        // Pure native token transfer (no calldata)
        if data == "0x" || data.isEmpty {
            if valueBigUInt > 0 {
                return "Send \(formatDecimal(ethValue)) \(chain.nativeTokenSymbol) to \(toFormatted)"
            } else {
                return "Send 0 \(chain.nativeTokenSymbol) to \(toFormatted)"
            }
        }

        // Contract interaction - decode method selector
        guard data.count >= 10 else {
            return "Interact with contract \(toFormatted)"
        }

        let selector = String(data.prefix(10))

        switch selector {
        // ERC-20 transfer(address,uint256)
        case "0xa9059cbb":
            let recipientHex = extractAddressParam(data, index: 0)
            let recipientFormatted = formatAddress(recipientHex)
            return "Send tokens to \(recipientFormatted)"

        // ERC-20 approve(address,uint256)
        case "0x095ea7b3":
            let spenderHex = extractAddressParam(data, index: 0)
            let amountHex = extractUint256Param(data, index: 1)
            let spenderFormatted = formatAddress(spenderHex)
            let isUnlimited = amountHex.count > 60 // rough check for max uint256
            if isUnlimited {
                return "Approve unlimited token spending by \(spenderFormatted)"
            }
            return "Approve token spending by \(spenderFormatted)"

        // transferFrom(address,address,uint256)
        case "0x23b872dd":
            let toAddr = extractAddressParam(data, index: 1)
            return "Transfer tokens to \(formatAddress(toAddr))"

        // Swap selectors
        case "0x38ed1739", "0x7ff36ab5", "0x18cbafe5", "0x5c11d795":
            return "Swap tokens via router \(toFormatted)"

        // Uniswap Universal Router execute
        case "0x3593564c":
            return "Execute swap via Universal Router"

        // 1inch swap
        case "0x0162e2d0":
            return "Swap tokens via 1inch"

        default:
            if valueBigUInt > 0 {
                return "Interact with contract \(toFormatted) sending \(formatDecimal(ethValue)) \(chain.nativeTokenSymbol)"
            }
            return "Interact with contract \(toFormatted)"
        }
    }

    /// Build simplified balance change descriptions from the transaction data.
    private func buildBalanceChanges(
        from: String,
        to: String,
        value: String,
        data: String,
        chain: Chain
    ) -> [PreExecBalanceChange] {
        var changes: [PreExecBalanceChange] = []
        let valueBigUInt = TransactionManager.parseBigUIntFromHex(value)

        // Native token send
        if valueBigUInt > 0 {
            let ethValue = EthereumUtil.weiToEther(valueBigUInt)
            changes.append(PreExecBalanceChange(
                symbol: chain.nativeTokenSymbol,
                amount: -NSDecimalNumber(decimal: ethValue).doubleValue,
                isOutgoing: true
            ))
        }

        // ERC-20 transfer detection
        if data.count >= 10 {
            let selector = String(data.prefix(10))
            if selector == "0xa9059cbb" || selector == "0x23b872dd" {
                changes.append(PreExecBalanceChange(
                    symbol: "Token",
                    amount: 0, // Exact amount requires token decimals lookup
                    isOutgoing: true
                ))
            }
        }

        return changes
    }

    // MARK: - Helpers

    private func buildCacheKey(from: String, to: String, value: String, data: String, chainId: Int) -> String {
        return "\(chainId):\(from.lowercased()):\(to.lowercased()):\(value):\(data)"
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        if doubleValue == 0 { return "0" }
        if doubleValue < 0.0001 { return "< 0.0001" }
        if doubleValue < 1 { return String(format: "%.6f", doubleValue) }
        if doubleValue < 1000 { return String(format: "%.4f", doubleValue) }
        return String(format: "%.2f", doubleValue)
    }

    /// Extract an address parameter from ABI-encoded calldata at a given 32-byte slot index.
    private func extractAddressParam(_ data: String, index: Int) -> String {
        let clean = data.hasPrefix("0x") ? String(data.dropFirst(2)) : data
        // Skip 4-byte selector (8 hex chars)
        let offset = 8 + (index * 64)
        guard clean.count >= offset + 64 else { return "0x0" }
        let start = clean.index(clean.startIndex, offsetBy: offset)
        let end = clean.index(start, offsetBy: 64)
        let slot = String(clean[start..<end])
        // Address is the last 40 chars of the 64-char slot
        let addrHex = String(slot.suffix(40))
        return "0x" + addrHex
    }

    /// Extract a uint256 hex string from ABI-encoded calldata at a given 32-byte slot index.
    private func extractUint256Param(_ data: String, index: Int) -> String {
        let clean = data.hasPrefix("0x") ? String(data.dropFirst(2)) : data
        let offset = 8 + (index * 64)
        guard clean.count >= offset + 64 else { return "0" }
        let start = clean.index(clean.startIndex, offsetBy: offset)
        let end = clean.index(start, offsetBy: 64)
        return String(clean[start..<end])
    }
}

// MARK: - PreExecResult Model

/// The result of a pre-execution simulation.
struct PreExecResult {
    let success: Bool
    let revertReason: String?
    let estimatedGasUsed: BigUInt
    let gasPriceWei: BigUInt
    let totalGasCostWei: BigUInt
    let totalCostWithValueWei: BigUInt
    let explanation: String
    let balanceChanges: [PreExecBalanceChange]
    let chain: Chain

    /// Estimated gas cost formatted in the chain's native token (e.g., "0.003421 ETH").
    var formattedGasCost: String {
        let ether = EthereumUtil.weiToEther(totalGasCostWei)
        let doubleValue = NSDecimalNumber(decimal: ether).doubleValue
        return String(format: "%.6f %@", doubleValue, chain.nativeTokenSymbol)
    }

    /// Total cost (gas + value) formatted.
    var formattedTotalCost: String {
        let ether = EthereumUtil.weiToEther(totalCostWithValueWei)
        let doubleValue = NSDecimalNumber(decimal: ether).doubleValue
        return String(format: "%.6f %@", doubleValue, chain.nativeTokenSymbol)
    }

    /// Estimated gas as a human-readable number string.
    var formattedGasUsed: String {
        return estimatedGasUsed.description
    }
}

/// A simplified balance change entry from pre-execution analysis.
struct PreExecBalanceChange: Identifiable {
    let id = UUID()
    let symbol: String
    let amount: Double
    let isOutgoing: Bool
}

/// Internal cache wrapper.
private struct CachedPreExecResult {
    let result: PreExecResult
    let timestamp: TimeInterval
}

// MARK: - ReserveGasSettings

/// Persists per-chain reserve gas toggle state and custom reserve amounts in UserDefaults.
class ReserveGasSettings {
    static let shared = ReserveGasSettings()

    private let defaults = UserDefaults.standard
    private let enabledKeyPrefix = "reserveGas_enabled_"
    private let amountKeyPrefix = "reserveGas_amount_"

    /// Default reserve amounts per chain (in native token units, e.g., 0.01 ETH).
    /// Keyed by chain ID.
    static let defaultReserveAmounts: [Int: Double] = [
        1:     0.01,   // Ethereum
        56:    0.005,  // BNB Chain
        137:   0.1,    // Polygon
        42161: 0.001,  // Arbitrum
        10:    0.001,  // Optimism
        43114: 0.05,   // Avalanche
        250:   0.5,    // Fantom
        8453:  0.001,  // Base
        324:   0.001,  // zkSync Era
        59144: 0.001,  // Linea
    ]

    /// Fallback reserve amount for chains not in the default map.
    static let fallbackReserveAmount: Double = 0.01

    private init() {}

    /// Whether reserve gas is enabled for a given chain.
    func isEnabled(chainId: Int) -> Bool {
        let key = enabledKeyPrefix + "\(chainId)"
        // Default to true for first use
        if defaults.object(forKey: key) == nil {
            return true
        }
        return defaults.bool(forKey: key)
    }

    /// Set whether reserve gas is enabled for a given chain.
    func setEnabled(_ enabled: Bool, chainId: Int) {
        let key = enabledKeyPrefix + "\(chainId)"
        defaults.set(enabled, forKey: key)
    }

    /// Get the reserve amount for a given chain (in native token units).
    func reserveAmount(chainId: Int) -> Double {
        let key = amountKeyPrefix + "\(chainId)"
        let stored = defaults.double(forKey: key)
        if stored > 0 { return stored }
        return Self.defaultReserveAmounts[chainId] ?? Self.fallbackReserveAmount
    }

    /// Set a custom reserve amount for a given chain.
    func setReserveAmount(_ amount: Double, chainId: Int) {
        let key = amountKeyPrefix + "\(chainId)"
        defaults.set(amount, forKey: key)
    }

    /// Compute the maximum sendable amount after reserving gas.
    /// - Parameters:
    ///   - balance: The user's full native token balance in token units (e.g., 1.5 ETH).
    ///   - chainId: The chain ID.
    /// - Returns: The adjusted max amount. Never less than zero.
    func maxSendAmount(balance: Double, chainId: Int) -> Double {
        guard isEnabled(chainId: chainId) else { return balance }
        let reserve = reserveAmount(chainId: chainId)
        return max(balance - reserve, 0)
    }
}

// MARK: - ReserveGasToggle View

/// A toggle switch for "Reserve gas for future transactions".
/// Shows the reserved amount next to the toggle. Persists per-chain in UserDefaults.
///
/// Usage in SendTokenView:
/// ```
/// ReserveGasToggle(chain: chain, onToggleChanged: { enabled in
///     // Recalculate max send amount
/// })
/// ```
struct ReserveGasToggle: View {
    let chain: Chain
    var onToggleChanged: ((Bool) -> Void)? = nil

    @State private var isEnabled: Bool = true
    @State private var reserveAmount: Double = 0.01
    @State private var isEditingAmount: Bool = false
    @State private var customAmountText: String = ""

    private let settings = ReserveGasSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Toggle(isOn: $isEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "fuelpump.fill")
                            .font(.caption)
                            .foregroundColor(isEnabled ? .blue : .secondary)

                        Text(L("Reserve gas for future transactions"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: isEnabled) { newValue in
                    settings.setEnabled(newValue, chainId: chain.id)
                    onToggleChanged?(newValue)
                }
            }

            if isEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.caption2)
                        .foregroundColor(.orange)

                    if isEditingAmount {
                        // Editable reserve amount
                        HStack(spacing: 4) {
                            TextField(L("0.01"), text: $customAmountText)
                                .keyboardType(.decimalPad)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)

                            Text(chain.nativeTokenSymbol)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: applyCustomAmount) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }

                            Button(action: { isEditingAmount = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text("Reserved: \(formatReserveAmount(reserveAmount)) \(chain.nativeTokenSymbol)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            customAmountText = formatReserveAmount(reserveAmount)
                            isEditingAmount = true
                        }) {
                            Text(L("Edit"))
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEnabled ? Color.blue.opacity(0.05) : Color(.systemGray6))
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .onAppear {
            isEnabled = settings.isEnabled(chainId: chain.id)
            reserveAmount = settings.reserveAmount(chainId: chain.id)
        }
    }

    private func applyCustomAmount() {
        if let value = Double(customAmountText), value > 0 {
            reserveAmount = value
            settings.setReserveAmount(value, chainId: chain.id)
            onToggleChanged?(isEnabled)
        }
        isEditingAmount = false
    }

    private func formatReserveAmount(_ amount: Double) -> String {
        if amount < 0.0001 { return String(format: "%.8f", amount) }
        if amount < 0.01 { return String(format: "%.6f", amount) }
        if amount < 1 { return String(format: "%.4f", amount) }
        return String(format: "%.2f", amount)
    }
}

// MARK: - PreExecResultView

/// Displays pre-execution simulation results before signing.
/// Shows: simulation status badge, estimated gas, balance changes, and a
/// plain-language explanation of what the transaction will do.
struct PreExecResultView: View {
    let result: PreExecResult
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with simulation badge
            headerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if isExpanded {
                Divider()

                // Explanation
                explanationSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()

                // Gas details
                gasDetailsSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // Balance changes
                if !result.balanceChanges.isEmpty {
                    Divider()
                    balanceChangesSection
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }

                // Revert reason (if simulation failed)
                if !result.success, let reason = result.revertReason {
                    Divider()
                    revertReasonSection(reason: reason)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(result.success ? Color.green.opacity(0.4) : Color.red.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.rays")
                        .font(.subheadline)
                    Text(L("Pre-execution Simulation"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Simulation status badge
            simulationBadge

            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var simulationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
            Text(result.success ? "Success" : "Will Revert")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(result.success ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        .foregroundColor(result.success ? .green : .red)
        .cornerRadius(8)
    }

    // MARK: - Explanation

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("This transaction will..."))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(result.explanation)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Gas Details

    private var gasDetailsSection: some View {
        VStack(spacing: 8) {
            gasRow(label: "Estimated Gas", value: result.formattedGasUsed, icon: "flame")
            gasRow(label: "Gas Cost", value: result.formattedGasCost, icon: "fuelpump")
            if result.totalCostWithValueWei != result.totalGasCostWei {
                gasRow(label: "Total Cost (incl. value)", value: result.formattedTotalCost, icon: "sum")
            }
        }
    }

    private func gasRow(label: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }

    // MARK: - Balance Changes

    private var balanceChangesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Expected Balance Changes"))
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(result.balanceChanges) { change in
                HStack(spacing: 8) {
                    Text(change.isOutgoing ? "-" : "+")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(change.isOutgoing ? .red : .green)
                        .frame(width: 12)

                    Text(change.symbol)
                        .font(.caption)
                        .fontWeight(.medium)

                    if change.amount != 0 {
                        Text(String(format: "%.6f", abs(change.amount)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Revert Reason

    private func revertReasonSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text(L("Revert Reason"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }

            Text(reason)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.red.opacity(0.8))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
        }
    }
}

// MARK: - PreExecResultView Loading State

/// A placeholder view shown while the simulation is in progress.
struct PreExecLoadingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text(L("Simulating transaction..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#if DEBUG
struct ReserveGasView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleChain = Chain(
            id: 1, name: "Ethereum", serverId: "eth", symbol: "ETH",
            nativeTokenAddress: "0x0000000000000000000000000000000000000000",
            rpcUrl: "https://eth.llamarpc.com", scanUrl: "https://etherscan.io",
            logo: "eth_logo", isEIP1559: true
        )

        let successResult = PreExecResult(
            success: true,
            revertReason: nil,
            estimatedGasUsed: BigUInt(21000),
            gasPriceWei: BigUInt(30_000_000_000), // 30 Gwei
            totalGasCostWei: BigUInt(630_000_000_000_000), // 0.00063 ETH
            totalCostWithValueWei: BigUInt(1_000_630_000_000_000_000), // ~1.00063 ETH
            explanation: "Send 1.0000 ETH to 0x1234...5678",
            balanceChanges: [
                PreExecBalanceChange(symbol: "ETH", amount: -1.0, isOutgoing: true)
            ],
            chain: sampleChain
        )

        let revertResult = PreExecResult(
            success: false,
            revertReason: "ERC20: transfer amount exceeds balance",
            estimatedGasUsed: BigUInt(0),
            gasPriceWei: BigUInt(30_000_000_000),
            totalGasCostWei: BigUInt(0),
            totalCostWithValueWei: BigUInt(0),
            explanation: "Send tokens to 0xAbCd...eF01",
            balanceChanges: [
                PreExecBalanceChange(symbol: "USDC", amount: -1000.0, isOutgoing: true)
            ],
            chain: sampleChain
        )

        ScrollView {
            VStack(spacing: 20) {
                // Reserve Gas Toggle
                ReserveGasToggle(chain: sampleChain)

                // Successful simulation
                PreExecResultView(result: successResult)

                // Failed simulation
                PreExecResultView(result: revertResult)

                // Loading state
                PreExecLoadingView()
            }
            .padding()
        }
    }
}
#endif
