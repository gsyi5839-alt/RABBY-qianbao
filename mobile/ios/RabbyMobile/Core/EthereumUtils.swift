import Foundation
import CryptoKit
import BigInt
import GenericJSON

/// Ethereum utility functions for address validation, conversion, and transaction handling
class EthereumUtil {
    
    // MARK: - Address Utilities
    
    /// Convert address to EIP-55 checksum address
    static func toChecksumAddress(_ address: String) -> String {
        let lowercaseAddress = address.lowercased().replacingOccurrences(of: "0x", with: "")
        let hash = keccak256(lowercaseAddress.data(using: .utf8)!).hexString
        
        var checksumAddress = "0x"
        for (index, char) in lowercaseAddress.enumerated() {
            let hashChar = hash[hash.index(hash.startIndex, offsetBy: index)]
            if let hashValue = Int(String(hashChar), radix: 16), hashValue >= 8 {
                checksumAddress += String(char).uppercased()
            } else {
                checksumAddress += String(char)
            }
        }
        
        return checksumAddress
    }
    
    /// Validate Ethereum address format
    static func isValidAddress(_ address: String) -> Bool {
        let pattern = "^0x[a-fA-F0-9]{40}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: address.utf16.count)
        return regex?.firstMatch(in: address, range: range) != nil
    }
    
    /// Convert private key to Ethereum address
    static func privateKeyToAddress(_ privateKey: Data) throws -> String {
        guard privateKey.count == 32 else {
            throw EthereumError.invalidPrivateKey
        }
        
        let publicKey = try getPublicKey(from: privateKey)
        let address = try publicKeyToAddress(publicKey)
        return toChecksumAddress(address)
    }
    
    /// Get public key from private key
    static func getPublicKey(from privateKey: Data) throws -> Data {
        // Use secp256k1 curve via Secp256k1Helper
        return try Secp256k1Helper.getPublicKey(privateKey: privateKey)
    }
    
    /// Convert public key to Ethereum address
    static func publicKeyToAddress(_ publicKey: Data) throws -> String {
        // Remove 0x04 prefix if present (uncompressed public key)
        var pubKey = publicKey
        if publicKey.count == 65 && publicKey[0] == 0x04 {
            pubKey = publicKey.suffix(64)
        }
        
        guard pubKey.count == 64 else {
            throw EthereumError.invalidPublicKey
        }
        
        // Keccak256 hash of public key
        let hash = keccak256(pubKey)
        
        // Take last 20 bytes as address
        let address = hash.suffix(20)
        return "0x" + address.hexString
    }
    
    // MARK: - Data Conversion
    
