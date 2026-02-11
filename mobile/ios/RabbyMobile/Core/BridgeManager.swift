import Foundation
import Combine
import BigInt

/// Bridge Manager - Cross-chain Bridge Aggregator
/// Equivalent to Web version's bridge service
@MainActor
class BridgeManager: ObservableObject {
    static let shared = BridgeManager()
    
    @Published var selectedFromChain: String?
    @Published var selectedToChain: String?
    @Published var selectedFromToken: SwapManager.Token?
    @Published var selectedToToken: SwapManager.Token?
    @Published var selectedAggregators: [String] = []
    @Published var quotes: [BridgeQuote] = []
    @Published var isLoading = false
    
    private let networkManager = NetworkManager.shared
    private let storage = StorageManager.shared
    
    private let bridgeKey = "rabby_bridge_settings"
    
    // MARK: - Models
    
    struct BridgeQuote: Identifiable {
        let id: String
        let aggregatorId: String
        let aggregatorName: String
        let aggregatorLogo: String?
        let bridgeId: String
        let fromChainId: String
        let toChainId: String
        let fromToken: SwapManager.Token
        let toToken: SwapManager.Token
        let fromAmount: String
        let toAmount: String
        let estimatedTime: String // e.g., "3-5 minutes"
        let gasFee: String
        let bridgeFee: String
        let rabbyFee: Double
        let data: String
        let to: String
        let needApprove: Bool
        let spender: String?
    }
    
    struct BridgeSettings: Codable {
        var selectedFromChain: String?
        var selectedToChain: String?
        var selectedAggregators: [String]
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Get bridge quotes from aggregators
    func getQuotes(
        fromToken: SwapManager.Token,
        toToken: SwapManager.Token,
        amount: String,
        fromChain: Chain,
        toChain: Chain,
        userAddress: String
    ) async throws -> [BridgeQuote] {
        isLoading = true
        defer { isLoading = false }
        
        // Call Rabby API to get bridge quotes
        let url = "https://api.rabby.io/v1/bridge/quote"
        let params: [String: Any] = [
            "from_chain_id": fromChain.serverId,
            "to_chain_id": toChain.serverId,
            "from_token_id": fromToken.id,
            "to_token_id": toToken.id,
            "amount": amount,
            "user_address": userAddress,
        ]
        
        do {
            let response: BridgeQuoteResponse = try await networkManager.get(url: url, parameters: params)
            
            // Filter by selected aggregators if any
            var filteredData = response.data
            if !selectedAggregators.isEmpty {
                filteredData = filteredData.filter { selectedAggregators.contains($0.aggregator_id) }
            }
            
            // Convert to BridgeQuote models
            let quotes = filteredData.map { quoteData -> BridgeQuote in
                BridgeQuote(
                    id: "\(quoteData.aggregator_id)_\(quoteData.bridge_id)",
                    aggregatorId: quoteData.aggregator_id,
                    aggregatorName: quoteData.aggregator_name,
                    aggregatorLogo: quoteData.aggregator_logo,
                    bridgeId: quoteData.bridge_id,
                    fromChainId: fromChain.serverId,
                    toChainId: toChain.serverId,
                    fromToken: fromToken,
                    toToken: toToken,
                    fromAmount: amount,
                    toAmount: quoteData.to_token_amount,
                    estimatedTime: quoteData.estimated_time,
                    gasFee: quoteData.gas_fee,
                    bridgeFee: quoteData.bridge_fee,
                    rabbyFee: quoteData.rabby_fee,
                    data: quoteData.data,
                    to: quoteData.to,
                    needApprove: quoteData.need_approve,
                    spender: quoteData.spender
                )
            }
            
            self.quotes = quotes
            return quotes
        } catch {
            print("❌ Failed to get bridge quotes: \(error)")
            throw error
        }
    }
    
