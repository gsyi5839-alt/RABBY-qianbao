import Foundation
import Combine
import BigInt

/// WalletConnect Manager - Support WalletConnect v2 protocol for DApp connections
/// Equivalent to Web version's WalletConnect integration
@MainActor
class WalletConnectManager: ObservableObject {
    static let shared = WalletConnectManager()
    
    @Published var sessions: [WCSession] = []
    @Published var pendingProposals: [WCProposal] = []
    @Published var pendingRequests: [WCRequest] = []
    
    private let storage = StorageManager.shared
    private let keyringManager = KeyringManager.shared
    
    private let sessionsKey = "rabby_wc_sessions"
    private let maxDuration: TimeInterval = 3600 // 1 hour
    
    // WalletConnect v2 configuration
    struct WCConfig {
        static let projectId = "ed21a1293590bdc995404dff7e033f04" // Rabby project ID
        static let name = "Rabby Wallet"
        static let description = "The game-changing wallet for Ethereum and all EVM chains"
        static let url = "https://rabby.io"
        static let icons = ["https://static-assets.rabby.io/files/122da969-da58-42e9-ab39-0a8dd38d94b8.png"]
    }
    
    // MARK: - Models
    
    struct WCSession: Codable, Identifiable {
        let id: String
        let topic: String
        let peerName: String
        let peerUrl: String
        let peerIcon: String?
        let accounts: [String]
        let chains: [String]
        let createdAt: Date
        var lastUsedAt: Date
    }
    
    struct WCProposal: Identifiable {
        let id: String
        let proposer: Proposer
        let requiredNamespaces: [String: Namespace]
        let optionalNamespaces: [String: Namespace]?
        
        struct Proposer {
            let name: String
            let description: String
            let url: String
            let icons: [String]
        }
        
        struct Namespace {
            let chains: [String]
            let methods: [String]
            let events: [String]
        }
    }
    
    struct WCRequest: Identifiable {
        let id: String
        let topic: String
        let method: String
        let params: Any
        let chainId: String
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSessions()
    }
    
    // MARK: - Session Management
    
    /// Connect to DApp via WalletConnect URI
    func connect(uri: String) async throws {
        // Parse WalletConnect URI
        guard uri.hasPrefix("wc:") else {
            throw WCError.invalidURI
        }
        
        // In a real implementation, this would use WalletConnectSwift SDK
        // For now, we'll create a mock implementation
        
        print("📱 Connecting to WalletConnect: \(uri)")
        
        // This is a placeholder - real implementation needs WalletConnectSwift SDK
        throw WCError.notImplemented
    }
    
    /// Pair with DApp via WalletConnect URI (alias for connect)
    func pair(uri: String) async throws {
        try await connect(uri: uri)
    }
    
    /// Approve session proposal
    func approveSession(_ proposalId: String, accounts: [String], chains: [String]) async throws {
        guard let proposal = pendingProposals.first(where: { $0.id == proposalId }) else {
            throw WCError.proposalNotFound
        }
        
        // Create new session
        let session = WCSession(
            id: UUID().uuidString,
            topic: proposalId,
            peerName: proposal.proposer.name,
            peerUrl: proposal.proposer.url,
            peerIcon: proposal.proposer.icons.first,
            accounts: accounts,
            chains: chains,
            createdAt: Date(),
            lastUsedAt: Date()
        )
        
        sessions.append(session)
        pendingProposals.removeAll { $0.id == proposalId }
        
        saveSessions()
    }
    
    /// Reject session proposal
    func rejectSession(_ proposalId: String) {
        pendingProposals.removeAll { $0.id == proposalId }
    }
    
    /// Disconnect session
    func disconnectSession(_ sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        saveSessions()
    }
    
    /// Get active sessions for an address
    func getSessions(for address: String) -> [WCSession] {
        return sessions.filter { session in
            session.accounts.contains { $0.lowercased() == address.lowercased() }
        }
    }
    
    // MARK: - Request Handling
    
    /// Approve pending request
    func approveRequest(_ requestId: String, result: Any) async throws {
        guard let request = pendingRequests.first(where: { $0.id == requestId }) else {
            throw WCError.requestNotFound
        }
        
        // Send response to DApp
        // Real implementation would use WalletConnect SDK
        
        pendingRequests.removeAll { $0.id == requestId }
    }
    
