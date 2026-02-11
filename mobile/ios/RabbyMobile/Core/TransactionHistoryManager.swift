import Foundation
import Combine

/// Transaction History Manager - Complete transaction history with status tracking
/// Equivalent to Web version's transactionHistory service (1528 lines)
@MainActor
class TransactionHistoryManager: ObservableObject {
    static let shared = TransactionHistoryManager()
    
    @Published var transactions: [String: [TransactionGroup]] = [:] // address -> groups
    @Published var pendingTransactions: [String: [TransactionGroup]] = [:]
    @Published var swapHistory: [SwapHistoryItem] = []
    @Published var bridgeHistory: [BridgeHistoryItem] = []
    
    private let storage = StorageManager.shared
    private let historyKey = "rabby_tx_history"
    private let swapHistoryKey = "rabby_swap_history"
    private let bridgeHistoryKey = "rabby_bridge_history"
    
    // MARK: - Models
    
    struct TransactionHistoryItem: Codable, Identifiable {
        let id: String
        let hash: String
        let from: String
        let to: String
        let value: String
        let data: String
        let chainId: String
        let nonce: Int
        let gasUsed: String?
        let gasPrice: String?
        let status: TxStatus
        let createdAt: Date
        var completedAt: Date?
        var isSubmitFailed: Bool
        var pushType: String?
        var site: ConnectedSite?
        
        struct ConnectedSite: Codable {
            let origin: String
            let name: String
            let icon: String?
        }
    }
    
    struct TransactionGroup: Codable, Identifiable {
        let id: String
        let chainId: String
        let nonce: Int
        var txs: [TransactionHistoryItem]
        var isPending: Bool
        let createdAt: Date
        var completedAt: Date?
        var isFailed: Bool
        var isSubmitFailed: Bool
        
