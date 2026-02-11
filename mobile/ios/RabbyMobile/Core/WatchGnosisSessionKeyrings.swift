import Foundation

/// Watch Address Keyring - View-only wallet addresses
/// Corresponds to: Web's WatchKeyring (eth-watch-keyring)
/// Allows users to monitor addresses without private key access
class WatchAddressKeyring: Keyring {
    let type: KeyringType = .watchAddress
    private(set) var accounts: [String] = []
    
    init() {}
    
    func serialize() throws -> Data {
        return try JSONEncoder().encode(accounts)
    }
    
    func deserialize(from data: Data) throws {
        accounts = try JSONDecoder().decode([String].self, from: data)
    }
    
    func addAccounts(count: Int) async throws -> [String] {
        throw WatchKeyringError.cannotGenerateAccounts
    }
    
    /// Add a specific watch address
    func addWatchAddress(_ address: String) throws -> String {
        let normalized = address.lowercased()
        guard EthereumUtil.isValidAddress(normalized) else {
            throw WatchKeyringError.invalidAddress
        }
        guard !accounts.contains(normalized) else {
            throw WatchKeyringError.addressAlreadyExists
        }
        accounts.append(normalized)
        return normalized
    }
    
    func getAccounts() async -> [String] {
        return accounts
    }
    
    func removeAccount(address: String) throws {
        accounts.removeAll { $0.lowercased() == address.lowercased() }
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        throw WatchKeyringError.cannotSign
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        throw WatchKeyringError.cannotSign
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        throw WatchKeyringError.cannotSign
    }
    
    /// Check if address is watch-only
    func isWatchOnly(_ address: String) -> Bool {
        return accounts.contains(address.lowercased())
    }
}

enum WatchKeyringError: LocalizedError {
    case cannotGenerateAccounts
    case cannotSign
    case invalidAddress
    case addressAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .cannotGenerateAccounts: return "Watch-only keyring cannot generate accounts"
        case .cannotSign: return "Watch-only addresses cannot sign transactions"
        case .invalidAddress: return "Invalid Ethereum address"
        case .addressAlreadyExists: return "Address is already being watched"
        }
    }
}

// MARK: - Gnosis Safe Keyring
/// Corresponds to: src/background/service/keyring/eth-gnosis-keyring.ts (729 lines)
/// Manages Gnosis Safe multi-signature wallet interactions

class GnosisKeyring: Keyring {
    let type: KeyringType = .gnosis
    private(set) var accounts: [String] = []
    private var safes: [String: GnosisSafeInfo] = [:]
    
    struct GnosisSafeInfo: Codable {
        let address: String
        let chainId: Int
        let threshold: Int
        let owners: [String]
        let version: String
        let nonce: Int
        var networkPrefix: String
    }
    
    struct SafeTransaction: Codable {
        let to: String
        let value: String
        let data: String
        let operation: Int // 0 = call, 1 = delegatecall
        let safeTxGas: String
        let baseGas: String
        let gasPrice: String
        let gasToken: String
        let refundReceiver: String
        let nonce: Int
    }
    
    struct SafeSignature: Codable {
        let signer: String
        let data: String
        let timestamp: Date
    }
    
    init() {}
    
    func serialize() throws -> Data {
        return try JSONEncoder().encode(safes)
    }
    
    func deserialize(from data: Data) throws {
        safes = try JSONDecoder().decode([String: GnosisSafeInfo].self, from: data)
        accounts = Array(safes.keys)
    }
    
    func addAccounts(count: Int) async throws -> [String] {
        throw GnosisKeyringError.useAddSafe
    }
    
    /// Add a Gnosis Safe address
    func addSafe(address: String, chainId: Int, owners: [String], threshold: Int, version: String = "1.3.0") throws {
        let normalized = address.lowercased()
        guard EthereumUtil.isValidAddress(normalized) else {
            throw GnosisKeyringError.invalidAddress
        }
        
        let info = GnosisSafeInfo(
            address: normalized, chainId: chainId, threshold: threshold,
            owners: owners.map { $0.lowercased() }, version: version,
            nonce: 0, networkPrefix: "eth"
        )
        safes[normalized] = info
        if !accounts.contains(normalized) { accounts.append(normalized) }
    }
    
    func getAccounts() async -> [String] { accounts }
    
    func removeAccount(address: String) throws {
        let normalized = address.lowercased()
        accounts.removeAll { $0 == normalized }
        safes.removeValue(forKey: normalized)
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        // Gnosis Safe uses off-chain signatures collected from owners
        // Then submits to Safe Transaction Service API
        throw GnosisKeyringError.useMultisigFlow
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        throw GnosisKeyringError.useMultisigFlow
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        throw GnosisKeyringError.useMultisigFlow
    }
    
