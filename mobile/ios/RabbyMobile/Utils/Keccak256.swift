import Foundation
import CryptoKit
import CryptoSwift

/// Keccak256 hash implementation using CryptoSwift
/// This is the correct hash algorithm used by Ethereum (NOT SHA256!)
class Keccak256 {
    
    /// Compute Keccak256 hash of data
    /// @param data: Input data to hash
    /// @returns: 32-byte Keccak256 hash
    static func hash(data: Data) -> Data {
        // Use CryptoSwift's Keccak256 implementation
        let bytes = Array(data)
        let hashedBytes = bytes.sha3(.keccak256)
        return Data(hashedBytes)
    }
    
    /// Compute Keccak256 hash of string (UTF-8 encoded)
    static func hash(string: String) -> Data {
        guard let data = string.data(using: .utf8) else {
            return Data()
        }
        return hash(data: data)
    }
    
    /// Compute Keccak256 hash and return hex string
    static func hashToHex(data: Data) -> String {
        let hashData = hash(data: data)
        return "0x" + hashData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Compute Keccak256 hash of hex string
    static func hashHex(hex: String) -> Data {
        var cleanHex = hex
        if cleanHex.hasPrefix("0x") {
            cleanHex = String(cleanHex.dropFirst(2))
        }
        
        guard let data = Data(hexString: cleanHex) else {
            return Data()
        }
        
        return hash(data: data)
    }
}

// MARK: - Data Extension

extension Data {
    /// Create Data from hex string
    init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }
        
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Convert Data to hex string
    func toHexString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}
