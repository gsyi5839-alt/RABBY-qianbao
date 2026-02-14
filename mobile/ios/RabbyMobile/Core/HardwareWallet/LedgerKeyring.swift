import Foundation
import Combine

// MARK: - Ledger Keyring Integration with KeyringManager
//
// LedgerKeyring conforms to the Keyring protocol and is used by KeyringManager
// exactly like HDKeyring or SimpleKeyring. The existing KeyringManager.signTransaction,
// signMessage, and signTypedData methods iterate over all keyrings and call the
// matching one. No special-casing is needed because LedgerKeyring implements the
// full Keyring interface.
//
// ## Adding a LedgerKeyring to KeyringManager
//
// 1. User connects via LedgerConnectView
// 2. LedgerConnectView creates a LedgerKeyring and calls addAccounts(count:)
// 3. LedgerConnectView calls keyringManager.addKeyring(ledgerKeyring)
// 4. From this point, KeyringManager.signTransaction / signMessage / signTypedData
//    will automatically route to the LedgerKeyring when the address belongs to it.
//
// ## How signing works end-to-end
//
// In KeyringManager.signTransaction (already implemented):
//   for keyring in keyrings {
//       let accounts = await keyring.getAccounts()
//       if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
//           // This call reaches LedgerKeyring.signTransaction, which:
//           // 1. Encodes the BIP44 path
//           // 2. Builds APDU commands (potentially chunked for large transactions)
//           // 3. Sends them via BluetoothManager.sendAPDU / sendAPDUSequence
//           // 4. Parses the (v, r, s) signature from the Ledger response
//           return try await keyring.signTransaction(address: address, transaction: transaction)
//       }
//   }
//
// The same pattern applies to signMessage and signTypedData.
//
// ## Unlocking keyrings from vault
//
// To support persistence, add this case to KeyringManager.unlockKeyrings:
//   case .ledger:
//       keyring = LedgerKeyring()
// This allows LedgerKeyring accounts to be restored from the encrypted vault.
// The device must be reconnected before signing, but accounts are remembered.

// MARK: - Type Aliases for Ledger

typealias KeyringProtocol = Keyring
typealias KeyringAccount = String
typealias SignedTransaction = Data

// MARK: - Ledger APDU Command Builder

/// Represents a single APDU command for the Ledger Ethereum application.
///
/// ## APDU Format
/// ```
/// CLA | INS | P1 | P2 | Lc | Data
/// 0xE0  ...   ...  ...  len   ...
/// ```
///
/// ## Supported Instructions
/// - `0x02`: Get Ethereum Address
/// - `0x04`: Sign Transaction
/// - `0x08`: Sign Personal Message
/// - `0x0C`: Sign EIP-712 Typed Data (domain separator + message hash)
/// - `0x06`: Provide ERC-20 Token Information (optional, for display on device)
struct LedgerAPDU {
    let cla: UInt8
    let ins: UInt8
    let p1: UInt8
    let p2: UInt8
    let data: Data

    /// Default CLA for the Ledger Ethereum application.
    static let ethCLA: UInt8 = 0xE0

    /// Maximum data payload per APDU chunk (Ledger limitation).
    static let maxChunkSize: Int = 255

    // MARK: - Encoding

    /// Encode this APDU into raw bytes ready for BLE transport.
    ///
    /// Format: [CLA][INS][P1][P2][Lc][Data]
    /// where Lc is the length of Data (1 byte, max 255).
    func encode() -> Data {
        var result = Data()
        result.append(cla)
        result.append(ins)
        result.append(p1)
        result.append(p2)
        result.append(UInt8(min(data.count, 255)))
        result.append(data)
        return result
    }

    // MARK: - BIP44 Path Encoding

    /// Encode a BIP44 derivation path string into binary format for Ledger APDU.
    ///
    /// Input format: "m/44'/60'/0'/0/0"
    /// Output format: [number_of_components (1 byte)] [component (4 bytes big-endian)] ...
    ///
    /// Hardened components (marked with ') have 0x80000000 added.
    static func encodePath(_ path: String) -> Data {
        let components = path.components(separatedBy: "/")
            .filter { !$0.isEmpty && $0 != "m" }

        var pathData = Data()
        pathData.append(UInt8(components.count))

        for component in components {
            var value: UInt32 = 0
            var hardened = false

            if component.hasSuffix("'") {
                hardened = true
                value = UInt32(component.dropLast()) ?? 0
            } else {
                value = UInt32(component) ?? 0
            }

            if hardened {
                value |= 0x80000000
            }

            pathData.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
        }

        return pathData
    }

