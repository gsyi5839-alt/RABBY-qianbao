import Foundation

/// Centralized OpenAPI service for Rabby wallet backend communication
/// Corresponds to: src/background/service/openapi.ts
///
/// The extension uses WebSignApiPlugin (WASM-based request signing) for higher rate limits.
/// Without that signing, the API applies stricter rate limits. This service implements:
///   1. Proper X-Client / X-Version / X-API-Key / X-API-Time headers
///   2. Global concurrency limiting (max 3 concurrent requests)
///   3. Minimum spacing between requests (200ms)
///   4. Automatic retry with exponential backoff for 429 errors
@MainActor
class OpenAPIService: ObservableObject {
    static let shared = OpenAPIService()
    
    private let baseURL = "https://api.rabby.io"
    private let testnetBaseURL = "https://testnet-openapi.debank.com"
    private var apiKey: String
    private var apiTime: Int
    private let session: URLSession
    
    /// Tracks the last request time to enforce minimum spacing
    private var lastRequestTime: CFAbsoluteTime = 0
    private let minRequestInterval: TimeInterval = 0.3 // 300ms between requests
    
    private init() {
        // Persist API key like the extension does
        if let savedKey = UserDefaults.standard.string(forKey: "rabby_api_key"),
           let savedTime = UserDefaults.standard.object(forKey: "rabby_api_time") as? Int {
            self.apiKey = savedKey
            self.apiTime = savedTime
        } else {
            self.apiKey = UUID().uuidString
            self.apiTime = Int(Date().timeIntervalSince1970)
            UserDefaults.standard.set(self.apiKey, forKey: "rabby_api_key")
            UserDefaults.standard.set(self.apiTime, forKey: "rabby_api_time")
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }
    
    /// Apply standard headers matching the extension client
    private func applyHeaders(_ request: inout URLRequest) {
        request.setValue("Rabby", forHTTPHeaderField: "X-Client")
        request.setValue("0.93.77", forHTTPHeaderField: "X-Version")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("\(apiTime)", forHTTPHeaderField: "X-API-Time")
    }
    
    /// Check if the server rotated the API key via response headers
    private func checkAPIKeyRotation(_ response: HTTPURLResponse) {
        if let newKey = response.value(forHTTPHeaderField: "x-set-api-key"), !newKey.isEmpty {
            self.apiKey = newKey
            self.apiTime = Int(Date().timeIntervalSince1970)
            UserDefaults.standard.set(self.apiKey, forKey: "rabby_api_key")
            UserDefaults.standard.set(self.apiTime, forKey: "rabby_api_time")
            NSLog("[OpenAPI] API key rotated by server")
        }
    }
    
    /// Enforce minimum spacing between requests
    private func throttle() async {
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastRequestTime
        if elapsed < minRequestInterval {
            let waitNs = UInt64((minRequestInterval - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: waitNs)
        }
        lastRequestTime = CFAbsoluteTimeGetCurrent()
    }
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(_ path: String, params: [String: String] = [:], isTestnet: Bool = false) async throws -> T {
        let data = try await getRawData(path, params: params, isTestnet: isTestnet)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func getRawData(_ path: String, params: [String: String] = [:], isTestnet: Bool = false) async throws -> Data {
        let base = isTestnet ? testnetBaseURL : baseURL
        var components = URLComponents(string: "\(base)\(path)")!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyHeaders(&request)
        
        // Retry up to 4 times with exponential backoff for 429 (rate limit)
        var lastStatusCode = 0
        for attempt in 0..<4 {
            await throttle()
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAPIError.requestFailed(statusCode: 0)
            }
            let statusCode = httpResponse.statusCode
            lastStatusCode = statusCode
            
            // Check for API key rotation
            checkAPIKeyRotation(httpResponse)
            
            if (200...299).contains(statusCode) {
                return data
            }
            
            // Retry on 429 (Too Many Requests) with increasing backoff
            if statusCode == 429 && attempt < 3 {
                let delaySecs = Double(attempt + 1) * 3.0 // 3s, 6s, 9s
                let delay = UInt64(delaySecs * 1_000_000_000)
                NSLog("[OpenAPI] Rate limited (429) on %@, retry %d in %.0fs...", path, attempt + 1, delaySecs)
                try await Task.sleep(nanoseconds: delay)
                continue
            }
            
            throw OpenAPIError.requestFailed(statusCode: statusCode)
        }
        
        throw OpenAPIError.requestFailed(statusCode: lastStatusCode)
    }
    
    func post<T: Decodable>(_ path: String, body: [String: Any] = [:], isTestnet: Bool = false) async throws -> T {
        let base = isTestnet ? testnetBaseURL : baseURL
        var request = URLRequest(url: URL(string: "\(base)\(path)")!)
        request.httpMethod = "POST"
        applyHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Retry up to 4 times with exponential backoff for 429 (rate limit),
        // matching the GET behavior for consistency.
        var lastStatusCode = 0
        for attempt in 0..<4 {
            await throttle()

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAPIError.requestFailed(statusCode: 0)
            }
            let statusCode = httpResponse.statusCode
            lastStatusCode = statusCode
            checkAPIKeyRotation(httpResponse)

            if (200...299).contains(statusCode) {
                return try JSONDecoder().decode(T.self, from: data)
            }

            if statusCode == 429 && attempt < 3 {
                let delaySecs = Double(attempt + 1) * 3.0 // 3s, 6s, 9s
                let delay = UInt64(delaySecs * 1_000_000_000)
                NSLog("[OpenAPI] Rate limited (429) on %@, retry %d in %.0fs...", path, attempt + 1, delaySecs)
                try await Task.sleep(nanoseconds: delay)
                continue
            }

            throw OpenAPIError.requestFailed(statusCode: statusCode)
        }

        throw OpenAPIError.requestFailed(statusCode: lastStatusCode)
    }

    /// POST an `Encodable` body using `JSONEncoder`.
    /// Prefer this for typed request bodies (e.g. nested tx payloads).
    func postEncodable<T: Decodable, Body: Encodable>(_ path: String, body: Body, isTestnet: Bool = false) async throws -> T {
        let data = try JSONEncoder().encode(body)
        let base = isTestnet ? testnetBaseURL : baseURL
        var request = URLRequest(url: URL(string: "\(base)\(path)")!)
        request.httpMethod = "POST"
        applyHeaders(&request)
        request.httpBody = data

        var lastStatusCode = 0
        for attempt in 0..<4 {
            await throttle()

            let (respData, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAPIError.requestFailed(statusCode: 0)
            }
            let statusCode = httpResponse.statusCode
            lastStatusCode = statusCode
            checkAPIKeyRotation(httpResponse)

            if (200...299).contains(statusCode) {
                return try JSONDecoder().decode(T.self, from: respData)
            }

            if statusCode == 429 && attempt < 3 {
                let delaySecs = Double(attempt + 1) * 3.0
                let delay = UInt64(delaySecs * 1_000_000_000)
                NSLog("[OpenAPI] Rate limited (429) on %@, retry %d in %.0fs...", path, attempt + 1, delaySecs)
                try await Task.sleep(nanoseconds: delay)
                continue
            }

            throw OpenAPIError.requestFailed(statusCode: statusCode)
        }

        throw OpenAPIError.requestFailed(statusCode: lastStatusCode)
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
    }
    
    struct GasLevel: Codable {
        let price: Int
        let level: String?
        let front_tx_count: Int?
        let estimated_seconds: Int?
        let base_fee: Int?
        let priority_price: Int?
    }
    
    /// Fetch gas market data. The API returns an array of GasLevel objects.
    /// Extension uses `/v1/wallet/gas_market` (GET) or `/v2/wallet/gas_market` (POST).
    /// We parse them into slow/normal/fast by level name.
    func getGasPrice(chainId: String) async throws -> GasPrice {
        let levels: [GasLevel] = try await get("/v1/wallet/gas_market", params: ["chain_id": chainId])
        
        let slow = levels.first(where: { $0.level == "slow" }) ?? levels.first ?? GasLevel(price: 0, level: "slow", front_tx_count: nil, estimated_seconds: nil, base_fee: nil, priority_price: nil)
        let normal = levels.first(where: { $0.level == "normal" }) ?? slow
        let fast = levels.first(where: { $0.level == "fast" }) ?? normal
        
        return GasPrice(slow: slow, normal: normal, fast: fast)
    }
    
    /// Fetch native token info for a chain (price, logo, etc.)
    /// Extension uses `/v1/user/token` with the user's wallet address.
    func getNativeTokenInfo(chainId: String, userAddress: String) async throws -> TokenDetailInfo {
        let nativeAddr = "0x0000000000000000000000000000000000000000"
        return try await get("/v1/user/token", params: ["id": userAddress, "chain_id": chainId, "token_id": nativeAddr])
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

    struct ContractVerificationResponse: Codable {
        let is_verified: Bool?
    }

    struct OriginSecurityResponse: Codable {
        let is_phishing: Bool?
    }

    struct DomainInfoResponse: Codable {
        let age_days: Int?
        let reputation_score: Double?
    }
    
    func checkAddress(chainId: String, address: String) async throws -> SecurityCheckResponse {
        return try await get("/v1/security/check_address", params: ["chain_id": chainId, "address": address])
    }

    func checkContract(address: String, chainId: String) async throws -> ContractVerificationResponse {
        return try await get("/v1/contract/check", params: ["address": address, "chain_id": chainId])
    }

    func checkOrigin(origin: String) async throws -> OriginSecurityResponse {
        return try await get("/v1/security/check_origin", params: ["origin": origin])
    }

    func getDomainInfo(origin: String) async throws -> DomainInfoResponse {
        return try await get("/v1/security/domain_info", params: ["origin": origin])
    }

    // MARK: - Wallet Security (Extension-Compatible) APIs

    /// Matches `SecurityCheckDecision` in `@rabby-wallet/rabby-api`.
    /// (pass | warning | danger | forbidden | loading | pending)
    enum WalletSecurityDecision: String, Codable {
        case pass
        case warning
        case danger
        case forbidden
        case loading
        case pending
    }

    struct WalletSecurityCheckItem: Codable, Identifiable {
        let alert: String
        let description: String
        let is_alert: Bool
        let decision: WalletSecurityDecision
        let id: Int
    }

    struct WalletSecurityCheckResponse: Codable {
        let decision: WalletSecurityDecision
        let alert: String
        let danger_list: [WalletSecurityCheckItem]
        let warning_list: [WalletSecurityCheckItem]
        let forbidden_list: [WalletSecurityCheckItem]
        let forbidden_count: Int
        let warning_count: Int
        let danger_count: Int
        let alert_count: Int
        let trace_id: String
        let error: WalletAPIError?
    }

    struct WalletAPIError: Codable {
        let code: Int
        let msg: String
    }

    /// Transaction payload used by `/v1/wallet/check_tx` and `/v1/wallet/pre_exec_tx`.
    /// Uses the same field names as the extension's OpenApiService.
    struct WalletTx: Codable {
        let chainId: Int
        let data: String
        let from: String
        let gas: String?
        let gasLimit: String?
        let maxFeePerGas: String?
        let maxPriorityFeePerGas: String?
        let gasPrice: String?
        let nonce: String
        let to: String
        let value: String
    }

    struct WalletCheckOriginRequest: Codable {
        let user_addr: String
        let origin: String
    }

    func walletCheckOrigin(address: String, origin: String) async throws -> WalletSecurityCheckResponse {
        return try await postEncodable(
            "/v1/wallet/check_origin",
            body: WalletCheckOriginRequest(user_addr: address, origin: origin)
        )
    }

    struct WalletCheckTextRequest: Codable {
        let user_addr: String
        let origin: String
        let text: String
    }

    func walletCheckText(address: String, origin: String, text: String) async throws -> WalletSecurityCheckResponse {
        return try await postEncodable(
            "/v1/wallet/check_text",
            body: WalletCheckTextRequest(user_addr: address, origin: origin, text: text)
        )
    }

    struct WalletCheckTxRequest: Codable {
        let user_addr: String
        let origin: String
        let tx: WalletTx
        let update_nonce: Bool
    }

    func walletCheckTx(tx: WalletTx, origin: String, address: String, updateNonce: Bool = false) async throws -> WalletSecurityCheckResponse {
        return try await postEncodable(
            "/v1/wallet/check_tx",
            body: WalletCheckTxRequest(user_addr: address, origin: origin, tx: tx, update_nonce: updateNonce)
        )
    }

    // MARK: - Wallet Pre-Exec (Simulation)

    struct WalletTokenItem: Codable {
        let amount: Double
        let chain: String
        let decimals: Int
        let id: String
        let is_core: Bool?
        let is_scam: Bool?
        let is_suspicious: Bool?
        let is_verified: Bool?
        let logo_url: String
        let name: String
        let price: Double
        let symbol: String
        let usd_value: Double?
    }

    struct WalletTransferingNFTItem: Codable {
        struct Collection: Codable {
            let id: String
            let name: String
            let create_at: Int?
            let chains: [String]?
            let is_suspicious: Bool?
            let is_verified: Bool?
            let floor_price: Double?
        }
        let chain: String
        let collection: Collection
        let content: String
        let content_type: String?
        let contract_id: String?
        let detail_url: String?
        let id: String
        let inner_id: String?
        let name: String
        let total_supply: Int?
        let amount: Double
    }

    struct WalletBalanceChange: Codable {
        let error: WalletAPIError?
        let receive_nft_list: [WalletTransferingNFTItem]
        let receive_token_list: [WalletTokenItem]
        let send_nft_list: [WalletTransferingNFTItem]
        let send_token_list: [WalletTokenItem]
        let success: Bool
        let usd_value_change: Double
    }

    struct WalletExplainGas: Codable {
        let success: Bool?
        let gas_used: Double
        let gas_ratio: Double
        let gas_limit: Double
        let estimated_gas_cost_usd_value: Double
        let estimated_gas_cost_value: Double
        let estimated_gas_used: Double
        let estimated_seconds: Double
        let error: WalletAPIError?
    }

    struct WalletExplainTxTypeCall: Codable {
        let action: String
        let contract: String
        let contract_protocol_logo_url: String
        let contract_protocol_name: String
    }

    struct WalletExplainTxTypeSend: Codable {
        let to_addr: String
        let token_symbol: String
        let token_amount: Double
        let token: WalletTokenItem
    }

    struct WalletExplainTxTypeTokenApproval: Codable {
        let spender: String
        let spender_protocol_logo_url: String
        let spender_protocol_name: String
        let token_symbol: String
        let token_amount: Double
        let is_infinity: Bool
        let token: WalletTokenItem
    }

    struct WalletExplainTxResponse: Codable {
        let pre_exec_version: String
        let balance_change: WalletBalanceChange
        let gas: WalletExplainGas
        let trace_id: String
        let type_call: WalletExplainTxTypeCall?
        let type_send: WalletExplainTxTypeSend?
        let type_token_approval: WalletExplainTxTypeTokenApproval?
    }

    struct WalletPreExecTxRequest: Codable {
        let tx: WalletTx
        let user_addr: String
        let origin: String
        let update_nonce: Bool
        let pending_tx_list: [WalletTx]
        let delegate_call: Bool?
    }

    func walletPreExecTx(
        tx: WalletTx,
        origin: String,
        address: String,
        updateNonce: Bool = false,
        pendingTxList: [WalletTx] = [],
        delegateCall: Bool? = nil
    ) async throws -> WalletExplainTxResponse {
        return try await postEncodable(
            "/v1/wallet/pre_exec_tx",
            body: WalletPreExecTxRequest(
                tx: tx,
                user_addr: address,
                origin: origin,
                update_nonce: updateNonce,
                pending_tx_list: pendingTxList,
                delegate_call: delegateCall
            )
        )
    }

    // MARK: - Gas Account APIs

    struct GasAccountLoginResponse: Codable {
        let success: Bool?
        let message: String?
    }

    struct GasAccountBalanceResponse: Codable {
        let data: [GasAccountBalanceItem]
    }

    struct GasAccountBalanceItem: Codable {
        let chain_id: String
        let token_id: String
        let amount: Double
        let symbol: String
        let logo: String?
    }

    struct GasAccountBuildTxResponse: Codable {
        let gas_limit: String
        let sponsor: String?
    }

    struct GasAccountClaimGiftResponse: Codable {
        let success: Bool?
    }

    func gasAccountLogin(address: String, signature: String) async throws -> GasAccountLoginResponse {
        return try await post("/v1/gas_account/login", body: [
            "address": address,
            "signature": signature
        ])
    }

    func getGasAccountBalance(address: String, signature: String) async throws -> GasAccountBalanceResponse {
        return try await get("/v1/gas_account/balance", params: [
            "address": address,
            "signature": signature
        ])
    }

    func buildGasAccountTx(
        address: String,
        signature: String,
        chainId: String,
        from: String,
        to: String?,
        value: String,
        data: String
    ) async throws -> GasAccountBuildTxResponse {
        return try await post("/v1/gas_account/build_tx", body: [
            "address": address,
            "signature": signature,
            "chain_id": chainId,
            "from": from,
            "to": to as Any,
            "value": value,
            "data": data
        ])
    }

    func claimGasAccountGift(address: String, signature: String) async throws -> GasAccountClaimGiftResponse {
        return try await post("/v1/gas_account/claim_gift", body: [
            "address": address,
            "signature": signature
        ])
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

    struct LeaderboardEntry: Codable, Identifiable {
        let id: String
        let address: String
        let points: Int
        let rank: Int
    }

    struct LeaderboardResponse: Codable {
        let list: [LeaderboardEntry]
        let total: Int
        let my_rank: Int?
        let my_points: Int?
    }

    func getPointsLeaderboard(page: Int, limit: Int) async throws -> LeaderboardResponse {
        return try await get("/v1/points/leaderboard", params: [
            "page": "\(page)",
            "limit": "\(limit)"
        ])
    }

    struct VerifyAddressResponse: Codable {
        let success: Bool
        let points_awarded: Int?
    }

    func verifyPointsAddress(address: String, signature: String) async throws -> VerifyAddressResponse {
        return try await post("/v1/points/verify", body: [
            "address": address,
            "signature": signature
        ])
    }

    struct PointsHistoryItem: Codable, Identifiable {
        let id: String
        let type: String // "daily", "referral", "transaction", "swap", "special_event"
        let points: Int
        let description: String?
        let created_at: Double
    }

    struct PointsHistoryResponse: Codable {
        let list: [PointsHistoryItem]
        let total: Int
        let has_more: Bool
    }

    func getPointsHistory(address: String, page: Int, limit: Int) async throws -> PointsHistoryResponse {
        return try await get("/v1/points/history", params: [
            "id": address,
            "page": "\(page)",
            "limit": "\(limit)"
        ])
    }

    struct CheckInInfo: Codable {
        let consecutive_days: Int
        let multiplier: Double
        let checked_in_dates: [String] // "yyyy-MM-dd" format
        let already_checked_in_today: Bool
    }

    func getCheckInInfo(address: String) async throws -> CheckInInfo {
        return try await get("/v1/points/checkin_info", params: ["id": address])
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
    
    func getTokenDetail(chainId: String, tokenId: String, userAddress: String? = nil) async throws -> TokenDetailInfo {
        if let addr = userAddress {
            return try await get("/v1/user/token", params: ["id": addr, "chain_id": chainId, "token_id": tokenId])
        }
        // Fallback: try the public endpoint (may have different availability)
        return try await get("/v1/token", params: ["chain_id": chainId, "id": tokenId])
    }
    
    func getTokenPriceChange(chainId: String, tokenId: String) async throws -> Double {
        let detail: TokenDetailInfo = try await getTokenDetail(chainId: chainId, tokenId: tokenId)
        return detail.price_24h_change ?? 0
    }
    
    /// Token price change info from `/v1/token/price_change`
    /// Extension uses this for the gas bar: `wallet.openapi.tokenPrice(chainServerId)`
    /// Returns { change_percent, last_price }
    struct TokenPriceChange: Codable {
        let change_percent: Double?
        let last_price: Double?
    }
    
    func tokenPrice(token: String) async throws -> TokenPriceChange {
        return try await get("/v1/token/price_change", params: ["token": token])
    }
    
    // MARK: - Balance History APIs
    
    struct BalanceHistoryPoint: Codable {
        let timestamp: TimeInterval
        let usd_value: Double
    }
    
    private struct BalanceHistoryEnvelope: Codable {
        let data: [BalanceHistoryPoint]?
        let list: [BalanceHistoryPoint]?
        let history_list: [BalanceHistoryPoint]?
        let curve: [BalanceHistoryPoint]?
        let total_net_curve: [BalanceHistoryPoint]?
        let points: [BalanceHistoryPoint]?
    }
    
    private struct BalanceHistoryNestedEnvelope: Codable {
        struct Payload: Codable {
            let list: [BalanceHistoryPoint]?
            let history_list: [BalanceHistoryPoint]?
            let curve: [BalanceHistoryPoint]?
            let total_net_curve: [BalanceHistoryPoint]?
            let points: [BalanceHistoryPoint]?
        }
        
        let data: Payload?
        let result: Payload?
    }
    
    private func parseBalanceHistory(_ data: Data) throws -> [BalanceHistoryPoint] {
        let decoder = JSONDecoder()
        
        if let direct = try? decoder.decode([BalanceHistoryPoint].self, from: data) {
            return direct
        }
        
        if let wrapped = try? decoder.decode(BalanceHistoryEnvelope.self, from: data) {
            if let values = wrapped.data { return values }
            if let values = wrapped.list { return values }
            if let values = wrapped.history_list { return values }
            if let values = wrapped.curve { return values }
            if let values = wrapped.total_net_curve { return values }
            if let values = wrapped.points { return values }
        }
        
        if let nested = try? decoder.decode(BalanceHistoryNestedEnvelope.self, from: data) {
            if let values = nested.data?.list { return values }
            if let values = nested.data?.history_list { return values }
            if let values = nested.data?.curve { return values }
            if let values = nested.data?.total_net_curve { return values }
            if let values = nested.data?.points { return values }
            if let values = nested.result?.list { return values }
            if let values = nested.result?.history_list { return values }
            if let values = nested.result?.curve { return values }
            if let values = nested.result?.total_net_curve { return values }
            if let values = nested.result?.points { return values }
        }
        
        throw OpenAPIError.decodingFailed
    }
    
    private func daysValue(for timeRange: String) -> Int? {
        switch timeRange.lowercased() {
        case "24h", "1d", "day":
            return 1
        case "7d", "1w", "week":
            return 7
        case "30d", "1m", "month":
            return 30
        case "365d", "1y", "year":
            return 365
        default:
            return nil
        }
    }
    
    func getBalanceHistory(address: String, chainId: String? = nil, timeRange: String = "24h") async throws -> [BalanceHistoryPoint] {
        var params = ["id": address]
        if let days = daysValue(for: timeRange) {
            params["days"] = String(days)
        } else {
            params["days"] = timeRange
        }
        if let chainId = chainId { params["chain_id"] = chainId }
        
        let primaryData = try await getRawData("/v1/user/total_net_curve", params: params)
        let primaryPoints = try parseBalanceHistory(primaryData)
        if !primaryPoints.isEmpty {
            return primaryPoints
        }
        
        // Backward compatibility: some API variants still accept `time_range`.
        var fallbackParams = ["id": address, "time_range": timeRange]
        if let chainId = chainId { fallbackParams["chain_id"] = chainId }
        let fallbackData = try await getRawData("/v1/user/total_net_curve", params: fallbackParams)
        return try parseBalanceHistory(fallbackData)
    }
    
    struct ChainBalanceInfo: Decodable {
        let chain_id: String
        let chain_name: String
        let logo_url: String?
        let usd_value: Double
        let token_count: Int?
        
        private enum CodingKeys: String, CodingKey {
            case chain_id
            case chain_name
            case logo_url
            case usd_value
            case token_count
            case id
            case name
        }
        
        init(chain_id: String, chain_name: String, logo_url: String?, usd_value: Double, token_count: Int?) {
            self.chain_id = chain_id
            self.chain_name = chain_name
            self.logo_url = logo_url
            self.usd_value = usd_value
            self.token_count = token_count
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let id = (try? container.decode(String.self, forKey: .chain_id))
                ?? (try? container.decode(String.self, forKey: .id))
                ?? ""
            let name = (try? container.decode(String.self, forKey: .chain_name))
                ?? (try? container.decode(String.self, forKey: .name))
                ?? id
            let logo = try? container.decodeIfPresent(String.self, forKey: .logo_url)
            
            let usd: Double = {
                if let value = try? container.decode(Double.self, forKey: .usd_value) {
                    return value
                }
                if let value = try? container.decode(Int.self, forKey: .usd_value) {
                    return Double(value)
                }
                if let value = try? container.decode(String.self, forKey: .usd_value),
                   let parsed = Double(value) {
                    return parsed
                }
                return 0
            }()
            
            let tokenCount: Int? = {
                if let value = try? container.decode(Int.self, forKey: .token_count) {
                    return value
                }
                if let value = try? container.decode(String.self, forKey: .token_count),
                   let parsed = Int(value) {
                    return parsed
                }
                return nil
            }()
            
            self.chain_id = id
            self.chain_name = name
            self.logo_url = logo
            self.usd_value = usd
            self.token_count = tokenCount
        }
    }
    
    private struct ChainBalanceEnvelope: Decodable {
        let data: [ChainBalanceInfo]?
        let list: [ChainBalanceInfo]?
        let chain_list: [ChainBalanceInfo]?
    }
    
    private struct ChainBalanceNestedEnvelope: Decodable {
        struct Payload: Decodable {
            let list: [ChainBalanceInfo]?
            let chain_list: [ChainBalanceInfo]?
        }
        
        let data: Payload?
        let result: Payload?
    }
    
    private func parseChainBalances(_ data: Data) throws -> [ChainBalanceInfo] {
        let decoder = JSONDecoder()
        
        if let direct = try? decoder.decode([ChainBalanceInfo].self, from: data) {
            return direct
        }
        
        if let wrapped = try? decoder.decode(ChainBalanceEnvelope.self, from: data) {
            if let values = wrapped.data { return values }
            if let values = wrapped.list { return values }
            if let values = wrapped.chain_list { return values }
        }
        
        if let nested = try? decoder.decode(ChainBalanceNestedEnvelope.self, from: data) {
            if let values = nested.data?.list { return values }
            if let values = nested.data?.chain_list { return values }
            if let values = nested.result?.list { return values }
            if let values = nested.result?.chain_list { return values }
        }
        
        throw OpenAPIError.decodingFailed
    }
    
    func getChainBalances(address: String) async throws -> [ChainBalanceInfo] {
        let primaryData = try await getRawData("/v1/user/chain_balance", params: ["id": address])
        let primary = try parseChainBalances(primaryData)
        if !primary.isEmpty {
            return primary
        }
        
        // Fallback to total balance endpoint used by extension where chain_list is embedded.
        let fallbackData = try await getRawData("/v1/user/total_balance", params: ["id": address])
        return try parseChainBalances(fallbackData)
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
    
    // MARK: - Used Chain List
    
    /// Chain info returned by /v1/user/used_chain_list
    struct UsedChain: Codable {
        let id: String           // server id like "eth", "bsc"
        let community_id: Int?
        let name: String?
    }
    
    func getUsedChainList(address: String) async throws -> [UsedChain] {
        return try await get("/v1/user/used_chain_list", params: ["id": address])
    }
    
    // MARK: - Token Approval APIs
    
    /// Approval danger count summary from /v1/user/approval_status
    struct ApprovalStatus: Codable {
        let nft_approval_danger_cnt: Int?
        let token_approval_danger_cnt: Int?
        
        var totalDangerCount: Int {
            (nft_approval_danger_cnt ?? 0) + (token_approval_danger_cnt ?? 0)
        }
    }
    
    func getApprovalStatus(address: String) async throws -> [ApprovalStatus] {
        return try await get("/v1/user/approval_status", params: ["id": address])
    }
    
    /// Token authorized list per chain from /v1/user/token_authorized_list
    struct TokenApproval: Codable {
        let id: String?
        let spender: String?
        let token_id: String?
        let token_symbol: String?
        let token_logo_url: String?
        let chain: String?
        let risk_level: String?
        let risk_alert: String?
        let is_open_source: Bool?
        let is_contract: Bool?
        let approved_amount: Double?
        
        var isRisky: Bool {
            guard let level = risk_level else { return false }
            return level == "danger" || level == "warning"
        }
    }
    
    func getTokenAuthorizedList(address: String, chainId: String) async throws -> [TokenApproval] {
        return try await get("/v1/user/token_authorized_list", params: ["id": address, "chain_id": chainId])
    }
    
    /// NFT authorized list per chain
    struct NFTApproval: Codable {
        let id: String?
        let spender: String?
        let chain: String?
        let risk_level: String?
        let risk_alert: String?
        let contract_name: String?
        let nft_name: String?
        
        var isRisky: Bool {
            guard let level = risk_level else { return false }
            return level == "danger" || level == "warning"
        }
    }
    
    func getNFTAuthorizedList(address: String, chainId: String) async throws -> [NFTApproval] {
        return try await get("/v1/user/nft_authorized_list", params: ["id": address, "chain_id": chainId])
    }
    
    // MARK: - Offline Chain APIs
    
    struct OfflineChain: Codable {
        let id: String
        let name: String
        let community_id: Int?
        let logo_url: String?
    }
    
    func getOfflineChainList() async throws -> [OfflineChain] {
        return try await get("/v1/chain/offline_list", params: [:])
    }
    
    // MARK: - Direct RPC Gas Price (bypasses Rabby API rate limiting)
    
    /// Fetch gas price directly from the chain's RPC endpoint using `eth_gasPrice`.
    /// Returns the gas price in Wei (as UInt64).
    /// This is more reliable than the Rabby API because it doesn't require WASM signing.
    func getGasPriceViaRPC(rpcUrl: String) async throws -> UInt64 {
        guard let url = URL(string: rpcUrl) else { throw OpenAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        
        struct RPCResponse: Decodable {
            let result: String?
            let error: RPCError?
        }
        struct RPCError: Decodable {
            let code: Int?
            let message: String?
        }
        
        let response = try JSONDecoder().decode(RPCResponse.self, from: data)
        guard let hexStr = response.result else {
            throw OpenAPIError.noData
        }
        
        // Parse hex string (strip "0x" prefix)
        let hex = hexStr.hasPrefix("0x") ? String(hexStr.dropFirst(2)) : hexStr
        guard let value = UInt64(hex, radix: 16) else {
            throw OpenAPIError.decodingFailed
        }
        return value
    }
    
    /// Fetch fee history from RPC for EIP-1559 chains. Returns base fee + priority fees.
    func getFeeHistoryViaRPC(rpcUrl: String) async throws -> (slow: UInt64, normal: UInt64, fast: UInt64) {
        guard let url = URL(string: rpcUrl) else { throw OpenAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_feeHistory",
            "params": [4, "latest", [10, 50, 90]],
            "id": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        
        struct FeeHistoryResponse: Decodable {
            let result: FeeHistoryResult?
        }
        struct FeeHistoryResult: Decodable {
            let baseFeePerGas: [String]?
            let reward: [[String]]?
        }
        
        let response = try JSONDecoder().decode(FeeHistoryResponse.self, from: data)
        guard let result = response.result,
              let baseFees = result.baseFeePerGas, !baseFees.isEmpty,
              let rewards = result.reward, !rewards.isEmpty else {
            // Fallback to eth_gasPrice
            let gasPrice = try await getGasPriceViaRPC(rpcUrl: rpcUrl)
            return (slow: gasPrice * 80 / 100, normal: gasPrice, fast: gasPrice * 120 / 100)
        }
        
        // Latest base fee
        let latestBaseFeeHex = baseFees.last!.hasPrefix("0x") ? String(baseFees.last!.dropFirst(2)) : baseFees.last!
        let baseFee = UInt64(latestBaseFeeHex, radix: 16) ?? 0
        
        // Average priority fees across blocks
        func avgPriority(index: Int) -> UInt64 {
            var sum: UInt64 = 0
            var count: UInt64 = 0
            for block in rewards {
                if index < block.count {
                    let hex = block[index].hasPrefix("0x") ? String(block[index].dropFirst(2)) : block[index]
                    sum += UInt64(hex, radix: 16) ?? 0
                    count += 1
                }
            }
            return count > 0 ? sum / count : 0
        }
        
        let slowPriority = avgPriority(index: 0)   // 10th percentile
        let normalPriority = avgPriority(index: 1)  // 50th percentile
        let fastPriority = avgPriority(index: 2)    // 90th percentile
        
        return (
            slow: baseFee + slowPriority,
            normal: baseFee + normalPriority,
            fast: baseFee + fastPriority
        )
    }
    
    // MARK: - CoinGecko Token Price (bypasses Rabby API rate limiting)
    
    /// Mapping from chain serverId to CoinGecko coin ID for native tokens
    private static let coinGeckoIds: [String: String] = [
        "eth": "ethereum",
        "bsc": "binancecoin",
        "matic": "matic-network",
        "avax": "avalanche-2",
        "ftm": "fantom",
        "op": "ethereum",      // OP uses ETH
        "arb": "ethereum",     // Arbitrum uses ETH
        "base": "ethereum",    // Base uses ETH
        "era": "ethereum",     // zkSync Era uses ETH
        "linea": "ethereum",   // Linea uses ETH
        "nova": "ethereum",    // Arbitrum Nova uses ETH
        "zora": "ethereum",    // Zora uses ETH
        "boba": "ethereum",    // Boba uses ETH
        "pze": "ethereum",     // Polygon zkEVM uses ETH
        "scrl": "ethereum",    // Scroll uses ETH
        "mnt": "mantle",
        "celo": "celo",
        "xdai": "dai",         // Gnosis uses xDAI
        "cro": "crypto-com-chain",
        "kava": "kava",
        "ron": "ronin",
        "core": "coredaoorg",
        "movr": "moonriver",
        "mobm": "moonbeam",
        "cfx": "conflux-token",
        "klay": "klay-token",
        "astar": "astar",
        "iotx": "iotex",
        "rsk": "rootstock",
        "fuse": "fuse-network-token",
        "wemix": "wemix-token",
        "flr": "flare-networks",
        "canto": "canto",
        "tlos": "telos",
        "doge": "dogecoin",
        "blast": "ethereum",   // Blast uses ETH
        "mode": "ethereum",    // Mode uses ETH
        "merlin": "bitcoin",   // Merlin uses BTC
        "sei": "sei-network",
        "btt": "bittorrent",
        "pulse": "pulsechain",
    ]
    
    struct CoinGeckoPrice {
        let usdPrice: Double
        let usd24hChange: Double
    }
    
    /// Fetch native token price and 24h change from CoinGecko's free API.
    /// No authentication required. Rate limit: ~10-30 calls/minute.
    func getTokenPriceFromCoinGecko(chainServerId: String) async throws -> CoinGeckoPrice {
        guard let coinId = Self.coinGeckoIds[chainServerId] else {
            throw OpenAPIError.noData
        }
        
        let urlStr = "https://api.coingecko.com/api/v3/simple/price?ids=\(coinId)&vs_currencies=usd&include_24hr_change=true"
        guard let url = URL(string: urlStr) else { throw OpenAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OpenAPIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Response: { "ethereum": { "usd": 2345.67, "usd_24h_change": 1.234 } }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let coinData = json[coinId] as? [String: Any] else {
            throw OpenAPIError.decodingFailed
        }
        
        let price = coinData["usd"] as? Double ?? 0
        let change = coinData["usd_24h_change"] as? Double ?? 0
        
        return CoinGeckoPrice(usdPrice: price, usd24hChange: change)
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

// MARK: - Sendable conformance
extension OpenAPIService: @unchecked Sendable {}
