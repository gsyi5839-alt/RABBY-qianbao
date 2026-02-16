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
    @Published var slippage: String = "0.1"
    @Published var quotes: [SwapQuote] = []
    @Published var isLoading = false
    @Published var preferMEVGuarded = false
    
    private let openAPIService = OpenAPIService.shared
    private let storage = StorageManager.shared
    private let transactionManager = TransactionManager.shared
    private let chainManager = ChainManager.shared
    private let networkManager = NetworkManager.shared
    
    private let swapKey = "rabby_swap_settings"
    private var latestQuoteRequestId: Int = 0
    
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
        let txValue: String?
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
        chain: Chain,
        userAddress: String
    ) async throws -> [SwapQuote] {
        guard !userAddress.isEmpty else {
            throw SwapError.invalidUserAddress
        }
        guard !amount.isEmpty, isPositiveNumber(amount) else {
            throw SwapError.invalidAmount
        }

        latestQuoteRequestId += 1
        let requestId = latestQuoteRequestId
        isLoading = true
        defer {
            if requestId == latestQuoteRequestId {
                isLoading = false
            }
        }
        
        // Align with extension's OpenAPI path and auth headers.
        let params: [String: String] = [
            "from_token_id": fromToken.id,
            "to_token_id": toToken.id,
            "amount": amount,
            "chain_id": chain.serverId,
            "slippage": slippage,
            "user_address": userAddress,
        ]
        
        do {
            let response: SwapQuoteResponse = try await openAPIService.get("/v1/swap/quote", params: params)
            
            // Convert and sort to keep "best quote" stable.
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
                    spender: quoteData.spender,
                    txValue: quoteData.value
                )
            }.sorted { lhs, rhs in
                decimalNumber(from: lhs.toAmount) > decimalNumber(from: rhs.toAmount)
            }
            
            if requestId == latestQuoteRequestId {
                self.quotes = quotes
            }
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
        
        let valueHex = resolveSwapValueHex(
            txValue: quote.txValue,
            fromAmount: quote.fromAmount,
            fromToken: quote.fromToken,
            chain: chain
        )
        return try await transactionManager.buildTransaction(
            from: fromAddress,
            to: quote.to,
            value: valueHex,
            data: quote.data,
            chain: chain
        )
    }
    
    /// Approve token for swap
    func approveToken(
        token: Token,
        spender: String,
        amount: String,
        fromAddress: String,
        chain: Chain
    ) async throws -> String {
        _ = amount
        let transaction = try await transactionManager.buildTokenApproval(
            from: fromAddress,
            tokenAddress: token.address,
            spender: spender,
            amount: String(repeating: "f", count: 64),
            chain: chain
        )
        return try await transactionManager.sendTransaction(transaction)
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
        
        let txHash = try await transactionManager.sendTransaction(transaction)

        TransactionHistoryManager.shared.addSwapHistory(
            address: fromAddress,
            chainId: chain.serverId,
            fromToken: .init(
                id: quote.fromToken.id,
                symbol: quote.fromToken.symbol,
                decimals: quote.fromToken.decimals,
                logo: quote.fromToken.logo
            ),
            toToken: .init(
                id: quote.toToken.id,
                symbol: quote.toToken.symbol,
                decimals: quote.toToken.decimals,
                logo: quote.toToken.logo
            ),
            fromAmount: quote.fromAmount,
            toAmount: quote.toAmount,
            dexId: quote.dexId,
            hash: txHash,
            slippage: Double(slippage) ?? 0.1
        )
        
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
            self.slippage = "0.1"
        }
        saveSettings()
    }
    
    /// Check and confirm swap transaction (called from TransactionBroadcastWatcher)
    func checkAndConfirmSwap(txHash: String, chainId: Int) {
        Task {
            guard let chain = chainManager.getChain(id: chainId) else { return }
            do {
                if let receipt = try await networkManager.getTransactionReceipt(hash: txHash, chain: chain) {
                    TransactionHistoryManager.shared.updateSwapStatus(
                        hash: txHash,
                        status: receipt.isSuccess ? "success" : "failed"
                    )
                }
            } catch {
                print("SwapManager: failed to confirm swap \(txHash): \(error)")
            }
        }
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
            let _: PostSwapResponse = try await openAPIService.post("/v1/swap/post", body: params)
        } catch {
            print("⚠️ Failed to post swap: \(error)")
        }
    }

    private func isPositiveNumber(_ value: String) -> Bool {
        guard let decimal = Decimal(string: value), decimal > 0 else {
            return false
        }
        return true
    }

    private func decimalNumber(from value: String) -> Decimal {
        Decimal(string: value) ?? 0
    }

    private func resolveSwapValueHex(
        txValue: String?,
        fromAmount: String,
        fromToken: Token,
        chain: Chain
    ) -> String {
        if let txValue, !txValue.isEmpty {
            if txValue.hasPrefix("0x") {
                return txValue
            }
            if txValue.allSatisfy({ $0.isNumber }), let wei = BigUInt(txValue) {
                return "0x" + String(wei, radix: 16)
            }
        }
        let isNativeIn = fromToken.address.lowercased() == chain.nativeTokenAddress.lowercased()
            || fromToken.address.lowercased() == "0x0000000000000000000000000000000000000000"
            || fromToken.address.lowercased() == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
        guard isNativeIn else { return "0x0" }
        let wei = decimalToUnitAmount(fromAmount, decimals: fromToken.decimals)
        return "0x" + String(wei, radix: 16)
    }

    private func decimalToUnitAmount(_ value: String, decimals: Int) -> BigUInt {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = parts.first.map(String.init) ?? "0"
        let fractionRaw = parts.count > 1 ? String(parts[1]) : ""
        let fraction = String(fractionRaw.prefix(decimals)).padding(
            toLength: decimals,
            withPad: "0",
            startingAt: 0
        )
        let joined = (integerPart + fraction).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = joined.drop(while: { $0 == "0" })
        if normalized.isEmpty {
            return 0
        }
        return BigUInt(String(normalized)) ?? 0
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
        let value: String?
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
    case invalidAmount
    case invalidUserAddress
    
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
        case .invalidAmount:
            return "Invalid swap amount"
        case .invalidUserAddress:
            return "No wallet address selected"
        }
    }
}