        var latestTx: TransactionHistoryItem? {
            return txs.max(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) })
                ?? txs.first
        }
    }
    
    enum TxStatus: String, Codable {
        case pending = "pending"
        case confirmed = "confirmed"
        case failed = "failed"
        case dropped = "dropped"
        case submitFailed = "submitFailed"
    }
    
    struct SwapHistoryItem: Codable, Identifiable {
        let id: String
        let address: String
        let chainId: String
        let fromToken: TokenInfo
        let toToken: TokenInfo
        let fromAmount: String
        let toAmount: String
        let dexId: String
        var status: String // pending, success, failed
        let hash: String
        let createdAt: Date
        var completedAt: Date?
        let slippage: Double
    }
    
    struct BridgeHistoryItem: Codable, Identifiable {
        let id: String
        let address: String
        let fromChainId: String
        let toChainId: String
        let fromToken: TokenInfo
        let toToken: TokenInfo
        let fromAmount: String
        let toAmount: String
        let bridgeId: String
        var status: String // pending, fromSuccess, allSuccess, failed
        let hash: String
        let createdAt: Date
        var completedAt: Date?
        let estimatedDuration: TimeInterval
    }
    
    struct TokenInfo: Codable {
        let id: String
        let symbol: String
        let decimals: Int
        let logo: String?
    }
    
    // MARK: - Initialization
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Add Transaction
    
    func addTransaction(
        hash: String, from: String, to: String, value: String, data: String,
        chainId: String, nonce: Int, site: TransactionHistoryItem.ConnectedSite? = nil
    ) {
        let tx = TransactionHistoryItem(
            id: "\(hash)_\(chainId)", hash: hash, from: from, to: to,
            value: value, data: data, chainId: chainId, nonce: nonce,
            gasUsed: nil, gasPrice: nil, status: .pending,
            createdAt: Date(), completedAt: nil, isSubmitFailed: false,
            pushType: nil, site: site
        )
        
        let address = from.lowercased()
        var groups = transactions[address] ?? []
        
        // Find existing group with same nonce and chain
        if let groupIndex = groups.firstIndex(where: { $0.nonce == nonce && $0.chainId == chainId }) {
            groups[groupIndex].txs.append(tx)
        } else {
            let group = TransactionGroup(
                id: "\(address)_\(chainId)_\(nonce)",
                chainId: chainId, nonce: nonce, txs: [tx],
                isPending: true, createdAt: Date(), completedAt: nil,
                isFailed: false, isSubmitFailed: false
            )
            groups.insert(group, at: 0)
        }
        
        transactions[address] = groups
        
        // Update pending
        updatePendingTransactions(address: address)
        saveHistory()
        
        // Start watching this transaction
        TransactionWatcherManager.shared.watchTransaction(hash: hash, chain: chainId, nonce: String(nonce), address: address)
    }
    
    /// Mark transaction as completed
    func completeTransaction(hash: String, address: String, gasUsed: String?, success: Bool) {
        let lower = address.lowercased()
        guard var groups = transactions[lower] else { return }
        
        for i in 0..<groups.count {
            if let txIndex = groups[i].txs.firstIndex(where: { $0.hash == hash }) {
                var tx = groups[i].txs[txIndex]
                tx.completedAt = Date()
                groups[i].txs[txIndex] = tx
                groups[i].isPending = false
                groups[i].completedAt = Date()
                groups[i].isFailed = !success
                break
            }
        }
        
        transactions[lower] = groups
        updatePendingTransactions(address: lower)
        saveHistory()
    }
    
    /// Get transaction history for address
    func getHistory(address: String, chain: String? = nil) -> [TransactionGroup] {
        var groups = transactions[address.lowercased()] ?? []
        if let chain = chain {
            groups = groups.filter { $0.chainId == chain }
        }
        return groups.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Get pending transactions
    func getPendingTransactions(address: String) -> [TransactionGroup] {
        return pendingTransactions[address.lowercased()] ?? []
    }
    
    /// Get pending count
    func getPendingCount(address: String) -> Int {
        return getPendingTransactions(address: address).count
    }
    
    // MARK: - Swap History
    
    func addSwapHistory(
        address: String, chainId: String,
        fromToken: TokenInfo, toToken: TokenInfo,
        fromAmount: String, toAmount: String,
        dexId: String, hash: String, slippage: Double
    ) {
        let item = SwapHistoryItem(
            id: hash, address: address, chainId: chainId,
            fromToken: fromToken, toToken: toToken,
            fromAmount: fromAmount, toAmount: toAmount,
            dexId: dexId, status: "pending", hash: hash,
            createdAt: Date(), completedAt: nil, slippage: slippage
        )
        swapHistory.insert(item, at: 0)
        saveSwapHistory()
    }
    
    func updateSwapStatus(hash: String, status: String) {
        if let index = swapHistory.firstIndex(where: { $0.hash == hash }) {
            swapHistory[index].status = status
            if status == "success" || status == "failed" {
                swapHistory[index].completedAt = Date()
            }
            saveSwapHistory()
        }
    }
    
    func getSwapHistory(address: String) -> [SwapHistoryItem] {
        return swapHistory.filter { $0.address.lowercased() == address.lowercased() }
    }
    
    // MARK: - Bridge History
    
    func addBridgeHistory(
        address: String, fromChainId: String, toChainId: String,
        fromToken: TokenInfo, toToken: TokenInfo,
        fromAmount: String, toAmount: String,
        bridgeId: String, hash: String, estimatedDuration: TimeInterval
    ) {
        let item = BridgeHistoryItem(
            id: hash, address: address, fromChainId: fromChainId,
            toChainId: toChainId, fromToken: fromToken, toToken: toToken,
            fromAmount: fromAmount, toAmount: toAmount, bridgeId: bridgeId,
            status: "pending", hash: hash, createdAt: Date(),
            completedAt: nil, estimatedDuration: estimatedDuration
        )
        bridgeHistory.insert(item, at: 0)
        saveBridgeHistory()
    }
    
    func updateBridgeStatus(hash: String, status: String) {
        if let index = bridgeHistory.firstIndex(where: { $0.hash == hash }) {
            bridgeHistory[index].status = status
            if status == "allSuccess" || status == "failed" {
                bridgeHistory[index].completedAt = Date()
            }
            saveBridgeHistory()
        }
    }
    
    // MARK: - Clear
    
    func clearHistory(address: String) {
        transactions.removeValue(forKey: address.lowercased())
        pendingTransactions.removeValue(forKey: address.lowercased())
        saveHistory()
    }
    
    func clearAll() {
        transactions.removeAll()
        pendingTransactions.removeAll()
        swapHistory.removeAll()
        bridgeHistory.removeAll()
        saveHistory()
        saveSwapHistory()
        saveBridgeHistory()
    }
    
    // MARK: - Private
    
    private func updatePendingTransactions(address: String) {
        let groups = transactions[address] ?? []
        pendingTransactions[address] = groups.filter { $0.isPending }
    }
    
    private func loadHistory() {
        if let d = storage.getData(forKey: historyKey),
           let h = try? JSONDecoder().decode([String: [TransactionGroup]].self, from: d) {
            self.transactions = h
            for (addr, _) in h { updatePendingTransactions(address: addr) }
        }
        if let d = storage.getData(forKey: swapHistoryKey),
           let h = try? JSONDecoder().decode([SwapHistoryItem].self, from: d) {
            self.swapHistory = h
        }
        if let d = storage.getData(forKey: bridgeHistoryKey),
           let h = try? JSONDecoder().decode([BridgeHistoryItem].self, from: d) {
            self.bridgeHistory = h
        }
    }
    
    private func saveHistory() {
        if let d = try? JSONEncoder().encode(transactions) { storage.setData(d, forKey: historyKey) }
    }
    private func saveSwapHistory() {
        if let d = try? JSONEncoder().encode(swapHistory) { storage.setData(d, forKey: swapHistoryKey) }
    }
    private func saveBridgeHistory() {
        if let d = try? JSONEncoder().encode(bridgeHistory) { storage.setData(d, forKey: bridgeHistoryKey) }
    }
}