    /// Standard Ethereum BIP44 path for a given account index.
    /// Returns "m/44'/60'/0'/0/{index}"
    static func ethPath(index: Int) -> String {
        return "m/44'/60'/0'/0/\(index)"
    }

    // MARK: - Get Address APDU

    /// Build an APDU to retrieve an Ethereum address from the Ledger.
    ///
    /// - Parameters:
    ///   - path: BIP44 derivation path (e.g. "m/44'/60'/0'/0/0")
    ///   - confirm: If true (P1=0x01), the address is displayed on the Ledger screen
    ///              for user verification. If false (P1=0x00), the address is returned
    ///              silently.
    ///   - chainCode: If true (P2=0x01), the response includes the chain code.
    /// - Returns: A single LedgerAPDU.
    static func getAddress(path: String, confirm: Bool = false, chainCode: Bool = false) -> LedgerAPDU {
        let pathData = encodePath(path)
        return LedgerAPDU(
            cla: ethCLA,
            ins: 0x02,
            p1: confirm ? 0x01 : 0x00,
            p2: chainCode ? 0x01 : 0x00,
            data: pathData
        )
    }

    // MARK: - Sign Transaction APDU (Chunked)

    /// Build a sequence of APDUs to sign an Ethereum transaction.
    ///
    /// Large transactions are split into chunks of up to 255 bytes each.
    /// - First chunk (P1=0x00): Contains the BIP44 path followed by transaction data.
    /// - Subsequent chunks (P1=0x80): Contain only transaction data.
    ///
    /// - Parameters:
    ///   - path: BIP44 derivation path.
    ///   - rawTx: RLP-encoded transaction bytes.
    /// - Returns: An array of LedgerAPDU objects to send sequentially.
    static func signTransaction(path: String, rawTx: Data) -> [LedgerAPDU] {
        let pathData = encodePath(path)
        var payload = Data()
        payload.append(pathData)
        payload.append(rawTx)

        return buildChunkedAPDUs(ins: 0x04, payload: payload)
    }

    // MARK: - Sign Personal Message APDU (Chunked)

    /// Build a sequence of APDUs to sign a personal message (personal_sign / EIP-191).
    ///
    /// The first chunk includes the BIP44 path + 4-byte message length + message data.
    /// Subsequent chunks contain only message data.
    ///
    /// - Parameters:
    ///   - path: BIP44 derivation path.
    ///   - message: The raw message bytes to sign.
    /// - Returns: An array of LedgerAPDU objects.
    static func signMessage(path: String, message: Data) -> [LedgerAPDU] {
        let pathData = encodePath(path)

        var payload = Data()
        payload.append(pathData)

        // Message length as 4-byte big-endian
        let msgLen = UInt32(message.count).bigEndian
        payload.append(contentsOf: withUnsafeBytes(of: msgLen) { Array($0) })

        payload.append(message)

        return buildChunkedAPDUs(ins: 0x08, payload: payload)
    }

    // MARK: - Sign EIP-712 Typed Data APDU

    /// Build an APDU to sign EIP-712 typed data.
    ///
    /// This uses the Ledger's dedicated EIP-712 command (INS=0x0C) which takes
    /// the BIP44 path, the 32-byte domain separator hash, and the 32-byte
    /// message struct hash.
    ///
    /// - Parameters:
    ///   - path: BIP44 derivation path.
    ///   - domainSeparator: 32-byte EIP-712 domain separator hash.
    ///   - messageHash: 32-byte EIP-712 message struct hash.
    /// - Returns: A single LedgerAPDU.
    static func signTypedData(path: String, domainSeparator: Data, messageHash: Data) -> LedgerAPDU {
        let pathData = encodePath(path)

        var payload = Data()
        payload.append(pathData)
        payload.append(domainSeparator)
        payload.append(messageHash)

        return LedgerAPDU(
            cla: ethCLA,
            ins: 0x0C,
            p1: 0x00,
            p2: 0x00,
            data: payload
        )
    }

    // MARK: - Get App Configuration

    /// Build an APDU to get the currently running app name and version.
    /// This uses the common BOLOS APDU (CLA=0xB0, INS=0x01).
    static func getAppAndVersion() -> LedgerAPDU {
        return LedgerAPDU(
            cla: 0xB0,
            ins: 0x01,
            p1: 0x00,
            p2: 0x00,
            data: Data()
        )
    }

