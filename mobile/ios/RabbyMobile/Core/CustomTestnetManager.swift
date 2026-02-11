import Foundation
import Combine

/// Custom Testnet Manager - Manage custom testnet chains
/// Equivalent to Web version's customTestnet service
@MainActor
class CustomTestnetManager: ObservableObject {
    static let shared = CustomTestnetManager()
    
    @Published var testnets: [TestnetChain] = []
    @Published var customTokens: [CustomToken] = []
    
    private let storage = StorageManager.shared
    private let testnetKey = "rabby_custom_testnets"
    private let tokenKey = "rabby_custom_testnet_tokens"
    
    // MARK: - Models
    
    struct TestnetChain: Codable, Identifiable {
        let id: Int // Chain ID
        var name: String
        var nativeTokenSymbol: String
        var nativeTokenDecimals: Int
        var rpcUrl: String
        var scanLink: String?
        var logo: String?
        var isCustom: Bool // true if user-added
        
        var serverId: String {
            return "CUSTOM_\(id)"
        }
        
        var hex: String {
            return "0x" + String(id, radix: 16)
        }
    }
    
    struct CustomToken: Codable, Identifiable {
        let id: String
        let chainId: Int
        let address: String
        let symbol: String
        let decimals: Int
        let logo: String?
        var amount: String?
    }
    
    // MARK: - Initialization
    
    private init() {
        loadTestnets()
        loadCustomTokens()
    }
    
    // MARK: - Public Methods
    
    /// Add custom testnet
    func addTestnet(
        chainId: Int,
        name: String,
        nativeTokenSymbol: String,
        nativeTokenDecimals: Int = 18,
        rpcUrl: String,
        scanLink: String? = nil,
        logo: String? = nil
    ) async throws {
        // Validate chain ID doesn't conflict with existing chains
        if testnets.contains(where: { $0.id == chainId }) {
            throw TestnetError.chainAlreadyExists
        }
        
        // Validate RPC URL
        let isValid = try await validateRPC(url: rpcUrl, expectedChainId: chainId)
        if !isValid {
            throw TestnetError.rpcChainIdMismatch
        }
        
        // Create testnet
        let testnet = TestnetChain(
            id: chainId,
            name: name,
            nativeTokenSymbol: nativeTokenSymbol,
            nativeTokenDecimals: nativeTokenDecimals,
            rpcUrl: rpcUrl,
            scanLink: scanLink,
            logo: logo,
            isCustom: true
        )
        
        testnets.append(testnet)
        saveTestnets()
        
        // Update chain store
        await updateChainStore()
    }
    
    /// Update existing testnet
    func updateTestnet(
        chainId: Int,
        name: String? = nil,
        rpcUrl: String? = nil,
        scanLink: String? = nil
    ) async throws {
        guard let index = testnets.firstIndex(where: { $0.id == chainId }) else {
            throw TestnetError.chainNotFound
        }
        
        var testnet = testnets[index]
        
        if let name = name {
            testnet.name = name
        }
        
        if let rpcUrl = rpcUrl {
            // Validate new RPC
            let isValid = try await validateRPC(url: rpcUrl, expectedChainId: chainId)
            if !isValid {
                throw TestnetError.rpcChainIdMismatch
            }
            testnet.rpcUrl = rpcUrl
        }
        
        if let scanLink = scanLink {
            testnet.scanLink = scanLink
        }
        
        testnets[index] = testnet
        saveTestnets()
        
        await updateChainStore()
    }
    
    /// Remove custom testnet
    func removeTestnet(chainId: Int) {
        testnets.removeAll { $0.id == chainId }
        saveTestnets()
        
        // Also remove associated custom tokens
        customTokens.removeAll { $0.chainId == chainId }
        saveCustomTokens()
        
        Task {
            await updateChainStore()
        }
    }
    
    /// Get testnet by chain ID
    func getTestnet(chainId: Int) -> TestnetChain? {
        return testnets.first { $0.id == chainId }
    }
    
    /// Add custom token to testnet
    func addCustomToken(
        chainId: Int,
        address: String,
        symbol: String,
        decimals: Int,
        logo: String? = nil
    ) throws {
        // Validate testnet exists
        guard testnets.contains(where: { $0.id == chainId }) else {
            throw TestnetError.chainNotFound
        }
        
        // Validate address
        guard EthereumUtil.isValidAddress(address) else {
            throw TestnetError.invalidAddress
        }
        
        let token = CustomToken(
            id: "\(chainId)_\(address.lowercased())",
            chainId: chainId,
            address: address,
            symbol: symbol,
            decimals: decimals,
            logo: logo
        )
        
        customTokens.append(token)
        saveCustomTokens()
    }
    
    /// Remove custom token
    func removeCustomToken(id: String) {
        customTokens.removeAll { $0.id == id }
        saveCustomTokens()
    }
    
    /// Get custom tokens for chain
    func getCustomTokens(chainId: Int) -> [CustomToken] {
        return customTokens.filter { $0.chainId == chainId }
    }
    
