import Foundation
import BigInt

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
        var threshold: Int
        var owners: [String]
        var version: String
        var nonce: Int
        var networkPrefix: String
        var lastSynced: Date?
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

    // MARK: - Safe Address Import with On-Chain Validation

    /// Import a Gnosis Safe address by validating it on-chain.
    /// Calls getOwners(), getThreshold(), and nonce() on the Safe contract to verify it
    /// is a valid Safe and that the current wallet address is among the owners.
    /// - Parameters:
    ///   - address: The Safe proxy contract address.
    ///   - chainId: The chain ID where the Safe is deployed.
    ///   - currentOwnerAddress: The address of the current wallet user. If provided, the import
    ///     will verify that this address is an owner of the Safe.
    /// - Returns: The populated GnosisSafeInfo after on-chain validation.
    @discardableResult
    func importSafeAddress(
        address: String,
        chainId: Int,
        currentOwnerAddress: String? = nil
    ) async throws -> GnosisSafeInfo {
        let normalized = address.lowercased()
        guard EthereumUtil.isValidAddress(normalized) else {
            throw GnosisKeyringError.invalidAddress
        }

        // Resolve chain for RPC calls
        let chain = await GnosisSafeContractHelper.resolveChain(chainId: chainId)

        // 1. Call getOwners() on-chain
        let owners = try await GnosisSafeContractHelper.getOwners(safeAddress: normalized, chain: chain)
        guard !owners.isEmpty else {
            throw GnosisKeyringError.notASafeContract
        }

        // 2. Call getThreshold() on-chain
        let threshold = try await GnosisSafeContractHelper.getThreshold(safeAddress: normalized, chain: chain)
        guard threshold > 0 else {
            throw GnosisKeyringError.notASafeContract
        }

        // 3. Call nonce() on-chain
        let nonce = try await GnosisSafeContractHelper.getNonce(safeAddress: normalized, chain: chain)

        // 4. Verify current wallet address is among owners (if provided)
        if let ownerAddr = currentOwnerAddress?.lowercased() {
            let lowercasedOwners = owners.map { $0.lowercased() }
            guard lowercasedOwners.contains(ownerAddr) else {
                throw GnosisKeyringError.notAnOwner
            }
        }

        // 5. Determine Safe version (optional, via getVersion() fallback to "1.3.0")
        var version = "1.3.0"
        if let detectedVersion = try? await GnosisSafeContractHelper.getVersion(safeAddress: normalized, chain: chain) {
            version = detectedVersion
        }

        // 6. Determine network prefix
        let networkPrefix = SafeTransactionServiceURLs.networkPrefix(for: chainId)

        // 7. Build and persist info
        let info = GnosisSafeInfo(
            address: normalized,
            chainId: chainId,
            threshold: threshold,
            owners: owners.map { $0.lowercased() },
            version: version,
            nonce: nonce,
            networkPrefix: networkPrefix,
            lastSynced: Date()
        )
        safes[normalized] = info
        if !accounts.contains(normalized) {
            accounts.append(normalized)
        }

        // Save to local storage
        try persistSafeConfig(info)

        return info
    }

    /// Add a Gnosis Safe address (manual / offline mode -- no on-chain validation)
    func addSafe(address: String, chainId: Int, owners: [String], threshold: Int, version: String = "1.3.0") throws {
        let normalized = address.lowercased()
        guard EthereumUtil.isValidAddress(normalized) else {
            throw GnosisKeyringError.invalidAddress
        }

        let info = GnosisSafeInfo(
            address: normalized, chainId: chainId, threshold: threshold,
            owners: owners.map { $0.lowercased() }, version: version,
            nonce: 0, networkPrefix: SafeTransactionServiceURLs.networkPrefix(for: chainId),
            lastSynced: nil
        )
        safes[normalized] = info
        if !accounts.contains(normalized) { accounts.append(normalized) }
    }

    /// Refresh Safe info from on-chain data
    func refreshSafeInfo(address: String) async throws {
        let normalized = address.lowercased()
        guard var info = safes[normalized] else {
            throw GnosisKeyringError.safeNotFound
        }
        let chain = await GnosisSafeContractHelper.resolveChain(chainId: info.chainId)

        info.owners = try await GnosisSafeContractHelper.getOwners(safeAddress: normalized, chain: chain)
            .map { $0.lowercased() }
        info.threshold = try await GnosisSafeContractHelper.getThreshold(safeAddress: normalized, chain: chain)
        info.nonce = try await GnosisSafeContractHelper.getNonce(safeAddress: normalized, chain: chain)
        info.lastSynced = Date()

        safes[normalized] = info
        try persistSafeConfig(info)
    }

    func getAccounts() async -> [String] { accounts }

    func removeAccount(address: String) throws {
        let normalized = address.lowercased()
        accounts.removeAll { $0 == normalized }
        safes.removeValue(forKey: normalized)
        removeSafeConfig(normalized)
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

    // MARK: - EIP-712 Safe Transaction Hash Calculation

    /// Calculate the EIP-712 typed data hash for a Safe transaction.
    ///
    /// The hash follows the EIP-712 standard:
    ///   `keccak256(0x19 || 0x01 || domainSeparator || safeTxHash)`
    ///
    /// Where:
    ///   - domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, safeAddress))
    ///   - safeTxHash = keccak256(abi.encode(SAFE_TX_TYPEHASH, to, value, keccak256(data),
    ///       operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce))
    func calculateSafeTransactionHash(
        safe: String,
        to: String,
        value: BigUInt,
        data: Data,
        operation: UInt8,
        safeTxGas: BigUInt,
        baseGas: BigUInt,
        gasPrice: BigUInt,
        gasToken: String,
        refundReceiver: String,
        nonce: BigUInt,
        chainId: BigUInt
    ) -> Data {
        let domainSeparator = buildDomainSeparatorEIP712(safe: safe, chainId: chainId)
        let safeTxHash = buildSafeTxStructHash(
            to: to, value: value, data: data, operation: operation,
            safeTxGas: safeTxGas, baseGas: baseGas, gasPrice: gasPrice,
            gasToken: gasToken, refundReceiver: refundReceiver, nonce: nonce
        )

        // keccak256(0x19 || 0x01 || domainSeparator || safeTxHash)
        var packed = Data([0x19, 0x01])
        packed.append(domainSeparator)
        packed.append(safeTxHash)
        return Keccak256.hash(data: packed)
    }

    /// Convenience: calculate hash from a SafeTransaction struct
    func calculateSafeTransactionHash(safeAddress: String, tx: SafeTransaction) throws -> Data {
        guard let safe = safes[safeAddress.lowercased()] else {
            throw GnosisKeyringError.safeNotFound
        }

        let txData: Data
        if let dataHex = tx.data.isEmpty ? nil : tx.data.hexToData() {
            txData = dataHex
        } else {
            txData = Data()
        }

        return calculateSafeTransactionHash(
            safe: safe.address,
            to: tx.to,
            value: BigUInt(tx.value) ?? BigUInt(0),
            data: txData,
            operation: UInt8(tx.operation),
            safeTxGas: BigUInt(tx.safeTxGas) ?? BigUInt(0),
            baseGas: BigUInt(tx.baseGas) ?? BigUInt(0),
            gasPrice: BigUInt(tx.gasPrice) ?? BigUInt(0),
            gasToken: tx.gasToken,
            refundReceiver: tx.refundReceiver,
            nonce: BigUInt(tx.nonce),
            chainId: BigUInt(safe.chainId)
        )
    }

    /// Calculate EIP-712 hash for a Safe message (off-chain message signing).
    ///
    /// `keccak256(0x19 || 0x01 || domainSeparator || keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message))))`
    func calculateSafeMessageHash(safe: String, message: Data, chainId: BigUInt) -> Data {
        // SAFE_MSG_TYPEHASH = keccak256("SafeMessage(bytes message)")
        let safeMsgTypeHash = Keccak256.hash(data: "SafeMessage(bytes message)".data(using: .utf8)!)

        // hashStruct = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)))
        let messageHash = Keccak256.hash(data: message)
        var structData = Data()
        structData.append(safeMsgTypeHash)
        structData.append(messageHash.leftPad32())
        let structHash = Keccak256.hash(data: structData)

        let domainSeparator = buildDomainSeparatorEIP712(safe: safe, chainId: chainId)

        var packed = Data([0x19, 0x01])
        packed.append(domainSeparator)
        packed.append(structHash)
        return Keccak256.hash(data: packed)
    }

    // MARK: - EIP-712 Domain Separator & Struct Hash (Production Implementation)

    /// Build the EIP-712 domain separator for a Safe contract.
    /// `keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, verifyingContract))`
    private func buildDomainSeparatorEIP712(safe: String, chainId: BigUInt) -> Data {
        // DOMAIN_SEPARATOR_TYPEHASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
        let typeHash = Keccak256.hash(
            data: "EIP712Domain(uint256 chainId,address verifyingContract)".data(using: .utf8)!
        )

        var encoded = Data()
        encoded.append(typeHash)
        encoded.append(EthereumUtil.abiEncodeUint256(chainId))
        encoded.append(EthereumUtil.abiEncodeAddress(safe))

        return Keccak256.hash(data: encoded)
    }

    /// Build the struct hash for a Safe transaction (SAFE_TX_TYPEHASH).
    /// `keccak256(abi.encode(SAFE_TX_TYPEHASH, to, value, keccak256(data), operation,
    ///   safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce))`
    private func buildSafeTxStructHash(
        to: String,
        value: BigUInt,
        data: Data,
        operation: UInt8,
        safeTxGas: BigUInt,
        baseGas: BigUInt,
        gasPrice: BigUInt,
        gasToken: String,
        refundReceiver: String,
        nonce: BigUInt
    ) -> Data {
        // SAFE_TX_TYPEHASH = keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce)")
        let typeHash = Keccak256.hash(
            data: "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce)".data(using: .utf8)!
        )

        // Hash the data field (dynamic bytes -> keccak256)
        let dataHash = Keccak256.hash(data: data)

        var encoded = Data()
        encoded.append(typeHash)
        encoded.append(EthereumUtil.abiEncodeAddress(to))
        encoded.append(EthereumUtil.abiEncodeUint256(value))
        encoded.append(dataHash)                                          // keccak256(data)
        encoded.append(EthereumUtil.abiEncodeUint256(BigUInt(operation)))  // operation (uint8 as uint256)
        encoded.append(EthereumUtil.abiEncodeUint256(safeTxGas))
        encoded.append(EthereumUtil.abiEncodeUint256(baseGas))
        encoded.append(EthereumUtil.abiEncodeUint256(gasPrice))
        encoded.append(EthereumUtil.abiEncodeAddress(gasToken))
        encoded.append(EthereumUtil.abiEncodeAddress(refundReceiver))
        encoded.append(EthereumUtil.abiEncodeUint256(nonce))

        return Keccak256.hash(data: encoded)
    }

    // MARK: - execTransaction ABI Encoding

    /// Build the calldata for `execTransaction` on the Safe contract.
    /// This is used when enough confirmations have been collected and
    /// the transaction is ready to be executed on-chain.
    ///
    /// Function selector: `0x6a761202`
    /// ```
    /// function execTransaction(
    ///     address to, uint256 value, bytes calldata data, Enum.Operation operation,
    ///     uint256 safeTxGas, uint256 baseGas, uint256 gasPrice,
    ///     address gasToken, address payable refundReceiver,
    ///     bytes memory signatures
    /// ) external payable returns (bool success)
    /// ```
    func buildExecTransactionCalldata(tx: SafeTransaction, signatures: Data) -> Data {
        // selector: execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)
        let selector = Data([0x6a, 0x76, 0x12, 0x02])

        let txData: Data = tx.data.hexToData() ?? Data()

        // Head section: 10 params, each 32 bytes (320 bytes of head)
        // Params 3 (bytes data) and 10 (bytes signatures) are dynamic -> offsets
        let headSize = 10 * 32

        // The `data` tail starts right after the head
        let dataOffset = BigUInt(headSize)
        // Encode data tail: length(32) + data padded to 32-byte boundary
        let dataTail = EthereumUtil.abiEncodeBytes(txData)

        // The `signatures` tail starts after head + dataTail
        let signaturesOffset = BigUInt(headSize + dataTail.count)
        let signaturesTail = EthereumUtil.abiEncodeBytes(signatures)

        var result = selector
        // 1. to (address)
        result.append(EthereumUtil.abiEncodeAddress(tx.to))
        // 2. value (uint256)
        result.append(EthereumUtil.abiEncodeUint256(BigUInt(tx.value) ?? BigUInt(0)))
        // 3. data (bytes) -> offset
        result.append(EthereumUtil.abiEncodeUint256(dataOffset))
        // 4. operation (uint8 as uint256)
        result.append(EthereumUtil.abiEncodeUint256(BigUInt(tx.operation)))
        // 5. safeTxGas
        result.append(EthereumUtil.abiEncodeUint256(BigUInt(tx.safeTxGas) ?? BigUInt(0)))
        // 6. baseGas
        result.append(EthereumUtil.abiEncodeUint256(BigUInt(tx.baseGas) ?? BigUInt(0)))
        // 7. gasPrice
        result.append(EthereumUtil.abiEncodeUint256(BigUInt(tx.gasPrice) ?? BigUInt(0)))
        // 8. gasToken (address)
        result.append(EthereumUtil.abiEncodeAddress(tx.gasToken))
        // 9. refundReceiver (address)
        result.append(EthereumUtil.abiEncodeAddress(tx.refundReceiver))
        // 10. signatures (bytes) -> offset
        result.append(EthereumUtil.abiEncodeUint256(signaturesOffset))

        // Tail sections
        result.append(dataTail)
        result.append(signaturesTail)

        return result
    }

    /// Combine individual owner signatures into the packed format expected by
    /// `execTransaction`. Signatures are sorted by owner address (ascending, lowercase).
    /// Each signature is 65 bytes: r(32) + s(32) + v(1).
    func packSignatures(_ signatures: [(owner: String, signature: Data)]) -> Data {
        let sorted = signatures.sorted { $0.owner.lowercased() < $1.owner.lowercased() }
        var packed = Data()
        for sig in sorted {
            packed.append(sig.signature)
        }
        return packed
    }

    // MARK: - Local Persistence

    private func persistSafeConfig(_ info: GnosisSafeInfo) throws {
        let key = "gnosis_safe_\(info.address)"
        let data = try JSONEncoder().encode(info)
        UserDefaults.standard.set(data, forKey: key)
    }

    private func removeSafeConfig(_ address: String) {
        let key = "gnosis_safe_\(address)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Load all persisted Safe configs from local storage
    func loadPersistedSafes() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("gnosis_safe_0x") }
        for key in allKeys {
            if let data = defaults.data(forKey: key),
               let info = try? JSONDecoder().decode(GnosisSafeInfo.self, from: data) {
                safes[info.address] = info
                if !accounts.contains(info.address) {
                    accounts.append(info.address)
                }
            }
        }
    }
}

