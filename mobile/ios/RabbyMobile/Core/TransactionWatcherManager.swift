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
        // 通过 serverId 获取 Chain 对象
        if let chainObj = ChainManager.shared.getChain(serverId: chain) {
            // 优先使用自定义 RPC
            if let effectiveRPC = RPCManager.shared.getEffectiveRPC(chainId: chainObj.id) {
                return effectiveRPC
            }
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
    private let database = DatabaseManager.shared
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

    private func normalizedOrigin(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.hasPrefix("http://") && !value.hasPrefix("https://") {
            value = "https://\(value)"
        }

        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return raw.lowercased()
        }

        var origin = "\(scheme)://\(host)"
        if let port = components.port {
            let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
            if !isDefaultPort {
                origin += ":\(port)"
            }
        }
        return origin
    }

    private func legacyHost(_ raw: String) -> String? {
        guard let components = URLComponents(string: raw), let host = components.host else {
            if raw.contains("://") { return nil }
            return raw.lowercased()
        }
        return host.lowercased()
    }

    private func findSiteIndex(origin: String) -> Int? {
        let normalized = normalizedOrigin(origin)
        if let index = connectedSites.firstIndex(where: { normalizedOrigin($0.origin) == normalized }) {
            return index
        }
        if let host = legacyHost(normalized) {
            return connectedSites.firstIndex(where: { $0.origin.lowercased() == host })
        }
        return nil
    }

    /// Add connected site
    func addSite(origin: String, name: String, icon: String?, chain: String, account: ConnectedSite.AccountInfo?) {
        let normalized = normalizedOrigin(origin)
        let site = ConnectedSite(
            id: normalized, origin: normalized, name: name, icon: icon,
            chain: chain, isConnected: true, isFavorite: false,
            isTop: false, account: account, connectedAt: Date()
        )

        if let index = findSiteIndex(origin: normalized) {
            connectedSites[index] = site
        } else {
            connectedSites.append(site)
        }
        saveSites()
    }
    
    /// Remove site
    func removeSite(origin: String) {
        guard let index = findSiteIndex(origin: origin) else { return }
        connectedSites.remove(at: index)
        saveSites()
    }

    /// Disconnect site
    func disconnectSite(origin: String) {
        if let index = findSiteIndex(origin: origin) {
            connectedSites[index].isConnected = false
        }
        saveSites()
    }

    /// Check if site is connected
    func isConnected(origin: String) -> Bool {
        guard let index = findSiteIndex(origin: origin) else { return false }
        return connectedSites[index].isConnected
    }

    /// Get connected site
    func getSite(origin: String) -> ConnectedSite? {
        guard let index = findSiteIndex(origin: origin) else { return nil }
        return connectedSites[index]
    }
    
    /// Get all connected sites
    func getConnectedSites() -> [ConnectedSite] {
        return connectedSites.filter { $0.isConnected }
    }
    
    /// Toggle favorite
    func toggleFavorite(origin: String) {
        if let index = findSiteIndex(origin: origin) {
            connectedSites[index].isFavorite.toggle()
            saveSites()
        }
    }
    
    /// Toggle top/pin
    func toggleTop(origin: String) {
        if let index = findSiteIndex(origin: origin) {
            connectedSites[index].isTop.toggle()
            saveSites()
        }
    }
    
    /// Change chain for site
    func setSiteChain(origin: String, chain: String) {
        if let index = findSiteIndex(origin: origin) {
            connectedSites[index].chain = chain
            saveSites()
        }
    }

    /// Update connected account for a site (aligns with extension: per-site selected account).
    func setSiteAccount(origin: String, account: ConnectedSite.AccountInfo?) {
        if let index = findSiteIndex(origin: origin) {
            connectedSites[index].account = account
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
        if let data = try? database.getValueData(forKey: permKey),
           let sites = try? JSONDecoder().decode([ConnectedSite].self, from: data) {
            self.connectedSites = sites
            return
        }

        if let d = storage.getData(forKey: permKey),
           let s = try? JSONDecoder().decode([ConnectedSite].self, from: d) {
            self.connectedSites = s
        }
    }
    
    private func saveSites() {
        if let d = try? JSONEncoder().encode(connectedSites) {
            try? database.setValueData(d, forKey: permKey)
            storage.setData(d, forKey: permKey)
        }
    }
}
