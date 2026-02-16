import Foundation
import BigInt
import CryptoSwift
import Combine

// MARK: - Ledger Keyring Integration
//
// LedgerKeyring is fully integrated into KeyringManager through the Keyring protocol.
// The existing signTransaction / signMessage / signTypedData methods iterate over all
// keyrings and automatically route to LedgerKeyring when the target address belongs
// to a Ledger account:
//
//   // In KeyringManager.signTransaction (already implemented):
//   for keyring in keyrings {
//       let accounts = await keyring.getAccounts()
//       if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
//           // If keyring is LedgerKeyring, this sends APDU commands via BLE
//           return try await keyring.signTransaction(address: address, transaction: transaction)
//       }
//   }
//
// LedgerKeyring accounts are persisted in the vault. When the vault is unlocked,
// LedgerKeyring is restored (see unlockKeyrings). The Ledger device must be
// reconnected via BLE before signing, but account addresses are remembered.

// MARK: - Keyring Types
enum KeyringType: String, Codable {
    case hdKeyring = "HD Key Tree"
    case simpleKeyring = "Simple Key Pair"
    case watchAddress = "Watch Address"
    case ledger = "Ledger Hardware"
    case trezor = "Trezor Hardware"
    case onekey = "Onekey Hardware"
    case bitbox02 = "BitBox02 Hardware"
    case gridplus = "GridPlus Hardware"
    case keystone = "Keystone Hardware"
    case imkey = "ImKey Hardware"
    case gnosis = "Gnosis"
    case walletConnect = "WalletConnect"
    case coinbase = "Coinbase Wallet"
    case coboArgus = "Cobo Argus"
}

// MARK: - Account Model
struct Account: Codable {
    let address: String
    let type: KeyringType
    let brandName: String
    var alianName: String?
    var balance: String?
    var index: Int?
    
    var checksumAddress: String {
        return EthereumUtil.toChecksumAddress(address)
    }
}

// MARK: - Keyring Protocol
protocol Keyring {
    var type: KeyringType { get }
    var accounts: [String] { get }
    
    func serialize() throws -> Data
    func deserialize(from data: Data) throws
    func addAccounts(count: Int) async throws -> [String]
    func getAccounts() async -> [String]
    func removeAccount(address: String) throws
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data
    func signMessage(address: String, message: Data) async throws -> Data
    func signTypedData(address: String, typedData: String) async throws -> Data
}

// MARK: - HD Keyring (BIP44)
class HDKeyring: Keyring {
    let type: KeyringType = .hdKeyring
    private(set) var accounts: [String] = []
    private var mnemonic: String?
    private var passphrase: String = ""
    private var numberOfAccounts: Int = 0
    private var hdPath: String = "m/44'/60'/0'/0"
    var index: Int = 0
    
    init() {}
    
    init(mnemonic: String, passphrase: String = "") {
        print("[HDKeyring] 🔵 Initializing with mnemonic: \(mnemonic.split(separator: " ").count) words, passphrase: \(passphrase.isEmpty ? "empty" : "set")")
        self.mnemonic = mnemonic
        self.passphrase = passphrase
        print("[HDKeyring] 🔵 Mnemonic stored: \(self.mnemonic != nil ? "YES" : "NO")")
    }
    
    // Generate mnemonic
    static func generateMnemonic(strength: Int = 128) throws -> String {
        guard strength % 32 == 0 && strength >= 128 && strength <= 256 else {
            throw KeyringError.invalidMnemonicStrength
        }
        
        let byteCount = strength / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        
        guard result == errSecSuccess else {
            throw KeyringError.failedToGenerateMnemonic
        }
        
        return try BIP39.generateMnemonic(entropy: Data(bytes))
    }
    
    // Validate mnemonic
    static func validateMnemonic(_ mnemonic: String) -> Bool {
        return BIP39.validateMnemonic(mnemonic)
    }
    
    // Add accounts from mnemonic
    func addAccounts(count: Int = 1) async throws -> [String] {
        print("[HDKeyring] 🟡 addAccounts called, count: \(count)")
        print("[HDKeyring] 🟡 Current mnemonic status: \(mnemonic != nil ? "SET" : "NIL")")
        if let m = mnemonic {
            print("[HDKeyring] 🟡 Mnemonic length: \(m.isEmpty ? "EMPTY STRING" : "\(m.split(separator: " ").count) words")")
        }

        guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
            print("[HDKeyring] ❌ ERROR: addAccounts called but mnemonic is not set or empty")
            throw KeyringError.mnemonicNotSet
        }
        
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        var newAccounts: [String] = []
        
        for i in numberOfAccounts..<(numberOfAccounts + count) {
            let path = "\(hdPath)/\(i)"
            let privateKey = try derivePrivateKey(seed: seed, path: path)
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            newAccounts.append(address)
            accounts.append(address)
        }
        
