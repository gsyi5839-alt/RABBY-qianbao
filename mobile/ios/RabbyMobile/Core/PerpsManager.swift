import Foundation

/// Perpetuals Trading Manager - HyperLiquid-style perps trading
/// Corresponds to: src/background/service/perps.ts
@MainActor
class PerpsManager: ObservableObject {
    static let shared = PerpsManager()
    
    @Published var currentAccount: PerpsAccount?
    @Published var lastUsedAccount: PerpsAccount?
    @Published var hasDoneNewUserProcess: Bool = false
    @Published var favoritedCoins: [String] = ["BTC", "ETH", "SOL"]
    @Published var marketSlippage: Double = 0.08
    @Published var soundEnabled: Bool = true
    @Published var quoteUnit: QuoteUnit = .base
    @Published var positions: [Position] = []
    @Published var orders: [Order] = []
    @Published var isLoading = false
    
    private let storage = StorageManager.shared
    private let storageKey = "perps_store"
    private var agentWallets: [String: AgentWalletInfo] = [:]
    
    struct PerpsAccount: Codable, Identifiable {
        let address: String
        let type: String
        let brandName: String
        var id: String { address }
    }
    
    struct AgentWalletInfo: Codable {
        let vault: String
        var agentAddress: String
        var approveSignatures: [ApproveSignature]
    }
    
    struct ApproveSignature: Codable {
        let type: String // "approveAgent" | "approveBuilderFee"
        let signature: String
        let nonce: Int
    }
    
    enum QuoteUnit: String, Codable, CaseIterable {
        case base = "base"
        case usd = "usd"
    }
    
    struct Position: Identifiable, Codable {
        let id: String
        let coin: String
        let side: String // "long" | "short"
        let size: Double
        let entryPrice: Double
        let markPrice: Double
        let unrealizedPnl: Double
        let leverage: Int
        let liquidationPrice: Double?
        
        var pnlPercentage: Double {
            guard entryPrice > 0 else { return 0 }
            return (unrealizedPnl / (size * entryPrice)) * 100
        }
    }
    
    struct Order: Identifiable, Codable {
        let id: String
        let coin: String
        let side: String
        let orderType: String // "limit" | "market"
        let size: Double
        let price: Double?
        let status: String
        let createdAt: Date
    }
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Account
    
    func setCurrentAccount(_ account: PerpsAccount?) {
        if let account = account {
            lastUsedAccount = account
        }
        currentAccount = account
        saveToStorage()
    }
    
    func getLastUsedAccount() -> PerpsAccount? {
        return lastUsedAccount
    }
    
    // MARK: - Agent Wallet
    
    func createAgentWallet(masterAddress: String) async throws -> (agentAddress: String, vault: String) {
        // Generate new keypair for agent wallet
        var privateKeyBytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, privateKeyBytes.count, &privateKeyBytes)
        guard result == errSecSuccess else { throw PerpsError.keyGenerationFailed }
        
        let vault = privateKeyBytes.map { String(format: "%02x", $0) }.joined()
        
        // Derive address from private key (simplified)
        let agentAddress = "0x" + vault.prefix(40)
        
        let walletInfo = AgentWalletInfo(vault: vault, agentAddress: agentAddress, approveSignatures: [])
        agentWallets[masterAddress.lowercased()] = walletInfo
        saveToStorage()
        
        return (agentAddress, vault)
    }
    
    func getAgentWallet(address: String) -> AgentWalletInfo? {
        return agentWallets[address.lowercased()]
    }
    
    func hasAgentWallet(address: String) -> Bool {
        return agentWallets[address.lowercased()] != nil
    }
    
    func removeAgentWallet(address: String) {
        agentWallets.removeValue(forKey: address.lowercased())
        if currentAccount?.address.lowercased() == address.lowercased() { currentAccount = nil }
        if lastUsedAccount?.address.lowercased() == address.lowercased() { lastUsedAccount = nil }
        saveToStorage()
    }
    
    // MARK: - Trading Settings
    
    func setFavoritedCoins(_ coins: [String]) {
        favoritedCoins = coins
        saveToStorage()
    }
    
    func setMarketSlippage(_ slippage: Double) {
        marketSlippage = max(0, min(1, slippage))
        saveToStorage()
    }
    
    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        saveToStorage()
    }
    
    func setQuoteUnit(_ unit: QuoteUnit) {
        quoteUnit = unit
        saveToStorage()
    }
    
    func setHasDoneNewUserProcess(_ done: Bool) {
        hasDoneNewUserProcess = done
        saveToStorage()
    }
    
    // MARK: - Positions & Orders
    
    func loadPositions(address: String) async {
        isLoading = true
        // TODO: Fetch positions from HyperLiquid API
        isLoading = false
    }
    
    func loadOrders(address: String) async {
        // TODO: Fetch open orders from HyperLiquid API
    }
    
    func placeOrder(coin: String, side: String, size: Double, price: Double?, leverage: Int, orderType: String) async throws -> Order {
        guard let account = currentAccount else { throw PerpsError.noAccount }
        
        let order = Order(
            id: UUID().uuidString, coin: coin, side: side, orderType: orderType,
            size: size, price: price, status: "pending", createdAt: Date()
        )
        orders.append(order)
        return order
    }
    
    func cancelOrder(orderId: String) async throws {
        orders.removeAll { $0.id == orderId }
    }
    
    // MARK: - Storage
    
    private func loadFromStorage() {
        if let data = storage.getData(forKey: storageKey),
           let store = try? JSONDecoder().decode(PerpsStore.self, from: data) {
            currentAccount = store.currentAccount
            lastUsedAccount = store.lastUsedAccount
            hasDoneNewUserProcess = store.hasDoneNewUserProcess
            favoritedCoins = store.favoritedCoins
            marketSlippage = store.marketSlippage
            soundEnabled = store.soundEnabled
            quoteUnit = store.quoteUnit
        }
    }
    
    private func saveToStorage() {
        let store = PerpsStore(
            currentAccount: currentAccount, lastUsedAccount: lastUsedAccount,
            hasDoneNewUserProcess: hasDoneNewUserProcess, favoritedCoins: favoritedCoins,
            marketSlippage: marketSlippage, soundEnabled: soundEnabled, quoteUnit: quoteUnit
        )
        if let data = try? JSONEncoder().encode(store) {
            storage.setData(data, forKey: storageKey)
        }
    }
    
    private struct PerpsStore: Codable {
        let currentAccount: PerpsAccount?
        let lastUsedAccount: PerpsAccount?
        let hasDoneNewUserProcess: Bool
        let favoritedCoins: [String]
        let marketSlippage: Double
        let soundEnabled: Bool
        let quoteUnit: QuoteUnit
    }
}

enum PerpsError: LocalizedError {
    case noAccount
    case keyGenerationFailed
    case tradingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noAccount: return "No perps account configured"
        case .keyGenerationFailed: return "Failed to generate agent wallet key"
        case .tradingFailed(let msg): return "Trading failed: \(msg)"
        }
    }
}
