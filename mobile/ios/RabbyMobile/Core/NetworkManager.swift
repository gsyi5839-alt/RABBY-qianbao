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
        responseType: T.Type
    ) async throws -> T {
        let request = try createRPCRequest(method: method, params: params, rpcURL: rpcURL)
        
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
    
    private func createRPCRequest(method: String, params: [Any], rpcURL: URL) throws -> URLRequest {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rpcRequest = RPCRequest(
            jsonrpc: "2.0",
            id: Int.random(in: 1...999999),
            method: method,
            params: params
        )
        
        request.httpBody = try JSONEncoder().encode(rpcRequest)
        return request
    }
    
    // MARK: - Ethereum RPC Methods
    
    func getBalance(address: String, chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_getBalance",
            params: [address, "latest"],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func getTransactionCount(address: String, chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_getTransactionCount",
            params: [address, "latest"],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func estimateGas(transaction: [String: Any], chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_estimateGas",
            params: [transaction],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func getGasPrice(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_gasPrice",
            params: [],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func sendRawTransaction(signedTransaction: String, chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_sendRawTransaction",
            params: [signedTransaction],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func getTransactionReceipt(hash: String, chain: Chain) async throws -> TransactionReceipt? {
        return try await sendRPCRequest(
            method: "eth_getTransactionReceipt",
            params: [hash],
            rpcURL: chain.rpcURL,
            responseType: TransactionReceipt?.self
        )
    }
    
    func call(transaction: [String: Any], chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_call",
            params: [transaction, "latest"],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func getChainId(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_chainId",
            params: [],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func getBlockNumber(chain: Chain) async throws -> String {
        return try await sendRPCRequest(
            method: "eth_blockNumber",
            params: [],
            rpcURL: chain.rpcURL,
            responseType: String.self
        )
    }
    
    func getBlockByNumber(blockNumber: String, fullTransactions: Bool, chain: Chain) async throws -> Block {
        return try await sendRPCRequest(
            method: "eth_getBlockByNumber",
            params: [blockNumber, fullTransactions],
            rpcURL: chain.rpcURL,
            responseType: Block.self
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
    let rpcUrl: String
    let scanUrl: String
    let logo: String
    let decimals: Int
    let isEIP1559: Bool
    var isTestnet: Bool
    var isCustom: Bool
    
    // Backward compatibility aliases
    var nativeTokenSymbol: String { symbol }
    var rpcURLString: String { rpcUrl }
    var rpcURL: URL { URL(string: rpcUrl)! }
    var explorerURL: String { scanUrl }
    
    init(id: Int, name: String, serverId: String, symbol: String, nativeTokenAddress: String,
         rpcUrl: String, scanUrl: String, logo: String = "", decimals: Int = 18,
         isEIP1559: Bool = true, isTestnet: Bool = false, isCustom: Bool = false) {
        self.id = id; self.name = name; self.serverId = serverId; self.symbol = symbol
        self.nativeTokenAddress = nativeTokenAddress; self.rpcUrl = rpcUrl; self.scanUrl = scanUrl
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
    
    private init() {
        loadDefaultChains()
        
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
        getChain(serverId: chain)?.rpcUrl ?? "https://eth.llamarpc.com"
    }
    
    func getAllChains() -> [Chain] { allChains }
    
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
    
    private func loadDefaultChains() {
        mainnetChains = [
            Chain(id: 1, name: "Ethereum", serverId: "eth", symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://eth.llamarpc.com", scanUrl: "https://etherscan.io",
                  logo: "eth_logo", isEIP1559: true),
            Chain(id: 56, name: "BNB Chain", serverId: "bsc", symbol: "BNB",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://bsc-dataseed1.binance.org", scanUrl: "https://bscscan.com",
                  logo: "bsc_logo", isEIP1559: false),
            Chain(id: 137, name: "Polygon", serverId: "matic", symbol: "MATIC",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://polygon-rpc.com", scanUrl: "https://polygonscan.com",
                  logo: "polygon_logo"),
            Chain(id: 42161, name: "Arbitrum One", serverId: "arb", symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://arb1.arbitrum.io/rpc", scanUrl: "https://arbiscan.io",
                  logo: "arb_logo"),
            Chain(id: 10, name: "Optimism", serverId: "op", symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://mainnet.optimism.io", scanUrl: "https://optimistic.etherscan.io",
                  logo: "op_logo"),
            Chain(id: 43114, name: "Avalanche", serverId: "avax", symbol: "AVAX",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://api.avax.network/ext/bc/C/rpc", scanUrl: "https://snowtrace.io",
                  logo: "avax_logo"),
            Chain(id: 250, name: "Fantom", serverId: "ftm", symbol: "FTM",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://rpc.ftm.tools", scanUrl: "https://ftmscan.com",
                  logo: "ftm_logo", isEIP1559: false),
            Chain(id: 8453, name: "Base", serverId: "base", symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://mainnet.base.org", scanUrl: "https://basescan.org",
                  logo: "base_logo"),
            Chain(id: 324, name: "zkSync Era", serverId: "zksync", symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://mainnet.era.zksync.io", scanUrl: "https://explorer.zksync.io",
                  logo: "zksync_logo", isEIP1559: false),
            Chain(id: 59144, name: "Linea", serverId: "linea", symbol: "ETH",
                  nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                  rpcUrl: "https://rpc.linea.build", scanUrl: "https://lineascan.build",
                  logo: "linea_logo"),
        ]
    }
}

// MARK: - Convenience Chain Statics
extension Chain {
    static let ethereum = Chain(id: 1, name: "Ethereum", serverId: "eth", symbol: "ETH",
                                 nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                                 rpcUrl: "https://eth.llamarpc.com", scanUrl: "https://etherscan.io")
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