    static func hexToData(_ hex: String) -> Data? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "0x", with: "")
        
        var data = Data()
        var index = hexSanitized.startIndex
        
        while index < hexSanitized.endIndex {
            let nextIndex = hexSanitized.index(index, offsetBy: 2, limitedBy: hexSanitized.endIndex) ?? hexSanitized.endIndex
            let byteString = String(hexSanitized[index..<nextIndex])
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        return data
    }
    
    static func dataToHex(_ data: Data, withPrefix: Bool = true) -> String {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        return withPrefix ? "0x" + hex : hex
    }
    
    // MARK: - Keccak256 Hash
    
    static func keccak256(_ data: Data) -> Data {
        // Using Swift-Keccak or similar library
        return Keccak256.hash(data: data)
    }
    
    static func keccak256(_ string: String) -> Data {
        guard let data = string.data(using: .utf8) else {
            return Data()
        }
        return keccak256(data)
    }
    
    // MARK: - Transaction Hash
    
    static func hashTransaction(_ transaction: EthereumTransaction) throws -> Data {
        let encoded = try transaction.rlpEncode()
        return keccak256(encoded)
    }
    
    // MARK: - Personal Sign Message Hash
    
    static func hashPersonalMessage(_ message: Data) -> Data {
        let prefix = "\u{19}Ethereum Signed Message:\n\(message.count)"
        guard let prefixData = prefix.data(using: .utf8) else {
            return Data()
        }
        
        var combined = Data()
        combined.append(prefixData)
        combined.append(message)
        
        return keccak256(combined)
    }
    
    // MARK: - Address Formatting
    
    /// Format address to abbreviated form (0x1234...5678)
    static func formatAddress(_ address: String, headLength: Int = 6, tailLength: Int = 4) -> String {
        guard address.count > headLength + tailLength + 3 else { return address }
        let start = address.prefix(headLength)
        let end = address.suffix(tailLength)
        return "\(start)...\(end)"
    }

    /// Truncate an Ethereum address to short form: 0x1234...5678
    /// Convenience alias for `formatAddress`.
    static func truncateAddress(_ address: String) -> String {
        return formatAddress(address)
    }

    /// Encode an address string as 32-byte left-padded Data suitable for ABI encoding.
    /// The "0x" prefix is optional. Returns the raw bytes (not hex string).
    static func padAddress(_ address: String) -> Data {
        return abiEncodeAddress(address)
    }
    
    // MARK: - ABI Encoding Utilities

    /// Encode an Ethereum address as a 32-byte ABI parameter (left-padded with zeros).
    /// Accepts addresses with or without the "0x" prefix.
    static func abiEncodeAddress(_ address: String) -> Data {
        let cleaned = address.lowercased().replacingOccurrences(of: "0x", with: "")
        guard let addressData = hexToData(cleaned), addressData.count == 20 else {
            // Return 32 zero bytes on invalid input to keep encoding well-formed.
            return Data(repeating: 0, count: 32)
        }
        // 12 bytes zero-padding + 20 bytes address = 32 bytes
        var result = Data(repeating: 0, count: 12)
        result.append(addressData)
        return result
    }

    /// Encode a BigUInt value as a 32-byte ABI uint256 parameter (big-endian, left-padded).
    static func abiEncodeUint256(_ value: BigUInt) -> Data {
        return value.toPaddedData(length: 32)
    }

    /// Encode a dynamic `bytes` value using ABI rules.
    ///
    /// When used as a standalone encoding (not inside a tuple), returns:
    ///   length (32 bytes) + data padded to next 32-byte boundary
    ///
    /// The caller is responsible for placing the correct offset word
    /// in the head section when this is part of a multi-parameter encoding.
    static func abiEncodeBytes(_ data: Data) -> Data {
        // Length word (uint256)
        let lengthWord = abiEncodeUint256(BigUInt(data.count))

        // Data padded to 32-byte boundary
        let paddingLength = (32 - (data.count % 32)) % 32
        var result = lengthWord
        result.append(data)
        if paddingLength > 0 {
            result.append(Data(repeating: 0, count: paddingLength))
        }
        return result
    }

    /// Build a complete ABI-encoded function call from a 4-byte selector and
    /// a list of already-encoded 32-byte parameter words.
    ///
    /// For functions that contain only static types (address, uint256, etc.),
    /// simply concatenate selector + params.
    ///
    /// For functions with dynamic types, the caller must provide the correct
    /// offset words in `staticParams` and the tail data in `dynamicData`.
    static func abiEncodeFunctionCall(selector: Data, staticParams: [Data], dynamicData: Data = Data()) -> Data {
        var result = Data(selector.prefix(4))
        for param in staticParams {
            result.append(param)
        }
        result.append(dynamicData)
        return result
    }

    // MARK: - Wei/Ether Conversion
    
    static func weiToEther(_ wei: BigUInt) -> Decimal {
        let ether = Decimal(string: wei.description) ?? 0
        return ether / pow(10, 18)
    }
    
    static func etherToWei(_ ether: Decimal) -> BigUInt {
        let wei = ether * pow(10, 18)
        let weiString = NSDecimalNumber(decimal: wei).stringValue
        return BigUInt(weiString) ?? 0
    }
    
    static func weiToGwei(_ wei: BigUInt) -> Decimal {
        let gwei = Decimal(string: wei.description) ?? 0
        return gwei / pow(10, 9)
    }
    
    static func gweiToWei(_ gwei: Decimal) -> BigUInt {
        let wei = gwei * pow(10, 9)
        let weiString = NSDecimalNumber(decimal: wei).stringValue
        return BigUInt(weiString) ?? 0
    }
}

