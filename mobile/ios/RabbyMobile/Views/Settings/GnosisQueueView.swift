import SwiftUI
import BigInt

/// Gnosis Queue View - Pending Gnosis Safe transactions and messages
/// Corresponds to: src/ui/views/GnosisQueue/
/// Shows queued multi-sig transactions/messages that need more confirmations
struct GnosisQueueView: View {
    @StateObject private var viewModel: GnosisQueueViewModel

    let safeAddress: String
    let chainId: Int

    init(safeAddress: String, chainId: Int) {
        self.safeAddress = safeAddress
        self.chainId = chainId
        _viewModel = StateObject(wrappedValue: GnosisQueueViewModel(
            safeAddress: safeAddress,
            chainId: chainId
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Safe info header
                safeInfoHeader

                // Tab picker: Transactions / Messages
                Picker(L("Queue Type"), selection: $viewModel.selectedTab) {
                    Text(L("Transactions")).tag(GnosisQueueTab.transactions)
                    Text(L("Messages")).tag(GnosisQueueTab.messages)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(viewModel.selectedTab == .transactions
                                 ? LocalizationManager.shared.t("Loading pending transactions...")
                                 : LocalizationManager.shared.t("Loading pending messages..."))
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else {
                    switch viewModel.selectedTab {
                    case .transactions:
                        if viewModel.transactions.isEmpty {
                            emptyTransactionsState
                        } else {
                            transactionList
                        }
                    case .messages:
                        if viewModel.messages.isEmpty {
                            emptyMessagesState
                        } else {
                            messageList
                        }
                    }
                }
            }
            .navigationTitle(L("Safe Queue"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.refreshAll() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { viewModel.refreshAll() }
            .sheet(item: $viewModel.selectedTransaction) { tx in
                TransactionDetailSheet(
                    tx: tx,
                    viewModel: viewModel
                )
            }
            .sheet(item: $viewModel.selectedMessage) { msg in
                MessageDetailSheet(
                    message: msg,
                    viewModel: viewModel
                )
            }
            .alert(L("Error"), isPresented: $viewModel.showAlert) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }

    // MARK: - Subviews

    private var safeInfoHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title3).foregroundColor(.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Safe Address")).font(.caption).foregroundColor(.secondary)
                    Text(String(safeAddress.prefix(8)) + "..." + String(safeAddress.suffix(6)))
                        .font(.system(.subheadline, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(SafeTransactionServiceURLs.networkPrefix(for: chainId).uppercased())
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1)).cornerRadius(4)

                    HStack(spacing: 4) {
                        Text(LocalizationManager.shared.t("ios.gnosis.txCount", args: ["count": "\(viewModel.transactions.count)"]))
                            .font(.caption2).foregroundColor(.orange)
                        Text(LocalizationManager.shared.t("ios.gnosis.msgCount", args: ["count": "\(viewModel.messages.count)"]))
                            .font(.caption2).foregroundColor(.purple)
                    }
                }
            }

            // Threshold and owners summary
            if let safeInfo = viewModel.safeInfo {
                HStack(spacing: 16) {
                    Label(LocalizationManager.shared.t("ios.gnosis.threshold", args: ["threshold": "\(safeInfo.threshold)", "owners": "\(safeInfo.owners.count)"]),
                          systemImage: "lock.shield")
                        .font(.caption2).foregroundColor(.secondary)
                    Label("v\(safeInfo.version)", systemImage: "gearshape")
                        .font(.caption2).foregroundColor(.secondary)
                    if let lastSynced = safeInfo.lastSynced {
                        Text(lastSynced, style: .relative)
                            .font(.caption2).foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48)).foregroundColor(.orange)
            Text(L("Failed to load queue"))
                .font(.headline).foregroundColor(.secondary)
            Text(message)
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(L("Retry")) { viewModel.refreshAll() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var emptyTransactionsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48)).foregroundColor(.green)
            Text(L("No pending transactions"))
                .font(.headline).foregroundColor(.secondary)
            Text(L("All transactions have been executed or there are no queued transactions"))
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    private var emptyMessagesState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "envelope.open")
                .font(.system(size: 48)).foregroundColor(.green)
            Text(L("No pending messages"))
                .font(.headline).foregroundColor(.secondary)
            Text(L("There are no messages awaiting signatures"))
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            ForEach(viewModel.transactions) { tx in
                TransactionRowView(tx: tx, viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedTransaction = tx }
            }
        }
        .listStyle(.plain)
        .refreshable { viewModel.loadTransactions() }
    }

    // MARK: - Message List

    private var messageList: some View {
        List {
            ForEach(viewModel.messages) { msg in
                MessageRowView(message: msg, viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedMessage = msg }
            }
        }
        .listStyle(.plain)
        .refreshable { viewModel.loadMessages() }
    }
}

