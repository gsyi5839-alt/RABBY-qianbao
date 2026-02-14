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
    @State private var showAdvancedGas = false
    @State private var gasLimit = ""
    @State private var gasPrice = ""
    @State private var maxFeePerGas = ""
    @State private var maxPriorityFee = ""

    // Balance change preview state
    // Currently parsed locally from tx data. Future: integrate with OpenAPI preExec
    // endpoint (POST /v1/tx/pre_exec) for simulation-based accurate balance changes.
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
                if securityResults.isEmpty {
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
            if let chain = ChainManager.shared.selectedChain {
                securityResults = await securityEngine.checkTransaction(
                    from: approval.from, to: approval.to ?? "", value: approval.value ?? "0x0",
                    data: approval.data ?? "0x", chain: chain
                )
            }
        }
    }

    /// Parse balance changes from the approval request using local heuristics.
    /// This provides an immediate preview. For production accuracy, replace with
    /// OpenAPI preExec simulation: POST /v1/tx/pre_exec which returns the actual
    /// balance diff from executing the transaction on a forked state.
    private func parseBalanceChanges() {
        let result = BalanceChangeParser.parse(approval: approval)
        balanceChangeItems = result.changes
        balanceChangeRiskLevel = result.riskLevel
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
        message: String?, typedDataJSON: String?, signMethod: String? = nil,
        chainId: Int, origin: String?, siteName: String?, iconUrl: String?,
        isEIP1559: Bool, type: ApprovalType
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.value = value
        self.data = data
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
    }
}

