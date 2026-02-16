import SwiftUI

/// Unified history page:
/// - All: OpenAPI history (extension-aligned)
/// - Pending: local pending txs from TransactionManager
/// - Swap/Bridge: local business histories with real status updates
struct TransactionHistoryView: View {
    @StateObject private var preferenceManager = PreferenceManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var transactionManager = TransactionManager.shared
    @StateObject private var historyManager = TransactionHistoryManager.shared

    @State private var selectedFilter: TxFilter = .all
    @State private var allHistory: [OpenAPIService.HistoryItem] = []
    @State private var allHistoryStart: Int = 0
    @State private var canLoadMoreAllHistory = true
    @State private var isLoadingAllHistory = false
    @State private var isLoadingMoreAllHistory = false
    @State private var allHistoryError: String?
    @State private var didInitialLoad = false

    @Environment(\.openURL) private var openURL

    private typealias LocalTxGroup = TransactionGroup

    enum TxFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case swap = "Swap"
        case bridge = "Bridge"
    }

    private var currentAddress: String {
        preferenceManager.currentAccount?.address ?? ""
    }

    private var pendingGroups: [LocalTxGroup] {
        guard !currentAddress.isEmpty else { return [] }
        return transactionManager.pendingTransactions
            .filter { group in
                group.txs.contains { tx in
                    tx.rawTx.from.lowercased() == currentAddress.lowercased()
                }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var swapHistory: [TransactionHistoryManager.SwapHistoryItem] {
        guard !currentAddress.isEmpty else { return [] }
        return historyManager
            .getSwapHistory(address: currentAddress)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var bridgeHistory: [TransactionHistoryManager.BridgeHistoryItem] {
        guard !currentAddress.isEmpty else { return [] }
        return historyManager.bridgeHistory
            .filter { $0.address.lowercased() == currentAddress.lowercased() }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterTabs

                Group {
                    switch selectedFilter {
                    case .all:
                        allTransactionsList
                    case .pending:
                        pendingTransactionsList
                    case .swap:
                        swapHistoryList
                    case .bridge:
                        bridgeHistoryList
                    }
                }
            }
            .navigationTitle(L("History"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await reloadAllHistory()
        }
        .onChange(of: currentAddress) { _ in
            Task {
                await reloadAllHistory()
            }
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TxFilter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(L(filter.rawValue))
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - All (OpenAPI)

    private var allTransactionsList: some View {
        Group {
            if isLoadingAllHistory && allHistory.isEmpty {
                VStack {
                    Spacer()
                    ProgressView(L("Loading..."))
                    Spacer()
                }
            } else if let allHistoryError, allHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(allHistoryError)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L("Retry")) {
                        Task { await reloadAllHistory() }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            } else if allHistory.isEmpty {
                emptyState(LocalizationManager.shared.t("No transactions yet"))
            } else {
                List {
                    ForEach(Array(allHistory.enumerated()), id: \.element.id) { index, item in
                        allHistoryRow(item)
                            .onAppear {
                                guard index == allHistory.count - 1 else { return }
                                Task { await loadMoreAllHistoryIfNeeded() }
                            }
                    }

                    if isLoadingMoreAllHistory {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await reloadAllHistory()
                }
            }
        }
    }

    private func allHistoryRow(_ item: OpenAPIService.HistoryItem) -> some View {
        let chain = chainManager.getChain(serverId: item.chain)
        let chainName = chain?.name ?? item.chain.uppercased()
        let status = txStatusText(item)
        let statusColor = txStatusColor(item)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName(item))
                    .foregroundColor(statusColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: txTypeText(item))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(verbatim: "\(chainName) · \(relativeTimeText(item.time_at))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(verbatim: status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }

            if let amountLine = transferSummary(item) {
                Text(verbatim: amountLine)
                    .font(.subheadline)
            }

            HStack {
                if let hash = item.tx_hash, !hash.isEmpty {
                    Text(verbatim: EthereumUtil.truncateAddress(hash))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let url = explorerURL(for: item) {
                    Button(L("Explorer")) {
                        openURL(url)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func reloadAllHistory() async {
        guard !currentAddress.isEmpty else {
            allHistory = []
            return
        }

        isLoadingAllHistory = true
        allHistoryError = nil
        allHistoryStart = 0
        canLoadMoreAllHistory = true

        defer { isLoadingAllHistory = false }

        do {
            let items = try await OpenAPIService.shared.getTransactionHistory(
                address: currentAddress,
                start: 0,
                limit: 20
            )
            let filtered = normalizedAllHistory(items)
            allHistory = filtered
            allHistoryStart = Int(filtered.last?.time_at ?? 0)
            canLoadMoreAllHistory = items.count >= 20 && allHistoryStart > 0
        } catch {
            // SwiftUI tasks are frequently cancelled when switching tabs / leaving the page.
            // Cancellation is expected and should not be surfaced as an error to users.
            if isCancellationError(error) { return }
            allHistoryError = error.localizedDescription
        }
    }

    private func loadMoreAllHistoryIfNeeded() async {
        guard !currentAddress.isEmpty else { return }
        guard canLoadMoreAllHistory, !isLoadingMoreAllHistory, !isLoadingAllHistory else { return }

        isLoadingMoreAllHistory = true
        defer { isLoadingMoreAllHistory = false }

        do {
            let items = try await OpenAPIService.shared.getTransactionHistory(
                address: currentAddress,
                start: allHistoryStart,
                limit: 20
            )
            let filtered = normalizedAllHistory(items)
            let existingIDs = Set(allHistory.map { $0.id })
            let deduped = filtered.filter { !existingIDs.contains($0.id) }
            allHistory.append(contentsOf: deduped)
            allHistory.sort { $0.time_at > $1.time_at }

            let nextStart = Int(filtered.last?.time_at ?? 0)
            if items.count < 20 || nextStart == 0 || nextStart == allHistoryStart {
                canLoadMoreAllHistory = false
            } else {
                allHistoryStart = nextStart
            }
        } catch {
            if isCancellationError(error) { return }
            allHistoryError = error.localizedDescription
            canLoadMoreAllHistory = false
        }
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private func normalizedAllHistory(_ items: [OpenAPIService.HistoryItem]) -> [OpenAPIService.HistoryItem] {
        items
            .filter { !($0.is_scam ?? false) }
            .sorted { $0.time_at > $1.time_at }
    }

    // MARK: - Pending (Local)

    private var pendingTransactionsList: some View {
        Group {
            if pendingGroups.isEmpty {
                emptyState(LocalizationManager.shared.t("No pending transactions"))
            } else {
                List(pendingGroups, id: \.id) { group in
                    let converted = convertPendingGroup(group)
                    NavigationLink(destination: TransactionDetailView(transactionGroup: converted, chainId: converted.chainId)) {
                        transactionGroupRow(group: converted)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func convertPendingGroup(_ group: LocalTxGroup) -> TransactionHistoryManager.TransactionGroup {
        let chain = chainManager.getChain(id: group.chainId)
        let chainId = chain?.serverId ?? String(group.chainId)

        let txs: [TransactionHistoryManager.TransactionHistoryItem] = group.txs.enumerated().map { index, tx in
            let valueHex = "0x" + String(tx.rawTx.value, radix: 16)
            let dataHex = tx.rawTx.data.isEmpty ? "0x" : "0x" + tx.rawTx.data.hexString
            let gasPriceHex = tx.rawTx.gasPrice.map { "0x" + String($0, radix: 16) }
                ?? tx.rawTx.maxFeePerGas.map { "0x" + String($0, radix: 16) }

            let status: TransactionHistoryManager.TxStatus
            if tx.failed {
                status = .failed
            } else if tx.isCompleted {
                status = .confirmed
            } else {
                status = .pending
            }

            return TransactionHistoryManager.TransactionHistoryItem(
                id: tx.hash ?? "\(chainId)_\(group.nonce)_\(index)",
                hash: tx.hash ?? "\(chainId)_\(group.nonce)_\(index)",
                from: tx.rawTx.from,
                to: tx.rawTx.to ?? "0x0000000000000000000000000000000000000000",
                value: valueHex,
                data: dataHex,
                chainId: chainId,
                nonce: group.nonce,
                gasUsed: tx.gasUsed.map(String.init),
                gasPrice: gasPriceHex,
                status: status,
                createdAt: Date(timeIntervalSince1970: tx.createdAt),
                completedAt: tx.completedAt.map { Date(timeIntervalSince1970: $0) },
                isSubmitFailed: tx.isSubmitFailed ?? false,
                pushType: nil,
                site: nil
            )
        }

        let fromAddress = group.txs.first?.rawTx.from.lowercased() ?? "unknown"
        return TransactionHistoryManager.TransactionGroup(
            id: "\(fromAddress)_\(chainId)_\(group.nonce)",
            chainId: chainId,
            nonce: group.nonce,
            txs: txs,
            isPending: group.isPending,
            createdAt: Date(timeIntervalSince1970: group.createdAt),
            completedAt: group.completedAt.map { Date(timeIntervalSince1970: $0) },
            isFailed: group.isFailed,
            isSubmitFailed: group.isSubmitFailed ?? false
        )
    }

    // MARK: - Swap

    private var swapHistoryList: some View {
        Group {
            if swapHistory.isEmpty {
                emptyState(LocalizationManager.shared.t("No swap history"))
            } else {
                List(swapHistory) { swap in
                    swapHistoryRow(swap: swap)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Bridge

    private var bridgeHistoryList: some View {
        Group {
            if bridgeHistory.isEmpty {
                emptyState(LocalizationManager.shared.t("No bridge history"))
            } else {
                List(bridgeHistory) { bridge in
                    bridgeHistoryRow(bridge: bridge)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Row Builders

    private func transactionGroupRow(group: TransactionHistoryManager.TransactionGroup) -> some View {
        let tx = group.latestTx
        return HStack {
            statusIcon(isPending: group.isPending, isFailed: group.isFailed)

            VStack(alignment: .leading, spacing: 4) {
                Text(tx?.to.prefix(10).appending("...") ?? LocalizationManager.shared.t("Unknown"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(group.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(tx?.value ?? "0x0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(statusText(isPending: group.isPending, isFailed: group.isFailed))
                    .font(.caption)
                    .foregroundColor(statusColor(isPending: group.isPending, isFailed: group.isFailed))
            }
        }
        .padding(.vertical, 4)
    }

    private func swapHistoryRow(swap: TransactionHistoryManager.SwapHistoryItem) -> some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(swap.fromToken.symbol) → \(swap.toToken.symbol)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(swap.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: swap.toAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(verbatim: swap.status.capitalized)
                    .font(.caption)
                    .foregroundColor(swap.status == "success" ? .green : swap.status == "failed" ? .red : .orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func bridgeHistoryRow(bridge: TransactionHistoryManager.BridgeHistoryItem) -> some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(bridge.fromToken.symbol) → \(bridge.toToken.symbol)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(verbatim: "\(bridge.fromChainId) → \(bridge.toChainId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: bridge.toAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(verbatim: bridge.status.capitalized)
                    .font(.caption)
                    .foregroundColor(
                        bridge.status == "allSuccess" ? .green
                            : bridge.status == "failed" ? .red : .orange
                    )
            }
        }
        .padding(.vertical, 4)
    }

    private func statusIcon(isPending: Bool, isFailed: Bool) -> some View {
        Image(systemName: isPending ? "clock" : isFailed ? "xmark.circle" : "checkmark.circle")
            .foregroundColor(isPending ? .orange : isFailed ? .red : .green)
            .frame(width: 32, height: 32)
    }

    private func statusText(isPending: Bool, isFailed: Bool) -> String {
        isPending ? LocalizationManager.shared.t("Pending")
            : isFailed ? LocalizationManager.shared.t("Failed") : LocalizationManager.shared.t("Confirmed")
    }

    private func statusColor(isPending: Bool, isFailed: Bool) -> Color {
        isPending ? .orange : isFailed ? .red : .green
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text(message)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - All History Helpers

    private func txTypeText(_ item: OpenAPIService.HistoryItem) -> String {
        if item.token_approve != nil { return "Approve" }
        if !(item.sends ?? []).isEmpty && !(item.receives ?? []).isEmpty { return "Swap" }
        if !(item.sends ?? []).isEmpty { return "Send" }
        if !(item.receives ?? []).isEmpty { return "Receive" }
        return "Contract Interaction"
    }

    private func iconName(_ item: OpenAPIService.HistoryItem) -> String {
        if item.token_approve != nil { return "checkmark.shield" }
        if !(item.sends ?? []).isEmpty && !(item.receives ?? []).isEmpty { return "arrow.triangle.2.circlepath" }
        if !(item.sends ?? []).isEmpty { return "arrow.up.right" }
        if !(item.receives ?? []).isEmpty { return "arrow.down.left" }
        return "circle.grid.2x2"
    }

    private func txStatusText(_ item: OpenAPIService.HistoryItem) -> String {
        guard let status = item.tx?.status else {
            return "Pending"
        }
        return status == 1 ? "Confirmed" : "Failed"
    }

    private func txStatusColor(_ item: OpenAPIService.HistoryItem) -> Color {
        guard let status = item.tx?.status else {
            return .orange
        }
        return status == 1 ? .green : .red
    }

    private func relativeTimeText(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func transferSummary(_ item: OpenAPIService.HistoryItem) -> String? {
        if let send = item.sends?.first {
            return "-\(formatAmount(send.amount)) \(tokenSymbol(send.token_id))"
        }
        if let receive = item.receives?.first {
            return "+\(formatAmount(receive.amount)) \(tokenSymbol(receive.token_id))"
        }
        return nil
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount >= 1 {
            return String(format: "%.4f", amount)
        }
        return String(format: "%.6f", amount)
    }

    private func tokenSymbol(_ tokenID: String) -> String {
        if let last = tokenID.split(separator: ":").last, !last.isEmpty {
            return String(last.prefix(12)).uppercased()
        }
        return tokenID.prefix(12).uppercased()
    }

    private func explorerURL(for item: OpenAPIService.HistoryItem) -> URL? {
        guard let hash = item.tx_hash, !hash.isEmpty else { return nil }
        guard let chain = chainManager.getChain(serverId: item.chain) else { return nil }
        let base = chain.scanUrl.hasSuffix("/") ? String(chain.scanUrl.dropLast()) : chain.scanUrl
        return URL(string: "\(base)/tx/\(hash)")
    }
}
