import Foundation

// MARK: - ENS Resolver
//
// Ethereum Name Service (ENS) resolver for forward and reverse lookups.
// Uses the on-chain ENS Registry and per-name Resolver contracts via eth_call.
//
// Usage in SendTokenView:
// let result = await ENSResolver.shared.parseAddressInput(input)
// switch result {
// case .ensResolved(let name, let address):
//     showENSBadge(name: name)
//     setToAddress(address)
// case .ethereumAddress(let address):
//     setToAddress(address)
// case .ensNotFound(let name):
//     showError("ENS name not found: \(name)")
// case .invalid(let input):
//     showError("Invalid address or ENS name: \(input)")
// }

// MARK: - AddressParseResult

/// Result of parsing a user-provided address input string.
enum AddressParseResult: Equatable {
    /// A valid 0x Ethereum address was provided directly.
    case ethereumAddress(String)
    /// An ENS name was successfully resolved to an address.
    case ensResolved(name: String, address: String)
    /// An ENS name was provided but could not be resolved (no resolver or no address record).
    case ensNotFound(name: String)
    /// The input is neither a valid address nor a valid ENS name.
    case invalid(String)
}

// MARK: - ENSError

enum ENSError: Error, LocalizedError {
    case noResolverFound(String)
    case resolverReturnedZeroAddress
    case rpcCallFailed(String)
    case invalidNameFormat(String)
    case encodingError(String)

    var errorDescription: String? {
        switch self {
        case .noResolverFound(let name):
            return "No resolver found for ENS name: \(name)"
        case .resolverReturnedZeroAddress:
            return "Resolver returned zero address"
        case .rpcCallFailed(let detail):
            return "RPC call failed: \(detail)"
        case .invalidNameFormat(let name):
            return "Invalid ENS name format: \(name)"
        case .encodingError(let detail):
            return "Encoding error: \(detail)"
        }
    }
}

// MARK: - Cache Entry

/// Internal cache entry with a timestamp for TTL-based expiration.
private struct CacheEntry {
    let value: String
    let timestamp: Date

    /// Whether the entry is still valid (within the given TTL).
    func isValid(ttl: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) < ttl
    }
}

// MARK: - ENSResolver

@MainActor
final class ENSResolver {
    static let shared = ENSResolver()

    // MARK: - Constants

    /// ENS Registry contract address on Ethereum Mainnet.
    private let registryAddress = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

    /// The zero address (used to detect "no resolver" responses).
    private let zeroAddress = "0x0000000000000000000000000000000000000000"

    /// Function selector for `resolver(bytes32 node)` on the ENS Registry.
    private let resolverSelector = "0x0178b8bf"

    /// Function selector for `addr(bytes32 node)` on the ENS Resolver.
    private let addrSelector = "0x3b3b57de"

    /// Function selector for `name(bytes32 node)` on the ENS Resolver (reverse records).
    private let nameSelector = "0x691f3431"

    /// Cache TTL: 5 minutes for successful lookups.
    private let cacheTTL: TimeInterval = 300

    // MARK: - Cache

    /// Forward cache: ENS name (lowercased) -> resolved address.
    private var forwardCache: [String: CacheEntry] = [:]

    /// Reverse cache: lowercased address -> ENS name.
    private var reverseCache: [String: CacheEntry] = [:]

    // MARK: - Dependencies

    private let networkManager = NetworkManager.shared

    /// Ethereum Mainnet chain object used for all ENS RPC calls.
    private var ethereumMainnet: Chain {
        return Chain.ethereum
    }

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Resolve an ENS name to an Ethereum address (forward resolution).
    ///
    /// Steps:
    /// 1. Compute the namehash of the ENS name.
    /// 2. Call `resolver(bytes32)` on the ENS Registry to find the resolver contract.
    /// 3. Call `addr(bytes32)` on the resolver to get the Ethereum address.
    ///
    /// - Parameter name: An ENS name such as "vitalik.eth".
    /// - Returns: The resolved checksummed Ethereum address, or `nil` if the name has no address record.
    func resolve(_ name: String) async throws -> String? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard isENSName(normalizedName) else {
            throw ENSError.invalidNameFormat(name)
        }

        // Check cache first
        if let cached = forwardCache[normalizedName], cached.isValid(ttl: cacheTTL) {
            return cached.value
        }

