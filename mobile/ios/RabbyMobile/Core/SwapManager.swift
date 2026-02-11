import Foundation
import Combine
import BigInt

/// Swap Manager - DEX Aggregator for Token Swaps
/// Equivalent to Web version's swap service
@MainActor
class SwapManager: ObservableObject {
    static let shared = SwapManager()
    
    @Published var selectedChain: String?
    @Published var selectedFromToken: Token?
    @Published var selectedToToken: Token?
    @Published var autoSlippage: Bool = true
    @Published var slippage: String = "0.5"
    @Published var quotes: [SwapQuote] = []
    @Published var isLoading = false
    @Published var preferMEVGuarded = false
    
    private let networkManager = NetworkManager.shared
    private let storage = StorageManager.shared
    
    private let swapKey = "rabby_swap_settings"
    
    // MARK: - Models
    
    struct SwapQuote: Identifiable {
        let id: String
        let dexId: String
        let dexName: String
        let dexLogo: String?
        let fromToken: Token
        let toToken: Token
        let fromAmount: String
        let toAmount: String
        let minReceived: String
        let priceImpact: String
        let gasFee: String
        let data: String // Transaction data
        let to: String // Contract address
        let needApprove: Bool
        let spender: String?
    }
    
    struct Token: Codable {
        let id: String
        let chain: String
        let symbol: String
        let decimals: Int
        let address: String
        let logo: String?
        let amount: String?
        let price: Double?
    }
    
    struct SwapSettings: Codable {
        var selectedChain: String?
        var autoSlippage: Bool
        var slippage: String
        var preferMEVGuarded: Bool
        var recentToTokens: [Token]
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Get swap quotes from DEX aggregators
    func getQuotes(
        fromToken: Token,
        toToken: Token,
        amount: String,
        chain: Chain
    ) async throws -> [SwapQuote] {
        isLoading = true
        defer { isLoading = false }
        
        // Call Rabby API to get swap quotes
        let url = "https://api.rabby.io/v1/swap/quote"
        let params: [String: Any] = [
            "from_token_id": fromToken.id,
            "to_token_id": toToken.id,
            "amount": amount,
            "chain_id": chain.serverId,
            "slippage": Double(slippage) ?? 0.5,
            "user_address": "", // Will be filled by caller
        ]
        
        do {
            let response: SwapQuoteResponse = try await networkManager.get(url: url, parameters: params)
            
            // Convert to SwapQuote models
            let quotes = response.data.map { quoteData -> SwapQuote in
                SwapQuote(
                    id: quoteData.dex_id,
                    dexId: quoteData.dex_id,
                    dexName: quoteData.name,
                    dexLogo: quoteData.logo_url,
                    fromToken: fromToken,
                    toToken: toToken,
                    fromAmount: amount,
                    toAmount: quoteData.to_token_amount,
                    minReceived: quoteData.min_received,
                    priceImpact: quoteData.price_impact,
                    gasFee: quoteData.gas_fee,
                    data: quoteData.data,
                    to: quoteData.to,
                    needApprove: quoteData.need_approve,
                    spender: quoteData.spender
                )
            }
            
            self.quotes = quotes
            return quotes
        } catch {
            print("❌ Failed to get swap quotes: \(error)")
            throw error
        }
    }
    
