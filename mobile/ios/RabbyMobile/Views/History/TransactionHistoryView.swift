import SwiftUI

/// Transaction History View
struct TransactionHistoryView: View {
    @StateObject private var historyManager = TransactionHistoryManager.shared
    @State private var selectedFilter: TxFilter = .all
    
    enum TxFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case swap = "Swap"
        case bridge = "Bridge"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TxFilter.allCases, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(L(filter.rawValue))
                                    .font(.subheadline).fontWeight(selectedFilter == filter ? .semibold : .regular)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }.padding()
                }
                
                // Transaction list
                Group {
                    switch selectedFilter {
                    case .all: allTransactionsList
                    case .pending: pendingTransactionsList
                    case .swap: swapHistoryList
                    case .bridge: bridgeHistoryList
                    }
                }
            }
            .navigationTitle(L("History"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var allTransactionsList: some View {
        let address = PreferenceManager.shared.currentAccount?.address ?? ""
        let groups = historyManager.getHistory(address: address)

        return Group {
            if groups.isEmpty {
                emptyState(LocalizationManager.shared.t("No transactions yet"))
            } else {
                List(groups) { group in
                    NavigationLink(destination: TransactionDetailView(transactionGroup: group, chainId: group.chainId)) {
                        transactionGroupRow(group: group)
                    }
                }.listStyle(.plain)
            }
        }
    }

    private var pendingTransactionsList: some View {
        let address = PreferenceManager.shared.currentAccount?.address ?? ""
        let pending = historyManager.getPendingTransactions(address: address)

        return Group {
            if pending.isEmpty {
                emptyState(LocalizationManager.shared.t("No pending transactions"))
            } else {
                List(pending) { group in
                    NavigationLink(destination: TransactionDetailView(transactionGroup: group, chainId: group.chainId)) {
                        transactionGroupRow(group: group)
                    }
                }.listStyle(.plain)
            }
        }
    }
    
    private var swapHistoryList: some View {
        let address = PreferenceManager.shared.currentAccount?.address ?? ""
        let swaps = historyManager.getSwapHistory(address: address)
        
        return Group {
            if swaps.isEmpty {
                emptyState(LocalizationManager.shared.t("No swap history"))
            } else {
                List(swaps) { swap in
                    swapHistoryRow(swap: swap)
                }.listStyle(.plain)
            }
        }
    }
    
    private var bridgeHistoryList: some View {
        return Group {
            if historyManager.bridgeHistory.isEmpty {
                emptyState(LocalizationManager.shared.t("No bridge history"))
            } else {
                List(historyManager.bridgeHistory) { bridge in
                    bridgeHistoryRow(bridge: bridge)
                }.listStyle(.plain)
            }
        }
    }
    
    private func transactionGroupRow(group: TransactionHistoryManager.TransactionGroup) -> some View {
        let tx = group.latestTx
        return HStack {
            // Status icon
            statusIcon(isPending: group.isPending, isFailed: group.isFailed)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tx?.to.prefix(10).appending("...") ?? LocalizationManager.shared.t("Unknown"))
                    .font(.subheadline).fontWeight(.medium)
                Text(group.createdAt, style: .relative)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(tx?.value ?? "0")
                    .font(.subheadline).fontWeight(.medium)
                Text(statusText(isPending: group.isPending, isFailed: group.isFailed))
                    .font(.caption)
                    .foregroundColor(statusColor(isPending: group.isPending, isFailed: group.isFailed))
            }
        }.padding(.vertical, 4)
    }
    
    private func swapHistoryRow(swap: TransactionHistoryManager.SwapHistoryItem) -> some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(swap.fromToken.symbol) → \(swap.toToken.symbol)")
                    .font(.subheadline).fontWeight(.medium)
                Text(swap.createdAt, style: .relative).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(swap.toAmount).font(.subheadline).fontWeight(.medium)
                Text(swap.status.capitalized).font(.caption)
                    .foregroundColor(swap.status == "success" ? .green : swap.status == "failed" ? .red : .orange)
            }
        }.padding(.vertical, 4)
    }
    
    private func bridgeHistoryRow(bridge: TransactionHistoryManager.BridgeHistoryItem) -> some View {
        HStack {
            Image(systemName: "link").foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(bridge.fromToken.symbol) → \(bridge.toToken.symbol)")
                    .font(.subheadline).fontWeight(.medium)
                Text("\(bridge.fromChainId) → \(bridge.toChainId)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(bridge.toAmount).font(.subheadline).fontWeight(.medium)
                Text(bridge.status.capitalized).font(.caption)
                    .foregroundColor(bridge.status == "allSuccess" ? .green : bridge.status == "failed" ? .red : .orange)
            }
        }.padding(.vertical, 4)
    }
    
    private func statusIcon(isPending: Bool, isFailed: Bool) -> some View {
        Image(systemName: isPending ? "clock" : isFailed ? "xmark.circle" : "checkmark.circle")
            .foregroundColor(isPending ? .orange : isFailed ? .red : .green)
            .frame(width: 32, height: 32)
    }
    
    private func statusText(isPending: Bool, isFailed: Bool) -> String {
        isPending ? LocalizationManager.shared.t("Pending") : isFailed ? LocalizationManager.shared.t("Failed") : LocalizationManager.shared.t("Confirmed")
    }
    
    private func statusColor(isPending: Bool, isFailed: Bool) -> Color {
        isPending ? .orange : isFailed ? .red : .green
    }
    
    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.gray)
            Text(message).foregroundColor(.secondary)
            Spacer()
        }
    }
}