        // Step 1: Compute namehash
        let node = namehash(normalizedName)
        let nodeHex = node.toHexString()

        // Step 2: Get the resolver address from the Registry
        let resolverAddress = try await getResolverAddress(nodeHex: nodeHex)

        guard resolverAddress != zeroAddress else {
            return nil
        }

        // Step 3: Call addr(bytes32) on the resolver
        let callData = addrSelector + nodeHex
        let transaction: [String: Any] = [
            "to": resolverAddress,
            "data": callData
        ]

        let result = try await networkManager.call(transaction: transaction, chain: ethereumMainnet)
        let address = extractAddress(from: result)

        guard address != zeroAddress else {
            return nil
        }

        let checksumAddress = EthereumUtil.toChecksumAddress(address)

        // Cache the successful result
        forwardCache[normalizedName] = CacheEntry(value: checksumAddress, timestamp: Date())

        return checksumAddress
    }

    /// Reverse-resolve an Ethereum address to an ENS name.
    ///
    /// Steps:
    /// 1. Build the reverse name: `<lowercase-hex-address>.addr.reverse`
    /// 2. Compute its namehash.
    /// 3. Call `resolver(bytes32)` on the Registry.
    /// 4. Call `name(bytes32)` on the resolver.
    ///
    /// - Parameter address: A 0x-prefixed Ethereum address.
    /// - Returns: The ENS name associated with the address, or `nil` if none is set.
    func reverseLookup(_ address: String) async throws -> String? {
        guard EthereumUtil.isValidAddress(address) else {
            throw ENSError.invalidNameFormat(address)
        }

        let normalizedAddress = address.lowercased()

        // Check cache first
        if let cached = reverseCache[normalizedAddress], cached.isValid(ttl: cacheTTL) {
            return cached.value
        }

        // Step 1: Build reverse name
        let addrWithout0x = normalizedAddress.replacingOccurrences(of: "0x", with: "")
        let reverseName = "\(addrWithout0x).addr.reverse"

        // Step 2: Compute namehash
        let node = namehash(reverseName)
        let nodeHex = node.toHexString()

        // Step 3: Get resolver from registry
        let resolverAddress = try await getResolverAddress(nodeHex: nodeHex)

        guard resolverAddress != zeroAddress else {
            return nil
        }

        // Step 4: Call name(bytes32) on the resolver
        let callData = nameSelector + nodeHex
        let transaction: [String: Any] = [
            "to": resolverAddress,
            "data": callData
        ]

        let result = try await networkManager.call(transaction: transaction, chain: ethereumMainnet)
        let ensName = decodeString(from: result)

        guard let name = ensName, !name.isEmpty else {
            return nil
        }

        // Cache the successful result
        reverseCache[normalizedAddress] = CacheEntry(value: name, timestamp: Date())

        return name
    }

    /// Check whether the given input looks like an ENS name (ends with .eth or other supported TLDs).
    ///
    /// Currently supports `.eth` names only. Can be extended to support DNS-compatible names
    /// served by ENS (e.g. `.xyz`, `.com` via ENSIP-10 / CCIP-Read).
    func isENSName(_ input: String) -> Bool {
        let trimmed = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Must contain at least one dot and end with .eth
        guard trimmed.hasSuffix(".eth") else { return false }

        // Must have a label before .eth (i.e. not just ".eth")
        let labelPart = trimmed.dropLast(4) // drop ".eth"
        guard !labelPart.isEmpty else { return false }

        // Basic validation: labels should contain only alphanumeric, hyphens, underscores, or dots
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: ".-_"))
        let labelString = String(labelPart)
        guard labelString.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return false
        }

        return true
    }

    /// Smart resolution: determine whether the input is an Ethereum address or an ENS name,
    /// then resolve accordingly.
    ///
    /// - Parameter input: An Ethereum address (0x...) or ENS name (e.g. "vitalik.eth").
    /// - Returns: An `AddressParseResult` describing the outcome.
    func parseAddressInput(_ input: String) async throws -> AddressParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Case 1: Valid Ethereum address
        if EthereumUtil.isValidAddress(trimmed) {
            let checksummed = EthereumUtil.toChecksumAddress(trimmed)
            return .ethereumAddress(checksummed)
        }

        // Case 2: ENS name
        if isENSName(trimmed) {
            do {
                if let resolvedAddress = try await resolve(trimmed) {
                    return .ensResolved(name: trimmed.lowercased(), address: resolvedAddress)
                } else {
                    return .ensNotFound(name: trimmed.lowercased())
                }
            } catch {
                // Resolution failed (e.g. network error) -- treat as not found
                return .ensNotFound(name: trimmed.lowercased())
            }
        }

        // Case 3: Invalid input
        return .invalid(trimmed)
    }

    /// Clear all cached entries.
    func clearCache() {
        forwardCache.removeAll()
        reverseCache.removeAll()
    }

    // MARK: - Namehash

    /// Compute the ENS namehash for a given dot-separated name.
    ///
    /// Algorithm (EIP-137):
    /// ```
    /// namehash("")         = 0x0000...0000  (32 zero bytes)
    /// namehash("eth")      = keccak256(namehash("") + keccak256("eth"))
    /// namehash("foo.eth")  = keccak256(namehash("eth") + keccak256("foo"))
    /// ```
    ///
    /// - Parameter name: A dot-separated ENS name (e.g. "alice.eth"). May be empty.
    /// - Returns: The 32-byte namehash.
    func namehash(_ name: String) -> Data {
        if name.isEmpty {
            return Data(repeating: 0, count: 32)
        }

        // Split by "." and process from right to left
        let labels = name.split(separator: ".").map(String.init)

        var node = Data(repeating: 0, count: 32) // start with empty namehash

        for label in labels.reversed() {
            let labelHash = Keccak256.hash(data: Data(label.utf8))
            var combined = Data()
            combined.append(node)
            combined.append(labelHash)
            node = Keccak256.hash(data: combined)
        }

        return node
    }

    // MARK: - Private Helpers

    /// Query the ENS Registry for the resolver address of a given namehash node.
    ///
    /// - Parameter nodeHex: The hex-encoded namehash (without 0x prefix, 64 hex chars).
    /// - Returns: The resolver contract address (checksummed).
    private func getResolverAddress(nodeHex: String) async throws -> String {
        let callData = resolverSelector + nodeHex

        let transaction: [String: Any] = [
            "to": registryAddress,
            "data": callData
        ]

        let result = try await networkManager.call(transaction: transaction, chain: ethereumMainnet)
        let address = extractAddress(from: result)
        return address
    }

    /// Extract a 20-byte Ethereum address from a 32-byte ABI-encoded return value.
    ///
    /// The return value is a hex string like "0x000000000000000000000000<20-byte-address>".
    /// We take the last 40 hex characters and prefix with "0x".
    ///
    /// - Parameter hexResult: The raw hex string returned by `eth_call`.
    /// - Returns: A lowercase "0x"-prefixed address string.
    private func extractAddress(from hexResult: String) -> String {
        var hex = hexResult
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        // The address is in the last 40 characters of the 64-char (32-byte) word
        guard hex.count >= 40 else {
            return zeroAddress
        }

        let addressHex = String(hex.suffix(40))
        return "0x" + addressHex
    }

    /// Decode a Solidity `string` return value from ABI-encoded hex data.
    ///
    /// ABI encoding for a single `string` return:
    ///   - bytes 0..31:   offset to start of string data (always 0x20 for single return)
    ///   - bytes 32..63:  length of the string in bytes
    ///   - bytes 64+:     the UTF-8 string data (padded to 32-byte boundary)
    ///
    /// - Parameter hexResult: The raw hex string returned by `eth_call`.
    /// - Returns: The decoded string, or `nil` if decoding fails.
    private func decodeString(from hexResult: String) -> String? {
        var hex = hexResult
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        guard let data = Data(hexString: hex) else {
            return nil
        }

        // Need at least 64 bytes (offset + length)
        guard data.count >= 64 else {
            return nil
        }

        // Read the offset (first 32 bytes) - typically 0x20 (32)
        let offsetData = data.prefix(32)
        let offset = offsetData.reduce(0) { ($0 << 8) | Int($1) }

        // Read length at the offset position
        guard offset + 32 <= data.count else {
            return nil
        }

        let lengthData = data[offset..<(offset + 32)]
        let length = lengthData.reduce(0) { ($0 << 8) | Int($1) }

        guard length > 0, offset + 32 + length <= data.count else {
            return nil
        }

        // Read the actual string bytes
        let stringStart = offset + 32
        let stringData = data[stringStart..<(stringStart + length)]

        return String(data: stringData, encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
    }
}