        numberOfAccounts += count
        return newAccounts
    }
    
    func getAccounts() async -> [String] {
        return accounts
    }
    
    func removeAccount(address: String) throws {
        guard let index = accounts.firstIndex(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        accounts.remove(at: index)
        numberOfAccounts -= 1
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let index = accounts.firstIndex { $0.lowercased() == address.lowercased() }!
        let path = "\(hdPath)/\(index)"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        
        return try EthereumSigner.signTransaction(privateKey: privateKey, transaction: transaction)
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let index = accounts.firstIndex { $0.lowercased() == address.lowercased() }!
        let path = "\(hdPath)/\(index)"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        
        return try EthereumSigner.signMessage(privateKey: privateKey, message: message)
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let index = accounts.firstIndex { $0.lowercased() == address.lowercased() }!
        let path = "\(hdPath)/\(index)"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        
        return try EthereumSigner.signTypedData(privateKey: privateKey, typedDataJSON: typedData)
    }
    
    func serialize() throws -> Data {
        print("[HDKeyring] 🟢 serialize() called")
        print("[HDKeyring] 🟢 Mnemonic status before check: \(mnemonic != nil ? "SET" : "NIL")")

        // Ensure mnemonic is set before serializing
        guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
            print("[HDKeyring] ❌ ERROR: Cannot serialize - mnemonic not set or empty")
            print("[HDKeyring] ❌ mnemonic is nil: \(self.mnemonic == nil)")
            print("[HDKeyring] ❌ mnemonic is empty: \(self.mnemonic?.isEmpty ?? false)")
            throw KeyringError.mnemonicNotSet
        }

        let dict: [String: Any] = [
            "mnemonic": mnemonic,
            "passphrase": passphrase,
            "numberOfAccounts": numberOfAccounts,
            "hdPath": hdPath,
            "accounts": accounts,
            "index": index
        ]
        print("[HDKeyring] 🟢 Serializing with \(numberOfAccounts) accounts, mnemonic: \(mnemonic.split(separator: " ").count) words")
        let data = try JSONSerialization.data(withJSONObject: dict)
        print("[HDKeyring] 🟢 Serialized data size: \(data.count) bytes")
        return data
    }

    func deserialize(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }

        // Validate mnemonic exists and is not empty
        guard let mnemonic = dict["mnemonic"] as? String, !mnemonic.isEmpty else {
            print("[HDKeyring] ERROR: Invalid deserialization - mnemonic missing or empty")
            throw KeyringError.mnemonicNotSet
        }

        self.mnemonic = mnemonic
        self.passphrase = dict["passphrase"] as? String ?? ""
        self.numberOfAccounts = dict["numberOfAccounts"] as? Int ?? 0
        self.hdPath = dict["hdPath"] as? String ?? "m/44'/60'/0'/0"
        self.accounts = dict["accounts"] as? [String] ?? []
        self.index = dict["index"] as? Int ?? 0

        let wordCount = mnemonic.split(separator: " ").count
        print("[HDKeyring] Deserialized with \(numberOfAccounts) accounts, mnemonic: \(wordCount) words")
    }
    
    // BIP44 derivation
    private func derivePrivateKey(seed: Data, path: String) throws -> Data {
        // Implement BIP44 key derivation
        // This requires a crypto library like Web3.swift or similar
        return try BIP44.derivePrivateKey(seed: seed, path: path)
    }
}

// MARK: - Simple Keyring (Private Key)
class SimpleKeyring: Keyring {
    let type: KeyringType = .simpleKeyring
    private(set) var accounts: [String] = []
    private var privateKeys: [String: Data] = [:]
    
    init() {}
    
    init(privateKeys: [Data]) throws {
        for privateKey in privateKeys {
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            self.accounts.append(address)
            self.privateKeys[address.lowercased()] = privateKey
        }
    }
    
    func addAccounts(count: Int = 1) async throws -> [String] {
        // Simple keyring doesn't support generating new random accounts
        throw KeyringError.operationNotSupported
    }
    
    /// Add accounts from existing private keys
    func addAccounts(privateKeys: [Data]) throws -> [String] {
        var newAccounts: [String] = []
        for privateKey in privateKeys {
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            if !accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                accounts.append(address)
                self.privateKeys[address.lowercased()] = privateKey
                newAccounts.append(address)
            }
        }
        return newAccounts
    }
    
    func getAccounts() async -> [String] {
        return accounts
    }
    
    func removeAccount(address: String) throws {
        guard let index = accounts.firstIndex(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        accounts.remove(at: index)
        privateKeys.removeValue(forKey: address.lowercased())
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        guard let privateKey = privateKeys[address.lowercased()] else {
            throw KeyringError.accountNotFound
        }
        return try EthereumSigner.signTransaction(privateKey: privateKey, transaction: transaction)
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        guard let privateKey = privateKeys[address.lowercased()] else {
            throw KeyringError.accountNotFound
        }
        return try EthereumSigner.signMessage(privateKey: privateKey, message: message)
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        guard let privateKey = privateKeys[address.lowercased()] else {
            throw KeyringError.accountNotFound
        }
        return try EthereumSigner.signTypedData(privateKey: privateKey, typedDataJSON: typedData)
    }
    
    func serialize() throws -> Data {
        let dict: [String: Any] = [
            "accounts": accounts,
            "privateKeys": privateKeys.mapValues { $0.hexString }
        ]
        return try JSONSerialization.data(withJSONObject: dict)
    }
    
    func deserialize(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }
        
        self.accounts = dict["accounts"] as? [String] ?? []
        if let keysDict = dict["privateKeys"] as? [String: String] {
            self.privateKeys = keysDict.compactMapValues { Data(hexString: $0) }
        }
    }
}