    /// Reject pending request
    func rejectRequest(_ requestId: String, error: String) {
        pendingRequests.removeAll { $0.id == requestId }
    }
    
    /// Handle eth_sendTransaction request
    func handleSendTransaction(_ request: WCRequest) async throws -> String {
        guard let params = request.params as? [[String: Any]],
              let txParams = params.first else {
            throw WCError.invalidParams
        }
        
        // Extract transaction parameters
        guard let from = txParams["from"] as? String,
              let to = txParams["to"] as? String else {
            throw WCError.invalidParams
        }
        
        let value = txParams["value"] as? String ?? "0x0"
        let data = txParams["data"] as? String ?? "0x"
        let gas = txParams["gas"] as? String
        let gasPrice = txParams["gasPrice"] as? String
        
        // Create transaction
        let chainIdInt = Int(request.chainId) ?? 1
        let transaction = EthereumTransaction(
            to: to,
            from: from,
            nonce: BigUInt(0), // Will be filled by TransactionManager
            value: BigUInt(value.dropFirst(2), radix: 16) ?? BigUInt(0),
            data: Data(hex: data),
            gasLimit: BigUInt(gas?.dropFirst(2) ?? "5208", radix: 16) ?? BigUInt(21000),
            chainId: chainIdInt,
            maxFeePerGas: txParams["maxFeePerGas"].flatMap { ($0 as? String).flatMap { BigUInt($0.dropFirst(2), radix: 16) } },
            maxPriorityFeePerGas: txParams["maxPriorityFeePerGas"].flatMap { ($0 as? String).flatMap { BigUInt($0.dropFirst(2), radix: 16) } },
            gasPrice: gasPrice.flatMap { BigUInt($0.dropFirst(2), radix: 16) }
        )
        
        // Sign and send
        let signedTx = try await keyringManager.signTransaction(address: from, transaction: transaction)
        let txHash = try await TransactionManager.shared.broadcastTransaction(signedTx)
        
        return txHash
    }
    
    /// Handle personal_sign request
    func handlePersonalSign(_ request: WCRequest) async throws -> String {
        guard let params = request.params as? [String],
              params.count >= 2 else {
            throw WCError.invalidParams
        }
        
        let message = params[0]
        let address = params[1]
        
        guard let messageData = Data(hexString: message) else {
            throw WCError.invalidParams
        }
        
        let signature = try await keyringManager.signMessage(address: address, message: messageData)
        return "0x" + signature.toHexString()
    }
    
    /// Handle eth_signTypedData request
    func handleSignTypedData(_ request: WCRequest) async throws -> String {
        guard let params = request.params as? [Any],
              params.count >= 2 else {
            throw WCError.invalidParams
        }
        
        let address = params[0] as? String ?? ""
        guard let typedData = params[1] as? [String: Any] else {
            throw WCError.invalidParams
        }
        
        let typedDataString: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: typedData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            typedDataString = jsonString
        } else {
            throw WCError.invalidParams
        }
        
        let signature = try await keyringManager.signTypedData(address: address, typedData: typedDataString)
        return "0x" + signature.toHexString()
    }
    
    // MARK: - Private Methods
    
    private func loadSessions() {
        if let data = storage.getData(forKey: sessionsKey),
           let sessions = try? JSONDecoder().decode([WCSession].self, from: data) {
            self.sessions = sessions
        }
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            storage.setData(data, forKey: sessionsKey)
        }
    }
}

// MARK: - Errors

enum WCError: Error, LocalizedError {
    case invalidURI
    case proposalNotFound
    case requestNotFound
    case invalidParams
    case notImplemented
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURI:
            return "Invalid WalletConnect URI"
        case .proposalNotFound:
            return "Session proposal not found"
        case .requestNotFound:
            return "Request not found"
        case .invalidParams:
            return "Invalid request parameters"
        case .notImplemented:
            return "WalletConnect SDK integration required. Please install WalletConnectSwiftV2 via CocoaPods."
        case .connectionFailed:
            return "Failed to connect to DApp"
        }
    }
}
