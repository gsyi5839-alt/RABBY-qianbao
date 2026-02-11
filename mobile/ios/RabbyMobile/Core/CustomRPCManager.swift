import Foundation
import Combine

/// Custom RPC Manager - Manage custom RPC endpoints for chains
/// Equivalent to Web version's RPC service
@MainActor
class CustomRPCManager: ObservableObject {
    static let shared = CustomRPCManager()
    
    @Published var customRPCs: [String: RPCConfig] = [:]
    
    private let storage = StorageManager.shared
    private let rpcKey = "rabby_custom_rpc"
    
    // MARK: - Models
    
    struct RPCConfig: Codable {
        let url: String
        var enable: Bool
        var latency: Int? // in milliseconds
        var lastChecked: Date?
    }
    
    // MARK: - Initialization
    
    private init() {
        loadRPCs()
    }
    
    // MARK: - Public Methods
    
    /// Set custom RPC for chain
    func setRPC(chain: String, url: String) {
        customRPCs[chain] = RPCConfig(
            url: url,
            enable: true,
            latency: nil,
            lastChecked: nil
        )
        saveRPCs()
    }
    
    /// Remove custom RPC
    func removeRPC(chain: String) {
        customRPCs.removeValue(forKey: chain)
        saveRPCs()
    }
    
    /// Enable/Disable RPC
    func setRPCEnable(chain: String, enable: Bool) {
        if var config = customRPCs[chain] {
            config.enable = enable
            customRPCs[chain] = config
            saveRPCs()
        }
    }
    
    /// Get RPC for chain
    func getRPC(chain: String) -> RPCConfig? {
        return customRPCs[chain]
    }
    
    /// Check if chain has custom RPC enabled
    func hasCustomRPC(chain: String) -> Bool {
        return customRPCs[chain]?.enable == true
    }
    
    /// Ping RPC to check latency
    func pingRPC(url: String) async throws -> Int {
        let startTime = Date()
        
        // Make a simple eth_blockNumber request
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 1
        ]
        
        do {
            let _: CustomRPCResponse = try await NetworkManager.shared.post(url: url, body: params)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return latency
        } catch {
            throw CustomRPCError.connectionFailed
        }
    }
    
    /// Validate RPC URL and chain ID
    func validateRPC(url: String, expectedChainId: String) async throws -> Bool {
        // Request eth_chainId
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_chainId",
            "params": [],
            "id": 1
        ]
        
        do {
            let response: CustomRPCResponse = try await NetworkManager.shared.post(url: url, body: params)
            
            guard let result = response.result else {
                throw CustomRPCError.invalidResponse
            }
            
            // Convert hex to decimal
            let chainId = String(Int(result.dropFirst(2), radix: 16) ?? 0)
            
            return chainId == expectedChainId
        } catch {
            throw CustomRPCError.validationFailed
        }
    }
    
    /// Test RPC and update latency
    func testRPC(chain: String) async {
        guard var config = customRPCs[chain] else { return }
        
        do {
            let latency = try await pingRPC(url: config.url)
            config.latency = latency
            config.lastChecked = Date()
            customRPCs[chain] = config
            saveRPCs()
        } catch {
            print("❌ Failed to ping RPC for chain \(chain): \(error)")
            config.latency = nil
            config.lastChecked = Date()
            customRPCs[chain] = config
            saveRPCs()
        }
    }
    
    /// Get all custom RPCs
    func getAllRPCs() -> [String: RPCConfig] {
        return customRPCs
    }
    
    // MARK: - Private Methods
    
    private func loadRPCs() {
        if let data = storage.getData(forKey: rpcKey),
           let rpcs = try? JSONDecoder().decode([String: RPCConfig].self, from: data) {
            self.customRPCs = rpcs
        }
    }
    
    private func saveRPCs() {
        if let data = try? JSONEncoder().encode(customRPCs) {
            storage.setData(data, forKey: rpcKey)
        }
    }
}

// MARK: - Custom RPC Response Model

private struct CustomRPCResponse: Codable {
    let jsonrpc: String
    let id: Int
    let result: String?
    let error: CustomRPCErrorResponse?
    
    struct CustomRPCErrorResponse: Codable {
        let code: Int
        let message: String
    }
}

// MARK: - Errors

enum CustomRPCError: Error, LocalizedError {
    case connectionFailed
    case invalidResponse
    case validationFailed
    case chainIdMismatch
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to RPC"
        case .invalidResponse:
            return "Invalid RPC response"
        case .validationFailed:
            return "RPC validation failed"
        case .chainIdMismatch:
            return "Chain ID does not match"
        case .timeout:
            return "RPC request timeout"
        }
    }
}
