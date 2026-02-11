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
                    
                    // Gas settings
                    gasSettingsSection
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Approve Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reject") { rejectTransaction() }
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear { performSecurityCheck() }
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
                        Text(approval.siteName ?? "Unknown DApp").font(.headline)
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
            Text("Transaction Details").font(.headline)
            
            detailRow("From", value: formatAddress(approval.from))
            if let to = approval.to { detailRow("To", value: formatAddress(to)) }
            if let value = approval.value, value != "0x0" {
                detailRow("Value", value: formatWei(value) + " ETH")
            }
            if let data = approval.data, data.count > 2 {
                detailRow("Method", value: decodeMethod(data))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data").font(.caption).foregroundColor(.secondary)
                    Text(data.prefix(66) + "...")
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
                Text("Security Check").font(.headline)
                Spacer()
                if securityResults.isEmpty {
                    ProgressView().scaleEffect(0.8)
                } else {
                    let dangerCount = securityResults.filter { $0.level == .danger || $0.level == .forbidden }.count
                    if dangerCount > 0 {
                        Label("\(dangerCount) Risk(s)", systemImage: "exclamationmark.triangle.fill").foregroundColor(.red).font(.caption)
                    } else {
                        Label("Safe", systemImage: "checkmark.shield.fill").foregroundColor(.green).font(.caption)
                    }
                }
            }
            
            ForEach(Array(securityResults), id: \.ruleId) { result in
                HStack(spacing: 8) {
                    Circle()
                        .fill(securityColor(result.level))
                        .frame(width: 8, height: 8)
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(securityColor(result.level))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var gasSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showAdvancedGas.toggle() }) {
                HStack {
                    Text("Gas Settings").font(.headline)
                    Spacer()
                    Image(systemName: showAdvancedGas ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            
            if showAdvancedGas {
                TextField("Gas Limit", text: $gasLimit).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                
                if approval.isEIP1559 {
                    TextField("Max Fee Per Gas (Gwei)", text: $maxFeePerGas).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                    TextField("Max Priority Fee (Gwei)", text: $maxPriorityFee).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                } else {
                    TextField("Gas Price (Gwei)", text: $gasPrice).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
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
                Text("Reject")
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
                    Text(isProcessing ? "Signing..." : "Approve")
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
    
    private func approveTransaction() {
        isProcessing = true
        Task {
            do {
                let txHash = try await keyringManager.signAndSendTransaction(
                    from: approval.from, to: approval.to, value: approval.value,
                    data: approval.data, gasLimit: gasLimit.isEmpty ? nil : gasLimit,
                    gasPrice: gasPrice.isEmpty ? nil : gasPrice
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
        HStack { Text(label).font(.caption).foregroundColor(.secondary); Spacer(); Text(value).font(.caption).fontWeight(.medium) }
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
        guard data.count >= 10 else { return "Unknown" }
        let selector = String(data.prefix(10))
        let methodMap: [String: String] = [
            "0xa9059cbb": "Transfer", "0x095ea7b3": "Approve", "0x23b872dd": "TransferFrom",
            "0x38ed1739": "SwapExactTokensForTokens", "0x7ff36ab5": "SwapExactETHForTokens",
            "0x18cbafe5": "SwapExactTokensForETH", "0x5c11d795": "SwapExactTokensForTokensSupportingFee",
            "0x3593564c": "Execute (Universal Router)", "0x0162e2d0": "Swap (1inch)",
        ]
        return methodMap[selector] ?? "Contract Interaction (\(selector))"
    }
}

// MARK: - Approval Request Model

struct ApprovalRequest: Identifiable {
    let id: String
    let from: String
    let to: String?
    let value: String?
    let data: String?
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
}

/// Sign Text Approval View
struct SignTextApprovalView: View {
    let text: String
    let origin: String?
    let siteName: String?
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // DApp info
                if let name = siteName {
                    Text(name).font(.headline)
                    if let origin = origin { Text(origin).font(.caption).foregroundColor(.secondary) }
                }
                
                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message to Sign").font(.headline)
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
                
                Spacer()
                
                // Actions
                HStack(spacing: 16) {
                    Button("Reject") { onReject?(); dismiss() }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color(.systemGray5)).cornerRadius(12)
                    Button("Sign") { onApprove?(); dismiss() }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Sign Message")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