// MARK: - Watch Address Keyring is defined in WatchGnosisSessionKeyrings.swift

// MARK: - Keyring Manager
@MainActor
class KeyringManager: ObservableObject {
    static let shared = KeyringManager()
    
    @Published var isUnlocked: Bool = false
    @Published var isInitialized: Bool = false
    @Published var biometricsEnabled: Bool = false
    @Published var keyrings: [Keyring] = []
    @Published var currentAccount: Account?
    
    private var password: String?
    private let storageManager = StorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPreferenceSync()

        // Check if vault exists in Keychain
        // NOTE: NEVER clear vault on launch — user may have real funds.
        // If user forgot password, they must use "Reset Wallet" (requires mnemonic backup).
        Task {
            do {
                let vault = try await storageManager.getEncryptedVault()
                let hasVault = vault != nil
                NSLog("[KeyringManager] Init: vault exists = %@, vault size = %d bytes", hasVault ? "YES" : "NO", vault?.count ?? 0)
                await MainActor.run { self.isInitialized = hasVault }
            } catch {
                NSLog("[KeyringManager] Init ERROR: Failed to read vault from Keychain: %@", "\(error)")
                await MainActor.run { self.isInitialized = false }
            }
        }
    }
    
    // MARK: - Vault Creation
    func createNewVault(password: String) async {
        // Trim whitespace for consistency between create and unlock
        self.password = password.trimmingCharacters(in: .whitespacesAndNewlines)

        // ✅ 修复：清空旧的 keyrings，避免数据混乱
        // 创建新 vault 时应该是全新的开始，不应该保留旧钱包数据
        self.keyrings.removeAll()

        self.isInitialized = true
        self.isUnlocked = true
    }
    
    // MARK: - Unlock/Lock
    func submitPassword(_ password: String) async throws {
        NSLog("[KeyringManager] submitPassword called, password length: %d", password.count)
        NSLog("[KeyringManager] isInitialized: %@, vault exists: %@", isInitialized ? "YES" : "NO", storageManager.hasVault() ? "YES" : "NO")

        // Validate password is not empty/whitespace-only
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else {
            NSLog("[KeyringManager] Password is empty after trimming")
            throw KeyringError.invalidPassword
        }

        let valid = try await verifyPassword(trimmedPassword)
        guard valid else {
            NSLog("[KeyringManager] Password verification FAILED — wrong password or corrupted vault")
            throw KeyringError.invalidPassword
        }
        NSLog("[KeyringManager] Password verified OK, unlocking keyrings...")
        self.password = trimmedPassword
        do {
            self.keyrings = try await unlockKeyrings(password: trimmedPassword)
        } catch {
            NSLog("[KeyringManager] unlockKeyrings FAILED: %@", "\(error)")
            throw error
        }
        self.isUnlocked = true
        
        // Restore currentAccount from loaded keyrings
        if currentAccount == nil {
            for keyring in keyrings {
                let accounts = await keyring.getAccounts()
                if let firstAddr = accounts.first {
                    currentAccount = Account(address: firstAddr, type: keyring.type, brandName: keyring.type.rawValue)
                    NSLog("[KeyringManager] Restored currentAccount: %@", firstAddr)
                    break
                }
            }
        }
        
        NSLog("[KeyringManager] Unlocked successfully, %d keyring(s) loaded", keyrings.count)
        NotificationCenter.default.post(name: .keyringUnlocked, object: nil)
    }
    
    func setLocked() async {
        keyrings.removeAll()
        password = nil
        isUnlocked = false
        NotificationCenter.default.post(name: .keyringLocked, object: nil)
    }

    /// Returns the in-memory unlock password while wallet is unlocked.
    /// Used to seed biometric keychain credential when enabling biometrics.
    func currentUnlockPassword() -> String? {
        password
    }
    
    @discardableResult
    func verifyPassword(_ password: String) async throws -> Bool {
        NSLog("[KeyringManager] Verifying password (length=%d)...", password.count)
        let encryptedVault = try? await storageManager.getEncryptedVault()
        guard let vault = encryptedVault else {
            // No vault yet — password is accepted for new vault
            NSLog("[KeyringManager] No vault found - accepting password for new vault")
            return true
        }
        NSLog("[KeyringManager] Vault found (%d bytes), attempting to decrypt...", vault.count)
        do {
            let decrypted = try await storageManager.decrypt(data: vault, password: password)
            NSLog("[KeyringManager] Password verified OK, decrypted %d bytes", decrypted.count)
            return true
        } catch {
            NSLog("[KeyringManager] Password verification FAILED: %@", "\(error)")
            NSLog("[KeyringManager] Vault hex prefix: %@", vault.prefix(64).map { String(format: "%02x", $0) }.joined())
            return false
        }
    }
    
    // MARK: - Keyring Operations
    func addNewKeyring(type: KeyringType, options: [String: Any]? = nil) async throws -> Keyring {
        let keyring: Keyring
        
        switch type {
        case .hdKeyring:
            if let mnemonic = options?["mnemonic"] as? String {
                keyring = HDKeyring(mnemonic: mnemonic, passphrase: options?["passphrase"] as? String ?? "")
            } else {
                let mnemonic = try HDKeyring.generateMnemonic()
                keyring = HDKeyring(mnemonic: mnemonic)
            }
            
        case .simpleKeyring:
            if let privateKeyHex = options?["privateKey"] as? String,
               let privateKey = Data(hexString: privateKeyHex) {
                keyring = try SimpleKeyring(privateKeys: [privateKey])
            } else {
                throw KeyringError.invalidOptions
            }
            
        case .watchAddress:
            keyring = WatchAddressKeyring()
            if let addresses = options?["addresses"] as? [String] {
                for _ in addresses {
                    _ = try await keyring.addAccounts(count: 1)
                }
            }

        case .ledger:
            // Ledger keyrings are typically created through LedgerConnectView,
            // but this path supports programmatic creation as well.
            // The Ledger device must be connected via BLE before calling addAccounts.
            let ledger = LedgerKeyring()
            if let accountCount = options?["accountCount"] as? Int, accountCount > 0 {
                _ = try await ledger.addAccounts(count: accountCount)
            }
            keyring = ledger

        default:
            throw KeyringError.unsupportedKeyringType
        }
        
        keyrings.append(keyring)
        try await persistAllKeyrings()
        
        return keyring
    }
    
    func getAccounts() async -> [String] {
        var allAccounts: [String] = []
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            allAccounts.append(contentsOf: accounts)
        }
        return allAccounts
    }

    /// 获取最后添加的 keyring（用于备份新创建/导入的钱包）
    func getLastAddedKeyring() -> Keyring? {
        return keyrings.last
    }

    func removeAccount(address: String, type: KeyringType) async throws {
        let normalized = address.lowercased()

        var targetKeyring: Keyring?
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == normalized }) {
                targetKeyring = keyring
                break
            }
        }

        // Fallback to type match to preserve previous behavior.
        if targetKeyring == nil {
            targetKeyring = keyrings.first(where: { $0.type == type })
        }

        guard let keyring = targetKeyring else {
            throw KeyringError.keyringNotFound
        }
        
        try keyring.removeAccount(address: address)
        try await persistAllKeyrings()
        
        NotificationCenter.default.post(
            name: .accountRemoved,
            object: nil,
            userInfo: ["address": address, "type": type.rawValue]
        )
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                return try await keyring.signTransaction(address: address, transaction: transaction)
            }
        }
        throw KeyringError.accountNotFound
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                return try await keyring.signMessage(address: address, message: message)
            }
        }
        throw KeyringError.accountNotFound
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                return try await keyring.signTypedData(address: address, typedData: typedData)
            }
        }
        throw KeyringError.accountNotFound
    }
    
    // MARK: - Keyring Lifecycle
    func addKeyring(_ keyring: Keyring) async {
        keyrings.append(keyring)
        let accounts = await keyring.getAccounts()
        if currentAccount == nil, let firstAddr = accounts.first {
            currentAccount = Account(address: firstAddr, type: keyring.type, brandName: keyring.type.rawValue)
        }
    }
    
    // MARK: - Import Methods
    func importPrivateKey(privateKey: String, password: String?) async throws {
        if let pw = password, !isInitialized {
            await createNewVault(password: pw)
        }
        var cleanKey = privateKey
        if cleanKey.hasPrefix("0x") { cleanKey = String(cleanKey.dropFirst(2)) }
        guard let keyData = Data(hexString: cleanKey) else {
            throw KeyringError.invalidOptions
        }
        let keyring = try SimpleKeyring(privateKeys: [keyData])
        await addKeyring(keyring)
        try await persistAllKeyrings()
    }
    
    func importFromMnemonic(mnemonic: String, password: String?, accountCount: Int) async throws {
        if let pw = password, !isInitialized {
            await createNewVault(password: pw)
        }
        let keyring = HDKeyring(mnemonic: mnemonic)
        _ = try await keyring.addAccounts(count: accountCount)
        await addKeyring(keyring)
        try await persistAllKeyrings()
    }
    
    func importFromKeystore(json: String, password: String, walletPassword: String?) async throws {
        if let wp = walletPassword, !isInitialized {
            await createNewVault(password: wp)
        }
        let privateKey = try KeystoreV3.decryptPrivateKey(json: json, password: password)
        let keyring = try SimpleKeyring(privateKeys: [privateKey])
        await addKeyring(keyring)
        try await persistAllKeyrings()
    }

    /// Decrypt a Keystore V3 JSON file and import the private key.
    /// - Parameters:
    ///   - jsonString: The Keystore V3 JSON string.
    ///   - password: The password used to encrypt the keystore.
    /// - Returns: The checksummed Ethereum address derived from the decrypted private key.
    @discardableResult
    func importFromKeystore(_ jsonString: String, password: String) async throws -> String {
        let privateKey = try KeystoreV3.decryptPrivateKey(json: jsonString, password: password)
        let address = try EthereumUtil.privateKeyToAddress(privateKey)

        // Check if this address already exists in any keyring
        let existingAccounts = await getAccounts()
        guard !existingAccounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            // Address already imported; return it without duplicating
            return address
        }

        let keyring = try SimpleKeyring(privateKeys: [privateKey])
        await addKeyring(keyring)
        try await persistAllKeyrings()

        return address
    }
    
    func restoreFromMnemonic(mnemonic: String, password: String) async throws {
        guard HDKeyring.validateMnemonic(mnemonic) else {
            throw KeyringError.invalidMnemonic
        }
        // Reset vault with new password
        await createNewVault(password: password)
        keyrings.removeAll()
        try await importFromMnemonic(mnemonic: mnemonic, password: nil, accountCount: 1)
    }
    
    // MARK: - HD Derivation Helpers
    func deriveAddresses(mnemonic: String, hdPath: String, startIndex: Int, count: Int) async throws -> [String] {
        // Use the stored mnemonic if empty string passed
        var mnemonicToUse = mnemonic
        if mnemonicToUse.isEmpty {
            mnemonicToUse = try getStoredMnemonic()
        }
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonicToUse, passphrase: "")
        var addresses: [String] = []
        for i in startIndex..<(startIndex + count) {
            let path = "\(hdPath)/\(i)"
            let privateKey = try BIP44.derivePrivateKey(seed: seed, path: path)
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            addresses.append(address)
        }
        return addresses
    }
    
    func getAllAddresses() async -> [String] {
        return await getAccounts()
    }
    
    func addAccountFromExistingMnemonic(address: String) async throws {
        // If address is provided, add to that specific HD keyring group.
        var targetHDKeyring: HDKeyring?
        let normalized = address.lowercased()
        if !normalized.isEmpty {
            for keyring in keyrings {
                guard let hd = keyring as? HDKeyring else { continue }
                let accounts = await hd.getAccounts()
                if accounts.contains(where: { $0.lowercased() == normalized }) {
                    targetHDKeyring = hd
                    break
                }
            }
        }

        if targetHDKeyring == nil {
            targetHDKeyring = keyrings.first(where: { $0.type == .hdKeyring }) as? HDKeyring
        }

        guard let hdKeyring = targetHDKeyring else {
            throw KeyringError.keyringNotFound
        }
        _ = try await hdKeyring.addAccounts(count: 1)
        try await persistAllKeyrings()
    }

    func selectAccount(address: String) async throws {
        let normalized = address.lowercased()
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if let matched = accounts.first(where: { $0.lowercased() == normalized }) {
                let alias = PreferenceManager.shared.getAlias(address: matched)
                currentAccount = Account(
                    address: matched,
                    type: keyring.type,
                    brandName: keyring.type.rawValue,
                    alianName: alias
                )
                await syncPreferenceAccounts()
                return
            }
        }
        throw KeyringError.accountNotFound
    }

    func refreshPreferenceAccounts() async {
        await syncPreferenceAccounts()
    }
    
    // MARK: - Reset/Logout
    /// 完全重置钱包（退出登录）
    /// ⚠️ 警告：这会永久删除加密vault，用户必须有助记词备份才能恢复
    func resetWallet() async throws {
        NSLog("[KeyringManager] 🔴 resetWallet called - clearing vault and all data")

        // 1. 清除内存中的keyrings
        keyrings.removeAll()
        password = nil
        currentAccount = nil

        // 2. 删除Keychain中的加密vault
        try await storageManager.deleteEncryptedVault()
        NSLog("[KeyringManager] 🔴 Vault deleted from Keychain")

        // 3. 清除PreferenceManager中的账户数据
        PreferenceManager.shared.currentAccount = nil
        PreferenceManager.shared.accounts.removeAll()

        // 4. 清除生物识别密码
        BiometricAuthManager.shared.disableBiometric()

        // 5. 重置状态
        isUnlocked = false
        isInitialized = false

        NSLog("[KeyringManager] 🔴 Wallet reset complete - returning to onboarding state")

        // 发送通知
        NotificationCenter.default.post(name: .walletReset, object: nil)
    }

    // MARK: - Export Methods
    func getMnemonic(password: String) async throws -> String {
        let valid = try await verifyPassword(password)
        guard valid else { throw KeyringError.invalidPassword }
        return try getStoredMnemonic()
    }
    
    func exportPrivateKey(address: String, password: String) async throws -> String {
        let valid = try await verifyPassword(password)
        guard valid else { throw KeyringError.invalidPassword }
        // Find keyring containing this address and export
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                let data = try keyring.serialize()
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let keys = dict["privateKeys"] as? [String: String],
                   let key = keys[address.lowercased()] {
                    return "0x" + key
                }
                // For HD keyrings, derive the key
                if keyring.type == .hdKeyring {
                    return "0x" + (try keyring.serialize().hexString)
                }
                throw KeyringError.operationNotSupported
            }
        }
        throw KeyringError.accountNotFound
    }
    
    private func getStoredMnemonic() throws -> String {
        guard let hdKeyring = keyrings.first(where: { $0.type == .hdKeyring }) as? HDKeyring else {
            throw KeyringError.keyringNotFound
        }
        let data = try hdKeyring.serialize()
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mnemonic = dict["mnemonic"] as? String, !mnemonic.isEmpty else {
            throw KeyringError.mnemonicNotSet
        }
        return mnemonic
    }
    
    // MARK: - Sign and Send
    func signAndSendTransaction(
        from: String,
        to: String?,
        value: String?,
        data: String?,
        gasLimit: String?,
        gasPrice: String?,
        maxFeePerGas: String?,
        maxPriorityFeePerGas: String?
    ) async throws -> String {
        let chain = ChainManager.shared.selectedChain ?? Chain.ethereum
        guard let to = to, !to.isEmpty else {
            throw KeyringError.invalidOptions
        }
        
        let valueHex = (value?.isEmpty ?? true) ? "0x0" : (value ?? "0x0")
        let dataHex = (data?.isEmpty ?? true) ? "0x" : (data ?? "0x")
        
        // Nonce + gas
        let nonce = try await TransactionManager.shared.getRecommendedNonce(address: from, chain: chain)
        
        let resolvedGasLimit: BigUInt
        if let gasLimit = gasLimit, !gasLimit.isEmpty, let parsed = BigUInt(gasLimit) {
            resolvedGasLimit = parsed
        } else {
            resolvedGasLimit = try await TransactionManager.shared.estimateGas(
                from: from,
                to: to,
                value: valueHex,
                data: dataHex,
                chain: chain
            )
        }
        
        var tx = EthereumTransaction(
            to: to,
            from: from,
            nonce: nonce,
            value: BigUInt(valueHex.hexToData() ?? Data()),
            data: dataHex.hexToData() ?? Data(),
            gasLimit: resolvedGasLimit,
            chainId: chain.id
        )
        
        // Fees
        if chain.supportsEIP1559 {
            let resolvedMaxFee: BigUInt
            let resolvedPriority: BigUInt
            
            if let maxFeePerGas = maxFeePerGas, !maxFeePerGas.isEmpty,
               let maxPriorityFeePerGas = maxPriorityFeePerGas, !maxPriorityFeePerGas.isEmpty,
               (Decimal(string: maxFeePerGas) != nil),
               (Decimal(string: maxPriorityFeePerGas) != nil) {
                resolvedMaxFee = EthereumUtil.gweiToWei(Decimal(string: maxFeePerGas) ?? 0)
                resolvedPriority = EthereumUtil.gweiToWei(Decimal(string: maxPriorityFeePerGas) ?? 0)
            } else {
                if let feeData = try await TransactionManager.shared.getEIP1559FeeData(chain: chain) {
                    resolvedMaxFee = feeData.maxFeePerGas
                    resolvedPriority = feeData.maxPriorityFeePerGas
                } else {
                    resolvedMaxFee = EthereumUtil.gweiToWei(30)
                    resolvedPriority = EthereumUtil.gweiToWei(2)
                }
            }
            
            tx.maxFeePerGas = resolvedMaxFee
            tx.maxPriorityFeePerGas = resolvedPriority
            tx.gasPrice = nil
        } else {
            let resolvedGasPrice: BigUInt
            if let gasPrice = gasPrice, !gasPrice.isEmpty {
                let wei = EthereumUtil.gweiToWei(Decimal(string: gasPrice) ?? 0)
                resolvedGasPrice = wei
            } else {
                resolvedGasPrice = try await TransactionManager.shared.getGasPrice(chain: chain)
            }
            tx.gasPrice = resolvedGasPrice
            tx.maxFeePerGas = nil
            tx.maxPriorityFeePerGas = nil
        }
        
        return try await TransactionManager.shared.sendTransaction(tx)
    }
    
    // MARK: - Persistence
    func persistAllKeyrings() async throws {
        print("[KeyringManager] Persisting \(keyrings.count) keyring(s)...")
        guard let password = password else {
            print("[KeyringManager] ERROR: No password available for persistence")
            throw KeyringError.walletLocked
        }

        var serializedKeyrings: [[String: Any]] = []
        for keyring in keyrings {
            let data = try keyring.serialize()
            serializedKeyrings.append([
                "type": keyring.type.rawValue,
                "data": data.base64EncodedString()
            ])
        }

        let vaultData = try JSONSerialization.data(withJSONObject: serializedKeyrings)
        print("[KeyringManager] Saving encrypted vault (size: \(vaultData.count) bytes)...")
        try await storageManager.saveEncryptedVault(data: vaultData, password: password)
        print("[KeyringManager] Vault saved successfully")

        // Verify vault was saved AND can be decrypted with the same password
        do {
            guard let savedVault = try await storageManager.getEncryptedVault() else {
                print("[KeyringManager] CRITICAL: Vault not found in Keychain after save!")
                throw KeyringError.vaultSaveFailed
            }
            // Verify we can decrypt it with the current password
            _ = try await storageManager.decrypt(data: savedVault, password: password)
            print("[KeyringManager] ✓ Vault saved and decryption verified (\(savedVault.count) bytes)")
        } catch {
            print("[KeyringManager] CRITICAL: Vault verification failed after save: \(error)")
            // Retry once — in case of transient Keychain issue
            print("[KeyringManager] Retrying vault save...")
            try await storageManager.saveEncryptedVault(data: vaultData, password: password)
            guard let retryVault = try await storageManager.getEncryptedVault() else {
                throw KeyringError.vaultSaveFailed
            }
            _ = try await storageManager.decrypt(data: retryVault, password: password)
            print("[KeyringManager] ✓ Vault saved on retry and verified")
        }

        await syncPreferenceAccounts()
    }
    
    private func unlockKeyrings(password: String) async throws -> [Keyring] {
        guard let encryptedVault = try await storageManager.getEncryptedVault() else {
            return []
        }
        
        let vaultData = try await storageManager.decrypt(data: encryptedVault, password: password)
        guard let serializedKeyrings = try JSONSerialization.jsonObject(with: vaultData) as? [[String: Any]] else {
            return []
        }
        
        var loadedKeyrings: [Keyring] = []
        
        for item in serializedKeyrings {
            guard let typeString = item["type"] as? String,
                  let type = KeyringType(rawValue: typeString),
                  let dataString = item["data"] as? String,
                  let data = Data(base64Encoded: dataString) else {
                continue
            }
            
            let keyring: Keyring
            switch type {
            case .hdKeyring:
                keyring = HDKeyring()
            case .simpleKeyring:
                keyring = SimpleKeyring()
            case .watchAddress:
                keyring = WatchAddressKeyring()
            case .ledger:
                keyring = LedgerKeyring()
            default:
                continue
            }
            
            try keyring.deserialize(from: data)
            loadedKeyrings.append(keyring)
        }
        
        return loadedKeyrings
    }

    private func setupPreferenceSync() {
        $currentAccount
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.syncPreferenceAccounts()
                }
            }
            .store(in: &cancellables)

        $keyrings
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.syncPreferenceAccounts()
                }
            }
            .store(in: &cancellables)
    }

    private func syncPreferenceAccounts() async {
        let pref = PreferenceManager.shared
        let existingByAddress = Dictionary(uniqueKeysWithValues: pref.accounts.map {
            ($0.address.lowercased(), $0)
        })

        var merged: [PreferenceManager.Account] = []
        var seen = Set<String>()

        for keyring in keyrings {
            let addresses = await keyring.getAccounts()
            for (idx, address) in addresses.enumerated() {
                let lower = address.lowercased()
                guard !seen.contains(lower) else { continue }
                seen.insert(lower)

                let existing = existingByAddress[lower]
                let alias = existing?.aliasName ?? pref.getAlias(address: address)
                merged.append(
                    PreferenceManager.Account(
                        type: keyring.type.rawValue,
                        address: address,
                        brandName: keyring.type.rawValue,
                        aliasName: alias,
                        displayBrandName: existing?.displayBrandName,
                        index: idx,
                        balance: existing?.balance
                    )
                )
            }
        }

        // Keep the last known account snapshot while the wallet is locked.
        if !isUnlocked && keyrings.isEmpty && merged.isEmpty {
            return
        }

        pref.accounts = merged

        let currentLower = currentAccount?.address.lowercased()
        let matchedCurrent = currentLower.flatMap { lower in
            merged.first { $0.address.lowercased() == lower }
        }

        if let matchedCurrent {
            if pref.currentAccount?.address.lowercased() != matchedCurrent.address.lowercased() {
                pref.setCurrentAccount(matchedCurrent)
            } else if pref.currentAccount?.aliasName != matchedCurrent.aliasName {
                pref.currentAccount = matchedCurrent
            }
            return
        }

        if let prefCurrent = pref.currentAccount,
           let matchedPref = merged.first(where: { $0.address.lowercased() == prefCurrent.address.lowercased() }) {
            if let type = KeyringType(rawValue: matchedPref.type) {
                currentAccount = Account(
                    address: matchedPref.address,
                    type: type,
                    brandName: matchedPref.brandName,
                    alianName: matchedPref.aliasName
                )
            }
            pref.currentAccount = matchedPref
            return
        }

        if let first = merged.first {
            if let type = KeyringType(rawValue: first.type) {
                currentAccount = Account(
                    address: first.address,
                    type: type,
                    brandName: first.brandName,
                    alianName: first.aliasName
                )
            }
            pref.setCurrentAccount(first)
        } else if pref.currentAccount != nil {
            pref.currentAccount = nil
        }
    }
}