// MARK: - Safe Contract ABI Helpers

/// Provides static methods to interact with Gnosis Safe contracts via eth_call.
enum GnosisSafeContractHelper {

    /// ABI function selectors (first 4 bytes of keccak256 of the function signature)
    static let getOwnersSelector = Data([0xa0, 0xe6, 0x7e, 0x2b])   // getOwners()
    static let getThresholdSelector = Data([0xe7, 0x52, 0x35, 0xb8]) // getThreshold()
    static let nonceSelector = Data([0xaf, 0xfe, 0xd0, 0xe0])       // nonce()
    static let versionSelector = Data([0xfe, 0xdd, 0xc2, 0xa6])     // VERSION() -- newer Safes use feddC2a6

    /// Resolve a Chain object for the given chainId. Falls back to a generic chain
    /// with a public RPC if ChainManager does not know this chain.
    static func resolveChain(chainId: Int) async -> Chain {
        if let chain = await MainActor.run(body: { ChainManager.shared.getChain(id: chainId) }) {
            return chain
        }
        // Fallback: construct a minimal chain with a public RPC
        let rpcUrl: String
        switch chainId {
        case 1: rpcUrl = "https://eth.llamarpc.com"
        case 56: rpcUrl = "https://bsc-dataseed1.binance.org"
        case 137: rpcUrl = "https://polygon-rpc.com"
        case 42161: rpcUrl = "https://arb1.arbitrum.io/rpc"
        case 10: rpcUrl = "https://mainnet.optimism.io"
        case 43114: rpcUrl = "https://api.avax.network/ext/bc/C/rpc"
        case 100: rpcUrl = "https://rpc.gnosischain.com"
        case 8453: rpcUrl = "https://mainnet.base.org"
        default: rpcUrl = "https://eth.llamarpc.com"
        }
        return Chain(id: chainId, name: "Chain \(chainId)", serverId: "chain_\(chainId)",
                     symbol: "ETH", nativeTokenAddress: "0x0000000000000000000000000000000000000000",
                     rpcUrl: rpcUrl, scanUrl: "")
    }

