import Foundation
import CryptoKit
import secp256k1

/// Secp256k1 signing helper for Ethereum transactions using secp256k1.swift
/// Full production-ready implementation with proper secp256k1 support
class Secp256k1Helper {
    
    // MARK: - Core Signing Functions
    
    /// Sign message hash with private key (ECDSA signature)
    /// @param hash: 32-byte message hash (typically Keccak256)
    /// @param privateKey: 32-byte secp256k1 private key
    /// @returns: (r, s, recid) signature tuple where recid is 0/1 (Ethereum uses yParity) in practice
    ///
    /// Note: We enforce low-s (EIP-2). If normalization changes `s`, the recovery id must be flipped.
    static func sign(hash: Data, privateKey: Data) throws -> (r: Data, s: Data, recid: Int32) {
        guard hash.count == 32 else {
            throw Secp256k1Error.invalidHashLength
        }
        
        guard privateKey.count == 32 else {
            throw Secp256k1Error.invalidPrivateKeyLength
        }
        
        // Create secp256k1 context
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw Secp256k1Error.contextCreationFailed
        }
        defer { secp256k1_context_destroy(context) }
        
        // Create signature
        var signature = secp256k1_ecdsa_recoverable_signature()
        let result = hash.withUnsafeBytes { hashPtr in
            privateKey.withUnsafeBytes { keyPtr in
                secp256k1_ecdsa_sign_recoverable(
                    context,
                    &signature,
                    hashPtr.bindMemory(to: UInt8.self).baseAddress!,
                    keyPtr.bindMemory(to: UInt8.self).baseAddress!,
                    nil,
                    nil
                )
            }
        }
        
        guard result == 1 else {
            throw Secp256k1Error.signingFailed
        }
        
        // Convert to normal signature so we can normalize to low-s (EIP-2).
        var normalSig = secp256k1_ecdsa_signature()
        secp256k1_ecdsa_recoverable_signature_convert(context, &normalSig, &signature)
        
        var normalizedSig = secp256k1_ecdsa_signature()
        let didNormalize = secp256k1_ecdsa_signature_normalize(context, &normalizedSig, &normalSig)
        
        // Serialize normalized signature to compact 64 bytes (r||s).
        var output = [UInt8](repeating: 0, count: 64)
        secp256k1_ecdsa_signature_serialize_compact(context, &output, &normalizedSig)
        
        // Extract recovery id from the original recoverable signature, then flip if normalized.
        var recid: Int32 = 0
        var recoverableCompact = [UInt8](repeating: 0, count: 64)
        secp256k1_ecdsa_recoverable_signature_serialize_compact(context, &recoverableCompact, &recid, &signature)
        if didNormalize == 1 {
            recid ^= 1
        }
        
        let r = Data(output[0..<32])
        let s = Data(output[32..<64])
        
