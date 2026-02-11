import Foundation
import Combine

/// Transaction Watcher - Monitor pending transaction status
/// Equivalent to Web version's transactionWatcher service (306 lines)
@MainActor
class TransactionWatcherManager: ObservableObject {
    static let shared = TransactionWatcherManager()
    
    @Published var watchingTransactions: [String: WatchedTransaction] = [:]
    
    private var timers: [String: Timer] = [:]
    private let networkManager = NetworkManager.shared
    
    struct WatchedTransaction: Codable {
        let hash: String
        let chain: String
        let nonce: String
        let address: String
        let createdAt: Date
        var checkCount: Int
    }
    
    /// Add a pending transaction to watch (alias for watchTransaction with default nonce)
    func addPendingTx(hash: String, chain: String, from: String) {
        watchTransaction(hash: hash, chain: chain, nonce: "0", address: from)
    }
    
    private init() {}
    
    /// Start watching a transaction
    func watchTransaction(hash: String, chain: String, nonce: String, address: String) {
        let tx = WatchedTransaction(hash: hash, chain: chain, nonce: nonce, address: address, createdAt: Date(), checkCount: 0)
        watchingTransactions[hash] = tx
        
        // Poll every 5 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTransaction(hash: hash)
            }
        }
        timers[hash] = timer
    }
    
    /// Stop watching
    func stopWatching(hash: String) {
        timers[hash]?.invalidate()
        timers.removeValue(forKey: hash)
        watchingTransactions.removeValue(forKey: hash)
    }
    
    /// Check transaction status
    private func checkTransaction(hash: String) {
        guard var tx = watchingTransactions[hash] else { return }
        tx.checkCount += 1
        watchingTransactions[hash] = tx
        
        // Stop after 200 checks (~16 minutes)
        if tx.checkCount > 200 {
            stopWatching(hash: hash)
            return
        }
        
        Task {
            do {
                let receipt = try await getTransactionReceipt(hash: hash, chain: tx.chain)
                if let receipt = receipt {
                    let success = (receipt["status"] as? String) == "0x1"
                    let gasUsed = receipt["gasUsed"] as? String
                    
                    TransactionHistoryManager.shared.completeTransaction(
                        hash: hash, address: tx.address,
                        gasUsed: gasUsed, success: success
                    )
                    stopWatching(hash: hash)
                }
            } catch {
                // Transaction not found yet, continue polling
            }
        }
    }
    
    private func getTransactionReceipt(hash: String, chain: String) async throws -> [String: Any]? {
        let rpcUrl = getRPCUrl(chain: chain)
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getTransactionReceipt",
            "params": [hash],
            "id": 1
        ]
        
        struct RPCReceiptResponse: Codable {
            let result: ReceiptResult?
            
            struct ReceiptResult: Codable {
                let status: String?
                let gasUsed: String?
                let transactionHash: String?
            }
        }
        
        let response: RPCReceiptResponse = try await networkManager.post(url: rpcUrl, body: params)
        
        if let result = response.result {
            var dict: [String: Any] = [:]
            if let status = result.status { dict["status"] = status }
            if let gasUsed = result.gasUsed { dict["gasUsed"] = gasUsed }
            if let txHash = result.transactionHash { dict["transactionHash"] = txHash }
            return dict
        }
        return nil
    }
    
    private func getRPCUrl(chain: String) -> String {
        if let customRPC = CustomRPCManager.shared.getRPC(chain: chain), customRPC.enable {
            return customRPC.url
        }
        return ChainManager.shared.getRPCUrl(chain: chain)
    }
}

/// DApp Permission Manager - Manage DApp connection permissions
/// Equivalent to Web version's permission service (339 lines)
@MainActor
class DAppPermissionManager: ObservableObject {
    static let shared = DAppPermissionManager()
    
    @Published var connectedSites: [ConnectedSite] = []
    
    private let storage = StorageManager.shared
    private let permKey = "rabby_dapp_permissions"
    
    struct ConnectedSite: Codable, Identifiable {
        let id: String // origin
        let origin: String
        let name: String
        let icon: String?
        var chain: String
        var isConnected: Bool
        var isFavorite: Bool
        var isTop: Bool
        var account: AccountInfo?
        let connectedAt: Date
        
        struct AccountInfo: Codable {
            let address: String
            let type: String
            let brandName: String
        }
    }
    
    private init() { loadSites() }
    
    /// Add connected site
    func addSite(origin: String, name: String, icon: String?, chain: String, account: ConnectedSite.AccountInfo?) {
        let site = ConnectedSite(
            id: origin, origin: origin, name: name, icon: icon,
            chain: chain, isConnected: true, isFavorite: false,
            isTop: false, account: account, connectedAt: Date()
        )
        
        if let index = connectedSites.firstIndex(where: { $0.origin == origin }) {
            connectedSites[index] = site
        } else {
            connectedSites.append(site)
        }
        saveSites()
    }
    
    /// Remove site
    func removeSite(origin: String) {
        connectedSites.removeAll { $0.origin == origin }
        saveSites()
    }
    
    /// Disconnect site
    func disconnectSite(origin: String) {
        if let index = connectedSites.firstIndex(where: { $0.origin == origin }) {
            connectedSites[index].isConnected = false
        }
        saveSites()
    }
    
    /// Check if site is connected
    func isConnected(origin: String) -> Bool {
        return connectedSites.first(where: { $0.origin == origin })?.isConnected ?? false
    }
    
    /// Get connected site
    func getSite(origin: String) -> ConnectedSite? {
        return connectedSites.first(where: { $0.origin == origin })
    }
    
    /// Get all connected sites
    func getConnectedSites() -> [ConnectedSite] {
        return connectedSites.filter { $0.isConnected }
    }
    
    /// Toggle favorite
    func toggleFavorite(origin: String) {
        if let index = connectedSites.firstIndex(where: { $0.origin == origin }) {
            connectedSites[index].isFavorite.toggle()
            saveSites()
        }
    }
    
    /// Toggle top/pin
    func toggleTop(origin: String) {
        if let index = connectedSites.firstIndex(where: { $0.origin == origin }) {
            connectedSites[index].isTop.toggle()
            saveSites()
        }
    }
    
    /// Change chain for site
    func setSiteChain(origin: String, chain: String) {
        if let index = connectedSites.firstIndex(where: { $0.origin == origin }) {
            connectedSites[index].chain = chain
            saveSites()
        }
    }
    
    /// Disconnect all sites
    func disconnectAll() {
        for i in 0..<connectedSites.count {
            connectedSites[i].isConnected = false
        }
        saveSites()
    }
    
    private func loadSites() {
        if let d = storage.getData(forKey: permKey),
           let s = try? JSONDecoder().decode([ConnectedSite].self, from: d) {
            self.connectedSites = s
        }
    }
    
    private func saveSites() {
        if let d = try? JSONEncoder().encode(connectedSites) { storage.setData(d, forKey: permKey) }
    }
}