// MARK: - EIP-712 (Typed Data v4)

enum EIP712SignerError: Error, LocalizedError {
    case invalidJSON
    case unsupported
    case missingType(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid EIP-712 typed data JSON"
        case .unsupported:
            return "Unsupported EIP-712 typed data"
        case .missingType(let name):
            return "Missing type definition for '\(name)'"
        case .invalidField(let name):
            return "Invalid field: '\(name)'"
        }
    }
}

/// EIP-712 field definition: { "name": "...", "type": "..." }
struct EIP712Field: Codable, Equatable {
    let name: String
    let type: String
}

/// EIP-712 TypedData: { types, primaryType, domain, message }
struct TypedData: Codable {
    let types: [String: [EIP712Field]]
    let primaryType: String
    let domain: JSON
    let message: JSON

    /// Compute the final signable hash: keccak256("\x19\x01" || domainSeparator || hashStruct(primaryType, message))
    func signableHash() throws -> Data {
        let domainSeparator = try hashStruct(typeName: "EIP712Domain", data: domain)
        let messageHash = try hashStruct(typeName: primaryType, data: message)

        var payload = Data([0x19, 0x01])
        payload.append(domainSeparator)
        payload.append(messageHash)

        return Keccak256.hash(data: payload)
    }

    // MARK: - encodeType

    /// Build the canonical type string for a struct, including referenced types alphabetically.
    /// e.g. "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
    func encodeType(_ typeName: String) throws -> String {
        guard let fields = types[typeName] else {
            throw EIP712SignerError.missingType(typeName)
        }

        // Collect all referenced struct types (transitive)
        var referenced = Set<String>()
        try collectDependencies(typeName: typeName, into: &referenced)
        referenced.remove(typeName) // primary is placed first, not in the sorted tail

        let sortedRefs = referenced.sorted()

        var result = encodeTypeSingle(typeName, fields: fields)
        for ref in sortedRefs {
            if let refFields = types[ref] {
                result += encodeTypeSingle(ref, fields: refFields)
            }
        }
        return result
    }

    /// Encode a single struct type: "TypeName(type1 name1,type2 name2,...)"
    private func encodeTypeSingle(_ typeName: String, fields: [EIP712Field]) -> String {
        let inner = fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")
        return "\(typeName)(\(inner))"
    }

    /// Recursively collect all struct type dependencies for a given type name.
    private func collectDependencies(typeName: String, into set: inout Set<String>) throws {
        guard !set.contains(typeName) else { return }
        guard let fields = types[typeName] else { return }

        set.insert(typeName)

        for field in fields {
            let baseType = stripArraySuffix(field.type)
            if types[baseType] != nil {
                try collectDependencies(typeName: baseType, into: &set)
            }
        }
    }

    // MARK: - typeHash

    /// typeHash = keccak256(encodeType(typeName))
    func typeHash(_ typeName: String) throws -> Data {
        let encoded = try encodeType(typeName)
        return Keccak256.hash(data: Data(encoded.utf8))
    }

    // MARK: - hashStruct

    /// hashStruct(typeName, data) = keccak256(typeHash || encodeData(typeName, data))
    func hashStruct(typeName: String, data: JSON) throws -> Data {
        let tHash = try typeHash(typeName)
        let encodedData = try encodeData(typeName: typeName, data: data)

        var combined = Data()
        combined.append(tHash)
        combined.append(encodedData)

        return Keccak256.hash(data: combined)
    }

    // MARK: - encodeData

