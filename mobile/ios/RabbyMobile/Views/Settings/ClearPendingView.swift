import SwiftUI

/// Clear Pending Transactions + Reset Account
/// Corresponds to: Settings > Advanced
struct ClearPendingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var pendingTxs: [PendingTransaction] = []
    @State private var isClearingAll = false
    @State private var clearProgress = 0
    @State private var showResetConfirm = false
    @State private var resetConfirmText = ""

    var body: some View {
        NavigationView {
            List {
                // Clear pending section
                Section {
                    if pendingTxs.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(L("No pending transactions"))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(pendingTxs, id: \.hash) { tx in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizationManager.shared.t("ios.gnosis.nonce", args: ["nonce": "\(tx.nonce)"]))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(LocalizationManager.shared.t("ios.gnosis.toAddress", args: ["address": EthereumUtil.truncateAddress(tx.to)]))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(tx.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(tx.value)
                                    .font(.caption)
                            }
                        }

                        Button(action: { clearAllPending() }) {
                            HStack {
                                if isClearingAll {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(LocalizationManager.shared.t("ios.clearPending.clearingProgress", args: ["progress": "\(clearProgress)", "total": "\(pendingTxs.count)"]))
                                } else {
                                    Image(systemName: "trash")
                                    Text(LocalizationManager.shared.t("ios.clearPending.clearAll", args: ["count": "\(pendingTxs.count)"]))
                                }
                            }
                            .foregroundColor(.red)
                        }
                        .disabled(isClearingAll)
                    }
                } header: {
                    Text(L("Pending Transactions"))
                } footer: {
                    Text(L("Clearing sends a 0-value self-transfer with higher gas to replace each pending transaction. Gas fees will apply."))
                }

                // Reset account section
                Section {
                    Button(action: { showResetConfirm = true }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text(L("Reset Account"))
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text(L("Advanced"))
                } footer: {
                    Text(L("Clears local transaction history, pending queue, nonce cache, and token balance cache. Does NOT remove your accounts or private keys."))
                }
            }
            .navigationTitle(L("Clear Pending"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .alert(L("Reset Account"), isPresented: $showResetConfirm) {
                TextField(L("Type RESET to confirm"), text: $resetConfirmText)
                Button(L("Reset"), role: .destructive) {
                    if resetConfirmText == "RESET" { resetAccount() }
                }
                Button(L("Cancel"), role: .cancel) { resetConfirmText = "" }
            } message: {
                Text(L("This will clear all cached data. Your accounts and private keys will NOT be affected."))
            }
        }
        .task { await loadPendingTxs() }
    }

    private func loadPendingTxs() async {
        // Load from TransactionManager
    }

    private func clearAllPending() {
        isClearingAll = true
        Task {
            for (index, tx) in pendingTxs.enumerated() {
                do {
                    guard let historyItem = TransactionManager.shared.getTransactionByHash(tx.hash) else {
                        continue
                    }
                    let _ = try await TransactionManager.shared.cancelTransaction(
                        originalTx: historyItem
                    )
                    await MainActor.run { clearProgress = index + 1 }
                } catch {
                    continue
                }
            }
            await MainActor.run {
                isClearingAll = false
                pendingTxs.removeAll()
            }
        }
    }

    private func resetAccount() {
        // Clear local caches
        UserDefaults.standard.removeObject(forKey: "transactionHistory")
        UserDefaults.standard.removeObject(forKey: "pendingTransactions")
        UserDefaults.standard.removeObject(forKey: "nonceCache")
        UserDefaults.standard.removeObject(forKey: "tokenBalanceCache")
        resetConfirmText = ""
        dismiss()
    }
}