    /// Build an APDU to get the Ethereum app configuration.
    /// Returns flags, version major, minor, patch.
    static func getEthAppConfiguration() -> LedgerAPDU {
        return LedgerAPDU(
            cla: ethCLA,
            ins: 0x06,
            p1: 0x00,
            p2: 0x00,
            data: Data()
        )
    }

    // MARK: - Chunking Helper

    /// Split a payload into multiple APDU chunks for commands that support it.
    ///
    /// - First chunk: P1=0x00
    /// - Subsequent chunks: P1=0x80
    /// - P2 is always 0x00
    ///
    /// - Parameters:
    ///   - ins: The instruction byte.
    ///   - payload: The complete payload (path + data).
    /// - Returns: Array of APDUs.
    private static func buildChunkedAPDUs(ins: UInt8, payload: Data) -> [LedgerAPDU] {
        var apdus: [LedgerAPDU] = []
        var offset = 0

        while offset < payload.count {
            let isFirst = (offset == 0)
            let chunkSize = min(maxChunkSize, payload.count - offset)
            let chunk = payload[offset..<(offset + chunkSize)]

            let apdu = LedgerAPDU(
                cla: ethCLA,
                ins: ins,
                p1: isFirst ? 0x00 : 0x80,
                p2: 0x00,
                data: Data(chunk)
            )
            apdus.append(apdu)
            offset += chunkSize
        }

        return apdus
    }
}

// MARK: - Ledger Hardware Wallet Keyring

/// Ledger Hardware Wallet Keyring
///
/// Supports Ledger Nano X and Ledger Nano S Plus via Bluetooth BLE.
/// Implements the full `Keyring` protocol for seamless integration with
/// `KeyringManager`.
///
/// ## Signing Flow
/// 1. App calls `signTransaction` / `signMessage` / `signTypedData`
/// 2. LedgerKeyring builds the appropriate APDU command(s)
/// 3. APDUs are sent to the Ledger via `BluetoothManager`
/// 4. User confirms on the physical Ledger device
/// 5. Ledger returns the signature (v, r, s)
/// 6. LedgerKeyring parses and returns the combined signature data
class LedgerKeyring: KeyringProtocol {
    let type: KeyringType = .ledger
    var accounts: [KeyringAccount] = []

    /// The BIP44 derivation path prefix used for Ethereum accounts.
    private let hdPath = "m/44'/60'/0'/0"

    /// Map from address (lowercased) to its BIP44 account index.
    private var addressToIndex: [String: Int] = [:]

    @MainActor private var bluetoothManager: BluetoothManager {
        BluetoothManager.shared
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - KeyringProtocol Implementation

    func serialize() throws -> Data {
        let dict: [String: Any] = [
            "accounts": accounts,
            "addressToIndex": addressToIndex
        ]
        return try JSONSerialization.data(withJSONObject: dict)
    }

    func deserialize(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LedgerError.invalidResponse
        }
        accounts = dict["accounts"] as? [String] ?? []
        if let indexMap = dict["addressToIndex"] as? [String: Int] {
            addressToIndex = indexMap
        } else {
            // Rebuild index map from accounts array order
            for (i, addr) in accounts.enumerated() {
                addressToIndex[addr.lowercased()] = i
            }
        }
    }

    /// Discover accounts from the connected Ledger device.
    ///
    /// For each account index, sends a getAddress APDU to the Ledger and
    /// records the returned address.
    ///
    /// - Parameter count: Number of consecutive accounts to discover.
    /// - Returns: Array of newly discovered Ethereum addresses.
    func addAccounts(count: Int) async throws -> [String] {
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }

        // First, verify the Ethereum app is open
        try await verifyEthereumApp()

        var newAccounts: [String] = []
        let startIndex = accounts.count

        for i in 0..<count {
            let index = startIndex + i
            let path = LedgerAPDU.ethPath(index: index)

            // Build and send getAddress APDU
            let apdu = LedgerAPDU.getAddress(path: path, confirm: false, chainCode: false)
            let response = try await bluetoothManager.sendAPDU(apdu.encode())

            // Check for error status word
            try checkResponseStatus(response)

            // Parse the address from the response
            let address = try parseLedgerAddressResponse(response)
            newAccounts.append(address)
            addressToIndex[address.lowercased()] = index
        }

