import Foundation

/// Centralized OpenAPI service for Rabby wallet backend communication
/// Corresponds to: src/background/service/openapi.ts
@MainActor
class OpenAPIService: ObservableObject {
    static let shared = OpenAPIService()
    
    private let baseURL = "https://api.rabby.io"
    private let testnetBaseURL = "https://testnet-openapi.debank.com"
    private var apiKey: String
    private let session: URLSession
    
    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: "rabby_api_key") ?? UUID().uuidString
        UserDefaults.standard.set(self.apiKey, forKey: "rabby_api_key")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(_ path: String, params: [String: String] = [:], isTestnet: Bool = false) async throws -> T {
        let base = isTestnet ? testnetBaseURL : baseURL
        var components = URLComponents(string: "\(base)\(path)")!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw OpenAPIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func post<T: Decodable>(_ path: String, body: [String: Any] = [:], isTestnet: Bool = false) async throws -> T {
        let base = isTestnet ? testnetBaseURL : baseURL
        var request = URLRequest(url: URL(string: "\(base)\(path)")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw OpenAPIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Chain APIs
    
    struct SupportedChain: Codable {
        let id: String
        let community_id: Int
        let name: String
        let native_token_id: String
        let logo_url: String?
        let wrapped_token_id: String?
        let symbol: String?
        let is_disabled: Bool?
    }
    
    func getSupportedChains() async throws -> [SupportedChain] {
        return try await get("/v1/chain/list")
    }
    
    // MARK: - Token APIs
    
    struct TokenInfo: Codable {
        let id: String
        let chain: String
        let name: String
        let symbol: String
        let decimals: Int
        let logo_url: String?
        let price: Double?
        let amount: Double?
        let raw_amount: Double?
        let raw_amount_hex_str: String?
    }
    
    func getTokenList(address: String, chainId: String) async throws -> [TokenInfo] {
        return try await get("/v1/user/token_list", params: ["id": address, "chain_id": chainId])
    }
    
    func getTokenBalances(address: String) async throws -> [TokenInfo] {
        return try await get("/v1/user/total_balance", params: ["id": address])
    }
    
    // MARK: - NFT APIs
    
    struct NFTInfo: Codable {
        let id: String
        let contract_id: String
        let inner_id: String
        let chain: String
        let name: String?
        let description: String?
        let content_type: String?
        let content: String?
        let thumbnail_url: String?
        let total_supply: Int?
        let collection_id: String?
    }
    
    func getNFTList(address: String, chainId: String? = nil) async throws -> [NFTInfo] {
        var params = ["id": address]
        if let chainId = chainId { params["chain_id"] = chainId }
        return try await get("/v1/user/nft_list", params: params)
    }
    
    // MARK: - Transaction APIs
    
    struct TxRequest: Codable {
        let id: String
        let tx_id: String?
        let signed_tx: SignedTx
        let push_status: String?
        let is_finished: Bool
        let is_withdraw: Bool
    }
    
    struct SignedTx: Codable {
        let from: String
        let to: String?
        let chainId: Int
        let nonce: String
        let value: String?
        let data: String?
    }
    
    func submitTx(signedTx: String, chainId: Int) async throws -> TxRequest {
        return try await post("/v1/tx/submit", body: ["signed_tx": signedTx, "chain_id": chainId])
    }
    
    func getTxRequests(ids: [String]) async throws -> [TxRequest] {
        return try await post("/v1/tx/query", body: ["ids": ids])
    }
    
    // MARK: - Gas APIs
    
    struct GasPrice: Codable {
        let slow: GasLevel
        let normal: GasLevel
        let fast: GasLevel
        let custom: GasLevel?
    }
    
    struct GasLevel: Codable {
        let price: Int
        let level: String?
        let front_tx_count: Int?
        let estimated_seconds: Int?
        let base_fee: Int?
        let priority_price: Int?
    }
    
    func getGasPrice(chainId: String) async throws -> GasPrice {
        return try await get("/v1/chain/gas_market", params: ["chain_id": chainId])
    }
    
    // MARK: - Swap APIs
    
    struct SwapQuote: Codable {
        let dex_id: String
        let dex_name: String?
        let receive_token_amount: String
        let price_impact: Double?
        let gas_fee: String?
        let tx: SwapTx?
    }
    
    struct SwapTx: Codable {
        let from: String
        let to: String
        let data: String
        let value: String
        let gas: String?
        let chainId: Int?
    }
    
    func getSwapQuotes(chainId: String, fromToken: String, toToken: String, amount: String, slippage: Double, address: String) async throws -> [SwapQuote] {
        return try await get("/v1/swap/quote_list", params: [
            "chain_id": chainId, "from_token": fromToken, "to_token": toToken,
            "amount": amount, "slippage": "\(slippage)", "user_addr": address
        ])
    }
    
    // MARK: - Bridge APIs
    
    struct BridgeQuote: Codable {
        let aggregator_id: String
        let bridge_id: String?
        let from_chain_id: String
        let to_chain_id: String
        let from_token_amount: String
        let to_token_amount: String
        let estimated_time: Int?
        let fee: String?
        let tx: SwapTx?
    }
    
    func getBridgeQuotes(fromChain: String, toChain: String, fromToken: String, toToken: String, amount: String, address: String) async throws -> [BridgeQuote] {
        return try await get("/v1/bridge/quote_list", params: [
            "from_chain_id": fromChain, "to_chain_id": toChain,
            "from_token": fromToken, "to_token": toToken,
            "amount": amount, "user_addr": address
        ])
    }
    
    // MARK: - Security APIs
    
    struct SecurityCheckResponse: Codable {
        let is_contract: Bool?
        let is_open_source: Bool?
        let is_verified: Bool?
        let is_blacklisted: Bool?
        let risk_level: String?
        let risk_alert: String?
    }
    
    func checkAddress(chainId: String, address: String) async throws -> SecurityCheckResponse {
        return try await get("/v1/security/check_address", params: ["chain_id": chainId, "address": address])
    }
    
    // MARK: - Approval APIs
    
    struct ApprovalInfo: Codable {
        let spender: SpenderInfo
        let token: TokenApprovalInfo
        let value: String
    }
    
    struct SpenderInfo: Codable {
        let id: String
        let name: String?
        let logo_url: String?
        let is_verified: Bool?
    }
    
    struct TokenApprovalInfo: Codable {
        let id: String
        let symbol: String
        let logo_url: String?
        let chain: String
    }
    
    func getTokenApprovals(address: String, chainId: String? = nil) async throws -> [ApprovalInfo] {
        var params = ["id": address]
        if let chainId = chainId { params["chain_id"] = chainId }
        return try await get("/v1/user/token_authorized_list", params: params)
    }
    
    func getNFTApprovals(address: String) async throws -> [ApprovalInfo] {
        return try await get("/v1/user/nft_authorized_list", params: ["id": address])
    }
    
    // MARK: - Points APIs
    
    struct PointsInfo: Codable {
        let total_points: Int
        let rank: Int?
        let referral_code: String?
    }
    
    func getRabbyPoints(address: String) async throws -> PointsInfo {
        return try await get("/v1/points/user", params: ["id": address])
    }
    
    func claimRabbyPoints(address: String) async throws -> PointsInfo {
        return try await post("/v1/points/claim", body: ["id": address])
    }
    
    // MARK: - Transaction History APIs
    
    struct HistoryItem: Codable {
        let id: String
        let chain: String
        let tx_hash: String?
        let from_addr: String
        let to_addr: String?
        let token_approve: TokenApprove?
        let sends: [TokenTransfer]?
        let receives: [TokenTransfer]?
        let time_at: Double
        let is_scam: Bool?
        let tx: TxDetail?
    }
    
    struct TokenApprove: Codable {
        let spender: String
        let token_id: String
        let value: Double?
    }
    
    struct TokenTransfer: Codable {
        let token_id: String
        let amount: Double
    }
    
    struct TxDetail: Codable {
        let status: Int?
        let gas_used: Int?
        let value: String?
    }
    
    func getTransactionHistory(address: String, chainId: String? = nil, start: Int = 0, limit: Int = 20) async throws -> [HistoryItem] {
        var params = ["id": address, "start": "\(start)", "limit": "\(limit)"]
        if let chainId = chainId { params["chain_id"] = chainId }
        return try await get("/v1/user/history_list", params: params)
    }
    
    // MARK: - Activities APIs
    
    struct ActivityInfo: Codable {
        let id: String
        let type: String
        let protocolName: String?
        let description: String
        let chain: String
        let timestamp: TimeInterval
        let value: String?
        let status: String
        let txHash: String?
        struct TokenChangeInfo: Codable {
            let symbol: String
            let amount: String
            let isPositive: Bool
        }
        let tokenChanges: [TokenChangeInfo]
    }
    
    func getActivities(address: String) async throws -> [ActivityInfo] {
        let history: [HistoryItem] = try await getTransactionHistory(address: address, limit: 50)
        return history.map { item in
            let tokenChanges: [ActivityInfo.TokenChangeInfo] = {
                var changes: [ActivityInfo.TokenChangeInfo] = []
                for send in (item.sends ?? []) {
                    changes.append(.init(symbol: send.token_id, amount: String(send.amount), isPositive: false))
                }
                for receive in (item.receives ?? []) {
                    changes.append(.init(symbol: receive.token_id, amount: String(receive.amount), isPositive: true))
                }
                return changes
            }()
            let txType: String = {
                if item.token_approve != nil { return "approve" }
                if !(item.sends ?? []).isEmpty && !(item.receives ?? []).isEmpty { return "swap" }
                if !(item.sends ?? []).isEmpty { return "send" }
                if !(item.receives ?? []).isEmpty { return "receive" }
                return "contract"
            }()
            return ActivityInfo(
                id: item.id,
                type: txType,
                protocolName: nil,
                description: txType.capitalized,
                chain: item.chain,
                timestamp: item.time_at,
                value: item.tx?.value,
                status: item.tx?.status == 1 ? "completed" : "failed",
                txHash: item.tx_hash,
                tokenChanges: tokenChanges
            )
        }
    }
    
    // MARK: - Lending APIs
    
    struct LendingProtocol: Codable {
        let id: String
        let name: String
        let chain: String
        let logo_url: String?
        let tvl: Double?
    }
    
    struct LendingPosition: Codable {
        let protocol_id: String
        let supply_token_list: [TokenInfo]?
        let borrow_token_list: [TokenInfo]?
        let health_rate: Double?
    }
    
    func getLendingProtocols(chainId: String) async throws -> [LendingProtocol] {
        return try await get("/v1/lending/protocol_list", params: ["chain_id": chainId])
    }
    
    func getLendingPositions(address: String) async throws -> [LendingPosition] {
        return try await get("/v1/user/lending_list", params: ["id": address])
    }
    
    // MARK: - Gnosis Safe APIs
    
    struct GnosisPendingTx: Codable {
        let safeTxHash: String
        let nonce: Int
        let to: String
        let value: String
        let data: String?
        let operation: Int
        let confirmations: [GnosisConfirmation]
        let confirmationsRequired: Int
        let submissionDate: Date
        let isExecuted: Bool
    }
    
    struct GnosisConfirmation: Codable {
        let owner: String
        let signature: String
        let submissionDate: Date
    }
    
    func getGnosisPendingTxs(safeAddress: String, chainId: String) async throws -> [GnosisPendingTx] {
        return try await get("/v1/gnosis/pending_txs", params: ["safe_address": safeAddress, "chain_id": chainId])
    }
    
    // MARK: - RPC Proxy
    
    func ethCall(chainId: String, to: String, data: String) async throws -> String {
        return try await post("/v1/rpc/call", body: ["chain_id": chainId, "to": to, "data": data])
    }
    
    // MARK: - Token Detail APIs
    
    struct TokenDetailInfo: Codable {
        let id: String
        let chain: String
        let name: String
        let symbol: String
        let decimals: Int
        let logo_url: String?
        let price: Double?
        let price_24h_change: Double?
        let market_cap: Double?
        let total_supply: Double?
        let holders: Int?
        let is_verified: Bool?
        let is_scam: Bool?
    }
    
    func getTokenDetail(chainId: String, tokenId: String) async throws -> TokenDetailInfo {
        return try await get("/v1/token", params: ["chain_id": chainId, "id": tokenId])
    }
    
    func getTokenPriceChange(chainId: String, tokenId: String) async throws -> Double {
        let detail: TokenDetailInfo = try await getTokenDetail(chainId: chainId, tokenId: tokenId)
        return detail.price_24h_change ?? 0
    }
    
    // MARK: - Balance History APIs
    
    struct BalanceHistoryPoint: Codable {
        let timestamp: TimeInterval
        let usd_value: Double
    }
    
    func getBalanceHistory(address: String, chainId: String? = nil, timeRange: String = "24h") async throws -> [BalanceHistoryPoint] {
        var params = ["id": address, "time_range": timeRange]
        if let chainId = chainId { params["chain_id"] = chainId }
        return try await get("/v1/user/total_net_curve", params: params)
    }
    
    struct ChainBalanceInfo: Codable {
        let chain_id: String
        let chain_name: String
        let logo_url: String?
        let usd_value: Double
        let token_count: Int?
    }
    
    func getChainBalances(address: String) async throws -> [ChainBalanceInfo] {
        return try await get("/v1/user/chain_balance", params: ["id": address])
    }
    
    // MARK: - NFT Detail APIs
    
    struct NFTDetailInfo: Codable {
        let id: String
        let contract_id: String
        let inner_id: String
        let chain: String
        let name: String?
        let description: String?
        let content_type: String?
        let content: String?
        let thumbnail_url: String?
        let collection: NFTCollection?
        let attributes: [NFTAttribute]?
    }
    
    struct NFTCollection: Codable {
        let id: String
        let name: String
        let description: String?
        let logo_url: String?
        let floor_price: Double?
        let amount: Int?
    }
    
    struct NFTAttribute: Codable {
        let trait_type: String
        let value: String
    }
    
    func getNFTDetail(chainId: String, contractId: String, tokenId: String) async throws -> NFTDetailInfo {
        return try await get("/v1/nft", params: ["chain_id": chainId, "contract_id": contractId, "inner_id": tokenId])
    }
    
    // MARK: - Portfolio / DeFi APIs
    
    struct PortfolioItem: Codable {
        let id: String
        let chain: String
        let name: String
        let logo_url: String?
        let site_url: String?
        let net_usd_value: Double
        let asset_usd_value: Double
        let debt_usd_value: Double
        let portfolio_item_list: [PortfolioPosition]
    }
    
    struct PortfolioPosition: Codable {
        let name: String
        let detail_types: [String]?
        let detail: PortfolioDetail?
        let stats: PortfolioStats?
    }
    
    struct PortfolioDetail: Codable {
        let supply_token_list: [PortfolioToken]?
        let borrow_token_list: [PortfolioToken]?
        let reward_token_list: [PortfolioToken]?
        let token_list: [PortfolioToken]?
    }
    
    struct PortfolioToken: Codable {
        let id: String
        let chain: String
        let symbol: String
        let name: String?
        let logo_url: String?
        let price: Double?
        let amount: Double
    }
    
    struct PortfolioStats: Codable {
        let asset_usd_value: Double?
        let debt_usd_value: Double?
        let net_usd_value: Double?
    }
    
    func getPortfolios(address: String, chainId: String? = nil) async throws -> [PortfolioItem] {
        var params = ["id": address]
        if let chainId = chainId { params["chain_id"] = chainId }
        return try await get("/v1/user/complex_protocol_list", params: params)
    }
}

// MARK: - Errors

enum OpenAPIError: LocalizedError {
    case requestFailed(statusCode: Int)
    case decodingFailed
    case invalidURL
    case noData
    
    var errorDescription: String? {
        switch self {
        case .requestFailed(let code): return "API request failed with status code: \(code)"
        case .decodingFailed: return "Failed to decode API response"
        case .invalidURL: return "Invalid API URL"
        case .noData: return "No data received from API"
        }
    }
}