    /// Call `getOwners()` on the Safe contract and decode the returned address array.
    static func getOwners(safeAddress: String, chain: Chain) async throws -> [String] {
        let calldata = EthereumUtil.dataToHex(getOwnersSelector)
        let result = try await NetworkManager.shared.call(
            transaction: ["to": safeAddress, "data": calldata],
            chain: chain
        )
        return try decodeAddressArray(from: result)
    }

    /// Call `getThreshold()` on the Safe contract.
    static func getThreshold(safeAddress: String, chain: Chain) async throws -> Int {
        let calldata = EthereumUtil.dataToHex(getThresholdSelector)
        let result = try await NetworkManager.shared.call(
            transaction: ["to": safeAddress, "data": calldata],
            chain: chain
        )
        return decodeUint256AsInt(from: result)
    }

    /// Call `nonce()` on the Safe contract.
    static func getNonce(safeAddress: String, chain: Chain) async throws -> Int {
        let calldata = EthereumUtil.dataToHex(nonceSelector)
        let result = try await NetworkManager.shared.call(
            transaction: ["to": safeAddress, "data": calldata],
            chain: chain
        )
        return decodeUint256AsInt(from: result)
    }

    /// Call `VERSION()` on the Safe contract.
    static func getVersion(safeAddress: String, chain: Chain) async throws -> String {
        let calldata = EthereumUtil.dataToHex(versionSelector)
        let result = try await NetworkManager.shared.call(
            transaction: ["to": safeAddress, "data": calldata],
            chain: chain
        )
        return try decodeString(from: result)
    }

