import SwiftUI

/// Gnosis Queue View - Pending Gnosis Safe transactions
/// Corresponds to: src/ui/views/GnosisQueue/
/// Shows queued multi-sig transactions that need more confirmations
struct GnosisQueueView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var transactions: [GnosisQueueTx] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let safeAddress: String
    let chainId: Int
    
    struct GnosisQueueTx: Identifiable {
        let id: String
        let nonce: Int
        let to: String
        let value: String
        let data: String?
        let operation: Int
        let safeTxHash: String
        let confirmations: [Confirmation]
        let confirmationsRequired: Int
        let submissionDate: Date
        let isExecuted: Bool
        
        struct Confirmation: Identifiable {
            let id: String // signer address
            let owner: String
            let signature: String
            let submissionDate: Date
        }
        
        var confirmationProgress: Double {
            guard confirmationsRequired > 0 else { return 0 }
            return Double(confirmations.count) / Double(confirmationsRequired)
        }
        
        var isReady: Bool {
            confirmations.count >= confirmationsRequired
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Safe info header
                safeInfoHeader
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading pending transactions...")
                    Spacer()
                } else if transactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("Safe Queue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadTransactions() }
        }
    }
    
    // MARK: - Subviews
    
    private var safeInfoHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.title3).foregroundColor(.teal)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Safe Address").font(.caption).foregroundColor(.secondary)
                Text("\(safeAddress.prefix(8))...\(safeAddress.suffix(6))")
                    .font(.system(.subheadline, design: .monospaced))
            }
            
            Spacer()
            
            Text("\(transactions.count) pending")
                .font(.caption).foregroundColor(.orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.1)).cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48)).foregroundColor(.green)
            Text("No pending transactions")
                .font(.headline).foregroundColor(.secondary)
            Text("All transactions have been executed or there are no queued transactions")
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }
    
    private var transactionList: some View {
        List {
            ForEach(transactions) { tx in
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Text("Nonce #\(tx.nonce)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if tx.isReady {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundColor(.green)
                        } else {
                            Text("\(tx.confirmations.count)/\(tx.confirmationsRequired)")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                    
                    // Transaction info
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("To: \(tx.to.prefix(10))...\(tx.to.suffix(4))")
                                .font(.system(.caption, design: .monospaced))
                            if tx.value != "0" {
                                Text("Value: \(tx.value) ETH")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Confirmation progress
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: tx.confirmationProgress)
                            .tint(tx.isReady ? .green : .orange)
                        
                        Text("Confirmations: \(tx.confirmations.count) of \(tx.confirmationsRequired)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    
                    // Signers
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tx.confirmations) { conf in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2).foregroundColor(.green)
                                Text(conf.owner.prefix(8) + "..." + conf.owner.suffix(4))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        if tx.isReady {
                            Button(action: { executeTx(tx) }) {
                                Label("Execute", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Color.green).foregroundColor(.white).cornerRadius(8)
                            }
                        }
                        
                        if !hasCurrentUserSigned(tx) {
                            Button(action: { confirmTx(tx) }) {
                                Label("Confirm", systemImage: "signature")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                            }
                        }
                        
                        Button(action: { rejectTx(tx) }) {
                            Label("Reject", systemImage: "xmark")
                                .font(.caption)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Color(.systemGray5)).foregroundColor(.red).cornerRadius(8)
                        }
                    }
                    
                    // Submission date
                    Text(tx.submissionDate, style: .relative)
                        .font(.caption2).foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .refreshable { loadTransactions() }
    }
    
    // MARK: - Actions
    
    private func loadTransactions() {
        isLoading = transactions.isEmpty
        Task {
            do {
                // In production: call Safe Transaction Service API
                // GET /api/v1/safes/{address}/multisig-transactions/?executed=false
                let result = try await OpenAPIService.shared.getGnosisPendingTxs(
                    safeAddress: safeAddress, chainId: String(chainId)
                )
                transactions = result.map { tx in
                    GnosisQueueTx(
                        id: tx.safeTxHash, nonce: tx.nonce,
                        to: tx.to, value: tx.value, data: tx.data,
                        operation: tx.operation, safeTxHash: tx.safeTxHash,
                        confirmations: tx.confirmations.map {
                            GnosisQueueTx.Confirmation(
                                id: $0.owner, owner: $0.owner,
                                signature: $0.signature, submissionDate: $0.submissionDate
                            )
                        },
                        confirmationsRequired: tx.confirmationsRequired,
                        submissionDate: tx.submissionDate,
                        isExecuted: tx.isExecuted
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func hasCurrentUserSigned(_ tx: GnosisQueueTx) -> Bool {
        guard let currentAddr = keyringManager.currentAccount?.address.lowercased() else { return false }
        return tx.confirmations.contains { $0.owner.lowercased() == currentAddr }
    }
    
    private func confirmTx(_ tx: GnosisQueueTx) {
        // Sign safeTxHash and submit confirmation
        Task {
            guard let currentAccount = keyringManager.currentAccount else { return }
            do {
                let signature = try await keyringManager.signMessage(
                    address: currentAccount.address,
                    message: Data(hex: tx.safeTxHash)
                )
                print("Signed confirmation: \(signature.hexEncodedString())")
                loadTransactions()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func executeTx(_ tx: GnosisQueueTx) {
        // Execute the Safe transaction on-chain
        print("Executing tx nonce #\(tx.nonce)")
    }
    
    private func rejectTx(_ tx: GnosisQueueTx) {
        // Create rejection transaction (same nonce, 0 value, to safe itself)
        print("Rejecting tx nonce #\(tx.nonce)")
    }
}

// MARK: - Data Extensions

extension Data {
    init(hex: String) {
        let hex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var data = Data()
        var startIndex = hex.startIndex
        while startIndex < hex.endIndex {
            let endIndex = hex.index(startIndex, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let byteString = String(hex[startIndex..<endIndex])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            startIndex = endIndex
        }
        self = data
    }
    
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