// MARK: - Keystore (V3) Import

/// Minimal Ethereum keystore v3 decrypter (scrypt/pbkdf2 + aes-128-ctr + keccak256 mac).
/// Used by `KeyringManager.importFromKeystore`.
struct KeystoreV3 {
    static func decryptPrivateKey(json: String, password: String) throws -> Data {
        guard let jsonData = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }
        
        let addressInFile = (root["address"] as? String)?
            .lowercased()
            .replacingOccurrences(of: "0x", with: "")
        
        guard let crypto = (root["crypto"] as? [String: Any]) ?? (root["Crypto"] as? [String: Any]) else {
            throw KeyringError.invalidSerializedData
        }
        
        guard let cipher = (crypto["cipher"] as? String)?.lowercased(),
              cipher == "aes-128-ctr" else {
            throw KeyringError.operationNotSupported
        }
        
        guard let cipherparams = crypto["cipherparams"] as? [String: Any],
              let ivHex = cipherparams["iv"] as? String,
              let iv = Data(hexString: ivHex),
              iv.count == 16 else {
            throw KeyringError.invalidSerializedData
        }
        
        guard let ciphertextHex = crypto["ciphertext"] as? String,
              let ciphertext = Data(hexString: ciphertextHex) else {
            throw KeyringError.invalidSerializedData
        }
        