        return (r, s, recid)
    }
    
    /// Get uncompressed public key from private key
    /// @param privateKey: 32-byte secp256k1 private key
    /// @returns: 64-byte uncompressed public key (x || y coordinates, without 0x04 prefix)
    static func getPublicKey(privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw Secp256k1Error.invalidPrivateKeyLength
        }
        
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN)) else {
            throw Secp256k1Error.contextCreationFailed
        }
        defer { secp256k1_context_destroy(context) }
        
        // Create public key
        var publicKey = secp256k1_pubkey()
        let result = privateKey.withUnsafeBytes { keyPtr in
            secp256k1_ec_pubkey_create(
                context,
                &publicKey,
                keyPtr.bindMemory(to: UInt8.self).baseAddress!
            )
        }
        
        guard result == 1 else {
            throw Secp256k1Error.publicKeyCreationFailed
        }
        
        // Serialize to uncompressed format
        var output = [UInt8](repeating: 0, count: 65)
        var outputLen = 65
        
        secp256k1_ec_pubkey_serialize(
            context,
            &output,
            &outputLen,
            &publicKey,
            UInt32(SECP256K1_EC_UNCOMPRESSED)
        )
        
        // Remove 0x04 prefix and return 64 bytes
        return Data(output[1..<65])
    }

    /// Get compressed public key from private key
    /// @param privateKey: 32-byte secp256k1 private key
    /// @returns: 33-byte compressed public key (0x02/0x03 prefix + 32-byte x)
    static func getCompressedPublicKey(privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw Secp256k1Error.invalidPrivateKeyLength
        }
        
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN)) else {
            throw Secp256k1Error.contextCreationFailed
        }
        defer { secp256k1_context_destroy(context) }
        
        var publicKey = secp256k1_pubkey()
        let result = privateKey.withUnsafeBytes { keyPtr in
            secp256k1_ec_pubkey_create(
                context,
                &publicKey,
                keyPtr.bindMemory(to: UInt8.self).baseAddress!
            )
        }
        
        guard result == 1 else {
            throw Secp256k1Error.publicKeyCreationFailed
        }
        
        var output = [UInt8](repeating: 0, count: 33)
        var outputLen = 33
        secp256k1_ec_pubkey_serialize(
            context,
            &output,
            &outputLen,
            &publicKey,
            UInt32(SECP256K1_EC_COMPRESSED)
        )
        return Data(output[0..<outputLen])
    }
    
    /// Recover public key from signature (Ethereum-style)
    /// @param hash: 32-byte message hash
    /// @param r: 32-byte r component
    /// @param s: 32-byte s component  
    /// @param v: Recovery id (27 or 28)
    /// @returns: 64-byte uncompressed public key
    static func recoverPublicKey(hash: Data, r: Data, s: Data, v: UInt8) throws -> Data {
        guard hash.count == 32 && r.count == 32 && s.count == 32 else {
            throw Secp256k1Error.invalidSignature
        }
        
        let recid = Int32(v) - 27
        guard recid >= 0 && recid <= 3 else {
            throw Secp256k1Error.invalidRecoveryId
        }
        
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_VERIFY)) else {
            throw Secp256k1Error.contextCreationFailed
        }
        defer { secp256k1_context_destroy(context) }
        
        // Reconstruct signature
        var signature = secp256k1_ecdsa_recoverable_signature()
        var compactSig = [UInt8](repeating: 0, count: 64)
        r.copyBytes(to: &compactSig, count: 32)
        let sBytes = [UInt8](s)
        for i in 0..<min(sBytes.count, 32) { compactSig[32 + i] = sBytes[i] }
        
        let parseResult = secp256k1_ecdsa_recoverable_signature_parse_compact(
            context,
            &signature,
            compactSig,
            recid
        )
        
        guard parseResult == 1 else {
            throw Secp256k1Error.signatureParsingFailed
        }
        
        // Recover public key
        var publicKey = secp256k1_pubkey()
        let recoverResult = hash.withUnsafeBytes { hashPtr in
            secp256k1_ecdsa_recover(
                context,
                &publicKey,
                &signature,
                hashPtr.bindMemory(to: UInt8.self).baseAddress!
            )
        }
        
        guard recoverResult == 1 else {
            throw Secp256k1Error.publicKeyRecoveryFailed
        }
        
        // Serialize public key
        var output = [UInt8](repeating: 0, count: 65)
        var outputLen = 65
        
        secp256k1_ec_pubkey_serialize(
            context,
            &output,
            &outputLen,
            &publicKey,
            UInt32(SECP256K1_EC_UNCOMPRESSED)
        )
        
        // Remove 0x04 prefix
        return Data(output[1..<65])
    }
    
    /// Verify ECDSA signature
    /// @param hash: 32-byte message hash
    /// @param signature: (r, s, v) components
    /// @param publicKey: 64-byte uncompressed public key
    /// @returns: true if signature is valid
    static func verify(hash: Data, signature: (r: Data, s: Data, v: UInt8), publicKey: Data) throws -> Bool {
        guard hash.count == 32 else {
            throw Secp256k1Error.invalidHashLength
        }
        
        guard publicKey.count == 64 else {
            throw Secp256k1Error.invalidPublicKeyLength
        }
        
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_VERIFY)) else {
            throw Secp256k1Error.contextCreationFailed
        }
        defer { secp256k1_context_destroy(context) }
        
        // Parse public key (add 0x04 prefix)
        var fullPublicKey = [UInt8](repeating: 0, count: 65)
        fullPublicKey[0] = 0x04
        let pkBytes = [UInt8](publicKey)
        for i in 0..<min(pkBytes.count, 64) { fullPublicKey[1 + i] = pkBytes[i] }
        
        var pubkey = secp256k1_pubkey()
        let parseResult = secp256k1_ec_pubkey_parse(
            context,
            &pubkey,
            fullPublicKey,
            65
        )
        
        guard parseResult == 1 else {
            throw Secp256k1Error.publicKeyParsingFailed
        }
        
        // Parse signature
        var compactSig = [UInt8](repeating: 0, count: 64)
        signature.r.copyBytes(to: &compactSig, count: 32)
        let sigSBytes = [UInt8](signature.s)
        for i in 0..<min(sigSBytes.count, 32) { compactSig[32 + i] = sigSBytes[i] }
        
        var sig = secp256k1_ecdsa_signature()
        let sigParseResult = secp256k1_ecdsa_signature_parse_compact(
            context,
            &sig,
            compactSig
        )
        
        guard sigParseResult == 1 else {
            throw Secp256k1Error.signatureParsingFailed
        }
        
        // Verify
        let verifyResult = hash.withUnsafeBytes { hashPtr in
            secp256k1_ecdsa_verify(
                context,
                &sig,
                hashPtr.bindMemory(to: UInt8.self).baseAddress!,
                &pubkey
            )
        }
        
        return verifyResult == 1
    }
}