    /// Encode each field of a struct according to EIP-712 rules.
    /// Returns the concatenated ABI-encoded values (without the typeHash prefix -- that is prepended by hashStruct).
    func encodeData(typeName: String, data: JSON) throws -> Data {
        guard let fields = types[typeName] else {
            throw EIP712SignerError.missingType(typeName)
        }

        var result = Data()

        for field in fields {
            let value: JSON
            if case .object(let obj) = data, let v = obj[field.name] {
                value = v
            } else {
                // Missing fields are treated as their type's zero value
                value = .null
            }

            let encoded = try encodeValue(type: field.type, value: value)
            result.append(encoded)
        }

        return result
    }

    // MARK: - encodeValue

    /// Encode a single value according to its EIP-712 type.
    /// Returns exactly 32 bytes (ABI word) for atomic types, or hashed result for dynamic types.
    func encodeValue(type: String, value: JSON) throws -> Data {
        // Array type: e.g. "uint256[]" or "Person[]"
        if type.hasSuffix("[]") {
            let elementType = String(type.dropLast(2))
            guard case .array(let arr) = value else {
                // null or non-array -> hash of empty
                return Keccak256.hash(data: Data())
            }
            var concat = Data()
            for elem in arr {
                concat.append(try encodeValue(type: elementType, value: elem))
            }
            return Keccak256.hash(data: concat)
        }

        // Struct type (custom type defined in `types`)
        if types[type] != nil {
            if value.isNull {
                return Data(repeating: 0, count: 32)
            }
            let structHash = try hashStruct(typeName: type, data: value)
            return structHash
        }

        // Atomic / built-in types
        return try encodeAtomicValue(type: type, value: value)
    }

    /// Encode an atomic (non-struct, non-array) EIP-712 value into a 32-byte ABI word.
    private func encodeAtomicValue(type: String, value: JSON) throws -> Data {
        // bytes (dynamic)
        if type == "bytes" {
            let raw = extractBytes(value)
            return Keccak256.hash(data: raw)
        }

        // string
        if type == "string" {
            if case .string(let str) = value {
                return Keccak256.hash(data: Data(str.utf8))
            }
            return Keccak256.hash(data: Data())
        }

        // bytesN (fixed size, e.g. bytes32)
        if type.hasPrefix("bytes") {
            let raw = extractBytes(value)
            // Right-pad to 32 bytes
            var padded = Data(repeating: 0, count: 32)
            let copyLen = min(raw.count, 32)
            padded.replaceSubrange(0..<copyLen, with: raw.prefix(copyLen))
            return padded
        }

        // address
        if type == "address" {
            if case .string(let str) = value {
                var clean = str.lowercased()
                if clean.hasPrefix("0x") { clean = String(clean.dropFirst(2)) }
                guard let addrData = Data(hexString: clean), addrData.count == 20 else {
                    throw EIP712SignerError.invalidField("address: \(str)")
                }
                return leftPad32(addrData)
            }
            return Data(repeating: 0, count: 32)
        }

        // bool
        if type == "bool" {
            if case .bool(let b) = value {
                return leftPad32(Data([b ? 1 : 0]))
            }
            if case .number(let n) = value {
                return leftPad32(Data([n != 0 ? 1 : 0]))
            }
            return Data(repeating: 0, count: 32)
        }

        // uint<N> or int<N>
        if type.hasPrefix("uint") || type.hasPrefix("int") {
            return try encodeIntValue(type: type, value: value)
        }

        throw EIP712SignerError.invalidField("Unsupported type: \(type)")
    }

