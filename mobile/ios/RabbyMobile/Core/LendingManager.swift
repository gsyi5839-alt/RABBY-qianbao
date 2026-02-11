import Foundation

/// Lending Manager - DeFi lending/borrowing protocol support
/// Corresponds to: src/background/service/lending.ts
@MainActor
class LendingManager: ObservableObject {
    static let shared = LendingManager()
    
    @Published var protocols: [LendingProtocolInfo] = []
    @Published var positions: [LendingPosition] = []
    @Published var lastSelectedMarket: String = "aave_v3_eth"
    @Published var skipHealthFactorWarning: Bool = false
    @Published var isLoading = false
    
    private let storage = StorageManager.shared
    private let storageKey = "lending_store"
    
    struct LendingProtocolInfo: Identifiable, Codable {
        let id: String
        let name: String
        let chain: String
        let logoUrl: String?
        let tvl: Double?
        let apy: Double?
        let markets: [Market]?
        
        struct Market: Identifiable, Codable {
            let id: String
            let name: String
            let supplyAPY: Double?
            let borrowAPY: Double?
            let totalSupply: Double?
            let totalBorrow: Double?
            let tokenSymbol: String
            let tokenAddress: String
        }
    }
    
    struct LendingPosition: Identifiable, Codable {
        let id: String
        let protocolId: String
        let protocolName: String
        let chain: String
        let supplyTokens: [SupplyBorrowToken]
        let borrowTokens: [SupplyBorrowToken]
        let healthRate: Double?
        let netAPY: Double?
        
        struct SupplyBorrowToken: Identifiable, Codable {
            let id: String
            let symbol: String
            let amount: Double
            let value: Double
            let apy: Double?
        }
        
        var totalSupplyValue: Double { supplyTokens.reduce(0) { $0 + $1.value } }
        var totalBorrowValue: Double { borrowTokens.reduce(0) { $0 + $1.value } }
        var netValue: Double { totalSupplyValue - totalBorrowValue }
        
        var healthStatus: HealthStatus {
            guard let rate = healthRate else { return .unknown }
            if rate > 2.0 { return .safe }
            if rate > 1.2 { return .warning }
            return .danger
        }
        
        enum HealthStatus: String {
            case safe, warning, danger, unknown
        }
    }
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Public API
    
    func loadProtocols(chainId: String) async {
        isLoading = true
        do {
            let result = try await OpenAPIService.shared.getLendingProtocols(chainId: chainId)
            protocols = result.map { p in
                LendingProtocolInfo(id: p.id, name: p.name, chain: p.chain, logoUrl: p.logo_url, tvl: p.tvl, apy: nil, markets: nil)
            }
        } catch {
            print("LendingManager: load protocols failed - \(error)")
        }
        isLoading = false
    }
    
    func loadPositions(address: String) async {
        isLoading = true
        do {
            let result = try await OpenAPIService.shared.getLendingPositions(address: address)
            positions = result.compactMap { pos in
                let supplyTokens = pos.supply_token_list?.enumerated().map { idx, token in
                    LendingPosition.SupplyBorrowToken(
                        id: "\(pos.protocol_id)_supply_\(idx)", symbol: token.symbol,
                        amount: token.amount ?? 0, value: (token.amount ?? 0) * (token.price ?? 0), apy: nil
                    )
                } ?? []
                let borrowTokens = pos.borrow_token_list?.enumerated().map { idx, token in
                    LendingPosition.SupplyBorrowToken(
                        id: "\(pos.protocol_id)_borrow_\(idx)", symbol: token.symbol,
                        amount: token.amount ?? 0, value: (token.amount ?? 0) * (token.price ?? 0), apy: nil
                    )
                } ?? []
                return LendingPosition(
                    id: pos.protocol_id, protocolId: pos.protocol_id,
                    protocolName: pos.protocol_id, chain: "", supplyTokens: supplyTokens,
                    borrowTokens: borrowTokens, healthRate: pos.health_rate, netAPY: nil
                )
            }
        } catch {
            print("LendingManager: load positions failed - \(error)")
        }
        isLoading = false
    }
    
    func setLastSelectedMarket(_ market: String) {
        lastSelectedMarket = market
        saveToStorage()
    }
    
    func setSkipHealthFactorWarning(_ skip: Bool) {
        skipHealthFactorWarning = skip
        saveToStorage()
    }
    
    // MARK: - Storage
    
    private func loadFromStorage() {
        if let market = storage.getString(forKey: "\(storageKey)_market") {
            lastSelectedMarket = market
        }
        skipHealthFactorWarning = storage.getBool(forKey: "\(storageKey)_skipHealth")
    }
    
    private func saveToStorage() {
        storage.setString(lastSelectedMarket, forKey: "\(storageKey)_market")
        storage.setBool(skipHealthFactorWarning, forKey: "\(storageKey)_skipHealth")
    }
}
