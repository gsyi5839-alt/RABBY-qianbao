import SwiftUI
import BigInt

/// Transaction Detail View - Shows full details for a transaction group
struct TransactionDetailView: View {
    let transactionGroup: TransactionHistoryManager.TransactionGroup
    let chainId: String

    @StateObject private var transactionManager = TransactionManager.shared
    @StateObject private var chainManager = ChainManager.shared

    @State private var showSpeedUp = false
    @State private var showCancel = false
    @State private var showCopiedToast = false
    @State private var copiedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false

    @Environment(\.openURL) private var openURL

    /// Convenience accessor for the latest transaction in the group
    private var tx: TransactionHistoryManager.TransactionHistoryItem? {
        transactionGroup.latestTx
    }

    /// Resolved chain object from ChainManager
    private var chain: Chain? {
        // Try numeric chain ID first, then serverId
        if let numericId = Int(chainId) {
            return chainManager.getChain(id: numericId)
        }
        return chainManager.getChain(serverId: chainId)
    }

    /// Chain display name
    private var chainName: String {
        chain?.name ?? chainId
    }

    /// Native token symbol for the chain
    private var nativeSymbol: String {
        chain?.symbol ?? "ETH"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard
                detailsSection
                actionButtons
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L("Transaction Detail"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(L("Transaction Detail"))
                        .font(.headline)
                    Text(chainName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                copiedToastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
        .sheet(isPresented: $showSpeedUp) {
            speedUpSheet
        }
        .alert(L("Cancel Transaction"), isPresented: $showCancel) {
            Button(L("Confirm Cancel"), role: .destructive) {
                performCancel()
            }
            Button(L("Back"), role: .cancel) {}
        } message: {
            Text("This will send a 0 \(nativeSymbol) transaction to yourself with the same nonce to replace the pending transaction.")
        }
        .alert(L("Error"), isPresented: $showError) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 12) {
            // Status icon
            statusIconView
                .frame(width: 56, height: 56)

            // Status text
            Text(statusText)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(statusColor)

            // Amount or type description
            if let tx = tx {
                Text(transactionAmountText(tx))
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var statusIconView: some View {
        if transactionGroup.isPending {
            Image(systemName: "clock.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)
        } else if transactionGroup.isFailed {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)
        }
    }

    private var statusText: String {
        if transactionGroup.isPending { return "Pending" }
        if transactionGroup.isFailed { return "Failed" }
        return "Confirmed"
    }

    private var statusColor: Color {
        if transactionGroup.isPending { return .orange }
        if transactionGroup.isFailed { return .red }
        return .green
    }

    private func transactionAmountText(_ tx: TransactionHistoryManager.TransactionHistoryItem) -> String {
        // Check if this is a contract interaction with no value (approval, etc.)
        let valueStr = tx.value
        if valueStr == "0" || valueStr == "0x0" || valueStr == "0x" || valueStr.isEmpty {
            // Check data for known function signatures
            if tx.data.hasPrefix("0x095ea7b3") {
                return "Token Approval"
            } else if tx.data.hasPrefix("0xa9059cbb") {
                return "Token Transfer"
            } else if tx.data.count > 2 && tx.data != "0x" {
                return "Contract Interaction"
            }
            return "0 \(nativeSymbol)"
        }

        // Parse and format the value
        if let weiValue = parseValue(valueStr) {
            let etherValue = EthereumUtil.weiToEther(weiValue)
            let formatted = formatDecimal(etherValue)
            return "-\(formatted) \(nativeSymbol)"
        }

        return "-\(valueStr) \(nativeSymbol)"
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 0) {
            if let tx = tx {
                detailRow(title: "From", value: tx.from, isCopyable: true)
                divider
                detailRow(title: "To", value: tx.to, isCopyable: true)
                divider
                detailRow(title: "Value", value: formattedValue(tx.value))
                divider

                if let gasUsed = tx.gasUsed {
                    detailRow(title: "Gas Used", value: gasUsed)
                    divider
                }

                if let gasPrice = tx.gasPrice {
                    detailRow(title: "Gas Price", value: formattedGasPrice(gasPrice))
                    divider

                    if let gasUsed = tx.gasUsed {
                        detailRow(title: "Total Fee", value: formattedTotalFee(gasUsed: gasUsed, gasPrice: gasPrice))
                        divider
                    }
                }

                detailRow(title: "Nonce", value: "\(tx.nonce)")
                divider

                detailRow(title: "Block Number", value: transactionGroup.isPending ? "Pending" : "Confirmed")
                divider

                detailRow(title: "Timestamp", value: formattedTimestamp(tx.createdAt))
                divider

                detailRow(title: "Transaction Hash", value: tx.hash, isCopyable: true)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var divider: some View {
        Divider().padding(.leading, 16)
    }

    private func detailRow(title: String, value: String, isCopyable: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)

            Spacer()

            if isCopyable {
                Button(action: {
                    copyToClipboard(value)
                }) {
                    HStack(spacing: 4) {
                        Text(abbreviateIfAddress(value))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // View on Explorer button
            Button(action: openExplorer) {
                HStack {
                    Image(systemName: "safari")
                    Text(L("View on Explorer"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.body.weight(.semibold))
            }

            // Pending-only actions
            if transactionGroup.isPending {
                HStack(spacing: 12) {
                    // Speed Up button
                    Button(action: { showSpeedUp = true }) {
                        HStack {
                            Image(systemName: "hare")
                            Text(L("Speed Up"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .font(.body.weight(.semibold))
                    }
                    .disabled(isProcessing)

                    // Cancel button
                    Button(action: { showCancel = true }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(L("Cancel"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemBackground))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 1.5)
                        )
                        .font(.body.weight(.semibold))
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    // MARK: - Speed Up Sheet

    private var speedUpSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "hare.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text(L("Speed Up Transaction"))
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    if let gasPrice = tx?.gasPrice {
                        gasPriceRow(title: "Current Gas Price", value: formattedGasPrice(gasPrice))
                        gasPriceRow(title: "New Gas Price (x1.1)", value: formattedSpeedUpGasPrice(gasPrice))
                    } else {
                        Text(L("Gas price will be increased by 10%"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                Text(L("A replacement transaction with higher gas will be submitted."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button(action: {
                    showSpeedUp = false
                    performSpeedUp()
                }) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text(L("Confirm Speed Up"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.body.weight(.semibold))
                .disabled(isProcessing)
            }
            .padding()
            .navigationTitle(L("Speed Up"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        showSpeedUp = false
                    }
                }
            }
        }
        .modifier(SheetPresentationModifier(detents: [.medium]))
    }

    private func gasPriceRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Copied Toast

    private var copiedToastView: some View {
        Text("Copied: \(abbreviateIfAddress(copiedText))")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .padding(.bottom, 16)
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        copiedText = text
        showCopiedToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopiedToast = false
        }
    }

    private func openExplorer() {
        guard let hash = tx?.hash else { return }
        let explorerURL = buildExplorerURL(hash: hash)
        if let url = URL(string: explorerURL) {
            openURL(url)
        }
    }

    private func performSpeedUp() {
        guard let tx = tx else { return }
        isProcessing = true

        // Build a TransactionHistoryItem compatible with TransactionManager.speedUpTransaction
        let historyItem = buildTransactionHistoryItem(from: tx)

        Task {
            do {
                let _ = try await transactionManager.speedUpTransaction(originalTx: historyItem)
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    if error is CancellationError { return }
                    errorMessage = "Speed up failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func performCancel() {
        guard let tx = tx else { return }
        isProcessing = true

        let historyItem = buildTransactionHistoryItem(from: tx)

        Task {
            do {
                let _ = try await transactionManager.cancelTransaction(originalTx: historyItem)
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    if error is CancellationError { return }
                    errorMessage = "Cancel failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    // MARK: - Helpers

    /// Build a TransactionHistoryItem (TransactionManager's type) from a TransactionHistoryManager.TransactionHistoryItem
    private func buildTransactionHistoryItem(from tx: TransactionHistoryManager.TransactionHistoryItem) -> TransactionHistoryItem {
        let chainIdInt = Int(chainId) ?? chain?.id ?? 1
        let nonceValue = BigUInt(tx.nonce)
        let valueData = tx.value.hexToData() ?? Data()
        let valueBigUInt = BigUInt(valueData)
        let txData = tx.data.hexToData() ?? Data()

        var gasPriceBigUInt: BigUInt? = nil
        if let gp = tx.gasPrice {
            gasPriceBigUInt = parseBigUIntFromString(gp)
        }

        let ethTx = EthereumTransaction(
            to: tx.to,
            from: tx.from,
            nonce: nonceValue,
            value: valueBigUInt,
            data: txData,
            gasLimit: BigUInt(21000),
            chainId: chainIdInt
        )

        var builtTx = ethTx
        builtTx.gasPrice = gasPriceBigUInt

        return TransactionHistoryItem(
            rawTx: builtTx,
            createdAt: tx.createdAt.timeIntervalSince1970,
            isCompleted: !transactionGroup.isPending,
            completedAt: tx.completedAt?.timeIntervalSince1970,
            hash: tx.hash,
            failed: transactionGroup.isFailed,
            gasUsed: tx.gasUsed != nil ? Int(tx.gasUsed!) : nil
        )
    }

    /// Parse a value string that could be hex or decimal into BigUInt
    private func parseBigUIntFromString(_ str: String) -> BigUInt {
        if str.hasPrefix("0x") || str.hasPrefix("0X") {
            return TransactionManager.parseBigUIntFromHex(str)
        }
        return BigUInt(str) ?? BigUInt(0)
    }

    /// Parse value from hex or decimal string
    private func parseValue(_ value: String) -> BigUInt? {
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            let hex = String(value.dropFirst(2))
            return BigUInt(hex, radix: 16)
        }
        return BigUInt(value)
    }

    /// Format a value string (hex or decimal wei) to readable ether
    private func formattedValue(_ value: String) -> String {
        if let weiValue = parseValue(value), weiValue > 0 {
            let etherValue = EthereumUtil.weiToEther(weiValue)
            return "\(formatDecimal(etherValue)) \(nativeSymbol)"
        }
        return "0 \(nativeSymbol)"
    }

    /// Format gas price string to Gwei display
    private func formattedGasPrice(_ gasPrice: String) -> String {
        if let gpWei = parseValue(gasPrice) {
            let gwei = EthereumUtil.weiToGwei(gpWei)
            return "\(formatDecimal(gwei)) Gwei"
        }
        return "\(gasPrice) Gwei"
    }

    /// Format the speed-up gas price (current * 1.1)
    private func formattedSpeedUpGasPrice(_ gasPrice: String) -> String {
        if let gpWei = parseValue(gasPrice) {
            let newGpWei = gpWei * 11 / 10
            let gwei = EthereumUtil.weiToGwei(newGpWei)
            return "\(formatDecimal(gwei)) Gwei"
        }
        return "N/A"
    }

    /// Format total fee from gasUsed and gasPrice
    private func formattedTotalFee(gasUsed: String, gasPrice: String) -> String {
        guard let gasUsedVal = parseValue(gasUsed),
              let gasPriceVal = parseValue(gasPrice) else {
            return "N/A"
        }

        let totalWei = gasUsedVal * gasPriceVal
        let totalEther = EthereumUtil.weiToEther(totalWei)
        return "\(formatDecimal(totalEther)) \(nativeSymbol)"
    }

    /// Format a Decimal to a human-readable string
    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.groupingSeparator = ""
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Format Date to readable timestamp
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// Abbreviate long strings (addresses, hashes) for display
    private func abbreviateIfAddress(_ text: String) -> String {
        guard text.count > 14 else { return text }
        let start = text.prefix(8)
        let end = text.suffix(6)
        return "\(start)...\(end)"
    }

    /// Build explorer URL from chain info and transaction hash
    private func buildExplorerURL(hash: String) -> String {
        // Use the chain's scanUrl if available
        if let chain = chain {
            let baseURL = chain.scanUrl.hasSuffix("/") ? String(chain.scanUrl.dropLast()) : chain.scanUrl
            return "\(baseURL)/tx/\(hash)"
        }

        // Fallback: map well-known chain IDs to explorers
        let chainIdInt = Int(chainId) ?? 1
        switch chainIdInt {
        case 1:
            return "https://etherscan.io/tx/\(hash)"
        case 56:
            return "https://bscscan.com/tx/\(hash)"
        case 137:
            return "https://polygonscan.com/tx/\(hash)"
        case 42161:
            return "https://arbiscan.io/tx/\(hash)"
        case 10:
            return "https://optimistic.etherscan.io/tx/\(hash)"
        case 43114:
            return "https://snowtrace.io/tx/\(hash)"
        case 250:
            return "https://ftmscan.com/tx/\(hash)"
        case 8453:
            return "https://basescan.org/tx/\(hash)"
        case 324:
            return "https://explorer.zksync.io/tx/\(hash)"
        case 59144:
            return "https://lineascan.build/tx/\(hash)"
        default:
            return "https://etherscan.io/tx/\(hash)"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TransactionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTx = TransactionHistoryManager.TransactionHistoryItem(
            id: "0xabc123_eth",
            hash: "0xabc123def456789012345678901234567890abcdef1234567890abcdef123456",
            from: "0x1234567890abcdef1234567890abcdef12345678",
            to: "0xabcdef1234567890abcdef1234567890abcdef12",
            value: "0x2386f26fc10000",
            data: "0x",
            chainId: "eth",
            nonce: 42,
            gasUsed: "21000",
            gasPrice: "0x12a05f200",
            status: .confirmed,
            createdAt: Date().addingTimeInterval(-3600),
            completedAt: Date(),
            isSubmitFailed: false
        )

        let sampleGroup = TransactionHistoryManager.TransactionGroup(
            id: "0x1234_eth_42",
            chainId: "eth",
            nonce: 42,
            txs: [sampleTx],
            isPending: false,
            createdAt: Date().addingTimeInterval(-3600),
            completedAt: Date(),
            isFailed: false,
            isSubmitFailed: false
        )

        NavigationView {
            TransactionDetailView(transactionGroup: sampleGroup, chainId: "eth")
        }
    }
}
#endif