    /// Encode uint/int value into 32-byte big-endian (two's complement for int).
    private func encodeIntValue(type: String, value: JSON) throws -> Data {
        let isUnsigned = type.hasPrefix("uint")

        // Extract the numeric value
        var bigValue: BigInt
        switch value {
        case .number(let n):
            // Handle integer values that may come as floating point from JSON
            if n == n.rounded(.towardZero) && abs(n) < 1e18 {
                bigValue = BigInt(Int64(n))
            } else {
                // Large numbers may lose precision -- fallback to string
                let formatted = String(format: "%.0f", n)
                bigValue = BigInt(formatted) ?? BigInt(0)
            }
        case .string(let s):
            // Support hex strings like "0x1" or decimal strings
            if s.hasPrefix("0x") || s.hasPrefix("0X") {
                bigValue = BigInt(String(s.dropFirst(2)), radix: 16) ?? BigInt(0)
            } else {
                bigValue = BigInt(s) ?? BigInt(0)
            }
        default:
            bigValue = BigInt(0)
        }

        if isUnsigned {
            // Unsigned: simple big-endian 32 bytes
            let magnitude = BigUInt(bigValue.magnitude)
            return magnitude.toPaddedData(length: 32)
        } else {
            // Signed: two's complement 32 bytes
            if bigValue >= 0 {
                let magnitude = BigUInt(bigValue.magnitude)
                return magnitude.toPaddedData(length: 32)
            } else {
                // Two's complement: 2^256 + value
                let twoTo256 = BigUInt(1) << 256
                let complement = twoTo256 - BigUInt(bigValue.magnitude)
                return complement.toPaddedData(length: 32)
            }
        }
    }

    // MARK: - Helpers

    /// Strip trailing "[]" from a type name (to get the base type for arrays).
    private func stripArraySuffix(_ type: String) -> String {
        if type.hasSuffix("[]") {
            return String(type.dropLast(2))
        }
        return type
    }

    /// Left-pad data to 32 bytes (ABI word alignment).
    private func leftPad32(_ data: Data) -> Data {
        if data.count >= 32 { return data.suffix(32) }
        return Data(repeating: 0, count: 32 - data.count) + data
    }

    /// Extract raw bytes from a JSON value (expects hex string).
    private func extractBytes(_ value: JSON) -> Data {
        switch value {
        case .string(let str):
            var clean = str
            if clean.hasPrefix("0x") { clean = String(clean.dropFirst(2)) }
            return Data(hexString: clean) ?? Data()
        default:
            return Data()
        }
    }
}

struct EIP712Signer {
    /// Compute the EIP-712 signable hash (keccak256(0x1901 || domainSeparator || messageHash)).
    static func signableHash(typedDataJSON: String) throws -> Data {
        guard let data = typedDataJSON.data(using: .utf8) else {
            throw EIP712SignerError.invalidJSON
        }

        let typedData = try JSONDecoder().decode(TypedData.self, from: data)
        return try typedData.signableHash()
    }
}

// MARK: - Ethereum Transaction Model

struct EthereumTransaction {
    var to: String?
    var from: String
    var nonce: BigUInt
    var value: BigUInt
    var data: Data
    var gasLimit: BigUInt
    var chainId: Int
    
    // EIP-1559
    var maxFeePerGas: BigUInt?
    var maxPriorityFeePerGas: BigUInt?
    
    // Legacy
    var gasPrice: BigUInt?
    
    // Signature
    var v: BigUInt?
    var r: BigUInt?
    var s: BigUInt?
    
    // EIP-2930
    var accessList: [[String: Any]]?

    var isEIP1559: Bool {
        return maxFeePerGas != nil && maxPriorityFeePerGas != nil
    }

    var isEIP2930: Bool {
        return !isEIP1559 && accessList != nil
    }

    var type: TransactionType {
        if isEIP1559 {
            return .eip1559
        }
        if isEIP2930 {
            return .eip2930
        }
        return .legacy
    }

    enum TransactionType: Int {
        case legacy = 0
        case eip2930 = 1
        case eip1559 = 2
    }
    
    // MARK: - RLP Encoding
    
    func rlpEncode() throws -> Data {
        if isEIP1559 {
            return try encodeEIP1559()
        } else if isEIP2930 {
            return try encodeEIP2930()
        } else {
            return try encodeLegacy()
        }
    }
    
