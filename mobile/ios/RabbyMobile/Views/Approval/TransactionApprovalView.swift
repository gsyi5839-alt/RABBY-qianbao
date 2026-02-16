import SwiftUI

/// Transaction Approval View - DApp transaction signing/approval flow
/// Corresponds to: src/ui/views/Approval/
struct TransactionApprovalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var securityEngine = SecurityEngineManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    
    let approval: ApprovalRequest
    var onApprove: ((String) -> Void)?
    var onReject: (() -> Void)?
    
    @State private var isProcessing = false
    @State private var securityResults: [SecurityEngineManager.SecurityCheckResult] = []
    @State private var isCheckingSecurity = true
    @State private var showAdvancedGas = false
    @State private var gasLimit = ""
    @State private var gasPrice = ""
    @State private var maxFeePerGas = ""
    @State private var maxPriorityFee = ""

    // Balance change preview state
    // Uses `/v1/wallet/pre_exec_tx` when origin is available, falls back to local heuristics.
    @State private var balanceChangeItems: [BalanceChangeItem] = []
    @State private var balanceChangeRiskLevel: SecurityEngineManager.RiskLevel = .safe
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // DApp info
                    dappInfoSection
                    
                    // Transaction details
                    transactionDetailsSection
                    
                    // Security check results
                    securityCheckSection

                    // Balance change preview (above gas settings, per Rabby extension layout)
                    balanceChangeSection

                    // Gas settings
                    gasSettingsSection
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(L("Approve Transaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Reject")) { rejectTransaction() }
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // Prefill gas fields if the DApp provided them.
            if gasLimit.isEmpty {
                gasLimit = approval.gasLimit ?? approval.gas ?? ""
            }
            if gasPrice.isEmpty {
                gasPrice = approval.gasPrice ?? ""
            }
            if maxFeePerGas.isEmpty {
                maxFeePerGas = approval.maxFeePerGas ?? ""
            }
            if maxPriorityFee.isEmpty {
                maxPriorityFee = approval.maxPriorityFeePerGas ?? ""
            }
            performSecurityCheck()
            parseBalanceChanges()
        }
    }
    
    // MARK: - Sections
    
    private var dappInfoSection: some View {
        VStack(spacing: 8) {
            if let origin = approval.origin {
                HStack(spacing: 8) {
                    if let iconUrl = approval.iconUrl, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().frame(width: 40, height: 40).cornerRadius(8)
                        } placeholder: { Color.gray.frame(width: 40, height: 40).cornerRadius(8) }
                    }
                    VStack(alignment: .leading) {
                        Text(approval.siteName ?? LocalizationManager.shared.t("Unknown DApp")).font(.headline)
                        Text(origin).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var transactionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Transaction Details")).font(.headline)
            
            detailRow(LocalizationManager.shared.t("From"), value: formatAddress(approval.from))
            if let to = approval.to { detailRow(LocalizationManager.shared.t("To"), value: formatAddress(to)) }
            if let value = approval.value, value != "0x0" {
                detailRow(LocalizationManager.shared.t("Value"), value: LocalizationManager.shared.t("ios.approval.txValue", args: ["value": formatWei(value)]))
            }
            if let data = approval.data, data.count > 2 {
                detailRow(LocalizationManager.shared.t("Method"), value: decodeMethod(data))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Data")).font(.caption).foregroundColor(.secondary)
                    Text(verbatim: String(data.prefix(66)) + "...")
                        .font(.system(.caption2, design: .monospaced))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    private var securityCheckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Security Check")).font(.headline)
                Spacer()
                if isCheckingSecurity {
                    ProgressView().scaleEffect(0.8)
                } else {
                    let dangerCount = securityResults.filter { $0.level == .danger || $0.level == .forbidden }.count
                    if dangerCount > 0 {
                        Label(LocalizationManager.shared.t("ios.approval.riskCount", args: ["count": "\(dangerCount)"]), systemImage: "exclamationmark.triangle.fill").foregroundColor(.red).font(.caption)
                    } else {
                        Label(L("Safe"), systemImage: "checkmark.shield.fill").foregroundColor(.green).font(.caption)
                    }
                }
            }

            if !isCheckingSecurity && securityResults.isEmpty {
                Text(L("No security issues detected."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(securityResults), id: \.ruleId) { result in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(securityColor(result.level))
                            .frame(width: 8, height: 8)
                        Text(verbatim: result.message)
                            .font(.caption)
                            .foregroundColor(securityColor(result.level))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    /// Balance change preview section - shows predicted token/NFT balance changes
    /// from executing this transaction. Positioned above Gas Settings to match
    /// the Rabby browser extension approval flow layout.
    private var balanceChangeSection: some View {
        BalanceChangeView(
            changes: balanceChangeItems,
            riskLevel: balanceChangeRiskLevel
        )
    }

    private var gasSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showAdvancedGas.toggle() }) {
                HStack {
                    Text(L("Gas Settings")).font(.headline)
                    Spacer()
                    Image(systemName: showAdvancedGas ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            
            if showAdvancedGas {
                TextField(L("Gas Limit"), text: $gasLimit).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                
                if approval.isEIP1559 {
                    TextField(L("Max Fee Per Gas (Gwei)"), text: $maxFeePerGas).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                    TextField(L("Max Priority Fee (Gwei)"), text: $maxPriorityFee).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                } else {
                    TextField(L("Gas Price (Gwei)"), text: $gasPrice).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: rejectTransaction) {
                Text(L("Reject"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            
            Button(action: approveTransaction) {
                HStack {
                    if isProcessing { ProgressView().tint(.white) }
                    Text(isProcessing ? L("Signing...") : L("Approve"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(hasDangerousRisk ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Helpers
    
    private var hasDangerousRisk: Bool {
        securityResults.contains { $0.level == .danger || $0.level == .forbidden }
    }
    
    private func performSecurityCheck() {
        Task {
            isCheckingSecurity = true
            if let chain = ChainManager.shared.selectedChain {
                securityResults = await securityEngine.checkTransaction(
                    from: approval.from, to: approval.to ?? "", value: approval.value ?? "0x0",
                    data: approval.data ?? "0x",
                    chain: chain,
                    origin: approval.origin,
                    nonce: approval.nonce,
                    gas: approval.gas,
                    gasLimit: approval.gasLimit,
                    gasPrice: approval.gasPrice,
                    maxFeePerGas: approval.maxFeePerGas,
                    maxPriorityFeePerGas: approval.maxPriorityFeePerGas
                )
            }
            isCheckingSecurity = false
        }
    }

    /// Balance change preview:
    /// - Uses OpenAPI simulation `/v1/wallet/pre_exec_tx` when origin is available.
    /// - Falls back to local heuristics when API is unavailable or origin is missing.
    private func parseBalanceChanges() {
        Task {
            if let chain = ChainManager.shared.selectedChain,
               let to = approval.to {
                if let explain = await securityEngine.preExecTransaction(
                    from: approval.from,
                    to: to,
                    value: approval.value ?? "0x0",
                    data: approval.data ?? "0x",
                    chain: chain,
                    origin: approval.origin,
                    nonce: approval.nonce,
                    gas: approval.gas,
                    gasLimit: approval.gasLimit,
                    gasPrice: approval.gasPrice,
                    maxFeePerGas: approval.maxFeePerGas,
                    maxPriorityFeePerGas: approval.maxPriorityFeePerGas
                ) {
                    applyPreExecBalanceChange(explain)
                    // Add an extra risk hint for infinite approvals (matches extension behavior).
                    if explain.type_token_approval?.is_infinity == true {
                        balanceChangeRiskLevel = .danger
                    }
                    return
                }
            }

            // Fallback: heuristic parser when API is unavailable / rate-limited.
            let result = BalanceChangeParser.parse(approval: approval)
            balanceChangeItems = result.changes
            balanceChangeRiskLevel = result.riskLevel
        }
    }

    private func applyPreExecBalanceChange(_ explain: OpenAPIService.WalletExplainTxResponse) {
        let bc = explain.balance_change
        var items: [BalanceChangeItem] = []

        func tokenUsdValue(_ t: OpenAPIService.WalletTokenItem) -> Double? {
            if let v = t.usd_value { return v }
            if t.price > 0 { return t.price * t.amount }
            return nil
        }

        for t in bc.send_token_list {
            items.append(BalanceChangeItem(
                tokenSymbol: t.symbol,
                tokenLogoUrl: t.logo_url,
                chainId: t.chain,
                amount: -abs(t.amount),
                usdValue: tokenUsdValue(t).map { -abs($0) },
                isNFT: false,
                nftName: nil
            ))
        }

        for t in bc.receive_token_list {
            items.append(BalanceChangeItem(
                tokenSymbol: t.symbol,
                tokenLogoUrl: t.logo_url,
                chainId: t.chain,
                amount: abs(t.amount),
                usdValue: tokenUsdValue(t).map { abs($0) },
                isNFT: false,
                nftName: nil
            ))
        }

        for n in bc.send_nft_list {
            items.append(BalanceChangeItem(
                tokenSymbol: "NFT",
                tokenLogoUrl: n.content,
                chainId: n.chain,
                amount: -abs(n.amount),
                usdValue: nil,
                isNFT: true,
                nftName: n.name
            ))
        }

        for n in bc.receive_nft_list {
            items.append(BalanceChangeItem(
                tokenSymbol: "NFT",
                tokenLogoUrl: n.content,
                chainId: n.chain,
                amount: abs(n.amount),
                usdValue: nil,
                isNFT: true,
                nftName: n.name
            ))
        }

        balanceChangeItems = items
        balanceChangeRiskLevel = .safe
        if !bc.success {
            // Keep the UI stable: show empty preview state when simulation fails.
            balanceChangeItems = []
        }
    }
    
    private func approveTransaction() {
        isProcessing = true
        Task {
            do {
                let txHash = try await keyringManager.signAndSendTransaction(
                    from: approval.from, to: approval.to, value: approval.value,
                    data: approval.data, gasLimit: gasLimit.isEmpty ? nil : gasLimit,
                    gasPrice: gasPrice.isEmpty ? nil : gasPrice,
                    maxFeePerGas: maxFeePerGas.isEmpty ? nil : maxFeePerGas,
                    maxPriorityFeePerGas: maxPriorityFee.isEmpty ? nil : maxPriorityFee
                )
                onApprove?(txHash)
                dismiss()
            } catch {
                print("Approval failed: \(error)")
            }
            isProcessing = false
        }
    }
    
    private func rejectTransaction() {
        onReject?()
        dismiss()
    }
    
    private func securityColor(_ level: SecurityEngineManager.RiskLevel) -> Color {
        switch level { case .safe: return .green; case .warning: return .orange; case .danger, .forbidden: return .red }
    }
    
    private func detailRow(_ label: String, value: String) -> some View {
        HStack { Text(label).font(.caption).foregroundColor(.secondary); Spacer(); Text(verbatim: value).font(.caption).fontWeight(.medium) }
    }
    
    private func formatAddress(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
    
    private func formatWei(_ hex: String) -> String {
        // Simplified hex to ETH conversion
        guard hex.hasPrefix("0x"), let value = UInt64(hex.dropFirst(2), radix: 16) else { return "0" }
        return String(format: "%.6f", Double(value) / 1e18)
    }
    
    private func decodeMethod(_ data: String) -> String {
        guard data.count >= 10 else { return LocalizationManager.shared.t("Unknown") }
        let selector = String(data.prefix(10))
        let methodMap: [String: String] = [
            "0xa9059cbb": LocalizationManager.shared.t("Transfer"),
            "0x095ea7b3": LocalizationManager.shared.t("Approve"),
            "0x23b872dd": LocalizationManager.shared.t("TransferFrom"),
            "0x38ed1739": LocalizationManager.shared.t("SwapExactTokensForTokens"),
            "0x7ff36ab5": LocalizationManager.shared.t("SwapExactETHForTokens"),
            "0x18cbafe5": LocalizationManager.shared.t("SwapExactTokensForETH"),
            "0x5c11d795": LocalizationManager.shared.t("SwapExactTokensForTokensSupportingFee"),
            "0x3593564c": LocalizationManager.shared.t("Execute (Universal Router)"),
            "0x0162e2d0": LocalizationManager.shared.t("Swap (1inch)"),
        ]
        return methodMap[selector] ?? LocalizationManager.shared.t("ios.approval.contractInteraction", args: ["selector": selector])
    }
}

// MARK: - Approval Request Model

struct ApprovalRequest: Identifiable {
    let id: String
    let from: String
    let to: String?
    let value: String?
    let data: String?
    /// Optional transaction fields (may be provided by the DApp).
    let nonce: String?
    let gas: String?
    let gasLimit: String?
    let gasPrice: String?
    let maxFeePerGas: String?
    let maxPriorityFeePerGas: String?
    /// For `signText` approvals: raw message string (hex string or plain text).
    let message: String?
    /// For `signTypedData` approvals: full typed data JSON string (EIP-712 v4).
    let typedDataJSON: String?
    /// The original RPC method name (e.g. "personal_sign", "eth_signTypedData_v4").
    let signMethod: String?
    let chainId: Int
    let origin: String?
    let siteName: String?
    let iconUrl: String?
    let isEIP1559: Bool
    let type: ApprovalType

    enum ApprovalType {
        case signTx
        case signText
        case signTypedData
        case connect
    }

    // Convenience initializer without signMethod for backward compatibility
    init(
        id: String, from: String, to: String?, value: String?, data: String?,
        nonce: String? = nil,
        gas: String? = nil,
        gasLimit: String? = nil,
        gasPrice: String? = nil,
        maxFeePerGas: String? = nil,
        maxPriorityFeePerGas: String? = nil,
        message: String?, typedDataJSON: String?, signMethod: String? = nil,
        chainId: Int, origin: String?, siteName: String?, iconUrl: String?,
        isEIP1559: Bool, type: ApprovalType
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.value = value
        self.data = data
        self.nonce = nonce
        self.gas = gas
        self.gasLimit = gasLimit
        self.gasPrice = gasPrice
        self.maxFeePerGas = maxFeePerGas
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.message = message
        self.typedDataJSON = typedDataJSON
        self.signMethod = signMethod
        self.chainId = chainId
        self.origin = origin
        self.siteName = siteName
        self.iconUrl = iconUrl
        self.isEIP1559 = isEIP1559
        self.type = type
    }
}

/// Sign Text Approval View
struct SignTextApprovalView: View {
    let text: String
    let origin: String?
    let signerAddress: String?
    let siteName: String?
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?
    @Environment(\.dismiss) var dismiss

    /// Attempt to decode a hex-encoded personal_sign message to a human-readable UTF-8 string.
    private var displayText: String {
        if text.hasPrefix("0x"), text.count > 2 {
            let hexBody = String(text.dropFirst(2))
            // Try to decode hex to UTF-8 string
            if let data = Data(hexString: hexBody),
               let decoded = String(data: data, encoding: .utf8),
               decoded.allSatisfy({ !$0.isASCII || ($0.asciiValue ?? 0) >= 0x20 || $0.isNewline }) {
                return decoded
            }
        }
        return text
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // DApp info
                VStack(spacing: 4) {
                    if let name = siteName ?? origin {
                        Text(name).font(.headline)
                    }
                    if let origin = origin {
                        Text(origin).font(.caption).foregroundColor(.secondary)
                    }
                }

                // Signer address
                if let addr = signerAddress {
                    HStack {
                        Text(L("Signing Address")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(verbatim: EthereumUtil.formatAddress(addr)).font(.caption).fontWeight(.medium)
                    }
                    .padding(.horizontal)
                }

                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Message to Sign")).font(.headline)
                    ScrollView {
                        Text(verbatim: displayText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                Spacer()

                // Actions
                HStack(spacing: 16) {
                    Button(L("Reject")) { onReject?(); dismiss() }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color(.systemGray5)).cornerRadius(12)
                    Button(L("Sign")) { onApprove?(); dismiss() }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle(L("Sign Message"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Sign TypedData (EIP-712 v4) Approval View
struct SignTypedDataApprovalView: View {
    let typedDataJSON: String
    let origin: String?
    let signerAddress: String?
    let siteName: String?
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @StateObject private var securityEngine = SecurityEngineManager.shared
    @State private var securityResults: [SecurityEngineManager.SecurityCheckResult] = []

    // Parse the typed data for structured display
    private var parsedData: (domain: [String: Any], primaryType: String, message: [String: Any])? {
        guard let data = typedDataJSON.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let domain = obj["domain"] as? [String: Any],
              let primaryType = obj["primaryType"] as? String,
              let message = obj["message"] as? [String: Any] else {
            return nil
        }
        return (domain, primaryType, message)
    }

    private var prettyJSON: String {
        guard let data = typedDataJSON.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return typedDataJSON
        }
        return str
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // DApp info
                    VStack(spacing: 4) {
                        if let name = siteName ?? origin {
                            Text(name).font(.headline)
                        }
                        if let origin = origin {
                            Text(origin).font(.caption).foregroundColor(.secondary)
                        }
                    }

                    // Signer address
                    if let addr = signerAddress {
                        HStack {
                            Text(L("Signing Address")).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(verbatim: EthereumUtil.formatAddress(addr)).font(.caption).fontWeight(.medium)
                        }
                        .padding(.horizontal)
                    }

                    // Security checks (best-effort, extension-compatible)
                    if !securityResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Security Check"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            ForEach(Array(securityResults.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(securityColor(item.level))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 4)
                                    Text(item.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Structured typed data display
                    if let parsed = parsedData {
                        // Domain info
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("Domain")).font(.subheadline).fontWeight(.semibold)
                            ForEach(Array(parsed.domain.keys.sorted()), id: \.self) { key in
                                let valueString = String(describing: parsed.domain[key] ?? "")
                                HStack {
                                    Text(key).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(verbatim: valueString)
                                        .font(.caption).fontWeight(.medium)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)

                        // Primary type
                        HStack {
                            Text(L("Primary Type")).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(parsed.primaryType).font(.caption).fontWeight(.bold).foregroundColor(.blue)
                        }
                        .padding(.horizontal)

                        // Message fields
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("Message")).font(.subheadline).fontWeight(.semibold)
                            ForEach(Array(parsed.message.keys.sorted()), id: \.self) { key in
                                let valueString = String(describing: parsed.message[key] ?? "")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key).font(.caption).foregroundColor(.secondary)
                                    Text(verbatim: valueString)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(3)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else {
                        // Fallback: raw JSON
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Typed Data to Sign")).font(.headline)
                            ScrollView {
                                Text(verbatim: prettyJSON)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 380)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    // Actions
                    HStack(spacing: 16) {
                        Button(L("Reject")) { onReject?(); dismiss() }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(.systemGray5)).cornerRadius(12)
                        Button(L("Sign")) { onApprove?(); dismiss() }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }
                    .padding()
                }
                .padding(.top)
            }
            .navigationTitle(L("Sign Typed Data"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            Task {
                guard let addr = signerAddress, !addr.isEmpty else { return }
                securityResults = await securityEngine.checkSignMessage(
                    from: addr,
                    message: typedDataJSON,
                    origin: origin
                )
            }
        }
    }

    private func securityColor(_ level: SecurityEngineManager.RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .warning: return .orange
        case .danger, .forbidden: return .red
        }
    }
}