    // MARK: - ABI Decoding Helpers

    /// Decode a uint256 hex result to an Int.
    private static func decodeUint256AsInt(from hex: String) -> Int {
        let cleaned = hex.replacingOccurrences(of: "0x", with: "")
        guard let value = BigUInt(cleaned, radix: 16) else { return 0 }
        return Int(value)
    }

    /// Decode an ABI-encoded address[] (dynamic array) from a hex-encoded eth_call response.
    ///
    /// Layout:
    ///   word 0: offset to array data (always 0x20 for a single return value)
    ///   word 1: array length N
    ///   word 2..N+1: left-padded addresses (last 20 bytes of each 32-byte word)
    private static func decodeAddressArray(from hex: String) throws -> [String] {
        let cleaned = hex.replacingOccurrences(of: "0x", with: "")
        guard let data = Data(hexString: cleaned), data.count >= 64 else {
            throw GnosisKeyringError.invalidContractResponse
        }

        // word 0: offset (skip)
        // word 1: array length
        let lengthSlice = data.subdata(in: 32..<64)
        let length = Int(BigUInt(lengthSlice))

        guard data.count >= 64 + length * 32 else {
            throw GnosisKeyringError.invalidContractResponse
        }

        var addresses: [String] = []
        for i in 0..<length {
            let start = 64 + i * 32
            let word = data.subdata(in: start..<(start + 32))
            // Address is the last 20 bytes
            let addressBytes = word.suffix(20)
            let address = "0x" + addressBytes.toHexString()
            addresses.append(address)
        }

        return addresses
    }

