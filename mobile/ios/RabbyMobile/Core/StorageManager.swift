import Foundation
import Security
import CryptoKit

/// Secure storage manager for sensitive wallet data
/// Storage Architecture:
/// - Keychain: encrypted vault (private keys, seed phrases)
/// - UserDefaults: lightweight preferences, settings
/// - File System (Caches): large data (transaction history, token lists)
/// - NSCache: in-memory hot cache for frequently accessed data
class StorageManager {
    static let shared = StorageManager()
    
    private let keychainService = "com.rabby.wallet"
    private let userDefaults = UserDefaults.standard
    
    /// In-memory cache for frequently accessed preferences (avoids repeated JSON decode)
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    /// File manager for cache directory storage
    private let fileManager = FileManager.default
    
    private init() {
        memoryCache.countLimit = 100 // max 100 cached objects
        memoryCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    // MARK: - Keychain Operations
    
    /// Save encrypted vault to keychain
    func saveEncryptedVault(data: Data, password: String) async throws {
        let encrypted = try await encrypt(data: data, password: password)
        try saveToKeychain(data: encrypted, key: "encryptedVault")
    }
    
    /// Get encrypted vault from keychain
    func getEncryptedVault() async throws -> Data? {
        return try getFromKeychain(key: "encryptedVault")
    }
    
    /// Delete encrypted vault
    func deleteEncryptedVault() throws {
        try deleteFromKeychain(key: "encryptedVault")
    }
    
    /// Check if vault exists
    func hasVault() -> Bool {
        do {
            return try getFromKeychain(key: "encryptedVault") != nil
        } catch {
            return false
        }
    }
    
    // MARK: - Encryption/Decryption
    
    func encrypt(data: Data, password: String) async throws -> Data {
        // Generate salt
        var salt = [UInt8](repeating: 0, count: 32)
        let saltResult = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        guard saltResult == errSecSuccess else {
            throw StorageError.encryptionFailed
        }
        
        // Derive key using PBKDF2
        let key = try deriveKey(password: password, salt: Data(salt))
        
        // Generate nonce
        let nonce = AES.GCM.Nonce()
        
        // Encrypt data
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        // Combine salt + nonce + ciphertext + tag
        var result = Data()
        result.append(Data(salt))
        result.append(nonce.dataRepresentation)
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)
        
        return result
    }
    
    func decrypt(data: Data, password: String) async throws -> Data {
        // Extract components
        guard data.count > 32 + 12 + 16 else {
            throw StorageError.decryptionFailed
        }
        
        let salt = data.prefix(32)
        let nonceData = data.subdata(in: 32..<44)
        let ciphertextAndTag = data.suffix(from: 44)
        let ciphertext = ciphertextAndTag.prefix(ciphertextAndTag.count - 16)
        let tag = ciphertextAndTag.suffix(16)
        
        // Derive key
        let key = try deriveKey(password: password, salt: salt)
        
        // Decrypt
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        
        return decrypted
    }
    