    /// Load tokens balance for testnet
    func loadTokensBalance(chainId: Int, address: String) async throws {
        let tokens = getCustomTokens(chainId: chainId)
        
        guard let testnet = getTestnet(chainId: chainId) else {
            throw TestnetError.chainNotFound
        }
        
        // Load balance for each token
        for token in tokens {
            do {
                let balance = try await getTokenBalance(
                    tokenAddress: token.address,
                    ownerAddress: address,
                    rpcUrl: testnet.rpcUrl,
                    decimals: token.decimals
                )
                
                if let index = customTokens.firstIndex(where: { $0.id == token.id }) {
                    customTokens[index].amount = balance
                }
            } catch {
                print("⚠️ Failed to load balance for token \(token.symbol): \(error)")
            }
        }
        
        saveCustomTokens()
    }
    
    // MARK: - Private Methods
    
    private func validateRPC(url: String, expectedChainId: Int) async throws -> Bool {
        // Make eth_chainId request
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_chainId",
            "params": [],
            "id": 1
        ]
        
        do {
            let response: CustomTestnetRPCResponse = try await NetworkManager.shared.post(url: url, body: params)
            
            guard let result = response.result else {
                return false
            }
            
            // Convert hex to decimal
            let chainId = Int(String(result.dropFirst(2)), radix: 16) ?? 0
            return chainId == expectedChainId
        } catch {
            throw TestnetError.rpcValidationFailed
        }
    }
    
    private func getTokenBalance(
        tokenAddress: String,
        ownerAddress: String,
        rpcUrl: String,
        decimals: Int
    ) async throws -> String {
        // ERC20 balanceOf function
        let functionSignature = "balanceOf(address)"
        let selector = Keccak256.hash(string: functionSignature).prefix(4)
        
        var data = Data(selector)
        
        // Owner address (padded to 32 bytes)
        if let ownerData = Data(hexString: String(ownerAddress.dropFirst(2))) {
            data.append(Data(repeating: 0, count: 12))
            data.append(ownerData)
        }
        
        // Make eth_call request
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                [
                    "to": tokenAddress,
                    "data": "0x" + data.toHexString()
                ],
                "latest"
            ],
            "id": 1
        ]
        
        let response: CustomTestnetRPCResponse = try await NetworkManager.shared.post(url: rpcUrl, body: params)
        
        guard let result = response.result else {
            return "0"
        }
        
        // Convert hex balance to decimal string
        let resultString = String(result.dropFirst(2))
        if let balance = BigInt(resultString, radix: 16) {
            let divisor = BigInt(10).power(decimals)
            let amount = balance / divisor
            return String(describing: amount)
        }
        
        return "0"
    }
    
    private func loadTestnets() {
        if let data = storage.getData(forKey: testnetKey),
           let testnets = try? JSONDecoder().decode([TestnetChain].self, from: data) {
            self.testnets = testnets
        }
    }
    
    private func saveTestnets() {
        if let data = try? JSONEncoder().encode(testnets) {
            storage.setData(data, forKey: testnetKey)
        }
    }
    
    private func loadCustomTokens() {
        if let data = storage.getData(forKey: tokenKey),
           let tokens = try? JSONDecoder().decode([CustomToken].self, from: data) {
            self.customTokens = tokens
        }
    }
    
    private func saveCustomTokens() {
        if let data = try? JSONEncoder().encode(customTokens) {
            storage.setData(data, forKey: tokenKey)
        }
    }
    
    private func updateChainStore() async {
        // In a real app, this would update a global chain store
        // For now, just notify observers
        objectWillChange.send()
    }
}

// MARK: - Custom Testnet RPC Response

private struct CustomTestnetRPCResponse: Codable {
    let result: String?
    
    enum CodingKeys: String, CodingKey {
        case result
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try? container.decode(String.self, forKey: .result)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(result, forKey: .result)
    }
}

// MARK: - BigInt Helper

private struct BigInt {
    let value: String
    
    init?(_ string: String, radix: Int) {
        // Simplified BigInt - in real app use a proper BigInt library
        self.value = string
    }
    
    init(_ value: Int) {
        self.value = String(value)
    }
    
    static func /(lhs: BigInt, rhs: BigInt) -> BigInt {
        // Simplified division
        return BigInt(0)
    }
    
    func power(_ exponent: Int) -> BigInt {
        return BigInt(0)
    }
}

// MARK: - Errors

enum TestnetError: Error, LocalizedError {
    case chainAlreadyExists
    case chainNotFound
    case rpcChainIdMismatch
    case rpcValidationFailed
    case invalidAddress
    
    var errorDescription: String? {
        switch self {
        case .chainAlreadyExists:
            return "Chain already exists"
        case .chainNotFound:
            return "Chain not found"
        case .rpcChainIdMismatch:
            return "RPC chain ID does not match"
        case .rpcValidationFailed:
            return "RPC validation failed"
        case .invalidAddress:
            return "Invalid Ethereum address"
        }
    }
}