// MARK: - Queue Tab Enum

enum GnosisQueueTab: String, CaseIterable {
    case transactions
    case messages
}

// MARK: - Transaction Row View

private struct TransactionRowView: View {
    let tx: GnosisQueueTransaction
    @ObservedObject var viewModel: GnosisQueueViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: nonce + type + status
            HStack {
                Text(LocalizationManager.shared.t("ios.gnosis.nonce", args: ["nonce": "\(tx.nonce)"]))
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(.blue)

                txTypeLabel

                Spacer()

                statusBadge
            }

            // Transaction info
            HStack(spacing: 8) {
                Image(systemName: txTypeIcon)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizationManager.shared.t("ios.gnosis.toAddress", args: ["address": String(tx.to.prefix(10)) + "..." + String(tx.to.suffix(4))]))
                        .font(.system(.caption, design: .monospaced))
                    if tx.decodedDescription != nil {
                        Text(tx.decodedDescription!)
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if tx.value != "0" {
                        let ethValue = formatWeiToEth(tx.value)
                        Text(LocalizationManager.shared.t("ios.gnosis.valueETH", args: ["value": ethValue]))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            // Confirmation progress
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: tx.confirmationProgress)
                    .tint(tx.isReady ? .green : .orange)

                Text(LocalizationManager.shared.t("ios.gnosis.confirmations", args: ["count": "\(tx.confirmations.count)", "required": "\(tx.confirmationsRequired)"]))
                    .font(.caption2).foregroundColor(.secondary)
            }

            // Signers
            VStack(alignment: .leading, spacing: 3) {
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
                if tx.isReady && !tx.isExecuted {
                    Button(action: { viewModel.executeTx(tx) }) {
                        Label(L("Execute"), systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.green).foregroundColor(.white).cornerRadius(8)
                    }
                    .disabled(viewModel.isProcessing)
                }

                if !viewModel.hasCurrentUserSigned(tx) && !tx.isExecuted {
                    Button(action: { viewModel.confirmTx(tx) }) {
                        Label(L("Confirm"), systemImage: "signature")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                    }
                    .disabled(viewModel.isProcessing)
                }

                if !tx.isExecuted {
                    Button(action: { viewModel.rejectTx(tx) }) {
                        Label(L("Reject"), systemImage: "xmark")
                            .font(.caption)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color(.systemGray5)).foregroundColor(.red).cornerRadius(8)
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            // Submission date
            Text(tx.submissionDate, style: .relative)
                .font(.caption2).foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var txTypeLabel: some View {
        Text(tx.txType.rawValue)
            .font(.caption2).fontWeight(.medium)
            .foregroundColor(txTypeColor)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(txTypeColor.opacity(0.12)).cornerRadius(4)
    }

    private var statusBadge: some View {
        Group {
            switch tx.status {
            case .pendingSignatures:
                Text("\(tx.confirmations.count)/\(tx.confirmationsRequired)")
                    .font(.caption).foregroundColor(.orange)
            case .readyToExecute:
                Label(L("Ready"), systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.green)
            case .executed:
                Label(L("Executed"), systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundColor(.blue)
            }
        }
    }

    private var txTypeIcon: String {
        switch tx.txType {
        case .transfer: return "arrow.right.circle"
        case .contractCall: return "doc.text"
        case .settingsChange: return "gearshape"
        case .rejection: return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    private var txTypeColor: Color {
        switch tx.txType {
        case .transfer: return .blue
        case .contractCall: return .purple
        case .settingsChange: return .orange
        case .rejection: return .red
        case .unknown: return .gray
        }
    }

    private func formatWeiToEth(_ weiString: String) -> String {
        guard let wei = BigUInt(weiString) else { return weiString }
        let ether = EthereumUtil.weiToEther(wei)
        return String(format: "%.6f", NSDecimalNumber(decimal: ether).doubleValue)
    }
}

// MARK: - Message Row View

private struct MessageRowView: View {
    let message: GnosisQueueMessage
    @ObservedObject var viewModel: GnosisQueueViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.purple)
                Text(message.isTypedMessage ? LocalizationManager.shared.t("Typed Data") : LocalizationManager.shared.t("Message"))
                    .font(.caption).fontWeight(.bold).foregroundColor(.purple)

                Spacer()

                Text("\(message.confirmations.count)/\(message.confirmationsRequired)")
                    .font(.caption).foregroundColor(.orange)
            }

            // Message preview
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Message Hash:"))
                    .font(.caption2).foregroundColor(.secondary)
                Text(message.messageHash.prefix(20) + "..." + message.messageHash.suffix(8))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)

                if let preview = message.messagePreview {
                    Text(preview)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            // Confirmation progress
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: message.confirmationProgress)
                    .tint(message.isFullyConfirmed ? .green : .orange)
                Text(LocalizationManager.shared.t("ios.gnosis.signatures", args: ["count": "\(message.confirmations.count)", "required": "\(message.confirmationsRequired)"]))
                    .font(.caption2).foregroundColor(.secondary)
            }

            // Signers
            VStack(alignment: .leading, spacing: 3) {
                ForEach(message.confirmations) { conf in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2).foregroundColor(.green)
                        Text(conf.owner.prefix(8) + "..." + conf.owner.suffix(4))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Sign button
            if !viewModel.hasCurrentUserSignedMessage(message) {
                Button(action: { viewModel.signMessage(message) }) {
                    Label(L("Sign Message"), systemImage: "signature")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.purple).foregroundColor(.white).cornerRadius(8)
                }
                .disabled(viewModel.isProcessing)
            }

            // Date
            Text(message.createdDate, style: .relative)
                .font(.caption2).foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Transaction Detail Sheet

private struct TransactionDetailSheet: View {
    let tx: GnosisQueueTransaction
    @ObservedObject var viewModel: GnosisQueueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Transaction Type & Status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Transaction Type")).font(.caption).foregroundColor(.secondary)
                            Text(tx.txType.rawValue).font(.headline)
                        }
                        Spacer()
                        Text(tx.status.displayName)
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(tx.status.color.opacity(0.15))
                            .foregroundColor(tx.status.color)
                            .cornerRadius(6)
                    }