    private func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw StorageError.invalidPassword
        }
        
        // PBKDF2 with SHA256, 100,000 iterations
        let derivedKey = try PBKDF2.deriveKey(
            password: passwordData,
            salt: salt,
            iterations: 100_000,
            keyLength: 32
        )
        
        return SymmetricKey(data: derivedKey)
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(data: Data, key: String) throws {
        // Delete existing item
        try? deleteFromKeychain(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw StorageError.keychainSaveFailed(status)
        }
    }
    
    private func getFromKeychain(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw StorageError.keychainLoadFailed(status)
        }
        
        return result as? Data
    }
    
    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychainDeleteFailed(status)
        }
    }
    
    // MARK: - User Preferences
    
    func savePreference<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: key)
        // Cache in memory to avoid repeated JSON decode
        memoryCache.setObject(value as AnyObject, forKey: key as NSString)
    }
    
    func getPreference<T: Codable>(forKey key: String, type: T.Type) throws -> T? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) as? T {
            return cached
        }
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder()
        let value = try decoder.decode(T.self, from: data)
        // Store in memory cache
        memoryCache.setObject(value as AnyObject, forKey: key as NSString)
        return value
    }
    
    func removePreference(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        memoryCache.removeObject(forKey: key as NSString)
    }
    
    // MARK: - Raw Data Accessors (used by AutoLockManager, PreferenceManager, etc.)
    
    func getData(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }
    
    func setData(_ data: Data, forKey key: String) {
        userDefaults.set(data, forKey: key)
    }
    
    // MARK: - Primitive Type Convenience Accessors
    
    func getString(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    func setString(_ value: String, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func getBool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    func setBool(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func getInt(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }
    
    func setInt(_ value: Int, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func getDouble(forKey key: String) -> Double {
        return userDefaults.double(forKey: key)
    }
    
    func setDouble(_ value: Double, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    // MARK: - Current Account
    
    func saveCurrentAccount(_ account: Account) throws {
        try savePreference(account, forKey: "currentAccount")
    }
    
    func getCurrentAccount() throws -> Account? {
        return try getPreference(forKey: "currentAccount", type: Account.self)
    }
    
    // MARK: - Chain Preferences
    
    func saveSelectedChains(_ chains: [String]) throws {
        try savePreference(chains, forKey: "selectedChains")
    }
    
    func getSelectedChains() throws -> [String] {
        return try getPreference(forKey: "selectedChains", type: [String].self) ?? []
    }
    
    // MARK: - Permissions
    
    func saveConnectedSites(_ sites: [String: ConnectedSite]) throws {
        try savePreference(sites, forKey: "connectedSites")
    }
    
    func getConnectedSites() throws -> [String: ConnectedSite] {
        return try getPreference(forKey: "connectedSites", type: [String: ConnectedSite].self) ?? [:]
    }
    
    // MARK: - Transaction History
    
    func saveTransactionHistory(_ history: [TransactionRecord]) throws {
        try savePreference(history, forKey: "transactionHistory")
    }
    
    func getTransactionHistory() throws -> [TransactionRecord] {
        return try getPreference(forKey: "transactionHistory", type: [TransactionRecord].self) ?? []
    }
    
    // MARK: - Address Book
    
    func saveAddressBook(_ addressBook: [String: Contact]) throws {
        try savePreference(addressBook, forKey: "addressBook")
    }
    
    func getAddressBook() throws -> [String: Contact] {
        return try getPreference(forKey: "addressBook", type: [String: Contact].self) ?? [:]
    }
    
    // MARK: - Security Settings
    
    func saveBiometricEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: "biometricEnabled")
    }
    
    func isBiometricEnabled() -> Bool {
        return userDefaults.bool(forKey: "biometricEnabled")
    }
    
    func saveAutoLockTimeout(_ seconds: Int) {
        userDefaults.set(seconds, forKey: "autoLockTimeout")
    }
    
    func getAutoLockTimeout() -> Int {
        let timeout = userDefaults.integer(forKey: "autoLockTimeout")
        return timeout > 0 ? timeout : 300 // Default 5 minutes
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() throws {
        // Delete keychain items
        try deleteEncryptedVault()
        
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Clear image cache
        Task { @MainActor in
            ImageCacheManager.shared.clearAll()
        }
        
        // Clear all UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
    }
}

// MARK: - Supporting Types

struct ConnectedSite: Codable {
    let origin: String
    let name: String
    let icon: String?
    let connectedAt: Date
    var isConnected: Bool
    var permissions: [String]
}

struct TransactionRecord: Codable, Identifiable {
    let id: String
    let hash: String
    let from: String
    let to: String
    let value: String
    let gasPrice: String
    let gasLimit: String
    let nonce: Int
    let chainId: Int
    let timestamp: Date
    var status: TransactionStatus
    let type: TransactionType
    
    enum TransactionStatus: String, Codable {
        case pending
        case confirmed
        case failed
        case cancelled
    }
    
    enum TransactionType: String, Codable {
        case send
        case receive
        case contractInteraction
        case approval
        case swap
        case bridge
    }
}

struct Contact: Codable {
    let address: String
    var name: String
    var note: String?
    let addedAt: Date
}

// MARK: - Errors

enum StorageError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidPassword
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data. Wrong password or corrupted data."
        case .invalidPassword:
            return "Invalid password format"
        case .keychainSaveFailed(let status):
            return "Failed to save to keychain. Status: \(status)"
        case .keychainLoadFailed(let status):
            return "Failed to load from keychain. Status: \(status)"
        case .keychainDeleteFailed(let status):
            return "Failed to delete from keychain. Status: \(status)"
        }
    }
}

// MARK: - PBKDF2 Helper

struct PBKDF2 {
    static func deriveKey(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        
        let status = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                    password.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivedKey,
                    keyLength
                )
            }
        }
        
        guard status == kCCSuccess else {
            throw StorageError.encryptionFailed
        }
        
        return Data(derivedKey)
    }
}

// Import CommonCrypto
import CommonCrypto

extension AES.GCM.Nonce {
    var dataRepresentation: Data {
        return Swift.withUnsafeBytes(of: self) { Data($0) }
    }
}