    private func encodeLegacy() throws -> Data {
        let items: [Any] = [
            nonce.toData(),
            (gasPrice ?? 0).toData(),
            gasLimit.toData(),
            to?.hexToData() ?? Data(),
            value.toData(),
            data,
            chainId,
            0, // r placeholder for unsigned
            0  // s placeholder for unsigned
        ]
        
        return try RLP.encode(items)
    }
    
    private func encodeEIP1559() throws -> Data {
        let items: [Any] = [
            chainId,
            nonce.toData(),
            (maxPriorityFeePerGas ?? 0).toData(),
            (maxFeePerGas ?? 0).toData(),
            gasLimit.toData(),
            to?.hexToData() ?? Data(),
            value.toData(),
            data,
            [] // access list (empty for basic transactions)
        ]

        let encoded = try RLP.encode(items)
        var result = Data([0x02]) // EIP-1559 transaction type
        result.append(encoded)

        return result
    }

    private func encodeEIP2930() throws -> Data {
        let items: [Any] = [
            chainId,
            nonce.toData(),
            (gasPrice ?? 0).toData(),
            gasLimit.toData(),
            to?.hexToData() ?? Data(),
            value.toData(),
            data,
            accessList ?? [] as [Any] // access list
        ]

        let encoded = try RLP.encode(items)
        var result = Data([0x01]) // EIP-2930 transaction type
        result.append(encoded)

        return result
    }
    
    func encodeSigned() throws -> Data {
        guard let v = v, let r = r, let s = s else {
            throw EthereumError.transactionNotSigned
        }

        if isEIP1559 {
            return try encodeSignedEIP1559(v: v, r: r, s: s)
        } else if isEIP2930 {
            return try encodeSignedEIP2930(v: v, r: r, s: s)
        } else {
            return try encodeSignedLegacy(v: v, r: r, s: s)
        }
    }
    
    private func encodeSignedLegacy(v: BigUInt, r: BigUInt, s: BigUInt) throws -> Data {
        let items: [Any] = [
            nonce.toData(),
            (gasPrice ?? 0).toData(),
            gasLimit.toData(),
            to?.hexToData() ?? Data(),
            value.toData(),
            data,
            v.toData(),
            r.toData(),
            s.toData()
        ]
        
        return try RLP.encode(items)
    }
    
    private func encodeSignedEIP1559(v: BigUInt, r: BigUInt, s: BigUInt) throws -> Data {
        let items: [Any] = [
            chainId,
            nonce.toData(),
            (maxPriorityFeePerGas ?? 0).toData(),
            (maxFeePerGas ?? 0).toData(),
            gasLimit.toData(),
            to?.hexToData() ?? Data(),
            value.toData(),
            data,
            [], // access list
            v.toData(),
            r.toData(),
            s.toData()
        ]

        let encoded = try RLP.encode(items)
        var result = Data([0x02]) // EIP-1559 transaction type
        result.append(encoded)

        return result
    }

    private func encodeSignedEIP2930(v: BigUInt, r: BigUInt, s: BigUInt) throws -> Data {
        let items: [Any] = [
            chainId,
            nonce.toData(),
            (gasPrice ?? 0).toData(),
            gasLimit.toData(),
            to?.hexToData() ?? Data(),
            value.toData(),
            data,
            accessList ?? [] as [Any], // access list
            v.toData(),
            r.toData(),
            s.toData()
        ]

        let encoded = try RLP.encode(items)
        var result = Data([0x01]) // EIP-2930 transaction type
        result.append(encoded)

        return result
    }
}

// MARK: - Ethereum Signer

class EthereumSigner {
    