    /// Get Safe info
    func getSafeInfo(address: String) -> GnosisSafeInfo? {
        return safes[address.lowercased()]
    }
    
    /// Get Safe owners
    func getOwners(address: String) -> [String] {
        return safes[address.lowercased()]?.owners ?? []
    }
    
    /// Check if current user is an owner
    func isOwner(safeAddress: String, ownerAddress: String) -> Bool {
        return safes[safeAddress.lowercased()]?.owners.contains(ownerAddress.lowercased()) ?? false
    }
    
    /// Get confirmation threshold
    func getThreshold(address: String) -> Int {
        return safes[address.lowercased()]?.threshold ?? 0
    }
    
    /// Build Safe transaction hash for signing
    func buildSafeTransactionHash(safeAddress: String, tx: SafeTransaction) async throws -> Data {
        guard let safe = safes[safeAddress.lowercased()] else {
            throw GnosisKeyringError.safeNotFound
        }
        
        // EIP-712 typed data hash for Safe transaction
        let domainSeparator = buildDomainSeparator(safe: safe)
        let safeTxHash = buildSafeTxHash(tx: tx)
        
        // keccak256(0x19 || 0x01 || domainSeparator || safeTxHash)
        var packed = Data([0x19, 0x01])
        packed.append(domainSeparator)
        packed.append(safeTxHash)
        return Keccak256.hash(data: packed)
    }
    
    private func buildDomainSeparator(safe: GnosisSafeInfo) -> Data {
        // Simplified - in production would use proper EIP-712 encoding
        let typeHash = Keccak256.hash(data: "EIP712Domain(uint256 chainId,address verifyingContract)".data(using: .utf8)!)
        var encoded = typeHash
        encoded.append(Data(repeating: 0, count: 32)) // chainId placeholder
        encoded.append(Data(repeating: 0, count: 32)) // address placeholder
        return Keccak256.hash(data: encoded)
    }
    
    private func buildSafeTxHash(tx: SafeTransaction) -> Data {
        // Simplified - in production would encode all tx fields
        return Keccak256.hash(data: "\(tx.to)\(tx.value)\(tx.data)\(tx.nonce)".data(using: .utf8)!)
    }
}

enum GnosisKeyringError: LocalizedError {
    case useAddSafe
    case invalidAddress
    case useMultisigFlow
    case safeNotFound
    case insufficientSignatures
    
    var errorDescription: String? {
        switch self {
        case .useAddSafe: return "Use addSafe() to add Gnosis Safe addresses"
        case .invalidAddress: return "Invalid Safe address"
        case .useMultisigFlow: return "Gnosis Safe requires multi-signature flow"
        case .safeNotFound: return "Safe not found"
        case .insufficientSignatures: return "Not enough signatures to execute"
        }
    }
}

// MARK: - Session Manager
/// Corresponds to: src/background/service/session.ts
/// Manages DApp session state (active connections, last interaction, etc.)

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var activeSessions: [String: DAppSession] = [:]
    
    private let storage = StorageManager.shared
    private let sessionKey = "rabby_dapp_sessions"
    
    struct DAppSession: Codable, Identifiable {
        var id: String { origin }
        let origin: String
        var chainId: Int
        var address: String?
        var lastInteraction: Date
        var isActive: Bool
    }
    
    private init() { loadSessions() }
    
    /// Get or create session for origin
    func getSession(origin: String) -> DAppSession {
        if let session = activeSessions[origin] {
            return session
        }
        let session = DAppSession(
            origin: origin, chainId: 1, address: nil,
            lastInteraction: Date(), isActive: true
        )
        activeSessions[origin] = session
        saveSessions()
        return session
    }
    
    /// Update session chain
    func setSessionChain(origin: String, chainId: Int) {
        activeSessions[origin]?.chainId = chainId
        activeSessions[origin]?.lastInteraction = Date()
        saveSessions()
    }
    
    /// Update session account
    func setSessionAccount(origin: String, address: String) {
        activeSessions[origin]?.address = address
        activeSessions[origin]?.lastInteraction = Date()
        saveSessions()
    }
    
    /// Remove session
    func removeSession(origin: String) {
        activeSessions.removeValue(forKey: origin)
        saveSessions()
    }
    
    /// Clean up stale sessions (older than 7 days)
    func cleanupStaleSessions() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        activeSessions = activeSessions.filter { $0.value.lastInteraction > cutoff }
        saveSessions()
    }
    
    /// Get all active session origins
    func getActiveOrigins() -> [String] {
        return activeSessions.filter { $0.value.isActive }.map { $0.key }
    }
    
    private func loadSessions() {
        if let data = storage.getData(forKey: sessionKey),
           let sessions = try? JSONDecoder().decode([String: DAppSession].self, from: data) {
            activeSessions = sessions
        }
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(activeSessions) {
            storage.setData(data, forKey: sessionKey)
        }
    }
}