    /// Decode a Solidity string return value from hex-encoded eth_call response.
    private static func decodeString(from hex: String) throws -> String {
        let cleaned = hex.replacingOccurrences(of: "0x", with: "")
        guard let data = Data(hexString: cleaned), data.count >= 96 else {
            throw GnosisKeyringError.invalidContractResponse
        }

        // word 0: offset to string data
        // word 1: string length
        let lengthSlice = data.subdata(in: 32..<64)
        let length = Int(BigUInt(lengthSlice))

        guard data.count >= 64 + length else {
            throw GnosisKeyringError.invalidContractResponse
        }

        let stringData = data.subdata(in: 64..<(64 + length))
        guard let str = String(data: stringData, encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) else {
            throw GnosisKeyringError.invalidContractResponse
        }
        return str
    }
}

// MARK: - Multi-Chain Safe Transaction Service URLs

/// Maps chain IDs to the corresponding Safe Transaction Service API base URLs.
enum SafeTransactionServiceURLs {

    /// Get the Safe Transaction Service base URL for a given chain ID.
    static func baseURL(for chainId: Int) -> String {
        switch chainId {
        case 1:     return "https://safe-transaction-mainnet.safe.global"
        case 5:     return "https://safe-transaction-goerli.safe.global"
        case 10:    return "https://safe-transaction-optimism.safe.global"
        case 56:    return "https://safe-transaction-bsc.safe.global"
        case 100:   return "https://safe-transaction-gnosis-chain.safe.global"
        case 137:   return "https://safe-transaction-polygon.safe.global"
        case 250:   return "https://safe-transaction-fantom.safe.global" // community-run
        case 324:   return "https://safe-transaction-zksync.safe.global"
        case 8453:  return "https://safe-transaction-base.safe.global"
        case 42161: return "https://safe-transaction-arbitrum.safe.global"
        case 42220: return "https://safe-transaction-celo.safe.global"
        case 43114: return "https://safe-transaction-avalanche.safe.global"
        case 59144: return "https://safe-transaction-linea.safe.global"
        case 84531: return "https://safe-transaction-base-testnet.safe.global"
        case 11155111: return "https://safe-transaction-sepolia.safe.global"
        default:    return "https://safe-transaction-mainnet.safe.global"
        }
    }

