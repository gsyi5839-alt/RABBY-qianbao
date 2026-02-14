import Foundation

/// Sync Chain Service - Periodically sync supported chain list from remote
/// Corresponds to: src/background/service/syncChain.ts
@MainActor
class SyncChainManager: ObservableObject {
    static let shared = SyncChainManager()
    
    @Published var lastUpdated: Date?
    @Published var isSyncing = false
    
    private let storage = StorageManager.shared
    private let storageKey = "sync_chain_store"
    private let chainListURL = "https://static.debank.com/supported_chains.json"
    private let syncInterval: TimeInterval = 55 * 60 // 55 minutes
    private var syncTimer: Timer?
    
    struct RemoteSupportedChain: Codable {
        let id: String
        let community_id: Int
        let name: String
        let native_token_id: String?  // Optional - some chains may not have this field
        let logo_url: String?
        let wrapped_token_id: String?
        let symbol: String?
        let is_disabled: Bool?
        let eip_1559: Bool?
        let need_estimate_gas: Bool?
        let explorer_host: String?
        let rpc_url: String?
    }
    
    private init() {
        let timestamp = storage.getDouble(forKey: "\(storageKey)_updatedAt")
        if timestamp > 0 {
            lastUpdated = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    // MARK: - Public API
    
    func syncIfNeeded() async {
        // Only sync if last sync was more than 55 minutes ago
        if let lastUpdated = lastUpdated, Date().timeIntervalSince(lastUpdated) < syncInterval {
            return
        }
        await syncMainnetChainList()
    }
    
    func syncMainnetChainList() async {
        guard !isSyncing else { return }
        isSyncing = true
        
        do {
            guard let url = URL(string: chainListURL) else {
                isSyncing = false
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let chains = try JSONDecoder().decode([RemoteSupportedChain].self, from: data)
            
            let activeChains = chains.filter { !($0.is_disabled ?? false) }
            
            // Update ChainManager with fresh chain data
            updateChainManager(with: activeChains)
            
            // Save to local storage
            if let encodedData = try? JSONEncoder().encode(activeChains) {
                storage.setData(encodedData, forKey: "\(storageKey)_chains")
            }
            
            lastUpdated = Date()
            storage.setDouble(Date().timeIntervalSince1970, forKey: "\(storageKey)_updatedAt")
        } catch {
            print("SyncChainManager: sync failed - \(error)")
        }
        
        isSyncing = false
    }
    
    func startPeriodicSync() {
        stopPeriodicSync()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncMainnetChainList()
            }
        }
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Load cached chains
    
    func loadCachedChains() {
        if let data = storage.getData(forKey: "\(storageKey)_chains"),
           let chains = try? JSONDecoder().decode([RemoteSupportedChain].self, from: data) {
            updateChainManager(with: chains)
        }
    }
    
    // MARK: - Private
    
    private func updateChainManager(with remoteChains: [RemoteSupportedChain]) {
        var updatedChains: [Chain] = []
        
        for remote in remoteChains {
            guard let communityId = Optional(remote.community_id), communityId > 0,
                  let rpcUrl = remote.rpc_url, !rpcUrl.isEmpty else { continue }
            
            let chain = Chain(
                id: communityId,
                name: remote.name,
                serverId: remote.id,
                symbol: remote.symbol ?? (remote.native_token_id?.uppercased() ?? "ETH"),
                nativeTokenAddress: remote.native_token_id ?? "eth",
                rpcUrl: rpcUrl,
                scanUrl: remote.explorer_host.map { "https://\($0)" } ?? "",
                logo: remote.logo_url ?? "",
                decimals: 18,
                isEIP1559: remote.eip_1559 ?? false
            )
            updatedChains.append(chain)
        }
        
        if !updatedChains.isEmpty {
            ChainManager.shared.mainnetChains = updatedChains
            if ChainManager.shared.selectedChain == nil {
                ChainManager.shared.selectedChain = updatedChains.first
            }
        }
    }
}
