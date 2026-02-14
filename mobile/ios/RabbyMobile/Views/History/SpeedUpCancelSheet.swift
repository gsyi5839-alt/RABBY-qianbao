import SwiftUI

/// Transaction Speed Up / Cancel sheet
/// Corresponds to: src/ui/views/TransactionHistory/components/CancelTx
struct SpeedUpCancelSheet: View {
    @Environment(\.dismiss) var dismiss

    enum Mode { case speedUp, cancel }

    let mode: Mode
    let originalTx: PendingTransaction
    var onConfirm: ((String) -> Void)?

    @State private var gasMultiplier: Double = 1.1
    @State private var customGasPrice = ""
    @State private var isProcessing = false

    let multiplierPresets: [(String, Double)] = [
        ("+10%", 1.1), ("+20%", 1.2), ("+50%", 1.5), ("Custom", 0)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Transaction summary
                txSummarySection

                if mode == .speedUp {
                    speedUpSection
                } else {
                    cancelSection
                }

                // Cost comparison
                costComparison

                Spacer()

                // Confirm button
                confirmButton

                // Disclaimer
                Text(mode == .cancel
                    ? "Cancellation is not guaranteed if the original tx is already being mined."
                    : "Speed up replaces your transaction with a higher gas fee.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(mode == .speedUp ? "Speed Up" : "Cancel Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Close")) { dismiss() }
                }
            }
        }
    }

    private var txSummarySection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L("Transaction")).foregroundColor(.secondary)
                Spacer()
                Text(EthereumUtil.truncateAddress(originalTx.hash))
                    .font(.system(.caption, design: .monospaced))
            }
            HStack {
                Text(L("Nonce")).foregroundColor(.secondary)
                Spacer()
                Text("#\(originalTx.nonce)")
            }
            HStack {
                Text(L("To")).foregroundColor(.secondary)
                Spacer()
                Text(EthereumUtil.truncateAddress(originalTx.to))
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .font(.subheadline)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var speedUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Gas Price Increase")).font(.subheadline).foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(multiplierPresets, id: \.1) { preset in
                    Button(preset.0) {
                        gasMultiplier = preset.1
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(gasMultiplier == preset.1 ? Color.blue : Color(.systemGray5))
                    .foregroundColor(gasMultiplier == preset.1 ? .white : .primary)
                    .cornerRadius(8)
                }
            }

            if gasMultiplier == 0 {
                HStack {
                    TextField(L("Custom gas price (Gwei)"), text: $customGasPrice)
                        .keyboardType(.decimalPad)
                    Text(L("Gwei")).foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private var cancelSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(L("This will attempt to cancel your pending transaction"))
                    .font(.subheadline)
            }

            Text(L("A self-transfer with higher gas will be sent to replace the pending transaction."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private var costComparison: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L("Original Gas")).foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", originalTx.gasPrice)) Gwei")
            }
            HStack {
                Text(L("New Gas")).foregroundColor(.secondary)
                Spacer()
                let newGas = mode == .cancel
                    ? originalTx.gasPrice * 1.5
                    : (gasMultiplier > 0 ? originalTx.gasPrice * gasMultiplier : Double(customGasPrice) ?? originalTx.gasPrice)
                Text("\(String(format: "%.1f", newGas)) Gwei")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .font(.subheadline)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var confirmButton: some View {
        Button(action: { executeTx() }) {
            HStack {
                if isProcessing {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isProcessing ? "Processing..." : (mode == .speedUp ? "Speed Up" : "Cancel Transaction"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(mode == .cancel ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isProcessing)
    }

    private func executeTx() {
        isProcessing = true
        Task {
            do {
                guard let historyItem = TransactionManager.shared.getTransactionByHash(originalTx.hash) else {
                    await MainActor.run { isProcessing = false }
                    return
                }

                let txHash: String
                if mode == .speedUp {
                    txHash = try await TransactionManager.shared.speedUpTransaction(
                        originalTx: historyItem
                    )
                } else {
                    txHash = try await TransactionManager.shared.cancelTransaction(
                        originalTx: historyItem
                    )
                }

                await MainActor.run {
                    isProcessing = false
                    onConfirm?(txHash)
                    dismiss()
                }
            } catch {
                await MainActor.run { isProcessing = false }
            }
        }
    }
}

// MARK: - Pending Transaction Banner

struct PendingTxBanner: View {
    let pendingTxs: [PendingTransaction]
    @State private var isExpanded = false
    @State private var selectedTx: PendingTransaction?
    @State private var sheetMode: SpeedUpCancelSheet.Mode = .speedUp

    var body: some View {
        if !pendingTxs.isEmpty {
            VStack(spacing: 0) {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("\(pendingTxs.count) pending transaction\(pendingTxs.count > 1 ? "s" : "")")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.15))
                }

                if isExpanded {
                    ForEach(pendingTxs, id: \.hash) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nonce #\(tx.nonce)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(EthereumUtil.truncateAddress(tx.to))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(L("Speed Up")) {
                                sheetMode = .speedUp
                                selectedTx = tx
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)

                            Button(L("Cancel")) {
                                sheetMode = .cancel
                                selectedTx = tx
                            }
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .sheet(item: $selectedTx) { tx in
                SpeedUpCancelSheet(mode: sheetMode, originalTx: tx)
            }
        }
    }
}

// MARK: - Pending Transaction Model

struct PendingTransaction: Identifiable {
    var id: String { hash }
    let hash: String
    let nonce: Int
    let to: String
    let value: String
    let gasPrice: Double
    let data: String
    let timestamp: Date
}