// MARK: - Ethereum Address Utilities

extension Secp256k1Helper {
    
    /// Derive Ethereum address from public key
    /// Address = "0x" + last 20 bytes of Keccak256(publicKey)
    static func publicKeyToAddress(_ publicKey: Data) -> String {
        // Public key should be 64 bytes (uncompressed, without 0x04 prefix)
        guard publicKey.count == 64 else {
            return ""
        }
        
        // Keccak256 hash of public key
        let hash = Keccak256.hash(data: publicKey)
        
        // Take last 20 bytes
        let addressBytes = hash.suffix(20)
        
        // Convert to checksummed address
        let address = "0x" + addressBytes.map { String(format: "%02x", $0) }.joined()
        return toChecksumAddress(address)
    }
    
    /// Derive Ethereum address from private key
    static func privateKeyToAddress(_ privateKey: Data) throws -> String {
        let publicKey = try getPublicKey(privateKey: privateKey)
        return publicKeyToAddress(publicKey)
    }
    
    /// Convert address to EIP-55 checksummed format
    /// Reference: https://eips.ethereum.org/EIPS/eip-55
    static func toChecksumAddress(_ address: String) -> String {
        var cleanAddress = address.lowercased()
        if cleanAddress.hasPrefix("0x") {
            cleanAddress = String(cleanAddress.dropFirst(2))
        }
        
        // Keccak256 hash of lowercase address
        let hash = Keccak256.hash(string: cleanAddress)
        let hashHex = hash.map { String(format: "%02x", $0) }.joined()
        
        var checksummed = "0x"
        
        for (index, char) in cleanAddress.enumerated() {
            if char.isLetter {
                // Get corresponding hash character
                let hashIndex = hashHex.index(hashHex.startIndex, offsetBy: index)
                let hashChar = hashHex[hashIndex]
                
                // If hash char is >= 8, capitalize the address char
                if let hashValue = Int(String(hashChar), radix: 16), hashValue >= 8 {
                    checksummed += char.uppercased()
                } else {
                    checksummed += String(char)
                }
            } else {
                checksummed += String(char)
            }
        }
        
        return checksummed
    }
}

// MARK: - Errors

enum Secp256k1Error: Error, LocalizedError {
    case invalidPrivateKeyLength
    case invalidPublicKeyLength
    case invalidHashLength
    case invalidSignature
    case invalidRecoveryId
    case contextCreationFailed
    case signingFailed
    case publicKeyCreationFailed
    case signatureParsingFailed
    case publicKeyParsingFailed
    case publicKeyRecoveryFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPrivateKeyLength:
            return "Private key must be 32 bytes"
        case .invalidPublicKeyLength:
            return "Public key must be 64 bytes (uncompressed)"
        case .invalidHashLength:
            return "Hash must be 32 bytes"
        case .invalidSignature:
            return "Invalid signature format"
        case .invalidRecoveryId:
            return "Recovery id must be 0-3 (or 27-30 for Ethereum)"
        case .contextCreationFailed:
            return "Failed to create secp256k1 context"
        case .signingFailed:
            return "Signature creation failed"
        case .publicKeyCreationFailed:
            return "Public key creation failed"
        case .signatureParsingFailed:
            return "Failed to parse signature"
        case .publicKeyParsingFailed:
            return "Failed to parse public key"
        case .publicKeyRecoveryFailed:
            return "Failed to recover public key from signature"
        }
    }
}