                    Divider()

                    // Transaction Fields
                    detailRow(LocalizationManager.shared.t("Nonce"), "\(tx.nonce)")
                    detailRow(LocalizationManager.shared.t("To"), tx.to)
                    detailRow(LocalizationManager.shared.t("Value (wei)"), tx.value)
                    if let data = tx.data, !data.isEmpty, data != "0x" {
                        detailRow(LocalizationManager.shared.t("Data"), data)
                    }
                    detailRow(LocalizationManager.shared.t("Operation"), tx.operation == 0 ? LocalizationManager.shared.t("Call") : LocalizationManager.shared.t("DelegateCall"))
                    detailRow("SafeTxGas", tx.safeTxGas)
                    detailRow("BaseGas", tx.baseGas)
                    detailRow("GasPrice", tx.gasPrice)
                    detailRow("GasToken", tx.gasToken)
                    detailRow("RefundReceiver", tx.refundReceiver)
                    detailRow("SafeTxHash", tx.safeTxHash)

                    Divider()

                    // Confirmations
                    Text(LocalizationManager.shared.t("ios.gnosis.confirmationsHeader", args: ["count": "\(tx.confirmations.count)", "required": "\(tx.confirmationsRequired)"]))
                        .font(.subheadline).fontWeight(.semibold)