    /// Sign transaction with private key
    static func signTransaction(privateKey: Data, transaction: EthereumTransaction) throws -> Data {
        let hash = try EthereumUtil.hashTransaction(transaction)
        let signature = try sign(hash: hash, privateKey: privateKey)

        var signedTx = transaction
        signedTx.r = BigUInt(signature.r)
        signedTx.s = BigUInt(signature.s)

        // EIP-155 / typed-tx v rules:
        // - Legacy (EIP-155): v = recid + 35 + chainId * 2
        // - EIP-2930 (type 0x01): yParity = recid (0/1)
        // - EIP-1559 (type 0x02): yParity = recid (0/1)
        let yParity = BigUInt(Int(signature.recid & 1))
        switch transaction.type {
        case .eip1559, .eip2930:
            signedTx.v = yParity
        case .legacy:
            signedTx.v = yParity + BigUInt(35 + transaction.chainId * 2)
        }

        return try signedTx.encodeSigned()
    }
    
    /// Sign personal message
    static func signMessage(privateKey: Data, message: Data) throws -> Data {
        let hash = EthereumUtil.hashPersonalMessage(message)
        let signature = try sign(hash: hash, privateKey: privateKey)
        
        // Concatenate r(32), s(32), v(1) where v is 27/28.
        let v = UInt8(27 + (signature.recid & 1))
        return signature.r + signature.s + Data([v])
    }
    
    /// Sign EIP-712 typed data
    static func signTypedData(privateKey: Data, typedDataJSON: String) throws -> Data {
        let hash = try EIP712Signer.signableHash(typedDataJSON: typedDataJSON)
        let signature = try sign(hash: hash, privateKey: privateKey)
        
        // Concatenate r(32), s(32), v(1) where v is 27/28.
        let v = UInt8(27 + (signature.recid & 1))
        return signature.r + signature.s + Data([v])
    }
    
    /// Sign hash with private key using secp256k1
    private static func sign(hash: Data, privateKey: Data) throws -> ECDSASignature {
        let sig = try Secp256k1Helper.sign(hash: hash, privateKey: privateKey)
        return ECDSASignature(r: sig.r, s: sig.s, recid: sig.recid)
    }
    
    /// Recover address from signature
    static func recoverAddress(hash: Data, signature: Data) throws -> String {
        guard signature.count == 65 else {
            throw EthereumError.invalidSignature
        }
        
        _ = signature.prefix(32)
        _ = signature.subdata(in: 32..<64)
        _ = signature[64]
        
        // Recovery logic would go here
        // This requires a full secp256k1 implementation
        
        throw EthereumError.notImplemented
    }
}

// MARK: - Supporting Types

struct ECDSASignature {
    /// 32-byte r component
    let r: Data
    /// 32-byte s component (low-s, EIP-2)
    let s: Data
    /// Recovery id (0/1 in Ethereum usage)
    let recid: Int32
}

// MARK: - Errors

enum EthereumError: Error, LocalizedError {
    case invalidPrivateKey
    case invalidPublicKey
    case invalidAddress
    case invalidSignature
    case invalidTypedData
    case transactionNotSigned
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid private key format"
        case .invalidPublicKey:
            return "Invalid public key format"
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .invalidSignature:
            return "Invalid signature format"
        case .invalidTypedData:
            return "Invalid EIP-712 typed data"
        case .transactionNotSigned:
            return "Transaction has not been signed"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}

// MARK: - Extensions

extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    func hexToData() -> Data? {
        return EthereumUtil.hexToData(self)
    }
}

extension BigUInt {
    /// Serialize BigUInt to minimal Data representation (no leading zeros)
    func toData() -> Data {
        // RLP encodes integer 0 as empty bytes (0x80 at the RLP layer).
        if self == 0 { return Data() }
        var value = self
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data(bytes)
    }

    /// Serialize BigUInt to fixed-length big-endian bytes (left padded with zeros).
    /// Used for message signatures where r/s must be 32 bytes.
    func toPaddedData(length: Int) -> Data {
        let minimal = toData()
        if minimal.count == length { return minimal }
        if minimal.count > length { return minimal.suffix(length) }
        return Data(repeating: 0, count: length - minimal.count) + minimal
    }
}