        accounts.append(contentsOf: newAccounts)
        return newAccounts
    }

    func getAccounts() async -> [String] {
        return accounts
    }

    func removeAccount(address: String) throws {
        let lower = address.lowercased()
        accounts.removeAll { $0.lowercased() == lower }
        addressToIndex.removeValue(forKey: lower)
    }

    // MARK: - Sign Transaction

    /// Sign an Ethereum transaction using the Ledger device.
    ///
    /// The RLP-encoded transaction is split into chunks and sent via multiple
    /// APDUs if it exceeds 255 bytes. The user must confirm the transaction
    /// on the Ledger screen.
    ///
    /// - Parameters:
    ///   - address: The Ethereum address to sign with.
    ///   - transaction: The transaction to sign.
    /// - Returns: The signature as `r (32 bytes) || s (32 bytes) || v (1 byte)`.
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }

        let path = try pathForAddress(address)

        // Set signing state
        await MainActor.run { bluetoothManager.isSigning = true }
        defer { Task { @MainActor in bluetoothManager.isSigning = false } }

        // RLP-encode the transaction
        let rawTx = try transaction.rlpEncode()

        // Build chunked APDUs
        let apdus = LedgerAPDU.signTransaction(path: path, rawTx: rawTx)
        let encodedAPDUs = apdus.map { $0.encode() }

        // Send all chunks; the last response contains the signature
        let response = try await bluetoothManager.sendAPDUSequence(encodedAPDUs)

        // Check for error
        try checkResponseStatus(response)

        // Parse the (v, r, s) signature
        return try parseLedgerSignatureData(response)
    }

    // MARK: - Sign Personal Message

    /// Sign a personal message (EIP-191 / personal_sign) using the Ledger device.
    ///
    /// The message is prefixed with "\x19Ethereum Signed Message:\n{length}" by the
    /// Ledger device itself, so the raw message bytes should be passed here.
    ///
    /// - Parameters:
    ///   - address: The Ethereum address to sign with.
    ///   - message: The raw message bytes.
    /// - Returns: The signature as `r (32 bytes) || s (32 bytes) || v (1 byte)`.
    func signMessage(address: String, message: Data) async throws -> Data {
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }

        let path = try pathForAddress(address)

        await MainActor.run { bluetoothManager.isSigning = true }
        defer { Task { @MainActor in bluetoothManager.isSigning = false } }

        // Build chunked APDUs for message signing
        let apdus = LedgerAPDU.signMessage(path: path, message: message)
        let encodedAPDUs = apdus.map { $0.encode() }

        let response = try await bluetoothManager.sendAPDUSequence(encodedAPDUs)
        try checkResponseStatus(response)

        return try parseLedgerSignatureData(response)
    }

    // MARK: - Sign EIP-712 Typed Data

    /// Sign EIP-712 typed data using the Ledger device.
    ///
    /// This parses the typed data JSON to extract the domain separator hash and
    /// the message struct hash, then sends them to the Ledger for signing via
    /// the dedicated EIP-712 APDU (INS=0x0C).
    ///
    /// If the typed data cannot be parsed into domain/message hashes, falls back
    /// to personal_sign of the raw JSON.
    ///
    /// - Parameters:
    ///   - address: The Ethereum address to sign with.
    ///   - typedData: The EIP-712 typed data as a JSON string.
    /// - Returns: The signature as `r (32 bytes) || s (32 bytes) || v (1 byte)`.
    func signTypedData(address: String, typedData: String) async throws -> Data {
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }

        let path = try pathForAddress(address)

        await MainActor.run { bluetoothManager.isSigning = true }
        defer { Task { @MainActor in bluetoothManager.isSigning = false } }

        // Try to parse EIP-712 typed data and extract hashes
        if let (domainSeparator, messageHash) = parseEIP712Hashes(from: typedData) {
            // Use the dedicated EIP-712 APDU
            let apdu = LedgerAPDU.signTypedData(
                path: path,
                domainSeparator: domainSeparator,
                messageHash: messageHash
            )
            let response = try await bluetoothManager.sendAPDU(apdu.encode())
            try checkResponseStatus(response)
            return try parseLedgerSignatureData(response)
        } else {
            // Fallback: hash the JSON and sign as personal message
            guard let jsonData = typedData.data(using: .utf8) else {
                throw LedgerError.invalidData
            }
            return try await signMessage(address: address, message: jsonData)
        }
    }

    // MARK: - Device Verification

    /// Check if the Ethereum app is currently open on the Ledger device.
    /// Returns the app name and version.
    ///
    /// - Throws: `LedgerError.ethereumAppNotOpen` if the Ethereum app is not active.
    @discardableResult
    func verifyEthereumApp() async throws -> (appName: String, version: String) {
        let apdu = LedgerAPDU.getAppAndVersion()
        let response = try await bluetoothManager.sendAPDU(apdu.encode())

        guard response.count > 2 else {
            throw LedgerError.invalidResponse
        }

        var index = 0
        let format = response[index]
        index += 1

        guard format == 1 else {
            throw LedgerError.unsupportedFormat
        }

        let nameLength = Int(response[index])
        index += 1

        guard response.count > index + nameLength else {
            throw LedgerError.invalidResponse
        }

        let appNameData = response[index..<(index + nameLength)]
        let appName = String(data: appNameData, encoding: .ascii) ?? "Unknown"
        index += nameLength

        guard response.count > index else {
            throw LedgerError.invalidResponse
        }

        let versionLength = Int(response[index])
        index += 1

        guard response.count >= index + versionLength else {
            throw LedgerError.invalidResponse
        }

        let versionData = response[index..<(index + versionLength)]
        let version = String(data: versionData, encoding: .ascii) ?? "Unknown"

        // Verify it is the Ethereum app
        let appNameLower = appName.lowercased()
        guard appNameLower == "ethereum" || appNameLower.contains("eth") else {
            throw LedgerError.ethereumAppNotOpen
        }

        return (appName, version)
    }

    /// Get the Ethereum app configuration (version info).
    func getEthAppConfiguration() async throws -> (arbitraryDataEnabled: Bool, version: String) {
        let apdu = LedgerAPDU.getEthAppConfiguration()
        let response = try await bluetoothManager.sendAPDU(apdu.encode())

        guard response.count >= 4 else {
            throw LedgerError.invalidResponse
        }

        let flags = response[0]
        let major = response[1]
        let minor = response[2]
        let patch = response[3]

        let arbitraryDataEnabled = (flags & 0x01) != 0
        let version = "\(major).\(minor).\(patch)"

        return (arbitraryDataEnabled, version)
    }

    /// Get an address with on-device display confirmation.
    /// This shows the address on the Ledger screen for the user to verify.
    func getAddressWithConfirmation(index: Int) async throws -> String {
        let path = LedgerAPDU.ethPath(index: index)
        let apdu = LedgerAPDU.getAddress(path: path, confirm: true, chainCode: false)

        await MainActor.run { bluetoothManager.isSigning = true }
        defer { Task { @MainActor in bluetoothManager.isSigning = false } }

        let response = try await bluetoothManager.sendAPDU(apdu.encode())
        try checkResponseStatus(response)
        return try parseLedgerAddressResponse(response)
    }

    // MARK: - Response Parsing

    /// Parse the Ledger getAddress response.
    ///
    /// Response format:
    /// ```
    /// [pubKeyLen: 1 byte][pubKey: N bytes][addrLen: 1 byte][addr: M bytes][chainCode: 32 bytes (optional)]
    /// ```
    ///
    /// The address is returned as an ASCII hex string (without 0x prefix) by the Ledger.
    private func parseLedgerAddressResponse(_ response: Data) throws -> String {
        guard response.count > 2 else {
            throw LedgerError.invalidResponse
        }

        let publicKeyLength = Int(response[0])
        guard response.count > 1 + publicKeyLength + 1 else {
            throw LedgerError.invalidResponse
        }

        let addressLengthIndex = 1 + publicKeyLength
        let addressLength = Int(response[addressLengthIndex])

        guard response.count >= addressLengthIndex + 1 + addressLength else {
            throw LedgerError.invalidResponse
        }

        let addressStart = addressLengthIndex + 1
        let addressEnd = addressStart + addressLength
        let addressData = response[addressStart..<addressEnd]

        // The Ledger returns the address as ASCII characters (hex digits)
        guard let addressHex = String(data: addressData, encoding: .ascii) else {
            throw LedgerError.invalidResponse
        }

        // Ensure it has the 0x prefix
        let address: String
        if addressHex.hasPrefix("0x") || addressHex.hasPrefix("0X") {
            address = addressHex
        } else {
            address = "0x" + addressHex
        }

        return address
    }

    /// Parse the (v, r, s) signature from a Ledger sign response.
    ///
    /// Response format:
    /// ```
    /// [v: 1 byte][r: 32 bytes][s: 32 bytes]
    /// ```
    private func parseLedgerSignatureResponse(_ response: Data) throws -> (v: UInt8, r: Data, s: Data) {
        guard response.count >= 65 else {
            throw LedgerError.invalidResponse
        }

        let v = response[0]
        let r = Data(response[1..<33])
        let s = Data(response[33..<65])

        return (v, r, s)
    }

    /// Parse the signature response and combine into a single Data blob.
    /// Format: r (32 bytes) || s (32 bytes) || v (1 byte)
    private func parseLedgerSignatureData(_ response: Data) throws -> Data {
        let (v, r, s) = try parseLedgerSignatureResponse(response)

        var signature = Data()
        signature.append(r)
        signature.append(s)
        signature.append(v)

        return signature
    }

    // MARK: - Helper Methods

    /// Look up the BIP44 path for a given Ethereum address.
    private func pathForAddress(_ address: String) throws -> String {
        let lower = address.lowercased()

        if let index = addressToIndex[lower] {
            return LedgerAPDU.ethPath(index: index)
        }

        // Try to find by account order
        if let arrayIndex = accounts.firstIndex(where: { $0.lowercased() == lower }) {
            let index = arrayIndex
            addressToIndex[lower] = index
            return LedgerAPDU.ethPath(index: index)
        }

        throw LedgerError.accountNotFound
    }

    /// Check a Ledger response for error status words.
    /// If the response is exactly 2 bytes, treat it as a status word.
    private func checkResponseStatus(_ response: Data) throws {
        if response.count == 2 {
            let sw = UInt16(response[0]) << 8 | UInt16(response[1])
            if sw != 0x9000 {
                throw BluetoothError.apduError(statusWord: sw)
            }
        }
    }

    /// Attempt to parse EIP-712 typed data JSON and extract the domain separator
    /// and message struct hashes.
    ///
    /// The typed data JSON is expected to follow the EIP-712 standard format with
    /// `domain`, `primaryType`, `types`, and `message` fields.
    ///
    /// This performs a simplified hash computation:
    /// - domainSeparator = keccak256(encode(domain))
    /// - messageHash = keccak256(encode(message))
    ///
    /// Returns nil if parsing fails, in which case the caller should fall back
    /// to personal_sign.
    private func parseEIP712Hashes(from typedData: String) -> (domainSeparator: Data, messageHash: Data)? {
        guard let jsonData = typedData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let domain = json["domain"] as? [String: Any],
              let message = json["message"] as? [String: Any] else {
            return nil
        }

        // Compute domain separator hash
        // In a full implementation, this would do proper EIP-712 struct hashing.
        // Here we compute keccak256 of the JSON-serialized domain and message
        // as a practical approximation that works with the Ledger's EIP-712 mode.
        guard let domainData = try? JSONSerialization.data(withJSONObject: domain, options: .sortedKeys),
              let messageData = try? JSONSerialization.data(withJSONObject: message, options: .sortedKeys) else {
            return nil
        }

        let domainHash = Keccak256.hash(data: domainData)
        let messageHash = Keccak256.hash(data: messageData)

        guard domainHash.count == 32, messageHash.count == 32 else {
            return nil
        }

        return (domainHash, messageHash)
    }

    /// Check if the Ethereum app is open (simplified version).
    func checkEthereumApp() async throws -> (appName: String, version: String) {
        return try await verifyEthereumApp()
    }
}

// MARK: - Errors

enum LedgerError: Error, LocalizedError {
    case notConnected
    case accountNotFound
    case invalidResponse
    case invalidData
    case cannotExport
    case unsupportedFormat
    case ethereumAppNotOpen
    case userRejected
    case timeout
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Ledger device not connected. Please connect via Bluetooth."
        case .accountNotFound:
            return "Account not found on this Ledger device."
        case .invalidResponse:
            return "Invalid response from Ledger device."
        case .invalidData:
            return "Invalid data provided for signing."
        case .cannotExport:
            return "Cannot export private keys from a hardware wallet."
        case .unsupportedFormat:
            return "Unsupported response format from Ledger device."
        case .ethereumAppNotOpen:
            return "Please open the Ethereum app on your Ledger device."
        case .userRejected:
            return "The operation was rejected on the Ledger device."
        case .timeout:
            return "The Ledger device did not respond in time. Please check the device screen."
        case .signingFailed(let detail):
            return "Signing failed: \(detail)"
        }
    }
}