        guard let kdf = (crypto["kdf"] as? String)?.lowercased(),
              let kdfparams = crypto["kdfparams"] as? [String: Any],
              let dklen = kdfparams["dklen"] as? Int,
              let saltHex = kdfparams["salt"] as? String,
              let salt = Data(hexString: saltHex) else {
            throw KeyringError.invalidSerializedData
        }
        
        let derivedKey: Data
        switch kdf {
        case "scrypt":
            guard let n = kdfparams["n"] as? Int,
                  let r = kdfparams["r"] as? Int,
                  let p = kdfparams["p"] as? Int else {
                throw KeyringError.invalidSerializedData
            }
            let scrypt = try Scrypt(
                password: Array(password.utf8),
                salt: [UInt8](salt),
                dkLen: dklen,
                N: n,
                r: r,
                p: p
            )
            derivedKey = Data(try scrypt.calculate())
            
        case "pbkdf2":
            // Only support hmac-sha256 for now.
            if let prf = (kdfparams["prf"] as? String)?.lowercased(), prf != "hmac-sha256" {
                throw KeyringError.operationNotSupported
            }
            guard let c = kdfparams["c"] as? Int else {
                throw KeyringError.invalidSerializedData
            }
            derivedKey = try PBKDF2.deriveKey(
                password: Data(password.utf8),
                salt: salt,
                iterations: c,
                keyLength: dklen
            )
            
        default:
            throw KeyringError.operationNotSupported
        }
        