    /// Build swap transaction
    func buildSwapTransaction(
        quote: SwapQuote,
        fromAddress: String,
        chain: Chain
    ) async throws -> EthereumTransaction {
        // If need approve, should approve first
        if quote.needApprove, let spender = quote.spender {
            throw SwapError.needApproval(spender: spender)
        }
        
        // Create swap transaction
        let chainIdInt = Int(chain.serverId) ?? chain.id
        let valueStr = quote.fromToken.address.lowercased() == chain.nativeTokenAddress.lowercased() ? quote.fromAmount : "0x0"
        let valueBigUInt = BigUInt(valueStr.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? BigUInt(0)
        let txData = quote.data.hexToData() ?? Data()
        
        let transaction = EthereumTransaction(
            to: quote.to,
            from: fromAddress,
            nonce: BigUInt(0),
            value: valueBigUInt,
            data: txData,
            gasLimit: BigUInt(300000),
            chainId: chainIdInt
        )
        
        return transaction
    }
    
    /// Approve token for swap
    func approveToken(
        token: Token,
        spender: String,
        amount: String,
        fromAddress: String,
        chain: Chain
    ) async throws -> String {
        // ERC20 approve function
        let functionSignature = "approve(address,uint256)"
        let selector = Keccak256.hash(string: functionSignature).prefix(4)
        
        var data = Data(selector)
        
        // Spender address (padded to 32 bytes)
        if let spenderData = Data(hexString: String(spender.dropFirst(2))) {
            data.append(Data(repeating: 0, count: 12))
            data.append(spenderData)
        }
        
        // Amount (padded to 32 bytes) - use max uint256 for unlimited
        let maxUint256 = Data(repeating: 0xFF, count: 32)
        data.append(maxUint256)
        
        // Create approval transaction
        let chainIdInt = Int(chain.serverId) ?? chain.id
        let transaction = EthereumTransaction(
            to: token.address,
            from: fromAddress,
            nonce: BigUInt(0),
            value: BigUInt(0),
            data: data,
            gasLimit: BigUInt(100000),
            chainId: chainIdInt
        )
        
        // Sign and send
        let signedTx = try await KeyringManager.shared.signTransaction(address: fromAddress, transaction: transaction)
        let txHash = try await TransactionManager.shared.broadcastTransaction(signedTx)
        
        return txHash
    }
    
    /// Execute swap
    func executeSwap(
        quote: SwapQuote,
        fromAddress: String,
        chain: Chain
    ) async throws -> String {
        // Build transaction
        let transaction = try await buildSwapTransaction(
            quote: quote,
            fromAddress: fromAddress,
            chain: chain
        )
        
        // Sign and send
        let signedTx = try await KeyringManager.shared.signTransaction(address: fromAddress, transaction: transaction)
        let txHash = try await TransactionManager.shared.broadcastTransaction(signedTx)
        
        // Post swap to backend
        await postSwap(chain: chain, txHash: txHash, quote: quote)
        
        return txHash
    }
    
    /// Set slippage
    func setSlippage(_ value: String) {
        self.slippage = value
        self.autoSlippage = false
        saveSettings()
    }
    
    /// Set auto slippage
    func setAutoSlippage(_ auto: Bool) {
        self.autoSlippage = auto
        if auto {
            self.slippage = "0.5"
        }
        saveSettings()
    }
    
    /// Check and confirm swap transaction (called from TransactionBroadcastWatcher)
    func checkAndConfirmSwap(txHash: String, chainId: Int) {
        // Track swap confirmation for analytics
        print("SwapManager: Swap confirmed - txHash: \(txHash), chainId: \(chainId)")
    }
    
    /// Add recent token
    func addRecentToken(_ token: Token) {
        var recent = getRecentTokens()
        recent.removeAll { $0.id == token.id }
        recent.insert(token, at: 0)
        if recent.count > 5 {
            recent = Array(recent.prefix(5))
        }
        saveRecentTokens(recent)
    }
    
    /// Get recent tokens
    func getRecentTokens() -> [Token] {
        if let data = storage.getData(forKey: "rabby_recent_swap_tokens"),
           let tokens = try? JSONDecoder().decode([Token].self, from: data) {
            return tokens
        }
        return []
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = storage.getData(forKey: swapKey),
           let settings = try? JSONDecoder().decode(SwapSettings.self, from: data) {
            self.selectedChain = settings.selectedChain
            self.autoSlippage = settings.autoSlippage
            self.slippage = settings.slippage
            self.preferMEVGuarded = settings.preferMEVGuarded
        }
    }
    
    private func saveSettings() {
        let settings = SwapSettings(
            selectedChain: selectedChain,
            autoSlippage: autoSlippage,
            slippage: slippage,
            preferMEVGuarded: preferMEVGuarded,
            recentToTokens: getRecentTokens()
        )
        if let data = try? JSONEncoder().encode(settings) {
            storage.setData(data, forKey: swapKey)
        }
    }
    
    private func saveRecentTokens(_ tokens: [Token]) {
        if let data = try? JSONEncoder().encode(tokens) {
            storage.setData(data, forKey: "rabby_recent_swap_tokens")
        }
    }
    
    private func postSwap(chain: Chain, txHash: String, quote: SwapQuote) async {
        // Report swap to backend for analytics
        let url = "https://api.rabby.io/v1/swap/post"
        let params: [String: Any] = [
            "tx_id": txHash,
            "chain_id": chain.serverId,
            "dex_id": quote.dexId,
            "from_token_id": quote.fromToken.id,
            "from_token_amount": quote.fromAmount,
            "to_token_id": quote.toToken.id,
            "to_token_amount": quote.toAmount,
        ]
        
        do {
            struct PostSwapResponse: Codable {
                let success: Bool?
            }
            let _: PostSwapResponse = try await networkManager.post(url: url, body: params)
        } catch {
            print("⚠️ Failed to post swap: \(error)")
        }
    }
}

// MARK: - API Response Models

private struct SwapQuoteResponse: Codable {
    let data: [QuoteData]
    
    struct QuoteData: Codable {
        let dex_id: String
        let name: String
        let logo_url: String?
        let to_token_amount: String
        let min_received: String
        let price_impact: String
        let gas_fee: String
        let data: String
        let to: String
        let need_approve: Bool
        let spender: String?
    }
}

// MARK: - Errors

enum SwapError: Error, LocalizedError {
    case needApproval(spender: String)
    case insufficientBalance
    case quoteNotFound
    case slippageTooHigh
    
    var errorDescription: String? {
        switch self {
        case .needApproval(let spender):
            return "Need to approve token for spender: \(spender)"
        case .insufficientBalance:
            return "Insufficient balance"
        case .quoteNotFound:
            return "No swap quote found"
        case .slippageTooHigh:
            return "Slippage tolerance too high"
        }
    }
}
