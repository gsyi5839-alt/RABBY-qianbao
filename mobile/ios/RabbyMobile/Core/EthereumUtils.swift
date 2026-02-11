import Foundation
import CryptoKit
import BigInt
import secp256k1

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
    
    var isEIP1559: Bool {
        return maxFeePerGas != nil && maxPriorityFeePerGas != nil
    }
    
    var type: TransactionType {
        if isEIP1559 {
            return .eip1559
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
    
    func encodeSigned() throws -> Data {
        guard let v = v, let r = r, let s = s else {
            throw EthereumError.transactionNotSigned
        }
        
        if isEIP1559 {
            return try encodeSignedEIP1559(v: v, r: r, s: s)
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
}

// MARK: - Ethereum Signer

class EthereumSigner {
    
    /// Sign transaction with private key
    static func signTransaction(privateKey: Data, transaction: EthereumTransaction) throws -> Data {
        let hash = try EthereumUtil.hashTransaction(transaction)
        let signature = try sign(hash: hash, privateKey: privateKey)
        
        var signedTx = transaction
        signedTx.r = signature.r
        signedTx.s = signature.s
        signedTx.v = signature.v
        
        return try signedTx.encodeSigned()
    }
    
    /// Sign personal message
    static func signMessage(privateKey: Data, message: Data) throws -> Data {
        let hash = EthereumUtil.hashPersonalMessage(message)
        let signature = try sign(hash: hash, privateKey: privateKey)
        
        // Concatenate r, s, v
        var result = Data()
        result.append(signature.r.toData())
        result.append(signature.s.toData())
        result.append(signature.v.toData())
        
        return result
    }
    
    /// Sign EIP-712 typed data
    static func signTypedData(privateKey: Data, typedDataJSON: String) throws -> Data {
        let typedData = try EIP712TypedData.parse(json: typedDataJSON)
        let hash = try typedData.hash()
        let signature = try sign(hash: hash, privateKey: privateKey)
        
        var result = Data()
        result.append(signature.r.toData())
        result.append(signature.s.toData())
        result.append(signature.v.toData())
        
        return result
    }
    
    /// Sign hash with private key using secp256k1
    private static func sign(hash: Data, privateKey: Data) throws -> ECDSASignature {
        let sig = try Secp256k1Helper.sign(hash: hash, privateKey: privateKey)
        
        let r = BigUInt(sig.r)
        let s = BigUInt(sig.s)
        let v = BigUInt(sig.v)
        
        return ECDSASignature(r: r, s: s, v: v)
    }
    
    /// Recover address from signature
    static func recoverAddress(hash: Data, signature: Data) throws -> String {
        guard signature.count == 65 else {
            throw EthereumError.invalidSignature
        }
        
        let r = signature.prefix(32)
        let s = signature.subdata(in: 32..<64)
        let v = signature[64]
        
        // Recovery logic would go here
        // This requires a full secp256k1 implementation
        
        throw EthereumError.notImplemented
    }
}

// MARK: - Supporting Types

struct ECDSASignature {
    let r: BigUInt
    let s: BigUInt
    let v: BigUInt
}

// MARK: - EIP-712 Typed Data

struct EIP712TypedData {
    let domain: [String: Any]
    let message: [String: Any]
    let primaryType: String
    let types: [String: [TypeProperty]]
    
    struct TypeProperty {
        let name: String
        let type: String
    }
    
    static func parse(json: String) throws -> EIP712TypedData {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EthereumError.invalidTypedData
        }
        
        guard let domain = dict["domain"] as? [String: Any],
              let message = dict["message"] as? [String: Any],
              let primaryType = dict["primaryType"] as? String,
              let types = dict["types"] as? [String: [[String: String]]] else {
            throw EthereumError.invalidTypedData
        }
        
        var parsedTypes: [String: [TypeProperty]] = [:]
        for (key, value) in types {
            parsedTypes[key] = value.compactMap { prop in
                guard let name = prop["name"], let type = prop["type"] else { return nil }
                return TypeProperty(name: name, type: type)
            }
        }
        
        return EIP712TypedData(domain: domain, message: message, primaryType: primaryType, types: parsedTypes)
    }
    
    func hash() throws -> Data {
        // EIP-712 structured data hashing
        let domainSeparator = try hashStruct(type: "EIP712Domain", data: domain)
        let messageHash = try hashStruct(type: primaryType, data: message)
        
        var combined = Data([0x19, 0x01])
        combined.append(domainSeparator)
        combined.append(messageHash)
        
        return EthereumUtil.keccak256(combined)
    }
    
    private func hashStruct(type: String, data: [String: Any]) throws -> Data {
        // Implement EIP-712 struct hashing
        // This is a simplified version
        let encoded = try encodeData(type: type, data: data)
        return EthereumUtil.keccak256(encoded)
    }
    
    private func encodeData(type: String, data: [String: Any]) throws -> Data {
        // Implement EIP-712 data encoding
        // This would need full implementation
        throw EthereumError.notImplemented
    }
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
        if self == 0 { return Data([0]) }
        var value = self
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data(bytes)
    }
}