        guard derivedKey.count >= 32 else {
            throw KeyringError.invalidSerializedData
        }
        
        // Validate MAC: keccak256(derivedKey[16..32] + ciphertext)
        let macInput = derivedKey.suffix(16) + ciphertext
        let computedMac = Keccak256.hash(data: macInput).hexString.lowercased()
        let storedMac = (crypto["mac"] as? String)?
            .lowercased()
            .replacingOccurrences(of: "0x", with: "")
        
        guard storedMac == computedMac else {
            throw KeyringError.invalidPassword
        }
        
        // Decrypt ciphertext with AES-128-CTR using derivedKey[0..16] as key.
        let aesKey = [UInt8](derivedKey.prefix(16))
        let aes = try AES(
            key: aesKey,
            blockMode: CTR(iv: [UInt8](iv)),
            padding: .noPadding
        )
        let plainBytes = try aes.decrypt([UInt8](ciphertext))
        let privateKey = Data(plainBytes)
        
        guard privateKey.count == 32 else {
            throw KeyringError.invalidSerializedData
        }
        
        // If address is present, ensure it matches the decrypted private key.
        if let expected = addressInFile, !expected.isEmpty {
            let derivedAddr = try EthereumUtil.privateKeyToAddress(privateKey)
                .lowercased()
                .replacingOccurrences(of: "0x", with: "")
            guard derivedAddr == expected else {
                throw KeyringError.invalidSerializedData
            }
        }
        