    /// Human-friendly network prefix (used in Safe address format: "eth:0x...")
    static func networkPrefix(for chainId: Int) -> String {
        switch chainId {
        case 1:     return "eth"
        case 5:     return "gor"
        case 10:    return "oeth"
        case 56:    return "bnb"
        case 100:   return "gno"
        case 137:   return "matic"
        case 250:   return "ftm"
        case 324:   return "zksync"
        case 8453:  return "base"
        case 42161: return "arb1"
        case 42220: return "celo"
        case 43114: return "avax"
        case 59144: return "linea"
        case 11155111: return "sep"
        default:    return "eth"
        }
    }

    /// Multisig transactions endpoint
    static func multisigTransactionsURL(for chainId: Int, safeAddress: String) -> String {
        return "\(baseURL(for: chainId))/api/v1/safes/\(safeAddress)/multisig-transactions/"
    }

    /// Pending multisig transactions (not yet executed)
    static func pendingTransactionsURL(for chainId: Int, safeAddress: String) -> String {
        return "\(multisigTransactionsURL(for: chainId, safeAddress: safeAddress))?executed=false&ordering=-nonce"
    }

    /// Messages endpoint
    static func messagesURL(for chainId: Int, safeAddress: String) -> String {
        return "\(baseURL(for: chainId))/api/v1/safes/\(safeAddress)/messages/"
    }

    /// Submit a confirmation (signature) for a transaction
    static func confirmTransactionURL(for chainId: Int, safeTxHash: String) -> String {
        return "\(baseURL(for: chainId))/api/v1/multisig-transactions/\(safeTxHash)/confirmations/"
    }

    /// Submit a confirmation (signature) for a message
    static func confirmMessageURL(for chainId: Int, messageHash: String) -> String {
        return "\(baseURL(for: chainId))/api/v1/messages/\(messageHash)/signatures/"
    }
}

// MARK: - Gnosis Keyring Errors

enum GnosisKeyringError: LocalizedError {
    case useAddSafe
    case invalidAddress
    case useMultisigFlow
    case safeNotFound
    case insufficientSignatures
    case notASafeContract
    case notAnOwner
    case invalidContractResponse
    case transactionServiceError(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .useAddSafe: return "Use addSafe() or importSafeAddress() to add Gnosis Safe addresses"
        case .invalidAddress: return "Invalid Safe address"
        case .useMultisigFlow: return "Gnosis Safe requires multi-signature flow"
        case .safeNotFound: return "Safe not found"
        case .insufficientSignatures: return "Not enough signatures to execute"
        case .notASafeContract: return "Address is not a valid Gnosis Safe contract"
        case .notAnOwner: return "Current wallet address is not an owner of this Safe"
        case .invalidContractResponse: return "Invalid response from Safe contract"
        case .transactionServiceError(let msg): return "Safe Transaction Service error: \(msg)"
        case .executionFailed(let msg): return "Transaction execution failed: \(msg)"
        }
    }
}

// MARK: - Data Extension for EIP-712

private extension Data {
    /// Left-pad data to 32 bytes
    func leftPad32() -> Data {
        if self.count >= 32 { return self.suffix(32) }
        return Data(repeating: 0, count: 32 - self.count) + self
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
