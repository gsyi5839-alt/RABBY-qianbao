import Foundation
import Combine

/// Network manager for blockchain RPC requests
class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - RPC Request
    
    func sendRPCRequest<T: Decodable>(
        method: String,
        params: [Any],
        rpcURL: URL,
        responseType: T.Type,
        timeout: TimeInterval? = nil  // ← 新增：可选的超时参数（毫秒）
    ) async throws -> T {
        let request = try createRPCRequest(method: method, params: params, rpcURL: rpcURL, timeout: timeout)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        let rpcResponse = try JSONDecoder().decode(RPCResponse<T>.self, from: data)

        if let error = rpcResponse.error {
            throw NetworkError.rpcError(error.code, error.message)
        }

        guard let result = rpcResponse.result else {
            throw NetworkError.emptyResponse
        }

        return result
    }

    private func createRPCRequest(method: String, params: [Any], rpcURL: URL, timeout: TimeInterval? = nil) throws -> URLRequest {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // ✅ 如果提供了 timeout，设置请求超时（转换毫秒为秒）
        if let timeoutMs = timeout {
            request.timeoutInterval = timeoutMs / 1000.0
        }

        let rpcRequest = RPCRequest(
            jsonrpc: "2.0",
            id: Int.random(in: 1...999999),
            method: method,
            params: params
        )

        request.httpBody = try JSONEncoder().encode(rpcRequest)
        return request
    }

    /// Resolve the effective RPC URL for a chain.
    /// - Prefers custom RPC when enabled (aligns with extension behavior).
    /// - Falls back to the chain default RPC when the custom RPC URL is invalid.
    private func resolvedRPCURL(for chain: Chain) async -> URL {
        let urlString: String = await MainActor.run {
            RPCManager.shared.getEffectiveRPC(chainId: chain.id) ?? chain.defaultRpcUrl
        }

        if let url = URL(string: urlString) {
            return url
        }

        // Custom RPC could be an invalid URL string; never crash.
        return URL(string: chain.defaultRpcUrl) ?? chain.rpcURL
    }
    
    // MARK: - Ethereum RPC Methods
    
    func getBalance(address: String, chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_getBalance",
            params: [address, "latest"],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func getTransactionCount(address: String, chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_getTransactionCount",
            params: [address, "latest"],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func estimateGas(transaction: [String: Any], chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_estimateGas",
            params: [transaction],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func getGasPrice(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_gasPrice",
            params: [],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func sendRawTransaction(signedTransaction: String, chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_sendRawTransaction",
            params: [signedTransaction],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func getTransactionReceipt(hash: String, chain: Chain) async throws -> TransactionReceipt? {
        return try await sendRPCRequest(
            method: "eth_getTransactionReceipt",
            params: [hash],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: TransactionReceipt?.self
        )
    }
    
    func call(transaction: [String: Any], chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_call",
            params: [transaction, "latest"],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func getChainId(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_chainId",
            params: [],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func getBlockNumber(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_blockNumber",
            params: [],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    func getBlockByNumber(blockNumber: String, fullTransactions: Bool, chain: Chain) async throws -> Block {
        return try await sendRPCRequest(
            method: "eth_getBlockByNumber",
            params: [blockNumber, fullTransactions],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: Block.self
        )
    }

    /// Fetch the network-recommended max priority fee per gas (EIP-1559).
    /// Returns a hex-encoded wei value, e.g. "0x59682f00".
    func getMaxPriorityFeePerGas(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_maxPriorityFeePerGas",
            params: [],
            rpcURL: await resolvedRPCURL(for: chain),
            responseType: String.self
        )
    }
    
    // MARK: - ERC20 Token Methods
    
    func getERC20Balance(tokenAddress: String, ownerAddress: String, chain: Chain) async throws -> String {
        let data = "0x70a08231" + ownerAddress.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        
        let transaction: [String: Any] = [
            "to": tokenAddress,
            "data": data
        ]
        
        return try await call(transaction: transaction, chain: chain)
    }
    
    func getERC20Symbol(tokenAddress: String, chain: Chain) async throws -> String {
        let data = "0x95d89b41" // symbol()
        
        let transaction: [String: Any] = [
            "to": tokenAddress,
            "data": data
        ]
        
        let result = try await call(transaction: transaction, chain: chain)
        return try decodeString(from: result)
    }
    
    func getERC20Decimals(tokenAddress: String, chain: Chain) async throws -> Int {
        let data = "0x313ce567" // decimals()
        
        let transaction: [String: Any] = [
            "to": tokenAddress,
            "data": data
        ]
        
        let result = try await call(transaction: transaction, chain: chain)
        guard let value = Int(result.replacingOccurrences(of: "0x", with: ""), radix: 16) else {
            throw NetworkError.invalidResponse
        }
        return value
    }
    
    private func decodeString(from hex: String) throws -> String {
        let hexData = hex.replacingOccurrences(of: "0x", with: "")
        guard let data = Data(hexString: hexData) else {
            throw NetworkError.invalidResponse
        }
        
        // Skip first 64 bytes (offset) and next 32 bytes (length)
        let stringData = data.dropFirst(64)
        guard let string = String(data: stringData, encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) else {
            throw NetworkError.invalidResponse
        }
        
        return string
    }
    
    // MARK: - HTTP Methods for API Calls
    
    /// Generic GET request
    func get<T: Decodable>(url: String, parameters: [String: Any]? = nil) async throws -> T {
        var urlComponents = URLComponents(string: url)
        
        if let parameters = parameters {
            urlComponents?.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }
        
        guard let requestURL = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Generic POST request
    func post<T: Decodable>(url: String, body: [String: Any]) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Unified Chain Model

struct Chain: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let serverId: String
    let symbol: String
    let nativeTokenAddress: String
    let defaultRpcUrl: String  // ← 改名：原 rpcUrl -> defaultRpcUrl（内部存储）
    let scanUrl: String
    let logo: String
    let decimals: Int
    let isEIP1559: Bool
    var isTestnet: Bool
    var isCustom: Bool

    // Backward compatibility aliases
    var nativeTokenSymbol: String { symbol }
    var explorerURL: String { scanUrl }

    // ✅ rpcUrl: 直接返回 defaultRpcUrl（实际使用时通过 ChainManager.getEffectiveRPCUrl 获取）
    var rpcUrl: String {
        return defaultRpcUrl
    }

    var rpcURLString: String { rpcUrl }
    var rpcURL: URL { URL(string: rpcUrl)! }

    // CodingKeys：兼容旧数据（rpcUrl -> defaultRpcUrl）
    enum CodingKeys: String, CodingKey {
        case id, name, serverId, symbol, nativeTokenAddress
        case defaultRpcUrl = "rpcUrl"  // 解码时从 "rpcUrl" 读取到 defaultRpcUrl
        case scanUrl, logo, decimals, isEIP1559, isTestnet, isCustom
    }

    init(id: Int, name: String, serverId: String, symbol: String, nativeTokenAddress: String,
         rpcUrl: String, scanUrl: String, logo: String = "", decimals: Int = 18,
         isEIP1559: Bool = true, isTestnet: Bool = false, isCustom: Bool = false) {
        self.id = id; self.name = name; self.serverId = serverId; self.symbol = symbol
        self.nativeTokenAddress = nativeTokenAddress; self.defaultRpcUrl = rpcUrl; self.scanUrl = scanUrl
        self.logo = logo; self.decimals = decimals; self.isEIP1559 = isEIP1559
        self.isTestnet = isTestnet; self.isCustom = isCustom
    }

    /// Convenience init from serverId only (defaults to Ethereum)
    init(id: String) {
        self.init(id: 1, name: "Ethereum", serverId: id, symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://eth.llamarpc.com", scanUrl: "https://etherscan.io",
                  logo: "eth_logo")
    }

    static func == (lhs: Chain, rhs: Chain) -> Bool { lhs.id == rhs.id }
}

// MARK: - Unified Chain Manager

@MainActor
class ChainManager: ObservableObject {
    static let shared = ChainManager()
    
    @Published var mainnetChains: [Chain] = []
    @Published var testnetChains: [Chain] = []
    @Published var selectedChain: Chain?
    @Published var customChains: [Chain] = []
    
    private let storageManager = StorageManager.shared
    
    // Backward compatibility
    var supportedChains: [Chain] { mainnetChains }
    var allChains: [Chain] { mainnetChains + testnetChains + customChains }
    /// Chains that should be shown in UI / used for balance refresh, respecting "Show testnet".
    /// Aligns with extension behavior where testnets are hidden globally when the toggle is off.
    var visibleChains: [Chain] {
        let showTestnet = PreferenceManager.shared.showTestnet
        if showTestnet { return allChains }
        return allChains.filter { !$0.isTestnet }
    }
    
    private init() {
        loadDefaultChains()

        // ✅ 加载自定义测试网（从 CustomTestnetManager）
        loadCustomTestnets()

        // Load custom chains
        if let saved = try? storageManager.getPreference(forKey: "customChains", type: [Chain].self) {
            customChains = saved
        }

        // Load selected chain
        if let savedId = try? storageManager.getPreference(forKey: "selectedChainId", type: Int.self),
           let chain = allChains.first(where: { $0.id == savedId }) {
            selectedChain = chain
        } else {
            selectedChain = mainnetChains.first
        }
    }
    
    func selectChain(_ chain: Chain) {
        selectedChain = chain
        try? storageManager.savePreference(chain.id, forKey: "selectedChainId")
    }
    
    // Multiple getter signatures for backward compatibility
    func getChain(serverId: String) -> Chain? {
        allChains.first(where: { $0.serverId == serverId })
    }
    func getChain(id: Int) -> Chain? {
        allChains.first(where: { $0.id == id })
    }
    func getChain(byId id: Int) -> Chain? { getChain(id: id) }
    func getChain(byServerId serverId: String) -> Chain? { getChain(serverId: serverId) }
    
    func getRPCUrl(chain: String) -> String {
        guard let c = getChain(serverId: chain) else {
            return "https://eth.llamarpc.com"
        }
        return RPCManager.shared.getEffectiveRPC(chainId: c.id) ?? c.defaultRpcUrl
    }

    /// ✅ 获取生效的 RPC URL（优先使用自定义 RPC）
    /// 注意：由于编译器限制，暂时让调用者自己调用 RPCManager.shared.getEffectiveRPC()
    /// 示例：RPCManager.shared.getEffectiveRPC(chainId: chainId) ?? chain.defaultRpcUrl
    /*
    func getEffectiveRPCUrl(chainId: Int) -> String {
        // 1. 优先使用自定义 RPC
        if let customRpc = RPCManager.shared.getEffectiveRPC(chainId: chainId) {
            return customRpc
        }

        // 2. 使用链的默认 RPC
        if let chain = getChain(id: chainId) {
            return chain.defaultRpcUrl
        }

        // 3. 回退到默认值
        return "https://eth.llamarpc.com"
    }
    */
    
    func getAllChains() -> [Chain] { allChains }
    func getVisibleChains() -> [Chain] { visibleChains }
    
    func addCustomChain(_ chain: Chain) throws {
        var newChain = chain
        newChain.isCustom = true
        customChains.append(newChain)
        try storageManager.savePreference(customChains, forKey: "customChains")
    }
    
    func removeCustomChain(_ chain: Chain) throws {
        customChains.removeAll { $0.id == chain.id }
        try storageManager.savePreference(customChains, forKey: "customChains")
    }

    // ✅ 加载自定义测试网（从 CustomTestnetManager）
    private func loadCustomTestnets() {
        let customTestnetManager = CustomTestnetManager.shared
        let testnets = customTestnetManager.getList()

        // 将 TestnetChain 转换为 Chain
        let chains = testnets.map { testnet -> Chain in
            Chain(
                id: testnet.id,
                name: testnet.name,
                serverId: testnet.serverId,
                symbol: testnet.nativeTokenSymbol,
                nativeTokenAddress: testnet.nativeTokenAddress,
                rpcUrl: testnet.rpcUrl,
                scanUrl: testnet.scanLink,
                logo: testnet.logo,
                decimals: testnet.nativeTokenDecimals,
                isEIP1559: false,  // 自定义测试网默认不支持 EIP-1559
                isTestnet: true,
                isCustom: true
            )
        }

        // 添加到 testnetChains（不重复添加）
        for chain in chains {
            if !testnetChains.contains(where: { $0.id == chain.id }) {
                testnetChains.append(chain)
            }
        }

        print("[ChainManager] 📦 Loaded \(chains.count) custom testnets")
    }

    /// 刷新自定义测试网列表（当 CustomTestnetManager 更新时调用）
    func refreshCustomTestnets() {
        // 移除旧的自定义测试网
        testnetChains.removeAll { $0.isCustom }

        // 重新加载
        loadCustomTestnets()
    }
    
    // swiftlint:disable function_body_length
    private func loadDefaultChains() {
        let addr = "0x0000000000000000000000000000000000000000"
        mainnetChains = [
            // ── Tier 0: Major chains ──
            Chain(id: 1, name: "Ethereum", serverId: "eth", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://eth.llamarpc.com", scanUrl: "https://etherscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/eth/42ba589cd077e7bdd97db6480b0ff61d.png", isEIP1559: true),
            Chain(id: 56, name: "BNB Chain", serverId: "bsc", symbol: "BNB", nativeTokenAddress: addr,
                  rpcUrl: "https://bsc-dataseed1.binance.org", scanUrl: "https://bscscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/bsc/bc73fa84b7fc5337905e527dadcbc854.png", isEIP1559: false),
            Chain(id: 100, name: "Gnosis Chain", serverId: "xdai", symbol: "xDai", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.gnosischain.com", scanUrl: "https://gnosisscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/xdai/43c1e09e93e68c9f0f3b132976394529.png"),
            Chain(id: 137, name: "Polygon", serverId: "matic", symbol: "POL", nativeTokenAddress: addr,
                  rpcUrl: "https://polygon-rpc.com", scanUrl: "https://polygonscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/matic/52ca152c08831e4765506c9bd75767e8.png"),
            Chain(id: 250, name: "Fantom", serverId: "ftm", symbol: "FTM", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.ftm.tools", scanUrl: "https://explorer.fantom.network",
                  logo: "https://static.debank.com/image/chain/logo_url/ftm/14133435f89637157a4405e954e1b1b2.png", isEIP1559: false),
            Chain(id: 43114, name: "Avalanche", serverId: "avax", symbol: "AVAX", nativeTokenAddress: addr,
                  rpcUrl: "https://api.avax.network/ext/bc/C/rpc", scanUrl: "https://snowscan.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/avax/4d1649e8a0c7dec9de3491b81807d402.png"),
            Chain(id: 10, name: "OP", serverId: "op", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.optimism.io", scanUrl: "https://optimistic.etherscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/op/68bef0c9f75488f4e302805ef9c8fc84.png"),
            Chain(id: 42161, name: "Arbitrum", serverId: "arb", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://arb1.arbitrum.io/rpc", scanUrl: "https://arbiscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/arb/854f629937ce94bebeb2cd38fb336de7.png"),
            Chain(id: 42220, name: "Celo", serverId: "celo", symbol: "CELO", nativeTokenAddress: addr,
                  rpcUrl: "https://forno.celo.org", scanUrl: "https://celoscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/celo/faae2c36714d55db1d7a36aba5868f6a.png"),
            Chain(id: 1285, name: "Moonriver", serverId: "movr", symbol: "MOVR", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.api.moonriver.moonbeam.network", scanUrl: "https://moonriver.moonscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/movr/cfdc1aef482e322abd02137b0e484dba.png"),
            Chain(id: 25, name: "Cronos", serverId: "cro", symbol: "CRO", nativeTokenAddress: addr,
                  rpcUrl: "https://evm.cronos.org", scanUrl: "https://explorer.cronos.org",
                  logo: "https://static.debank.com/image/chain/logo_url/cro/f947000cc879ee8ffa032793808c741c.png"),
            Chain(id: 288, name: "Boba", serverId: "boba", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.boba.network", scanUrl: "https://bobascan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/boba/e43d79cd8088ceb3ea3e4a240a75728f.png", isEIP1559: false),
            Chain(id: 1088, name: "Metis", serverId: "metis", symbol: "Metis", nativeTokenAddress: addr,
                  rpcUrl: "https://andromeda.metis.io/?owner=1088", scanUrl: "https://explorer.metis.io",
                  logo: "https://static.debank.com/image/chain/logo_url/metis/7485c0a61c1e05fdf707113b6b6ac917.png", isEIP1559: false),
            Chain(id: 1284, name: "Moonbeam", serverId: "mobm", symbol: "GLMR", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.api.moonbeam.network", scanUrl: "https://moonscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/mobm/fcfe3dee0e55171580545cf4d4940257.png"),
            Chain(id: 122, name: "Fuse", serverId: "fuse", symbol: "FUSE", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.fuse.io", scanUrl: "https://explorer.fuse.io",
                  logo: "https://static.debank.com/image/chain/logo_url/fuse/7a21b958761d52d04ff0ce829d1703f4.png", isEIP1559: false),
            Chain(id: 8217, name: "Kaia", serverId: "klay", symbol: "KAIA", nativeTokenAddress: addr,
                  rpcUrl: "https://public-en-cypress.klaytn.net", scanUrl: "https://kaiascan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/klay/4182ee077031d843a57e42746c30c072.png", isEIP1559: false),
            Chain(id: 592, name: "Astar", serverId: "astar", symbol: "ASTR", nativeTokenAddress: addr,
                  rpcUrl: "https://evm.astar.network", scanUrl: "https://blockscout.com/astar",
                  logo: "https://static.debank.com/image/chain/logo_url/astar/398c7e0014bdada3d818367a7273fabe.png"),
            Chain(id: 4689, name: "IoTeX", serverId: "iotx", symbol: "IOTX", nativeTokenAddress: addr,
                  rpcUrl: "https://babel-api.mainnet.iotex.io", scanUrl: "https://iotexscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/iotx/d3be2cd8677f86bd9ab7d5f3701afcc9.png", isEIP1559: false),
            Chain(id: 30, name: "Rootstock", serverId: "rsk", symbol: "RBTC", nativeTokenAddress: addr,
                  rpcUrl: "https://public-node.rsk.co", scanUrl: "https://rootstock.blockscout.com",
                  logo: "https://static.debank.com/image/chain/logo_url/rsk/ff47def89fba98394168bf5f39920c8c.png", isEIP1559: false),
            Chain(id: 53935, name: "DFK", serverId: "dfk", symbol: "JEWEL", nativeTokenAddress: addr,
                  rpcUrl: "https://subnets.avax.network/defi-kingdoms/dfk-chain/rpc", scanUrl: "https://subnets.avax.network/defi-kingdoms/dfk-chain/explorer",
                  logo: "https://static.debank.com/image/chain/logo_url/dfk/233867c089c5b71be150aa56003f3f7a.png"),
            Chain(id: 40, name: "Telos EVM", serverId: "tlos", symbol: "TLOS", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.telos.net/evm", scanUrl: "https://www.teloscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/tlos/6191b8e0b261536044fc70ba746ba2c9.png", isEIP1559: false),
            Chain(id: 42170, name: "Arbitrum Nova", serverId: "nova", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://nova.arbitrum.io/rpc", scanUrl: "https://nova.arbiscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/nova/06eb2b7add8ba443d5b219c04089c326.png"),
            Chain(id: 7700, name: "Canto", serverId: "canto", symbol: "CANTO", nativeTokenAddress: addr,
                  rpcUrl: "https://canto.gravitychain.io", scanUrl: "https://tuber.build",
                  logo: "https://static.debank.com/image/chain/logo_url/canto/47574ef619e057d2c6bbce1caba57fb6.png"),
            Chain(id: 2000, name: "Dogechain", serverId: "doge", symbol: "DOGE", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.dogechain.dog", scanUrl: "https://explorer.dogechain.dog",
                  logo: "https://static.debank.com/image/chain/logo_url/doge/2538141079688a7a43bc22c7b60fb45f.png", isEIP1559: false),
            Chain(id: 2222, name: "Kava", serverId: "kava", symbol: "KAVA", nativeTokenAddress: addr,
                  rpcUrl: "https://evm.kava.io", scanUrl: "https://kavascan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/kava/b26bf85a1a817e409f9a3902e996dc21.png"),
            Chain(id: 1030, name: "Conflux", serverId: "cfx", symbol: "CFX", nativeTokenAddress: addr,
                  rpcUrl: "https://evm.confluxrpc.com", scanUrl: "https://evm.confluxscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/cfx/eab0c7304c6820b48b2a8d0930459b82.png", isEIP1559: false),
            Chain(id: 324, name: "zkSync Era", serverId: "era", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.era.zksync.io", scanUrl: "https://era.zksync.network",
                  logo: "https://static.debank.com/image/chain/logo_url/era/2cfcd0c8436b05d811b03935f6c1d7da.png"),
            Chain(id: 2020, name: "Ronin", serverId: "ron", symbol: "RON", nativeTokenAddress: addr,
                  rpcUrl: "https://api.roninchain.com/rpc", scanUrl: "https://explorer.roninchain.com",
                  logo: "https://static.debank.com/image/chain/logo_url/ron/6e0f509804bc83bf042ef4d674c1c5ee.png", isEIP1559: false),
            Chain(id: 1101, name: "Polygon zkEVM", serverId: "pze", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://zkevm-rpc.com", scanUrl: "https://zkevm.polygonscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/pze/a2276dce2d6a200c6148fb975f0eadd3.png", isEIP1559: false),
            Chain(id: 1116, name: "CORE", serverId: "core", symbol: "CORE", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.coredao.org", scanUrl: "https://scan.coredao.org",
                  logo: "https://static.debank.com/image/chain/logo_url/core/ccc02f660e5dd410b23ca3250ae7c060.png", isEIP1559: false),
            Chain(id: 1111, name: "WEMIX", serverId: "wemix", symbol: "WEMIX", nativeTokenAddress: addr,
                  rpcUrl: "https://api.wemix.com", scanUrl: "https://explorer.wemix.com",
                  logo: "https://static.debank.com/image/chain/logo_url/wemix/d1ba88d1df6cca0b0cb359c36a09c054.png"),
            Chain(id: 14, name: "Flare", serverId: "flr", symbol: "FLR", nativeTokenAddress: addr,
                  rpcUrl: "https://flare-api.flare.network/ext/C/rpc", scanUrl: "https://flare-explorer.flare.network",
                  logo: "https://static.debank.com/image/chain/logo_url/flr/9ee03d5d7036ad9024e81d55596bb4dc.png", isEIP1559: false),
            Chain(id: 248, name: "Oasys", serverId: "oas", symbol: "OAS", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.mainnet.oasys.games", scanUrl: "https://scan.oasys.games",
                  logo: "https://static.debank.com/image/chain/logo_url/oas/61dfecab1ba8a404354ce94b5a54d4b3.png"),
            Chain(id: 7777777, name: "Zora", serverId: "zora", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.zora.energy", scanUrl: "https://explorer.zora.energy",
                  logo: "https://static.debank.com/image/chain/logo_url/zora/de39f62c4489a2359d5e1198a8e02ef1.png"),
            Chain(id: 8453, name: "Base", serverId: "base", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.base.org", scanUrl: "https://basescan.org",
                  logo: "https://static.debank.com/image/chain/logo_url/base/ccc1513e4f390542c4fb2f4b88ce9579.png"),
            Chain(id: 59144, name: "Linea", serverId: "linea", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.linea.build", scanUrl: "https://lineascan.build",
                  logo: "https://static.debank.com/image/chain/logo_url/linea/32d4ff2cf92c766ace975559c232179c.png"),
            Chain(id: 5000, name: "Mantle", serverId: "mnt", symbol: "MNT", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.mantle.xyz", scanUrl: "https://mantlescan.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/mnt/0af11a52431d60ded59655c7ca7e1475.png"),
            Chain(id: 169, name: "Manta Pacific", serverId: "manta", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://pacific-rpc.manta.network/http", scanUrl: "https://pacific-explorer.manta.network",
                  logo: "https://static.debank.com/image/chain/logo_url/manta/0e25a60b96a29d6a5b9e524be7565845.png"),
            Chain(id: 534352, name: "Scroll", serverId: "scrl", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.scroll.io", scanUrl: "https://scrollscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/scrl/1fa5c7e0bfd353ed0a97c1476c9c42d2.png"),
            Chain(id: 204, name: "opBNB", serverId: "opbnb", symbol: "BNB", nativeTokenAddress: addr,
                  rpcUrl: "https://opbnb-mainnet-rpc.bnbchain.org", scanUrl: "https://mainnet.opbnbscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/opbnb/07e2e686e363a842d0982493638e1285.png", isEIP1559: false),
            Chain(id: 109, name: "Shibarium", serverId: "shib", symbol: "BONE", nativeTokenAddress: addr,
                  rpcUrl: "https://www.shibrpc.com", scanUrl: "https://shibariumscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/shib/4ec79ed9ee4988dfdfc41e1634a447be.png"),
            Chain(id: 34443, name: "Mode", serverId: "mode", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.mode.network", scanUrl: "https://explorer.mode.network",
                  logo: "https://static.debank.com/image/chain/logo_url/mode/466e6e12f4fd827f8f497cceb0601a5e.png"),
            Chain(id: 7000, name: "ZetaChain", serverId: "zeta", symbol: "ZETA", nativeTokenAddress: addr,
                  rpcUrl: "https://zetachain-evm.blockpi.network/v1/rpc/public", scanUrl: "https://zetachain.blockscout.com",
                  logo: "https://static.debank.com/image/chain/logo_url/zeta/d0e1b5e519d99c452a30e83a1263d1d0.png"),
            Chain(id: 1380012617, name: "RARI", serverId: "rari", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.rpc.rarichain.org/http", scanUrl: "https://mainnet.explorer.rarichain.org",
                  logo: "https://static.debank.com/image/chain/logo_url/rari/67fc6abba5cfc6bb3a57bb6afcf5afee.png"),
            Chain(id: 4200, name: "Merlin", serverId: "merlin", symbol: "BTC", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.merlinchain.io", scanUrl: "https://scan.merlinchain.io",
                  logo: "https://static.debank.com/image/chain/logo_url/merlin/458e4686dfb909ba871bd96fe45417a8.png", isEIP1559: false),
            Chain(id: 81457, name: "Blast", serverId: "blast", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.blast.io", scanUrl: "https://blastscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/blast/15132294afd38ce980639a381ee30149.png"),
            Chain(id: 2410, name: "Karak", serverId: "karak", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.karak.network", scanUrl: "https://explorer.karak.network",
                  logo: "https://static.debank.com/image/chain/logo_url/karak/a9e47f00f6eeb2c9cc8f9551cff5fe68.png"),
            Chain(id: 252, name: "Fraxtal", serverId: "frax", symbol: "FRAX", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.frax.com", scanUrl: "https://fraxscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/frax/2e210d888690ad0c424355cc8471d48d.png"),
            Chain(id: 196, name: "X Layer", serverId: "xlayer", symbol: "OKB", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.xlayer.tech", scanUrl: "https://www.oklink.com/xlayer",
                  logo: "https://static.debank.com/image/chain/logo_url/xlayer/282a62903a4c74a964b704a161d1ba39.png", isEIP1559: false),
            Chain(id: 13371, name: "Immutable zkEVM", serverId: "itze", symbol: "IMX", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.immutable.com", scanUrl: "https://explorer.immutable.com",
                  logo: "https://static.debank.com/image/chain/logo_url/itze/ce3a511dc511053b1b35bb48166a5d39.png"),
            Chain(id: 200901, name: "Bitlayer", serverId: "btr", symbol: "BTC", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.bitlayer.org", scanUrl: "https://www.btrscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/btr/78ff16cf14dad73c168a70f7c971e401.png"),
            Chain(id: 223, name: "B\u{00B2}", serverId: "b2", symbol: "BTC", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.bsquared.network", scanUrl: "https://explorer.bsquared.network",
                  logo: "https://static.debank.com/image/chain/logo_url/b2/6ca6c8bc33af59c5b9273a2b7efbd236.png"),
            Chain(id: 60808, name: "BOB", serverId: "bob", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.gobob.xyz", scanUrl: "https://explorer.gobob.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/bob/4e0029be99877775664327213a8da60e.png"),
            Chain(id: 1729, name: "Reya", serverId: "reya", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.reya.network", scanUrl: "https://explorer.reya.network",
                  logo: "https://static.debank.com/image/chain/logo_url/reya/20d71aad4279c33229297da1f00d8ae1.png"),
            Chain(id: 6001, name: "BounceBit", serverId: "bb", symbol: "BB", nativeTokenAddress: addr,
                  rpcUrl: "https://fullnode-mainnet.bouncebitapi.com", scanUrl: "https://bbscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/bb/da74a4980f24d870cb43ccd763e0c966.png"),
            Chain(id: 167000, name: "Taiko", serverId: "taiko", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.mainnet.taiko.xyz", scanUrl: "https://taikoscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/taiko/7723fbdb38ef181cd07a8b8691671e6b.png"),
            Chain(id: 7560, name: "Cyber", serverId: "cyber", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://cyber.alt.technology", scanUrl: "https://cyberscan.co",
                  logo: "https://static.debank.com/image/chain/logo_url/cyber/3a3c0c5da5fa8876c8c338afae0db478.png"),
            Chain(id: 1329, name: "Sei", serverId: "sei", symbol: "SEI", nativeTokenAddress: addr,
                  rpcUrl: "https://evm-rpc.sei-apis.com", scanUrl: "https://seitrace.com",
                  logo: "https://static.debank.com/image/chain/logo_url/sei/34ddf58f678be2db5b2636b59c9828b5.png", isEIP1559: false),
            Chain(id: 185, name: "Mint", serverId: "mint", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.mintchain.io", scanUrl: "https://mintscan.org",
                  logo: "https://static.debank.com/image/chain/logo_url/mint/86404f93cd4e51eafcc2e244d417c03f.png"),
            Chain(id: 88888, name: "Chiliz", serverId: "chiliz", symbol: "CHZ", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.ankr.com/chiliz", scanUrl: "https://chiliscan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/chiliz/548bc261b49eabea7227832374e1fcb0.png"),
            Chain(id: 20240603, name: "DBK Chain", serverId: "dbk", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.mainnet.dbkchain.io", scanUrl: "https://scan.dbkchain.io",
                  logo: "https://static.debank.com/image/chain/logo_url/dbk/1255de5a9316fed901d14c069ac62f39.png"),
            Chain(id: 388, name: "Cronos zkEVM", serverId: "croze", symbol: "zkCRO", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.zkevm.cronos.org", scanUrl: "https://explorer.zkevm.cronos.org",
                  logo: "https://static.debank.com/image/chain/logo_url/croze/e9572bb5f00a04dd2e828dae75456abe.png"),
            Chain(id: 1625, name: "Gravity", serverId: "gravity", symbol: "G", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.gravity.xyz", scanUrl: "https://explorer.gravity.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/gravity/fa9a1d29f671b85a653f293893fa27e3.png"),
            Chain(id: 1135, name: "Lisk", serverId: "lisk", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.api.lisk.com", scanUrl: "https://blockscout.lisk.com",
                  logo: "https://static.debank.com/image/chain/logo_url/lisk/4d4970237c52104a22e93993de3dcdd8.png"),
            Chain(id: 291, name: "Orderly", serverId: "orderly", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.orderly.network", scanUrl: "https://explorer.orderly.network",
                  logo: "https://static.debank.com/image/chain/logo_url/orderly/aedf85948240dddcf334205794d2a6c9.png"),
            Chain(id: 33139, name: "ApeChain", serverId: "ape", symbol: "APE", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.apechain.com/http", scanUrl: "https://apescan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/ape/290d3884861ae5e09394c913f788168d.png"),
            Chain(id: 42793, name: "Etherlink", serverId: "ethlink", symbol: "XTZ", nativeTokenAddress: addr,
                  rpcUrl: "https://node.mainnet.etherlink.com", scanUrl: "https://explorer.etherlink.com",
                  logo: "https://static.debank.com/image/chain/logo_url/ethlink/76f6335793b594863f41df992dc53d22.png"),
            Chain(id: 48900, name: "Zircuit", serverId: "zircuit", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://zircuit1-mainnet.p2pify.com", scanUrl: "https://explorer.zircuit.com",
                  logo: "https://static.debank.com/image/chain/logo_url/zircuit/0571a12255432950da5112437058fa5b.png"),
            Chain(id: 480, name: "World Chain", serverId: "world", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://worldchain-mainnet.g.alchemy.com/public", scanUrl: "https://worldscan.org",
                  logo: "https://static.debank.com/image/chain/logo_url/world/3e8c6af046f442cf453ce79a12433e2f.png"),
            Chain(id: 2818, name: "Morph", serverId: "morph", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.morphl2.io", scanUrl: "https://explorer.morphl2.io",
                  logo: "https://static.debank.com/image/chain/logo_url/morph/2b5255a6c3a36d4b39e1dea02aa2f097.png"),
            Chain(id: 1923, name: "SwellChain", serverId: "swell", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://swell-mainnet.alt.technology", scanUrl: "https://explorer.swellnetwork.io",
                  logo: "https://static.debank.com/image/chain/logo_url/swell/3e98b1f206af5f2c0c2cc4d271ee1070.png"),
            Chain(id: 543210, name: "ZER\u{03F4}", serverId: "zero", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://zero-network.calderachain.xyz/http", scanUrl: "https://zero-network.calderaexplorer.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/zero/d9551d98b98482204b93544f90b43985.png"),
            Chain(id: 146, name: "Sonic", serverId: "sonic", symbol: "S", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.soniclabs.com", scanUrl: "https://sonicscan.org",
                  logo: "https://static.debank.com/image/chain/logo_url/sonic/8ba4d8395618ec1329ea7142b0fde642.png"),
            Chain(id: 21000000, name: "Corn", serverId: "corn", symbol: "BTCN", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.corn.fun", scanUrl: "https://cornscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/corn/2ac7405fee5fdeee5964ba0bcf2216f4.png"),
            Chain(id: 177, name: "HashKey", serverId: "hsk", symbol: "HSK", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.hsk.xyz", scanUrl: "https://explorer.hsk.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/hsk/3f35eb1691403fe4eae7a1d1c45b704c.png"),
            Chain(id: 57073, name: "Ink", serverId: "ink", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc-gel.inkonchain.com", scanUrl: "https://explorer.inkonchain.com",
                  logo: "https://static.debank.com/image/chain/logo_url/ink/af5b553a5675342e28bdb794328e8727.png"),
            Chain(id: 1480, name: "Vana", serverId: "vana", symbol: "VANA", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.vana.org", scanUrl: "https://vanascan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/vana/b2827795c1556eeeaeb58cb3411d0b15.png"),
            Chain(id: 50104, name: "Sophon", serverId: "sophon", symbol: "SOPH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.sophon.xyz", scanUrl: "https://sophscan.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/sophon/edc0479e5fc884b240959449ef44a386.png"),
            Chain(id: 5545, name: "DuckChain", serverId: "duck", symbol: "TON", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.duckchain.io", scanUrl: "https://scan.duckchain.io",
                  logo: "https://static.debank.com/image/chain/logo_url/duck/b0b13c10586f03bcfc12358c48a22c95.png"),
            Chain(id: 2741, name: "Abstract", serverId: "abs", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://api.mainnet.abs.xyz", scanUrl: "https://abscan.org",
                  logo: "https://static.debank.com/image/chain/logo_url/abs/c59200aadc06c79d7c061cfedca85c38.png"),
            Chain(id: 1868, name: "Soneium", serverId: "soneium", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.soneium.org", scanUrl: "https://soneium.blockscout.com",
                  logo: "https://static.debank.com/image/chain/logo_url/soneium/35014ebaa414b336a105ff2115ba2116.png"),
            Chain(id: 80094, name: "Berachain", serverId: "bera", symbol: "BERA", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.berachain.com", scanUrl: "https://berascan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/bera/89db55160bb8bbb19464cabf17e465bc.png"),
            Chain(id: 130, name: "Unichain", serverId: "uni", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.unichain.org", scanUrl: "https://uniscan.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/uni/7e9011cb7bd0d19deb7727280aa5c8b1.png"),
            Chain(id: 1514, name: "Story", serverId: "story", symbol: "IP", nativeTokenAddress: addr,
                  rpcUrl: "https://mainnet.storyrpc.io", scanUrl: "https://www.storyscan.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/story/d2311c0952f9801e0d42e3b87b4bd755.png"),
            Chain(id: 232, name: "Lens", serverId: "lens", symbol: "GHO", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.lens.xyz", scanUrl: "https://explorer.lens.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/lens/d41e14ba300d526518fb8ad20714685b.png"),
            Chain(id: 999, name: "HyperEVM", serverId: "hyper", symbol: "HYPE", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.hyperliquid.xyz/evm", scanUrl: "https://hyperevmscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/hyper/0b3e288cfe418e9ce69eef4c96374583.png"),
            Chain(id: 43111, name: "Hemi", serverId: "hemi", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.hemi.network", scanUrl: "https://explorer.hemi.xyz",
                  logo: "https://static.debank.com/image/chain/logo_url/hemi/db2e74d52c77b941d01f9beae0767ab6.png"),
            Chain(id: 98866, name: "Plume", serverId: "plume", symbol: "PLUME", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.plume.org", scanUrl: "https://explorer.plume.org",
                  logo: "https://static.debank.com/image/chain/logo_url/plume/f74d0d202dd8af7baf6940864ee79006.png"),
            Chain(id: 747474, name: "Katana", serverId: "katana", symbol: "ETH", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.katana.farm", scanUrl: "https://katanascan.com",
                  logo: "https://static.debank.com/image/chain/logo_url/katana/0202d6aecd963a9c0b2afb56c4d731b5.png"),
            Chain(id: 1440000, name: "XRPL EVM", serverId: "xrpl", symbol: "XRP", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc-evm-sidechain.xrpl.org", scanUrl: "https://explorer.xrplevm.org",
                  logo: "https://static.debank.com/image/chain/logo_url/xrpl/131298e77672be4a16611a103fa39366.png"),
            Chain(id: 2345, name: "GOAT", serverId: "goat", symbol: "BTC", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.goat.network", scanUrl: "https://explorer.goat.network",
                  logo: "https://static.debank.com/image/chain/logo_url/goat/b324eea675692ec1c99a83e415386ed0.png"),
            Chain(id: 9745, name: "Plasma", serverId: "plasma", symbol: "XPL", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.plasma.build", scanUrl: "https://plasmascan.to",
                  logo: "https://static.debank.com/image/chain/logo_url/plasma/baafefce3b9d43b12b0c016f30aff140.png"),
            Chain(id: 239, name: "TAC", serverId: "tac", symbol: "TAC", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.tac.build", scanUrl: "https://explorer.tac.build",
                  logo: "https://static.debank.com/image/chain/logo_url/tac/4b57fdb89de90a15f366cdf4bdc92665.png"),
            Chain(id: 124816, name: "Mitosis", serverId: "mito", symbol: "MITO", nativeTokenAddress: addr,
                  rpcUrl: "https://rpc.mitosis.org", scanUrl: "https://mitoscan.io",
                  logo: "https://static.debank.com/image/chain/logo_url/mito/d18958f17a84f20257ed89eff5ce6ff7.png"),
        ]
    }
    // swiftlint:enable function_body_length
}

// MARK: - Convenience Chain Statics
extension Chain {
    static let ethereum = Chain(id: 1, name: "Ethereum", serverId: "eth", symbol: "ETH",
                                 nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                                 rpcUrl: "https://eth.llamarpc.com", scanUrl: "https://etherscan.io",
                                 logo: "https://static.debank.com/image/chain/logo_url/eth/42ba589cd077e7bdd97db6480b0ff61d.png")
}

// MARK: - RPC Models

struct RPCRequest: Encodable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: [Any]
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        
        // Encode params as JSON array
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJSON = try JSONDecoder().decode([AnyCodable].self, from: paramsData)
        try container.encode(paramsJSON, forKey: .params)
    }
}

// Helper struct for encoding Any types
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

struct RPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int
    let result: T?
    let error: RPCError?
}

struct RPCError: Decodable {
    let code: Int
    let message: String
}

// MARK: - Transaction Receipt

struct TransactionReceipt: Codable {
    let transactionHash: String
    let blockNumber: String
    let blockHash: String
    let from: String
    let to: String?
    let gasUsed: String
    let cumulativeGasUsed: String
    let status: String
    let logs: [Log]
    
    var isSuccess: Bool {
        return status == "0x1"
    }
}

struct Log: Codable {
    let address: String
    let topics: [String]
    let data: String
    let blockNumber: String
    let transactionHash: String
    let logIndex: String
}

struct Block: Codable {
    let number: String
    let hash: String
    let parentHash: String
    let timestamp: String
    let transactions: [String]
    let gasLimit: String
    let gasUsed: String
    let baseFeePerGas: String?
}

// MARK: - Errors

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case rpcError(Int, String)
    case emptyResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RPC URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .rpcError(let code, let message):
            return "RPC error \(code): \(message)"
        case .emptyResponse:
            return "Empty response from server"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - String Extension

extension String {
    func padLeft(toLength length: Int, withPad pad: String) -> String {
        let paddingCount = max(0, length - self.count)
        return String(repeating: pad, count: paddingCount) + self
    }
}