    /// Build bridge transaction
    func buildBridgeTransaction(
        quote: BridgeQuote,
        fromAddress: String,
        fromChain: Chain
    ) async throws -> EthereumTransaction {
        // If need approve, should approve first
        if quote.needApprove, let spender = quote.spender {
            throw BridgeError.needApproval(spender: spender)
        }
        
        // Parse values
        let valueHex = quote.fromToken.address.lowercased() == fromChain.nativeTokenAddress.lowercased() ? quote.fromAmount : "0x0"
        let valueBigUInt = BigUInt(valueHex.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? BigUInt(0)
        
        // Parse data
        let dataHex = quote.data.hasPrefix("0x") ? String(quote.data.dropFirst(2)) : quote.data
        let dataBytes = Data(hex: dataHex)
        
        // Get nonce
        let nonceHex = try await networkManager.getTransactionCount(address: fromAddress, chain: fromChain)
        let nonce = BigUInt(nonceHex.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? BigUInt(0)
        
        // Create bridge transaction
        let transaction = EthereumTransaction(
            to: quote.to,
            from: fromAddress,
            nonce: nonce,
            value: valueBigUInt,
            data: dataBytes,
            gasLimit: BigUInt(300000), // Default gas limit
            chainId: Int(fromChain.serverId) ?? fromChain.id
        )
        
        return transaction
    }
    
    /// Approve token for bridge
    func approveToken(
        token: SwapManager.Token,
        spender: String,
        amount: String,
        fromAddress: String,
        chain: Chain
    ) async throws -> String {
        // Use SwapManager's approve logic
        return try await SwapManager.shared.approveToken(
            token: token,
            spender: spender,
            amount: amount,
            fromAddress: fromAddress,
            chain: chain
        )
    }
    
    /// Execute bridge
    func executeBridge(
        quote: BridgeQuote,
        fromAddress: String,
        fromChain: Chain
    ) async throws -> String {
        // Build transaction
        let transaction = try await buildBridgeTransaction(
            quote: quote,
            fromAddress: fromAddress,
            fromChain: fromChain
        )
        
        // Sign transaction
        let signedTxData = try await KeyringManager.shared.signTransaction(address: fromAddress, transaction: transaction)
        
        // Create signed transaction with signature
        var signedTransaction = transaction
        // Extract v, r, s from signature data
        // Note: This is a simplified version - actual implementation needs proper signature parsing
        
        // Send transaction
        let txHash = try await TransactionManager.shared.sendTransaction(signedTransaction)
        
        // Post bridge to backend
        await postBridge(fromChain: fromChain, txHash: txHash, quote: quote)
        
        return txHash
    }
    
    /// Check and confirm bridge transaction (called from TransactionBroadcastWatcher)
    func checkAndConfirmBridge(txHash: String, chainId: Int) {
        // Track bridge confirmation for analytics
        print("BridgeManager: Bridge confirmed - txHash: \(txHash), chainId: \(chainId)")
    }
    
    /// Set selected aggregators
    func setSelectedAggregators(_ aggregators: [String]) {
        self.selectedAggregators = aggregators
        saveSettings()
    }
    
    /// Get bridge status
    func getBridgeStatus(txHash: String, fromChain: Chain) async throws -> BridgeStatus {
        let url = "https://api.rabby.io/v1/bridge/status"
        let params: [String: Any] = [
            "tx_id": txHash,
            "chain_id": fromChain.serverId,
        ]
        
        let response: BridgeStatusResponse = try await networkManager.get(url: url, parameters: params)
        
        return BridgeStatus(
            status: response.status,
            fromTxHash: txHash,
            toTxHash: response.to_tx_hash,
            estimatedTime: response.estimated_time,
            actualTime: response.actual_time
        )
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = storage.getData(forKey: bridgeKey),
           let settings = try? JSONDecoder().decode(BridgeSettings.self, from: data) {
            self.selectedFromChain = settings.selectedFromChain
            self.selectedToChain = settings.selectedToChain
            self.selectedAggregators = settings.selectedAggregators
        }
    }
    
    private func saveSettings() {
        let settings = BridgeSettings(
            selectedFromChain: selectedFromChain,
            selectedToChain: selectedToChain,
            selectedAggregators: selectedAggregators
        )
        if let data = try? JSONEncoder().encode(settings) {
            storage.setData(data, forKey: bridgeKey)
        }
    }
    
    private func postBridge(fromChain: Chain, txHash: String, quote: BridgeQuote) async {
        // Report bridge to backend for analytics
        let url = "https://api.rabby.io/v1/bridge/post"
        let params: [String: Any] = [
            "tx_id": txHash,
            "aggregator_id": quote.aggregatorId,
            "bridge_id": quote.bridgeId,
            "from_chain_id": quote.fromChainId,
            "from_token_id": quote.fromToken.id,
            "from_token_amount": quote.fromAmount,
            "to_chain_id": quote.toChainId,
            "to_token_id": quote.toToken.id,
            "to_token_amount": quote.toAmount,
            "rabby_fee": quote.rabbyFee,
        ]
        
        do {
            let _: BridgePostResponse = try await networkManager.post(url: url, body: params)
        } catch {
            print("⚠️ Failed to post bridge: \(error)")
        }
    }
}

// MARK: - Response Models

private struct BridgePostResponse: Codable {
    let success: Bool?
}

// MARK: - Bridge Status

struct BridgeStatus {
    let status: String // pending, success, failed
    let fromTxHash: String
    let toTxHash: String?
    let estimatedTime: String?
    let actualTime: String?
}

// MARK: - API Response Models

private struct BridgeQuoteResponse: Codable {
    let data: [QuoteData]
    
    struct QuoteData: Codable {
        let aggregator_id: String
        let aggregator_name: String
        let aggregator_logo: String?
        let bridge_id: String
        let to_token_amount: String
        let estimated_time: String
        let gas_fee: String
        let bridge_fee: String
        let rabby_fee: Double
        let data: String
        let to: String
        let need_approve: Bool
        let spender: String?
    }
}

private struct BridgeStatusResponse: Codable {
    let status: String
    let to_tx_hash: String?
    let estimated_time: String?
    let actual_time: String?
}

// MARK: - Errors

enum BridgeError: Error, LocalizedError {
    case needApproval(spender: String)
    case insufficientBalance
    case quoteNotFound
    case bridgeNotSupported
    case invalidChain
    
    var errorDescription: String? {
        switch self {
        case .needApproval(let spender):
            return "Need to approve token for spender: \(spender)"
        case .insufficientBalance:
            return "Insufficient balance"
        case .quoteNotFound:
            return "No bridge quote found"
        case .bridgeNotSupported:
            return "Bridge not supported for this pair"
        case .invalidChain:
            return "Invalid chain selection"
        }
    }
}