        return privateKey
    }
}

// MARK: - Errors
enum KeyringError: Error, LocalizedError {
    case invalidMnemonicStrength
    case failedToGenerateMnemonic
    case mnemonicNotSet
    case invalidMnemonic
    case accountNotFound
    case operationNotSupported
    case watchAddressCannotSign
    case invalidSerializedData
    case vaultNotInitialized
    case walletLocked
    case keyringNotFound
    case unsupportedKeyringType
    case invalidOptions
    case invalidPassword
    case vaultSaveFailed

    var errorDescription: String? {
        switch self {
        case .invalidMnemonicStrength:
            return "Invalid mnemonic strength. Must be 128, 160, 192, 224, or 256."
        case .failedToGenerateMnemonic:
            return "Failed to generate secure random bytes for mnemonic."
        case .mnemonicNotSet:
            return "Mnemonic phrase is not set for this keyring."
        case .invalidMnemonic:
            return "Invalid seed phrase. Please check each word is a valid BIP39 word and the phrase has correct checksum."
        case .accountNotFound:
            return "Account not found in any keyring."
        case .operationNotSupported:
            return "This operation is not supported for this keyring type."
        case .watchAddressCannotSign:
            return "Watch addresses cannot sign transactions or messages."
        case .invalidSerializedData:
            return "Invalid serialized keyring data."
        case .vaultNotInitialized:
            return "Wallet vault is not initialized. Create a new wallet first."
        case .walletLocked:
            return "Wallet is locked. Please unlock first."
        case .keyringNotFound:
            return "Keyring not found."
        case .unsupportedKeyringType:
            return "Unsupported keyring type."
        case .invalidOptions:
            return "Invalid options provided."
        case .invalidPassword:
            return "Invalid password."
        case .vaultSaveFailed:
            return "Failed to save wallet vault to secure storage. Please try again."
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let keyringUnlocked = Notification.Name("keyringUnlocked")
    static let keyringLocked = Notification.Name("keyringLocked")
    static let accountRemoved = Notification.Name("accountRemoved")
    static let walletReset = Notification.Name("walletReset")
}
