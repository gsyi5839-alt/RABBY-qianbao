import Foundation

/// Transaction broadcast watcher - monitors submitted transactions for confirmation
/// Corresponds to: src/background/service/transactionBroadcastWatcher.ts
@MainActor
class TransactionBroadcastWatcherManager: ObservableObject {
    static let shared = TransactionBroadcastWatcherManager()
    
    @Published var pendingBroadcasts: [String: BroadcastItem] = [:]
    
    private let storage = StorageManager.shared
    private let storageKey = "txBroadcastWatcher"
    private var pollingTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 5.0
    
    struct BroadcastItem: Codable, Identifiable {
        let id: String // reqId
        let address: String
        let chainId: Int
        let nonce: String
        var txHash: String?
        var status: BroadcastStatus
        let createdAt: Date
        
        enum BroadcastStatus: String, Codable {
            case pending
            case submitted
            case confirmed
            case failed
            case withdrawn
        }
    }
    
    private init() {
        loadFromStorage()
        startPolling()
    }
    
    // MARK: - Public API
    
    func addTransaction(reqId: String, address: String, chainId: Int, nonce: String) {
        let item = BroadcastItem(
            id: reqId, address: address, chainId: chainId,
            nonce: nonce, txHash: nil, status: .pending, createdAt: Date()
        )
        pendingBroadcasts[reqId] = item
        saveToStorage()
    }
    
    func updateTransaction(reqId: String, txHash: String? = nil, status: BroadcastItem.BroadcastStatus? = nil) {
        guard var item = pendingBroadcasts[reqId] else { return }
        if let txHash = txHash { item.txHash = txHash }
        if let status = status { item.status = status }
        pendingBroadcasts[reqId] = item
        saveToStorage()
    }
    
    func removeTransaction(reqId: String) {
        pendingBroadcasts.removeValue(forKey: reqId)
        saveToStorage()
    }
    
    func clearPendingForAddress(_ address: String, chainId: Int? = nil) {
        let lowAddress = address.lowercased()
        pendingBroadcasts = pendingBroadcasts.filter { _, item in
            let isSameAddr = item.address.lowercased() == lowAddress
            if let chainId = chainId {
                return !(isSameAddr && item.chainId == chainId)
            }
            return !isSameAddr
        }
        saveToStorage()
    }
    
    func removeLocalPendingTx(address: String, chainId: Int, nonce: Int) {
        pendingBroadcasts = pendingBroadcasts.filter { _, item in
            !(item.address.lowercased() == address.lowercased() &&
              item.chainId == chainId &&
              Int(item.nonce) == nonce)
        }
        saveToStorage()
    }
    
    // MARK: - Polling
    
    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.queryPendingTransactions()
                try? await Task.sleep(nanoseconds: UInt64(5_000_000_000))
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func queryPendingTransactions() async {
        let pendingItems = pendingBroadcasts.values.filter { $0.status == .pending || $0.status == .submitted }
        guard !pendingItems.isEmpty else { return }
        
        let reqIds = pendingItems.map { $0.id }
        
        do {
            let results: [OpenAPIService.TxRequest] = try await OpenAPIService.shared.getTxRequests(ids: reqIds)
            
            for result in results {
                if result.is_finished || result.is_withdraw || result.tx_id != nil {
                    if result.is_finished {
                        updateTransaction(reqId: result.id, txHash: result.tx_id, status: .confirmed)
                    } else if result.is_withdraw {
                        updateTransaction(reqId: result.id, status: .withdrawn)
                    }
                    
                    // Notify transaction watcher if we got a tx hash
                    if let txId = result.tx_id {
                        let chain = ChainManager.shared.getChain(id: result.signed_tx.chainId)
                        if let chain = chain {
                            TransactionWatcherManager.shared.addPendingTx(
                                hash: txId,
                                chain: chain.serverId,
                                from: result.signed_tx.from
                            )
                        }
                        
                        // Update swap/bridge tracking
                        SwapManager.shared.checkAndConfirmSwap(txHash: txId, chainId: result.signed_tx.chainId)
                        BridgeManager.shared.checkAndConfirmBridge(txHash: txId, chainId: result.signed_tx.chainId)
                    }
                    
                    // Remove from broadcast watching once confirmed/finished
                    if result.is_finished || result.is_withdraw {
                        removeTransaction(reqId: result.id)
                    }
                }
            }
            
            // Notify UI to reload
            NotificationCenter.default.post(name: .txBroadcastUpdated, object: nil)
        } catch {
            print("TransactionBroadcastWatcher: query failed - \(error)")
        }
    }
    
    // MARK: - Storage
    
    private func loadFromStorage() {
        if let data = storage.getData(forKey: storageKey),
           let items = try? JSONDecoder().decode([String: BroadcastItem].self, from: data) {
            pendingBroadcasts = items
        }
    }
    
    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(pendingBroadcasts) {
            storage.setData(data, forKey: storageKey)
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let txBroadcastUpdated = Notification.Name("txBroadcastUpdated")
    static let txConfirmed = Notification.Name("txConfirmed")
    static let txFailed = Notification.Name("txFailed")
}
