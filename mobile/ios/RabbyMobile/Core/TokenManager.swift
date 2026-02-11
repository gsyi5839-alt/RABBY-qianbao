import Foundation
import Combine
import BigInt

/// Token manager for managing ERC20 tokens and balances
/// Optimized: balance cache limited to 500 entries, memory warning cleanup
@MainActor
class TokenManager: ObservableObject {
    static let shared = TokenManager()
    
    @Published var tokens: [String: [TokenItem]] = [:] // key -> tokens
    @Published var customTokens: [TokenItem] = []
    @Published var blockedTokens: Set<String> = [] // Set of token IDs
    @Published var tokenBalances: [String: TokenBalance] = [:] // tokenId -> balance
    @Published var showLPTokens: Bool = false
    
    /// Maximum number of balance cache entries
    private let maxBalanceCacheSize = 500
    
    private let networkManager = NetworkManager.shared
    private let storageManager = StorageManager.shared
    private let chainManager = ChainManager.shared
    
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadCustomTokens()
        loadBlockedTokens()
        startAutoRefresh()
        observeMemoryWarnings()
    }
    
    // MARK: - Token Loading
    
    /// Load tokens for address on specific chain
    func loadTokens(address: String, chain: Chain) async throws -> [TokenItem] {
        // For now, return native token + custom tokens
        // In production, would call backend API to get token list
        var tokenList: [TokenItem] = []
        
        // Add native token
        let nativeToken = TokenItem(
            id: "\(chain.serverId):\(chain.nativeTokenAddress)",
            chainId: chain.id,
            address: chain.nativeTokenAddress,
            symbol: chain.nativeTokenSymbol,
            name: chain.name,
            decimals: 18,
            logoURL: nil,
            price: 0,
            priceChange24h: nil,
            isNative: true
        )
        tokenList.append(nativeToken)
        
        // Add custom tokens for this chain
        let chainCustomTokens = customTokens.filter { $0.chainId == chain.id }
        tokenList.append(contentsOf: chainCustomTokens)
        
        // Update cache
        let key = "\(address.lowercased())_\(chain.id)"
        tokens[key] = tokenList
        
        // Load balances for these tokens
        await loadBalances(address: address, tokens: tokenList, chain: chain)
        
        return tokenList
    }
    
    /// Load balances for tokens
    func loadBalances(address: String, tokens: [TokenItem], chain: Chain) async {
        for token in tokens {
            do {
                let balance = try await getTokenBalance(
                    tokenAddress: token.address,
                    ownerAddress: address,
                    decimals: token.decimals,
                    chain: chain
                )
                
                let tokenBalance = TokenBalance(
                    tokenId: token.id,
                    address: address,
                    chainId: chain.id,
                    balance: balance,
                    balanceFormatted: formatTokenAmount(balance, decimals: token.decimals),
                    updatedAt: Date()
                )
                
                tokenBalances[token.id] = tokenBalance
            } catch {
                print("Error loading balance for token \(token.symbol): \(error)")
            }
        }
    }
    
    // MARK: - Token Balance Query
    
    /// Get token balance
    func getTokenBalance(
        tokenAddress: String,
        ownerAddress: String,
        decimals: Int,
        chain: Chain
    ) async throws -> String {
        if tokenAddress == chain.nativeTokenAddress || tokenAddress == "0x0000000000000000000000000000000000000000" {
            // Native token balance
            return try await networkManager.getBalance(address: ownerAddress, chain: chain)
        } else {
            // ERC20 token balance
            return try await networkManager.getERC20Balance(
                tokenAddress: tokenAddress,
                ownerAddress: ownerAddress,
                chain: chain
            )
        }
    }
    
    /// Get cached balance
    func getCachedBalance(tokenId: String) -> TokenBalance? {
        return tokenBalances[tokenId]
    }
    
    /// Get total portfolio value in USD
    func getTotalValue(address: String) -> Decimal {
        let addressTokens = tokens.values.flatMap { $0 }
        var total: Decimal = 0
        
        for token in addressTokens {
            if let balance = tokenBalances[token.id] {
                let balanceValue = Decimal(string: balance.balance) ?? 0
                let tokenValue = balanceValue / pow(10, token.decimals) * Decimal(token.price)
                total += tokenValue
            }
        }
        
        return total
    }
    
    // MARK: - Token Blocking
    
    /// Block a token from appearing in the list
    func blockToken(id: String) {
        blockedTokens.insert(id)
        saveBlockedTokens()
    }
    
    /// Unblock a token
    func unblockToken(id: String) {
        blockedTokens.remove(id)
        saveBlockedTokens()
    }
    
    /// Check if a token is blocked
    func isBlocked(tokenId: String) -> Bool {
        blockedTokens.contains(tokenId)
    }
    
    /// Get all blocked token items
    func getBlockedTokenItems(address: String) -> [TokenItem] {
        let allTokens = tokens.values.flatMap { $0 }
        return allTokens.filter { blockedTokens.contains($0.id) }
    }
    
    // MARK: - Custom Token Management
    
    /// Add custom token
    func addCustomToken(_ token: TokenItem) throws {
        // Validate token
        guard EthereumUtil.isValidAddress(token.address) else {
            throw TokenError.invalidAddress
        }
        
        // Check if already exists
        if customTokens.contains(where: { $0.address.lowercased() == token.address.lowercased() && $0.chainId == token.chainId }) {
            throw TokenError.tokenAlreadyExists
        }
        
        customTokens.append(token)
        saveCustomTokens()
    }
    
    /// Remove custom token
    func removeCustomToken(_ token: TokenItem) {
        customTokens.removeAll { $0.id == token.id }
        saveCustomTokens()
    }
    
    /// Import token by address
    func importToken(address: String, chain: Chain) async throws -> TokenItem {
        guard EthereumUtil.isValidAddress(address) else {
            throw TokenError.invalidAddress
        }
        
        // Query token info from chain
        let symbol = try await networkManager.getERC20Symbol(tokenAddress: address, chain: chain)
        let decimals = try await networkManager.getERC20Decimals(tokenAddress: address, chain: chain)
        
        let token = TokenItem(
            id: "\(chain.serverId):\(address)",
            chainId: chain.id,
            address: address,
            symbol: symbol,
            name: symbol, // Use symbol as name by default
            decimals: decimals,
            logoURL: nil,
            price: 0,
            priceChange24h: nil,
            isNative: false
        )
        
        try addCustomToken(token)
        return token
    }
    
    // MARK: - Token Search
    
    /// Search tokens by symbol or address
    func searchTokens(query: String, chainId: Int) -> [TokenItem] {
        let allTokens = tokens.values.flatMap { $0 } + customTokens
        
        return allTokens.filter { token in
            token.chainId == chainId &&
            (token.symbol.lowercased().contains(query.lowercased()) ||
             token.name.lowercased().contains(query.lowercased()) ||
             token.address.lowercased().contains(query.lowercased()))
        }
    }
    
    // MARK: - Token Allowance
    
    /// Get token allowance
    func getAllowance(
        tokenAddress: String,
        ownerAddress: String,
        spenderAddress: String,
        chain: Chain
    ) async throws -> String {
        // Encode allowance(address,address) function call
        let functionSignature = "0xdd62ed3e"
        let ownerPadded = ownerAddress.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let spenderPadded = spenderAddress.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let data = functionSignature + ownerPadded + spenderPadded
        
        let transaction: [String: Any] = [
            "to": tokenAddress,
            "data": data
        ]
        
        return try await networkManager.call(transaction: transaction, chain: chain)
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        // Refresh balances every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllBalances()
            }
        }
    }
    
    // MARK: - Memory Management
    
    /// Observe memory warnings to release non-essential data
    private func observeMemoryWarnings() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        // Keep only the current chain's tokens, clear others
        let currentKey = tokens.keys.first // simplified: keep at most one
        tokens = tokens.filter { $0.key == currentKey }
        
        // Trim balance cache
        trimBalanceCache()
        
        // Clear image cache memory layer
        ImageCacheManager.shared.clearMemoryCache()
    }
    
    /// Trim balance cache to max size (evict least recently used)
    private func trimBalanceCache() {
        guard tokenBalances.count > maxBalanceCacheSize else { return }
        // Keep only entries for currently visible tokens
        let activeTokenIds = Set(tokens.values.flatMap { $0.map { $0.id } })
        tokenBalances = tokenBalances.filter { activeTokenIds.contains($0.key) }
    }
    
    private func refreshAllBalances() async {
        for (key, tokenList) in tokens {
            let components = key.split(separator: "_")
            guard components.count == 2,
                  let chainId = Int(components[1]),
                  let chain = chainManager.getChain(byId: chainId) else {
                continue
            }
            
            let address = String(components[0])
            await loadBalances(address: address, tokens: tokenList, chain: chain)
        }
    }
    
    /// Manually refresh balances for address
    func refreshBalances(address: String) async {
        for chain in chainManager.allChains {
            if let tokenList = try? await loadTokens(address: address, chain: chain) {
                await loadBalances(address: address, tokens: tokenList, chain: chain)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadCustomTokens() {
        if let saved = try? storageManager.getPreference(forKey: "customTokens", type: [TokenItem].self) {
            customTokens = saved
        }
    }
    
    private func saveCustomTokens() {
        try? storageManager.savePreference(customTokens, forKey: "customTokens")
    }
    
    private func loadBlockedTokens() {
        if let saved = try? storageManager.getPreference(forKey: "blockedTokens", type: [String].self) {
            blockedTokens = Set(saved)
        }
    }
    
    private func saveBlockedTokens() {
        try? storageManager.savePreference(Array(blockedTokens), forKey: "blockedTokens")
    }
    
    // MARK: - Utility
    
    private func formatTokenAmount(_ balance: String, decimals: Int) -> String {
        let balanceValue = BigUInt(balance.hexToData() ?? Data())
        guard balanceValue > 0 else {
            return "0"
        }
        
        let divisor = BigUInt(10).power(decimals)
        let integerPart = balanceValue / divisor
        let fractionalPart = balanceValue % divisor
        
        if fractionalPart == 0 {
            return String(integerPart)
        }
        
        let fractionalString = String(fractionalPart)
        let paddedFractional = fractionalString.padLeft(toLength: decimals, withPad: "0")
        let trimmedFractional = paddedFractional.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
        
        if trimmedFractional.isEmpty {
            return String(integerPart)
        }
        
        return "\(integerPart).\(trimmedFractional)"
    }
}

// MARK: - Supporting Types

struct TokenItem: Codable, Identifiable, Hashable {
    let id: String
    let chainId: Int
    let address: String
    let symbol: String
    let name: String
    let decimals: Int
    var logoURL: String?
    var price: Double
    var priceChange24h: Double?
    var isNative: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TokenItem, rhs: TokenItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct TokenBalance: Codable {
    let tokenId: String
    let address: String
    let chainId: Int
    let balance: String // Hex string
    let balanceFormatted: String
    let updatedAt: Date
}

// MARK: - Token List

extension TokenItem {
    /// Popular tokens for quick add
    static let popularTokens: [TokenItem] = [
        // Ethereum
        TokenItem(
            id: "eth:0xdac17f958d2ee523a2206206994597c13d831ec7",
            chainId: 1,
            address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
            symbol: "USDT",
            name: "Tether USD",
            decimals: 6,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
        TokenItem(
            id: "eth:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            chainId: 1,
            address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            symbol: "USDC",
            name: "USD Coin",
            decimals: 6,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
        TokenItem(
            id: "eth:0x6b175474e89094c44da98b954eedeac495271d0f",
            chainId: 1,
            address: "0x6b175474e89094c44da98b954eedeac495271d0f",
            symbol: "DAI",
            name: "Dai Stablecoin",
            decimals: 18,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
        TokenItem(
            id: "eth:0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",
            chainId: 1,
            address: "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",
            symbol: "WBTC",
            name: "Wrapped Bitcoin",
            decimals: 8,
            logoURL: nil,
            price: 50000.0,
            priceChange24h: nil,
            isNative: false
        ),
        
        // BSC
        TokenItem(
            id: "bsc:0x55d398326f99059ff775485246999027b3197955",
            chainId: 56,
            address: "0x55d398326f99059ff775485246999027b3197955",
            symbol: "USDT",
            name: "Tether USD",
            decimals: 18,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
        TokenItem(
            id: "bsc:0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",
            chainId: 56,
            address: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",
            symbol: "USDC",
            name: "USD Coin",
            decimals: 18,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
        
        // Polygon
        TokenItem(
            id: "matic:0xc2132d05d31c914a87c6611c10748aeb04b58e8f",
            chainId: 137,
            address: "0xc2132d05d31c914a87c6611c10748aeb04b58e8f",
            symbol: "USDT",
            name: "Tether USD",
            decimals: 6,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
        TokenItem(
            id: "matic:0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
            chainId: 137,
            address: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
            symbol: "USDC",
            name: "USD Coin",
            decimals: 6,
            logoURL: nil,
            price: 1.0,
            priceChange24h: nil,
            isNative: false
        ),
    ]
}

// MARK: - Errors

enum TokenError: Error, LocalizedError {
    case invalidAddress
    case tokenAlreadyExists
    case tokenNotFound
    case queryFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid token address"
        case .tokenAlreadyExists:
            return "Token already exists in list"
        case .tokenNotFound:
            return "Token not found"
        case .queryFailed:
            return "Failed to query token information"
        }
    }
}
