import Foundation
import CryptoKit

/// BIP44 HD Wallet key derivation implementation
/// Reference: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
/// Path format: m / purpose' / coin_type' / account' / change / address_index
class BIP44 {
    
    /// Derive private key from seed using BIP44 path
    /// @param seed: BIP39 seed (64 bytes)
    /// @param path: Derivation path (e.g., "m/44'/60'/0'/0/0")
    /// @returns: 32-byte private key
    static func derivePrivateKey(seed: Data, path: String) throws -> Data {
        // Parse path
        let components = try parsePath(path)
        
        // Start with master key
        var key = try deriveMasterKey(seed: seed)
        
        // Derive each level
        for component in components {
            key = try deriveChild(parent: key, index: component.index, hardened: component.hardened)
        }
        
        return key.privateKey
    }
    
    /// Derive public key from private key
    static func derivePublicKey(privateKey: Data) throws -> Data {
        // This requires secp256k1 implementation
        // For now, use placeholder
        return try Secp256k1Helper.getPublicKey(privateKey: privateKey)
    }
    
    /// Derive Ethereum address from private key
    static func deriveAddress(privateKey: Data) throws -> String {
        return try EthereumUtil.privateKeyToAddress(privateKey)
    }
    
    // MARK: - BIP32 Master Key Derivation
    
    private static func deriveMasterKey(seed: Data) throws -> ExtendedKey {
        guard seed.count >= 16 else {
            throw BIP44Error.invalidSeedLength
        }
        
        // HMAC-SHA512 with key "Bitcoin seed"
        let hmacKey = "Bitcoin seed".data(using: .utf8)!
        let hmacResult = hmacSHA512(key: hmacKey, data: seed)
        
        let privateKey = hmacResult.prefix(32)
        let chainCode = hmacResult.suffix(32)
        
        return ExtendedKey(privateKey: privateKey, chainCode: chainCode)
    }
    
    // MARK: - Child Key Derivation
    
    private static func deriveChild(parent: ExtendedKey, index: UInt32, hardened: Bool) throws -> ExtendedKey {
        var data = Data()
        
        if hardened {
            // Hardened derivation: 0x00 || ser256(kpar) || ser32(i)
            data.append(0x00)
            data.append(parent.privateKey)
        } else {
            // Normal derivation: serP(point(kpar)) || ser32(i)
            let publicKey = try derivePublicKey(privateKey: parent.privateKey)
            data.append(publicKey)
        }
        
        var indexBytes = index.bigEndian
        data.append(Data(bytes: &indexBytes, count: 4))
        
        // HMAC-SHA512
        let hmacResult = hmacSHA512(key: parent.chainCode, data: data)
        
        let il = hmacResult.prefix(32)
        let ir = hmacResult.suffix(32)
        
        // Calculate child private key: parse256(IL) + kpar (mod n)
        let childPrivateKey = try addPrivateKeys(il, parent.privateKey)
        
        return ExtendedKey(privateKey: childPrivateKey, chainCode: ir)
    }
    
    // MARK: - Path Parsing
    
    private struct PathComponent {
        let index: UInt32
        let hardened: Bool
    }
    
    private static func parsePath(_ path: String) throws -> [PathComponent] {
        var components: [PathComponent] = []
        
        // Remove 'm/' prefix
        var cleanPath = path
        if cleanPath.hasPrefix("m/") {
            cleanPath = String(cleanPath.dropFirst(2))
        } else if cleanPath.hasPrefix("M/") {
            cleanPath = String(cleanPath.dropFirst(2))
        }
        
        // Parse each level
        let levels = cleanPath.split(separator: "/")
        for level in levels {
            var levelStr = String(level)
            var hardened = false
            
            // Check for hardened marker (')
            if levelStr.hasSuffix("'") || levelStr.hasSuffix("h") {
                hardened = true
                levelStr = String(levelStr.dropLast())
            }
            
            guard let index = UInt32(levelStr) else {
                throw BIP44Error.invalidPathFormat
            }
            
            // Hardened keys have index >= 2^31
            let actualIndex = hardened ? (index | 0x80000000) : index
            
            components.append(PathComponent(index: actualIndex, hardened: hardened))
        }
        
        return components
    }
    
    // MARK: - Cryptographic Helpers
    
    private static func hmacSHA512(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let signature = HMAC<SHA512>.authenticationCode(for: data, using: symmetricKey)
        return Data(signature)
    }
    
    private static func addPrivateKeys(_ key1: Data, _ key2: Data) throws -> Data {
        // This is a simplified version
        // Real implementation needs proper modular arithmetic with secp256k1's order
        guard key1.count == 32 && key2.count == 32 else {
            throw BIP44Error.invalidKeyLength
        }
        
        // For now, simple XOR (NOT CORRECT - needs proper secp256k1 implementation)
        // TODO: Replace with real secp256k1 scalar addition
        var result = Data(count: 32)
        for i in 0..<32 {
            result[i] = key1[i] ^ key2[i]
        }
        
        return result
    }
    
    // MARK: - Extended Key
    
    private struct ExtendedKey {
        let privateKey: Data
        let chainCode: Data
    }
}

// MARK: - Standard BIP44 Paths

extension BIP44 {
    /// Ethereum mainnet path: m/44'/60'/0'/0
    static let ethereumPath = "m/44'/60'/0'/0"
    
    /// Get address at specific index
    static func getEthereumAddress(seed: Data, index: Int) throws -> String {
        let path = "\(ethereumPath)/\(index)"
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        return try deriveAddress(privateKey: privateKey)
    }
    
    /// Get private key at specific index
    static func getEthereumPrivateKey(seed: Data, index: Int) throws -> Data {
        let path = "\(ethereumPath)/\(index)"
        return try derivePrivateKey(seed: seed, path: path)
    }
}

// MARK: - Errors

enum BIP44Error: Error, LocalizedError {
    case invalidSeedLength
    case invalidPathFormat
    case invalidKeyLength
    case derivationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidSeedLength:
            return "Seed must be at least 16 bytes"
        case .invalidPathFormat:
            return "Invalid BIP44 path format"
        case .invalidKeyLength:
            return "Invalid key length"
        case .derivationFailed:
            return "Key derivation failed"
        }
    }
}