                    ForEach(tx.confirmations) { conf in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conf.owner)
                                    .font(.system(.caption, design: .monospaced))
                                Text(conf.submissionDate, style: .relative)
                                    .font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }

                    Divider()

                    // Actions
                    VStack(spacing: 12) {
                        if !viewModel.hasCurrentUserSigned(tx) && !tx.isExecuted {
                            Button(action: {
                                viewModel.confirmTx(tx)
                                dismiss()
                            }) {
                                Label(L("Confirm Transaction"), systemImage: "signature")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(viewModel.isProcessing)
                        }

                        if tx.isReady && !tx.isExecuted {
                            Button(action: {
                                viewModel.executeTx(tx)
                                dismiss()
                            }) {
                                Label(L("Execute Transaction"), systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(viewModel.isProcessing)
                        }

                        if !tx.isExecuted {
                            Button(action: {
                                viewModel.rejectTx(tx)
                                dismiss()
                            }) {
                                Label(L("Reject Transaction"), systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                            .disabled(viewModel.isProcessing)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L("Transaction Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

// MARK: - Message Detail Sheet

private struct MessageDetailSheet: View {
    let message: GnosisQueueMessage
    @ObservedObject var viewModel: GnosisQueueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type
                    HStack {
                        Text(message.isTypedMessage ? LocalizationManager.shared.t("EIP-712 Typed Data") : LocalizationManager.shared.t("Plain Message"))
                            .font(.headline)
                        Spacer()
                        Text(message.isFullyConfirmed ? LocalizationManager.shared.t("Complete") : LocalizationManager.shared.t("Pending"))
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(message.isFullyConfirmed ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundColor(message.isFullyConfirmed ? .green : .orange)
                            .cornerRadius(6)
                    }

                    Divider()

                    detailRow(LocalizationManager.shared.t("Message Hash"), message.messageHash)
                    if let preview = message.messagePreview {
                        detailRow(LocalizationManager.shared.t("Content"), preview)
                    }

                    Divider()

                    // Confirmations
                    Text(LocalizationManager.shared.t("ios.gnosis.signaturesHeader", args: ["count": "\(message.confirmations.count)", "required": "\(message.confirmationsRequired)"]))
                        .font(.subheadline).fontWeight(.semibold)

                    ForEach(message.confirmations) { conf in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conf.owner)
                                    .font(.system(.caption, design: .monospaced))
                                Text(conf.submissionDate, style: .relative)
                                    .font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }

                    Divider()

                    // Action
                    if !viewModel.hasCurrentUserSignedMessage(message) {
                        Button(action: {
                            viewModel.signMessage(message)
                            dismiss()
                        }) {
                            Label(L("Sign Message"), systemImage: "signature")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(viewModel.isProcessing)
                    }
                }
                .padding()
            }
            .navigationTitle(L("Message Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(5)
        }
    }
}

// MARK: - Data Models

/// Transaction type detected from data/value/to analysis
enum GnosisTransactionType: String {
    case transfer = "Transfer"
    case contractCall = "Contract Call"
    case settingsChange = "Settings"
    case rejection = "Rejection"
    case unknown = "Unknown"
}

/// Transaction queue status
enum GnosisTransactionStatus {
    case pendingSignatures
    case readyToExecute
    case executed

    var displayName: String {
        switch self {
        case .pendingSignatures: return LocalizationManager.shared.t("Pending Signatures")
        case .readyToExecute: return LocalizationManager.shared.t("Ready to Execute")
        case .executed: return LocalizationManager.shared.t("Executed")
        }
    }

    var color: Color {
        switch self {
        case .pendingSignatures: return .orange
        case .readyToExecute: return .green
        case .executed: return .blue
        }
    }
}

/// A pending Safe multisig transaction in the queue
struct GnosisQueueTransaction: Identifiable {
    let id: String
    let nonce: Int
    let to: String
    let value: String
    let data: String?
    let operation: Int
    let safeTxGas: String
    let baseGas: String
    let gasPrice: String
    let gasToken: String
    let refundReceiver: String
    let safeTxHash: String
    let confirmations: [GnosisQueueConfirmation]
    let confirmationsRequired: Int
    let submissionDate: Date
    let isExecuted: Bool

    /// Decoded description (human-readable summary of the data field)
    var decodedDescription: String? {
        guard let data = data, data.count > 2, data != "0x" else { return nil }
        // Decode known function selectors
        let selector = String(data.prefix(10))
        switch selector {
        // transfer(address,uint256)
        case "0xa9059cbb": return "ERC-20 Transfer"
        // approve(address,uint256)
        case "0x095ea7b3": return "ERC-20 Approve"
        // addOwnerWithThreshold(address,uint256)
        case "0x0d582f13": return "Add Owner"
        // removeOwner(address,address,uint256)
        case "0xf8dc5dd9": return "Remove Owner"
        // changeThreshold(uint256)
        case "0x694e80c3": return "Change Threshold"
        // swapOwner(address,address,address)
        case "0xe318b52b": return "Swap Owner"
        // enableModule(address)
        case "0x610b5925": return "Enable Module"
        // disableModule(address,address)
        case "0xe009cfde": return "Disable Module"
        default: return "Contract Interaction"
        }
    }

    /// Detected transaction type
    var txType: GnosisTransactionType {
        // Self-send with 0 value and empty data = rejection
        if to.lowercased() == safeTxHash.lowercased() && value == "0" &&
            (data == nil || data == "0x" || data?.isEmpty == true) {
            return .rejection
        }
        // Settings changes (to = Safe itself with specific selectors)
        if let data = data, data.count >= 10 {
            let selector = String(data.prefix(10))
            let settingsSelectors = ["0x0d582f13", "0xf8dc5dd9", "0x694e80c3", "0xe318b52b", "0x610b5925", "0xe009cfde"]
            if settingsSelectors.contains(selector) {
                return .settingsChange
            }
        }
        // Pure ETH transfer (no data or "0x")
        if (data == nil || data == "0x" || data?.isEmpty == true) && value != "0" {
            return .transfer
        }
        // Has data -> contract call
        if data != nil && data != "0x" && data?.isEmpty == false {
            return .contractCall
        }
        return .unknown
    }

    /// Transaction status
    var status: GnosisTransactionStatus {
        if isExecuted { return .executed }
        if confirmations.count >= confirmationsRequired { return .readyToExecute }
        return .pendingSignatures
    }

    var confirmationProgress: Double {
        guard confirmationsRequired > 0 else { return 0 }
        return Double(confirmations.count) / Double(confirmationsRequired)
    }

    var isReady: Bool {
        confirmations.count >= confirmationsRequired
    }
}

/// A confirmation (signature) from a Safe owner
struct GnosisQueueConfirmation: Identifiable {
    let id: String // signer address
    let owner: String
    let signature: String
    let submissionDate: Date
}

/// A pending Safe message awaiting signatures
struct GnosisQueueMessage: Identifiable {
    let id: String // messageHash
    let messageHash: String
    let message: String // raw message content or typed data JSON
    let isTypedMessage: Bool
    let confirmations: [GnosisQueueConfirmation]
    let confirmationsRequired: Int
    let createdDate: Date

    var messagePreview: String? {
        if isTypedMessage {
            // Try to extract primaryType from typed data
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let primaryType = json["primaryType"] as? String {
                return "EIP-712: \(primaryType)"
            }
            return "Typed Data"
        }
        // Plain message - return first 100 chars
        if message.count > 100 {
            return String(message.prefix(100)) + "..."
        }
        return message.isEmpty ? nil : message
    }

    var confirmationProgress: Double {
        guard confirmationsRequired > 0 else { return 0 }
        return Double(confirmations.count) / Double(confirmationsRequired)
    }

    var isFullyConfirmed: Bool {
        confirmations.count >= confirmationsRequired
    }
}

// MARK: - View Model

@MainActor
class GnosisQueueViewModel: ObservableObject {
    @Published var selectedTab: GnosisQueueTab = .transactions
    @Published var transactions: [GnosisQueueTransaction] = []
    @Published var messages: [GnosisQueueMessage] = []
    @Published var safeInfo: GnosisKeyring.GnosisSafeInfo?
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var selectedTransaction: GnosisQueueTransaction?
    @Published var selectedMessage: GnosisQueueMessage?

    let safeAddress: String
    let chainId: Int

    private let keyringManager = KeyringManager.shared
    private let session: URLSession

    init(safeAddress: String, chainId: Int) {
        self.safeAddress = safeAddress
        self.chainId = chainId

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Data Loading

    func refreshAll() {
        loadSafeInfo()
        loadTransactions()
        loadMessages()
    }

    private func loadSafeInfo() {
        // Try to get from GnosisKeyring in KeyringManager
        for keyring in keyringManager.keyrings {
            if let gnosisKeyring = keyring as? GnosisKeyring,
               let info = gnosisKeyring.getSafeInfo(address: safeAddress) {
                safeInfo = info
                return
            }
        }
    }

    func loadTransactions() {
        guard !isLoading else { return }
        isLoading = transactions.isEmpty
        errorMessage = nil

        Task {
            do {
                let url = SafeTransactionServiceURLs.pendingTransactionsURL(
                    for: chainId, safeAddress: safeAddress
                )
                let response: SafeTransactionServiceResponse = try await fetchJSON(from: url)

                transactions = response.results.map { apiTx in
                    GnosisQueueTransaction(
                        id: apiTx.safeTxHash,
                        nonce: apiTx.nonce,
                        to: apiTx.to ?? "",
                        value: apiTx.value ?? "0",
                        data: apiTx.data,
                        operation: apiTx.operation ?? 0,
                        safeTxGas: apiTx.safeTxGas ?? "0",
                        baseGas: apiTx.baseGas ?? "0",
                        gasPrice: apiTx.gasPrice ?? "0",
                        gasToken: apiTx.gasToken ?? "0x0000000000000000000000000000000000000000",
                        refundReceiver: apiTx.refundReceiver ?? "0x0000000000000000000000000000000000000000",
                        safeTxHash: apiTx.safeTxHash,
                        confirmations: (apiTx.confirmations ?? []).map { conf in
                            GnosisQueueConfirmation(
                                id: conf.owner,
                                owner: conf.owner,
                                signature: conf.signature ?? "",
                                submissionDate: parseISO8601(conf.submissionDate) ?? Date()
                            )
                        },
                        confirmationsRequired: apiTx.confirmationsRequired ?? (safeInfo?.threshold ?? 1),
                        submissionDate: parseISO8601(apiTx.submissionDate) ?? Date(),
                        isExecuted: apiTx.isExecuted ?? false
                    )
                }
            } catch {
                if transactions.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }

    func loadMessages() {
        Task {
            do {
                let url = SafeTransactionServiceURLs.messagesURL(
                    for: chainId, safeAddress: safeAddress
                )
                let response: SafeMessageServiceResponse = try await fetchJSON(from: url)

                messages = response.results.map { apiMsg in
                    GnosisQueueMessage(
                        id: apiMsg.messageHash,
                        messageHash: apiMsg.messageHash,
                        message: apiMsg.message ?? "",
                        isTypedMessage: apiMsg.message?.contains("\"types\"") == true,
                        confirmations: (apiMsg.confirmations ?? []).map { conf in
                            GnosisQueueConfirmation(
                                id: conf.owner,
                                owner: conf.owner,
                                signature: conf.signature ?? "",
                                submissionDate: parseISO8601(conf.submissionDate) ?? Date()
                            )
                        },
                        confirmationsRequired: safeInfo?.threshold ?? 1,
                        createdDate: parseISO8601(apiMsg.created) ?? Date()
                    )
                }
            } catch {
                // Messages are secondary; do not overwrite main error
                print("[GnosisQueue] Failed to load messages: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Transaction Actions

    func hasCurrentUserSigned(_ tx: GnosisQueueTransaction) -> Bool {
        guard let currentAddr = keyringManager.currentAccount?.address.lowercased() else { return false }
        return tx.confirmations.contains { $0.owner.lowercased() == currentAddr }
    }

    func hasCurrentUserSignedMessage(_ msg: GnosisQueueMessage) -> Bool {
        guard let currentAddr = keyringManager.currentAccount?.address.lowercased() else { return false }
        return msg.confirmations.contains { $0.owner.lowercased() == currentAddr }
    }

    /// Sign and submit a confirmation for a pending transaction.
    /// 1. Compute the safeTxHash locally (or use the one from the API).
    /// 2. Sign the hash with the current wallet's private key.
    /// 3. POST the signature to the Safe Transaction Service.
    func confirmTx(_ tx: GnosisQueueTransaction) {
        guard let currentAccount = keyringManager.currentAccount else {
            showError("No active account")
            return
        }
        isProcessing = true

        Task {
            do {
                // Sign the safeTxHash using the current account's key
                guard let hashData = Data(hexString: tx.safeTxHash) else {
                    throw GnosisKeyringError.transactionServiceError("Invalid safeTxHash")
                }

                // Use EIP-191 personal sign over the safeTxHash bytes
                let signature = try await keyringManager.signMessage(
                    address: currentAccount.address,
                    message: hashData
                )
                let signatureHex = "0x" + signature.toHexString()

                // Adjust v value: Safe expects eth_sign style (v + 4)
                let adjustedSignature = adjustSignatureForSafe(signatureHex: signatureHex)

                // Submit confirmation to Safe Transaction Service
                let confirmURL = SafeTransactionServiceURLs.confirmTransactionURL(
                    for: chainId, safeTxHash: tx.safeTxHash
                )
                try await postConfirmation(url: confirmURL, signature: adjustedSignature)

                // Reload transactions
                loadTransactions()
            } catch {
                showError("Failed to confirm: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    /// Execute a Safe transaction on-chain when enough confirmations have been collected.
    /// 1. Collect all signatures and pack them.
    /// 2. Build the `execTransaction` calldata.
    /// 3. Send the on-chain transaction.
    func executeTx(_ tx: GnosisQueueTransaction) {
        guard tx.isReady else {
            showError("Not enough confirmations to execute")
            return
        }
        guard let currentAccount = keyringManager.currentAccount else {
            showError("No active account")
            return
        }
        isProcessing = true

        Task {
            do {
                // Build the Safe transaction struct
                let safeTx = GnosisKeyring.SafeTransaction(
                    to: tx.to,
                    value: tx.value,
                    data: tx.data ?? "0x",
                    operation: tx.operation,
                    safeTxGas: tx.safeTxGas,
                    baseGas: tx.baseGas,
                    gasPrice: tx.gasPrice,
                    gasToken: tx.gasToken,
                    refundReceiver: tx.refundReceiver,
                    nonce: tx.nonce
                )

                // Pack signatures (sorted by owner address)
                let gnosisKeyring = GnosisKeyring()
                let sigPairs: [(owner: String, signature: Data)] = tx.confirmations.compactMap { conf in
                    guard let sigData = Data(hexString: conf.signature) else { return nil }
                    return (owner: conf.owner, signature: sigData)
                }
                let packedSignatures = gnosisKeyring.packSignatures(sigPairs)

                // Build execTransaction calldata
                let calldata = gnosisKeyring.buildExecTransactionCalldata(
                    tx: safeTx,
                    signatures: packedSignatures
                )
                let calldataHex = "0x" + calldata.toHexString()

                // Send the on-chain transaction via KeyringManager
                let txHash = try await keyringManager.signAndSendTransaction(
                    from: currentAccount.address,
                    to: safeAddress,
                    value: tx.value == "0" ? "0x0" : "0x" + (BigUInt(tx.value) ?? BigUInt(0)).toData().toHexString(),
                    data: calldataHex,
                    gasLimit: nil,
                    gasPrice: nil,
                    maxFeePerGas: nil,
                    maxPriorityFeePerGas: nil
                )

                showError("Transaction submitted: \(txHash)")
                loadTransactions()
            } catch {
                showError("Execution failed: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    /// Create a rejection transaction (same nonce, 0 value, send to Safe itself, empty data).
    func rejectTx(_ tx: GnosisQueueTransaction) {
        guard let currentAccount = keyringManager.currentAccount else {
            showError("No active account")
            return
        }
        isProcessing = true

        Task {
            do {
                // A rejection is a transaction to the Safe itself with 0 value, 0 data, same nonce
                let rejectionBody: [String: Any] = [
                    "to": safeAddress,
                    "value": "0",
                    "data": "0x",
                    "operation": 0,
                    "safeTxGas": "0",
                    "baseGas": "0",
                    "gasPrice": "0",
                    "gasToken": "0x0000000000000000000000000000000000000000",
                    "refundReceiver": "0x0000000000000000000000000000000000000000",
                    "nonce": tx.nonce,
                    "sender": currentAccount.address
                ]

                // Compute rejection safeTxHash locally
                let gnosisKeyring = GnosisKeyring()
                let rejectionHash = gnosisKeyring.calculateSafeTransactionHash(
                    safe: safeAddress,
                    to: safeAddress,
                    value: BigUInt(0),
                    data: Data(),
                    operation: 0,
                    safeTxGas: BigUInt(0),
                    baseGas: BigUInt(0),
                    gasPrice: BigUInt(0),
                    gasToken: "0x0000000000000000000000000000000000000000",
                    refundReceiver: "0x0000000000000000000000000000000000000000",
                    nonce: BigUInt(tx.nonce),
                    chainId: BigUInt(chainId)
                )

                // Sign the rejection hash
                let signature = try await keyringManager.signMessage(
                    address: currentAccount.address,
                    message: rejectionHash
                )
                let signatureHex = "0x" + signature.toHexString()
                let adjustedSignature = adjustSignatureForSafe(signatureHex: signatureHex)

                // Submit the rejection transaction to Safe Transaction Service
                var bodyWithSig = rejectionBody
                bodyWithSig["signature"] = adjustedSignature
                bodyWithSig["contractTransactionHash"] = "0x" + rejectionHash.toHexString()

                let submitURL = SafeTransactionServiceURLs.multisigTransactionsURL(
                    for: chainId, safeAddress: safeAddress
                )
                try await postJSON(url: submitURL, body: bodyWithSig)

                loadTransactions()
            } catch {
                showError("Rejection failed: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    /// Sign a pending message.
    func signMessage(_ msg: GnosisQueueMessage) {
        guard let currentAccount = keyringManager.currentAccount else {
            showError("No active account")
            return
        }
        isProcessing = true

        Task {
            do {
                // Compute the Safe message hash
                let gnosisKeyring = GnosisKeyring()
                let messageData: Data
                if msg.isTypedMessage {
                    // For typed messages, the message content is the EIP-712 typed data JSON
                    messageData = msg.message.data(using: .utf8) ?? Data()
                } else {
                    messageData = msg.message.data(using: .utf8) ?? Data()
                }

                let safeMessageHash = gnosisKeyring.calculateSafeMessageHash(
                    safe: safeAddress,
                    message: messageData,
                    chainId: BigUInt(chainId)
                )

                // Sign with the current account
                let signature = try await keyringManager.signMessage(
                    address: currentAccount.address,
                    message: safeMessageHash
                )
                let signatureHex = "0x" + signature.toHexString()
                let adjustedSignature = adjustSignatureForSafe(signatureHex: signatureHex)

                // Submit to Safe Transaction Service
                let confirmURL = SafeTransactionServiceURLs.confirmMessageURL(
                    for: chainId, messageHash: msg.messageHash
                )
                try await postConfirmation(url: confirmURL, signature: adjustedSignature)

                loadMessages()
            } catch {
                showError("Message signing failed: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    // MARK: - Networking Helpers

    /// Fetch and decode JSON from a URL.
    private func fetchJSON<T: Decodable>(from urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw GnosisKeyringError.transactionServiceError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GnosisKeyringError.transactionServiceError("HTTP \(code)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// POST a confirmation (signature) to the Safe Transaction Service.
    private func postConfirmation(url: String, signature: String) async throws {
        guard let requestURL = URL(string: url) else {
            throw GnosisKeyringError.transactionServiceError("Invalid URL")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = ["signature": signature]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GnosisKeyringError.transactionServiceError("Failed to submit confirmation (HTTP \(code))")
        }
    }

    /// POST arbitrary JSON to the Safe Transaction Service.
    private func postJSON(url: String, body: [String: Any]) async throws {
        guard let requestURL = URL(string: url) else {
            throw GnosisKeyringError.transactionServiceError("Invalid URL")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GnosisKeyringError.transactionServiceError("Request failed (HTTP \(code))")
        }
    }

    // MARK: - Signature Helpers

    /// Adjust signature for Safe Transaction Service.
    /// When signing with eth_sign (personal_sign), Safe expects v to be incremented by 4
    /// (v = 31 or 32 instead of 27 or 28) to indicate eth_sign was used.
    private func adjustSignatureForSafe(signatureHex: String) -> String {
        var sigClean = signatureHex
        if sigClean.hasPrefix("0x") { sigClean = String(sigClean.dropFirst(2)) }
        guard sigClean.count == 130 else { return signatureHex }

        // Last byte is v
        let vHex = String(sigClean.suffix(2))
        guard let v = UInt8(vHex, radix: 16) else { return signatureHex }

        // If v is 27 or 28, add 4 for eth_sign
        let adjustedV: UInt8
        if v == 27 || v == 28 {
            adjustedV = v + 4
        } else {
            adjustedV = v
        }

        let prefix = String(sigClean.dropLast(2))
        return "0x" + prefix + String(format: "%02x", adjustedV)
    }

    // MARK: - Utility

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Safe Transaction Service API Response Models

/// Paginated response from Safe Transaction Service `/multisig-transactions/`
private struct SafeTransactionServiceResponse: Decodable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [SafeTransactionAPIItem]
}

/// A single transaction from the Safe Transaction Service API
private struct SafeTransactionAPIItem: Decodable {
    let safe: String?
    let to: String?
    let value: String?
    let data: String?
    let operation: Int?
    let safeTxGas: String?
    let baseGas: String?
    let gasPrice: String?
    let gasToken: String?
    let refundReceiver: String?
    let nonce: Int
    let submissionDate: String?
    let executionDate: String?
    let safeTxHash: String
    let isExecuted: Bool?
    let isSuccessful: Bool?
    let confirmations: [SafeConfirmationAPIItem]?
    let confirmationsRequired: Int?
    let transactionHash: String?
}

/// A confirmation from the Safe Transaction Service API
private struct SafeConfirmationAPIItem: Decodable {
    let owner: String
    let submissionDate: String?
    let signature: String?
    let signatureType: String?
}

/// Paginated response from Safe Transaction Service `/messages/`
private struct SafeMessageServiceResponse: Decodable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [SafeMessageAPIItem]
}

/// A single message from the Safe Transaction Service API
private struct SafeMessageAPIItem: Decodable {
    let messageHash: String
    let message: String?
    let created: String?
    let confirmations: [SafeConfirmationAPIItem]?
    let preparedSignature: String?
}
